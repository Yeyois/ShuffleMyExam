import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../parsing/geometry.dart';
import '../parsing/pdf_exam_parser.dart';
import 'in_place_shuffle_planner.dart';

/// Isolate-sendable inputs for [buildShuffledExamPdf].
///
/// The exporter edits the *original* PDF ([originalPdfPath]) in place so the
/// output keeps the source's exact formatting — it does not re-typeset the
/// exam. [regularFontBytes]/[boldFontBytes] are used only for the appended
/// answer-key page (Hebrew + Latin coverage, DejaVu Sans). [token] is needed
/// because pdfx rasterizes pages over platform channels, which requires the
/// binary messenger to be initialized inside the isolate.
class ShuffledPdfParams {
  const ShuffledPdfParams({
    required this.originalPdfPath,
    required this.regularFontBytes,
    required this.boldFontBytes,
    this.token,
    this.seed,
    this.includeAnswerKey = true,
  });

  final String originalPdfPath;
  final Uint8List regularFontBytes;
  final Uint8List boldFontBytes;
  final RootIsolateToken? token;

  /// Optional seed so the shuffled document and its answer key stay
  /// consistent and (for tests) reproducible. Null uses a fresh random.
  final int? seed;

  final bool includeAnswerKey;
}

/// Rasterization scale (~180 dpi at 72pt/inch) — sharp enough to print,
/// modest enough to keep page images in memory.
const double _renderScale = 2.5;

/// Builds a format-preserving, shuffled copy of the exam at
/// [ShuffledPdfParams.originalPdfPath] and returns the PDF bytes.
///
/// Each original page is rasterized (so no underlying answer text remains to
/// cheat from) and, for every cleanly-swappable text question, the answer
/// text regions are moved between slots while the א/ב/ג/ד bullets stay put.
/// Visual questions and answers that can't be swapped without overlapping
/// are left exactly as they were. When
/// [ShuffledPdfParams.includeAnswerKey] is set, a final "מפתח תשובות" page
/// lists the correct letter per question.
///
/// Heavy (page rasterization + image compositing) and touches pdfx, so it is
/// designed to run inside `compute()` — see `ShuffledPdfExportService`.
Future<Uint8List> buildShuffledExamPdf(ShuffledPdfParams params) async {
  final token = params.token;
  if (token != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }

  final bytes = await File(params.originalPdfPath).readAsBytes();
  final structure = PdfExamParser.parseBytes(bytes);
  final rng = params.seed == null ? Random() : Random(params.seed);
  final plan = planInPlaceShuffle(structure, random: rng);

  // Group the in-place redraws by page.
  final drawsByPage = <int, List<QuestionDraw>>{};
  for (final q in plan.questions) {
    drawsByPage.putIfAbsent(q.pageIndex, () => []).add(q);
  }

  final output = PdfDocument();
  final source = await pdfx.PdfDocument.openFile(params.originalPdfPath);
  try {
    for (var p = 0; p < source.pagesCount; p++) {
      final page = await source.getPage(p + 1);
      try {
        await _composePage(
          output: output,
          page: page,
          questions: drawsByPage[p] ?? const [],
        );
      } finally {
        await page.close();
      }
    }
  } finally {
    await source.close();
  }

  if (params.includeAnswerKey) {
    _appendAnswerKey(output, plan.answerKey, params);
  }

  final result = Uint8List.fromList(await output.save());
  output.dispose();
  return result;
}

/// Rasterizes [page], applies any answer swaps, and appends the result as a
/// same-size page in [output].
Future<void> _composePage({
  required PdfDocument output,
  required pdfx.PdfPage page,
  required List<QuestionDraw> questions,
}) async {
  final pageW = page.width;
  final pageH = page.height;

  final baseImage = await page.render(
    width: pageW * _renderScale,
    height: pageH * _renderScale,
    format: pdfx.PdfPageImageFormat.png,
    backgroundColor: '#FFFFFF',
  );
  if (baseImage == null) return;

  // Capture every source answer region from the clean original before we
  // touch the output page.
  final crops = <QuestionDraw, List<PdfBitmap>>{};
  for (final q in questions) {
    final captured = <PdfBitmap>[];
    for (final draw in q.answers) {
      final img = await _renderCrop(page, draw.source, pageW, pageH);
      captured.add(PdfBitmap(img));
    }
    crops[q] = captured;
  }

  output.pageSettings.margins.all = 0;
  output.pageSettings.size = Size(pageW, pageH);
  final outPage = output.pages.add();
  final g = outPage.graphics;

  g.drawImage(PdfBitmap(baseImage.bytes), Rect.fromLTWH(0, 0, pageW, pageH));

  for (final q in questions) {
    // Clear every original answer region first, so a source crop that is
    // slightly taller than its slot can't be erased by a later white-out.
    for (final draw in q.answers) {
      final c = draw.clear;
      g.drawRectangle(
        brush: PdfBrushes.white,
        // Inflate away from the (untouched) bullet on the right only.
        bounds: Rect.fromLTWH(c.left - 1, c.top - 1, c.width + 1, c.height + 2),
      );
    }
    final captured = crops[q]!;
    for (var i = 0; i < q.answers.length; i++) {
      final t = q.answers[i].target;
      g.drawImage(captured[i], Rect.fromLTWH(t.left, t.top, t.width, t.height));
    }
  }
}

/// Renders just [box] (PDF points) of [page] to PNG bytes.
Future<Uint8List> _renderCrop(
  pdfx.PdfPage page,
  PdfBox box,
  double pageW,
  double pageH,
) async {
  final img = await page.render(
    width: pageW * _renderScale,
    height: pageH * _renderScale,
    format: pdfx.PdfPageImageFormat.png,
    backgroundColor: '#FFFFFF',
    cropRect: Rect.fromLTWH(
      box.left * _renderScale,
      box.top * _renderScale,
      box.width * _renderScale,
      box.height * _renderScale,
    ),
  );
  if (img == null) {
    throw StateError('answer region render failed');
  }
  return img.bytes;
}

/// Appends the "מפתח תשובות" page listing the correct letter per question.
void _appendAnswerKey(
  PdfDocument document,
  Map<int, String> answerKey,
  ShuffledPdfParams params,
) {
  document.pageSettings.margins.all = 40;
  document.pageSettings.size = const Size(595, 842); // A4
  final page = document.pages.add();
  final size = page.getClientSize();

  final titleFont = PdfTrueTypeFont(params.boldFontBytes, 16);
  final keyFont = PdfTrueTypeFont(params.regularFontBytes, 12);
  final rtl = PdfStringFormat(
    alignment: PdfTextAlignment.right,
    textDirection: PdfTextDirection.rightToLeft,
  );

  final numbers = answerKey.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final n in numbers) {
    buffer.writeln('$n. ${answerKey[n]}');
  }

  page.graphics.drawString('מפתח תשובות', titleFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(0, 0, size.width, 30),
      format: rtl);
  PdfTextElement(
    text: buffer.toString().trimRight(),
    font: keyFont,
    brush: PdfBrushes.black,
    format: rtl,
  ).draw(
    page: page,
    bounds: Rect.fromLTWH(0, 36, size.width, size.height - 36),
    format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
  );
}
