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

/// Rasterization scale (~144 dpi at 72pt/inch). Matches the proven visual
/// renderer; sharp enough for a practice printout, modest enough to keep the
/// many per-answer page renders within memory.
const double _renderScale = 2.0;

/// Builds a format-preserving, shuffled copy of the exam at
/// [ShuffledPdfParams.originalPdfPath] and returns the PDF bytes.
///
/// Each original page is rasterized (so no underlying answer text remains to
/// cheat from) and, for every reorderable text question, the answer bands
/// are restacked in a new order and the א/ב/ג/ד bullets restamped in
/// sequence from the original glyph pixels. Visual questions and questions
/// without reorder geometry are left exactly as they were. When
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
  final drawsByPage = <int, List<QuestionReorder>>{};
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

/// Rasterizes [page], reorders any answer bands, and appends the result as a
/// same-size page in [output].
Future<void> _composePage({
  required PdfDocument output,
  required pdfx.PdfPage page,
  required List<QuestionReorder> questions,
}) async {
  final pageW = page.width;
  final pageH = page.height;

  // Render the page ONCE. Every answer band and bullet is then relocated by
  // redrawing this single bitmap offset + clipped to its destination — no
  // per-region re-render (which, at ~2 renders/answer, exhausted pdfx and
  // was very slow).
  final baseImage = await page.render(
    width: pageW * _renderScale,
    height: pageH * _renderScale,
    format: pdfx.PdfPageImageFormat.png,
  );
  if (baseImage == null) return;

  output.pageSettings.margins.all = 0;
  output.pageSettings.size = Size(pageW, pageH);
  final outPage = output.pages.add();
  final g = outPage.graphics;
  final base = PdfBitmap(baseImage.bytes); // one instance, embedded once
  g.drawImage(base, Rect.fromLTWH(0, 0, pageW, pageH));

  for (final q in questions) {
    // Clear the whole answers region, then restack the reordered bands.
    final r = q.region;
    g.drawRectangle(
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(r.left - 1, r.top - 1, r.width + 2, r.height + 2),
    );
    for (final d in q.bands) {
      _blit(g, base, d.source, d.target, pageW, pageH);
    }
    // Restamp bullets in sequence over the moved bands.
    for (final s in q.bullets) {
      final c = s.clear;
      g.drawRectangle(
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(c.left - 1, c.top - 1, c.width + 2, c.height + 2),
      );
      _blit(g, base, s.source, s.target, pageW, pageH);
    }
  }
}

/// Copies the [source] region of the full-page [base] bitmap onto [target] by
/// drawing the whole page translated so `source` lands on `target`, clipped
/// to `target`. Source and target share the same size, so pixels move 1:1
/// with no scaling.
void _blit(PdfGraphics g, PdfBitmap base, PdfBox source, PdfBox target,
    double pageW, double pageH) {
  final state = g.save();
  g.setClip(
    bounds: Rect.fromLTWH(target.left, target.top, target.width, target.height),
  );
  g.drawImage(
    base,
    Rect.fromLTWH(
      target.left - source.left,
      target.top - source.top,
      pageW,
      pageH,
    ),
  );
  g.restore(state);
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
