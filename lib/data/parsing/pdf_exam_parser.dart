import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'answer_extractor.dart';
import 'bidi_fixer.dart';
import 'block_classifier.dart';
import 'geometry.dart';
import 'parsed_structures.dart';
import 'question_detector.dart';
import 'smart_cropper.dart';

/// Pure-Dart structural parser for Zero-Exam PDFs.
///
/// CPU-heavy (PDF load, regex scan, bidi normalization, geometry) — always
/// call through `compute()`; never on the UI thread.
abstract final class PdfExamParser {
  /// Parses [bytes] into question drafts. No rendering happens here.
  static ParsedExamStructure parseBytes(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final pageSizes = [
        for (var i = 0; i < document.pages.count; i++)
          document.pages[i].size,
      ];

      final extracted = PdfTextExtractor(document).extractTextLines();

      // Line text as reported by extractors is unreliable for RTL: word
      // order follows the content stream, not reading order. Reconstruct
      // every line from word geometry in two candidate renderings and let
      // a document-wide vote decide which family reads correctly.
      final logicalCandidates = [
        for (final l in extracted) _logicalWordsText(l)
      ];
      final visualCandidates = [
        for (final l in extracted) _fixedVisualText(l)
      ];
      final useLogicalWords = ReconstructionArbiter.preferLogicalWords(
        logicalWordCandidates: logicalCandidates,
        visualCharCandidates: visualCandidates,
      );
      final texts = useLogicalWords ? logicalCandidates : visualCandidates;

      final lines = [
        for (var i = 0; i < extracted.length; i++)
          LineBox(
            text: texts[i],
            pageIndex: extracted[i].pageIndex,
            bounds: PdfBox(
              left: extracted[i].bounds.left,
              top: extracted[i].bounds.top,
              width: extracted[i].bounds.width,
              height: extracted[i].bounds.height,
            ),
          ),
      ];

      // Find question starts.
      final starts = <({int lineIndex, QuestionStartMatch match})>[];
      for (var i = 0; i < lines.length; i++) {
        final match = QuestionDetector.match(lines[i].text);
        if (match != null) {
          starts.add((lineIndex: i, match: match));
        }
      }

      final questions = <ParsedQuestionDraft>[];
      for (var s = 0; s < starts.length; s++) {
        final start = starts[s];
        final end =
            s + 1 < starts.length ? starts[s + 1].lineIndex : lines.length;

        // Where the next question begins on the same page, if anywhere —
        // graphics leave no text trace, so a visual block must extend down
        // to the next block (or toward the page bottom) to be captured.
        double? nextStartTop;
        if (s + 1 < starts.length) {
          final nextLine = lines[starts[s + 1].lineIndex];
          if (nextLine.pageIndex == lines[start.lineIndex].pageIndex) {
            nextStartTop = nextLine.bounds.top;
          }
        }

        final draft = _buildQuestion(
          startLine: lines[start.lineIndex],
          remainder: start.match.remainder,
          blockLines: lines.sublist(start.lineIndex + 1, end),
          pageSizes: pageSizes,
          nextStartTop: nextStartTop,
        );
        if (draft != null) questions.add(draft);
      }

      return ParsedExamStructure(questions: questions);
    } finally {
      document.dispose();
    }
  }

  /// Candidate A — extractor keeps each word's characters in logical order
  /// (Syncfusion's behavior): assemble words right-to-left by position,
  /// then restore left-to-right order inside runs of consecutive LTR words
  /// (multi-word English/numeric phrases).
  static String _logicalWordsText(TextLine line) {
    if (line.wordCollection.isEmpty) return line.text;
    final words = [...line.wordCollection]
      ..sort((a, b) => b.bounds.left.compareTo(a.bounds.left));
    final tokens = words
        .map((w) => w.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final result = <String>[];
    var i = 0;
    while (i < tokens.length) {
      if (_isLtrToken(tokens[i])) {
        var j = i;
        while (j < tokens.length && _isLtrToken(tokens[j])) {
          j++;
        }
        result.addAll(tokens.sublist(i, j).reversed);
        i = j;
      } else {
        result.add(tokens[i]);
        i++;
      }
    }
    return result.join(' ');
  }

  /// Candidate B — extractor stores glyphs visually (char-reversed Hebrew):
  /// assemble the on-page line left-to-right and run the full bidi fix.
  static String _fixedVisualText(TextLine line) {
    String text;
    if (line.wordCollection.isEmpty) {
      text = line.text;
    } else {
      final words = [...line.wordCollection]
        ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      text = words
          .map((w) => w.text.trim())
          .where((t) => t.isNotEmpty)
          .join(' ');
    }
    return BidiFixer.hasHebrew(text) ? BidiFixer.fixLine(text) : text;
  }

  static bool _isLtrToken(String token) =>
      !BidiFixer.hasHebrew(token) && RegExp(r'[A-Za-z0-9]').hasMatch(token);

  static ParsedQuestionDraft? _buildQuestion({
    required LineBox startLine,
    required String remainder,
    required List<LineBox> blockLines,
    required List<Size> pageSizes,
    double? nextStartTop,
  }) {
    final pageIndex = startLine.pageIndex;
    // Geometry only makes sense within the starting page.
    final samePageLines = [
      startLine,
      ...blockLines.where((l) => l.pageIndex == pageIndex),
    ];

    final blockTexts = blockLines.map((l) => l.text).toList();
    final extracted = AnswerExtractor.extract(blockTexts);
    final firstBulletIndex = AnswerExtractor.firstBulletLineIndex(blockTexts);

    final questionBodyLines = [
      if (remainder.isNotEmpty) remainder,
      ...blockTexts
          .sublist(0, firstBulletIndex ?? blockTexts.length)
          .where((t) => t.trim().isNotEmpty),
    ];
    final questionText = questionBodyLines.join('\n').trim();

    // Skip stray matches with no content at all.
    if (questionText.isEmpty && extracted.isEmpty) return null;

    final isVisual = BlockClassifier.isVisual(
      blockLines: samePageLines,
      answerBulletCount: extracted.length,
    );

    final pageSize = pageSizes[pageIndex];
    final pageWidth = pageSize.width;
    final pageHeight = pageSize.height;

    if (!isVisual) {
      return ParsedQuestionDraft(
        questionText: questionText,
        answers: extracted.map((e) => e.answer).toList(),
        isShufflable: true,
        pageIndex: pageIndex,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      );
    }

    // Path B: compute crop geometry. The first bullet's top Y is looked up
    // on the starting page only.
    double? firstBulletTop;
    if (firstBulletIndex != null &&
        blockLines[firstBulletIndex].pageIndex == pageIndex) {
      firstBulletTop = blockLines[firstBulletIndex].bounds.top;
    }

    var blockTop = samePageLines.first.bounds.top;
    var blockBottom = samePageLines.first.bounds.bottom;
    for (final l in samePageLines) {
      if (l.bounds.top < blockTop) blockTop = l.bounds.top;
      if (l.bounds.bottom > blockBottom) blockBottom = l.bounds.bottom;
    }

    // Graphics below the last text line leave no trace in the text layout;
    // stretch the block down to the next question (or toward the page
    // bottom) so diagrams are never cut off.
    const bottomMargin = 40.0;
    final visualFloor = nextStartTop != null
        ? nextStartTop - 2 * SmartCropper.padding
        : pageHeight - bottomMargin;
    if (visualFloor > blockBottom) blockBottom = visualFloor;

    final boxes = SmartCropper.computeCropBoxes(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      blockTop: blockTop,
      blockBottom: blockBottom,
      firstBulletTop: firstBulletTop,
    );

    return ParsedQuestionDraft(
      questionText: questionText,
      answers: const [],
      isShufflable: false,
      pageIndex: pageIndex,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      fullBox: boxes.full,
      croppedBox: boxes.cropped,
    );
  }
}
