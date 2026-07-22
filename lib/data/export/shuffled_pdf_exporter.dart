import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/utils/answer_shuffler.dart';
import '../../domain/models/exam.dart';

/// Isolate-sendable inputs for [buildShuffledExamPdf].
///
/// [regularFontBytes]/[boldFontBytes] must be a single TrueType face that
/// covers Hebrew + Latin + digits + punctuation (DejaVu Sans) — syncfusion
/// embeds exactly the font it is given, with no fallback, so a Hebrew-only
/// face would render mixed-script exam text as tofu. Fonts are loaded from
/// the asset bundle on the main isolate and passed in here because
/// `rootBundle` is not available inside a `compute()` isolate.
class ShuffledPdfParams {
  const ShuffledPdfParams({
    required this.exam,
    required this.regularFontBytes,
    required this.boldFontBytes,
    this.seed,
    this.includeAnswerKey = true,
  });

  final Exam exam;
  final Uint8List regularFontBytes;
  final Uint8List boldFontBytes;

  /// Optional seed so the printed form and its answer key stay consistent
  /// and (for tests) reproducible. Null uses a fresh random each run.
  final int? seed;

  final bool includeAnswerKey;
}

/// Builds a printable "shuffled" version of [ShuffledPdfParams.exam] and
/// returns the PDF bytes. Heavy (font embedding + image decode + layout), so
/// it is designed to run inside `compute()` — see `ShuffledPdfExportService`.
///
/// Text questions are emitted with their answers reordered (correct never
/// first, via [shuffleAnswers]) and lettered א/ב/ג/ד. Visual questions are
/// emitted as their cropped body image only (answers omitted — they can't be
/// reshuffled, and the full image would leak the Zero-Exam ordering). When
/// [ShuffledPdfParams.includeAnswerKey] is set, a final "מפתח תשובות" page
/// lists the correct letter per text question (visual questions show "—").
Future<Uint8List> buildShuffledExamPdf(ShuffledPdfParams params) async {
  final exam = params.exam;
  final rng = params.seed == null ? Random() : Random(params.seed);

  final document = PdfDocument();
  document.pageSettings.margins.all = 40;

  final titleFont = PdfTrueTypeFont(params.boldFontBytes, 18);
  final headerFont = PdfTrueTypeFont(params.boldFontBytes, 13);
  final bodyFont = PdfTrueTypeFont(params.regularFontBytes, 12);
  final keyFont = PdfTrueTypeFont(params.regularFontBytes, 12);
  final keyTitleFont = PdfTrueTypeFont(params.boldFontBytes, 16);

  final rtl = PdfStringFormat(
    alignment: PdfTextAlignment.right,
    textDirection: PdfTextDirection.rightToLeft,
  );

  final cursor = _Cursor(document);

  // Title block.
  cursor.drawText(exam.title, titleFont, rtl, spacingAfter: 6);
  cursor.drawText(
    'טופס מעורבב · ${exam.questions.length} שאלות',
    bodyFont,
    rtl,
    spacingAfter: 18,
  );

  // questionNumber -> correct Hebrew letter (or '—' for visual questions).
  final answerKey = <int, String>{};

  for (var i = 0; i < exam.questions.length; i++) {
    final q = exam.questions[i];
    final number = i + 1;

    // Keep a question header from dangling alone at the page bottom.
    cursor.ensureSpace(90);
    cursor.drawText('שאלה $number', headerFont, rtl, spacingAfter: 6);

    if (q.isShufflable && q.textAnswers.length >= 2) {
      if (q.questionText.trim().isNotEmpty) {
        cursor.drawText(q.questionText, bodyFont, rtl, spacingAfter: 8);
      }
      final shuffled = shuffleAnswers(q.textAnswers, random: rng);
      for (var a = 0; a < shuffled.length; a++) {
        final letter = _hebrewLetter(a);
        if (shuffled[a].isOriginalCorrect) answerKey[number] = letter;
        cursor.drawText('$letter. ${shuffled[a].text}', bodyFont, rtl,
            spacingAfter: 4);
      }
    } else {
      // Visual question: cropped body image only, no answers.
      answerKey[number] = '—';
      final drew = cursor.tryDrawImage(q.croppedImageUrl);
      if (!drew && q.questionText.trim().isNotEmpty) {
        cursor.drawText(q.questionText, bodyFont, rtl, spacingAfter: 4);
      }
    }
    cursor.advance(16);
  }

  if (params.includeAnswerKey) {
    cursor.newPage();
    cursor.drawText('מפתח תשובות', keyTitleFont, rtl, spacingAfter: 12);
    for (var i = 0; i < exam.questions.length; i++) {
      final number = i + 1;
      cursor.drawText('$number. ${answerKey[number] ?? '—'}', keyFont, rtl,
          spacingAfter: 4);
    }
  }

  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

/// א, ב, ג, ד, … for a 0-based answer index.
String _hebrewLetter(int index) => String.fromCharCode(0x05D0 + index);

/// A top-of-page write cursor that auto-paginates. All bounds are in
/// client-area coordinates (origin inside the page margins).
class _Cursor {
  _Cursor(this.document) {
    page = document.pages.add();
    _size = page.getClientSize();
  }

  final PdfDocument document;
  late PdfPage page;
  late Size _size;
  double y = 0;

  double get _remaining => _size.height - y;

  void advance(double dy) => y += dy;

  /// Start a fresh page if less than [minHeight] room remains.
  void ensureSpace(double minHeight) {
    if (_remaining < minHeight) newPage();
  }

  void newPage() {
    page = document.pages.add();
    y = 0;
  }

  void drawText(String text, PdfFont font, PdfStringFormat format,
      {double spacingAfter = 0}) {
    // A near-full page can leave no room; paginate manually first.
    if (_remaining < font.height) newPage();
    final element =
        PdfTextElement(text: text, font: font, format: format, brush: PdfBrushes.black);
    final result = element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, _size.width, _size.height - y),
      format: PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
        breakType: PdfLayoutBreakType.fitElement,
      ),
    );
    if (result != null) {
      page = result.page;
      y = result.bounds.bottom + spacingAfter;
    } else {
      y += font.height + spacingAfter;
    }
  }

  /// Draws the image at [path] fit to the content width. Returns false if the
  /// path is null/missing/unreadable so the caller can fall back to text.
  bool tryDrawImage(String? path) {
    if (path == null) return false;
    final Uint8List data;
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      data = file.readAsBytesSync();
    } on Object {
      return false;
    }
    final PdfBitmap bitmap;
    try {
      bitmap = PdfBitmap(data);
    } on Object {
      return false;
    }

    var drawW = _size.width;
    var drawH = bitmap.height * (drawW / bitmap.width);
    if (drawH > _size.height) {
      final s = _size.height / drawH;
      drawW *= s;
      drawH *= s;
    }
    if (_remaining < drawH) newPage();
    final x = (_size.width - drawW) / 2; // centered
    page.graphics.drawImage(bitmap, Rect.fromLTWH(x, y, drawW, drawH));
    y += drawH;
    return true;
  }
}
