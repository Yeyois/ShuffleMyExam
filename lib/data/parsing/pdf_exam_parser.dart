import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'answer_extractor.dart';
import 'bidi_fixer.dart';
import 'block_classifier.dart';
import 'geometry.dart';
import 'parsed_structures.dart';
import 'question_detector.dart';
import 'smart_cropper.dart';
import 'trailing_bullet_reconstructor.dart';

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

      // Some generators split one visual line into several TextLines (a
      // bold "שאלה" run and the rest of its header, or an orphaned bullet
      // letter). Merge fragments whose vertical extents overlap enough,
      // then keep everything in reading order.
      //
      // Exception: pages with *untrusted geometry* (most lines report the
      // same x for every word also report y-extents that overlap rows that
      // cannot physically overlap). Overlap-merging there combines
      // fragments of DIFFERENT rows and scrambles answer lines — on such
      // pages fragments are kept separate and only sorted by top.
      final untrustedGeometry = _hasUntrustedGeometry(extracted);
      final merged = _mergeFragmentedLines(
        extracted,
        skipMerging: untrustedGeometry,
      );

      // Line text as reported by extractors is unreliable for RTL: word
      // order follows the content stream, not reading order. Reconstruct
      // every line from word geometry in two candidate renderings and let
      // a document-wide vote decide which family reads correctly.
      final logicalCandidates = [
        for (final l in merged) _logicalWordsText(l)
      ];
      final visualCandidates = [
        for (final l in merged) _fixedVisualText(l)
      ];
      final useLogicalWords = ReconstructionArbiter.preferLogicalWords(
        logicalWordCandidates: logicalCandidates,
        visualCharCandidates: visualCandidates,
      );
      final texts = useLogicalWords ? logicalCandidates : visualCandidates;

      final lines = _coalesceSplitHeaders(<LineBox>[
        for (var i = 0; i < merged.length; i++)
          if (!_isTemplateNoise(
              texts[i], merged[i].bounds.top, pageSizes[merged[i].pageIndex]))
            LineBox(
              text: texts[i],
              pageIndex: merged[i].pageIndex,
              bounds: merged[i].bounds,
              words: [
                for (final w in merged[i].words)
                  WordBox(
                    text: w.text,
                    bounds: PdfBox(
                      left: w.bounds.left,
                      top: w.bounds.top,
                      width: w.bounds.width,
                      height: w.bounds.height,
                    ),
                  ),
              ],
            ),
      ]);

      // Find question starts.
      var starts = <({int lineIndex, QuestionStartMatch match})>[];
      for (var i = 0; i < lines.length; i++) {
        final match = QuestionDetector.match(lines[i].text);
        if (match != null) {
          starts.add((lineIndex: i, match: match));
        }
      }

      // A document that consistently uses "שאלה מספר X" headers numbers
      // nothing else that way — bare-number matches on such documents are
      // cover-page or instruction noise.
      final explicitCount = starts.where((s) => s.match.explicit).length;
      if (explicitCount >= 2) {
        starts = starts.where((s) => s.match.explicit).toList();
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
          untrustedGeometry: untrustedGeometry,
        );
        if (draft != null) questions.add(draft);
      }

      return ParsedExamStructure(questions: questions);
    } finally {
      document.dispose();
    }
  }

  /// True when the document's word x-positions are unusable: a large share
  /// of its multi-word Hebrew lines report one x for every word. Such
  /// documents come from one generator — the whole file is affected, and
  /// content-stream order is the only reliable signal. LTR-only lines
  /// (code snippets) are excluded; they always extract with sane order.
  static bool _hasUntrustedGeometry(List<TextLine> extracted) {
    var hebrewLines = 0;
    var degenerate = 0;
    for (final line in extracted) {
      if (line.wordCollection.length < 3) continue;
      if (!line.wordCollection.any((w) => BidiFixer.hasHebrew(w.text))) {
        continue;
      }
      hebrewLines++;
      if (_hasDegenerateGeometry(line.wordCollection)) degenerate++;
    }
    return hebrewLines > 0 && degenerate / hebrewLines > 0.4;
  }

  /// Merges TextLine fragments belonging to one visual line: same page and
  /// vertical overlap of at least 40% of the shorter fragment (different
  /// font sizes on a shared baseline report different tops). Output is
  /// sorted in reading order (page, then top).
  ///
  /// With [skipMerging] (untrusted geometry) lines are only sorted, never
  /// merged — on such documents y-extents routinely overlap across
  /// DIFFERENT rows, so any merge criterion combines unrelated fragments.
  static List<_MergedLine> _mergeFragmentedLines(
    List<TextLine> extracted, {
    bool skipMerging = false,
  }) {
    final byPage = <int, List<TextLine>>{};
    for (final line in extracted) {
      byPage.putIfAbsent(line.pageIndex, () => []).add(line);
    }

    final result = <_MergedLine>[];
    for (final page in byPage.keys.toList()..sort()) {
      final lines = byPage[page]!
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
      _MergedLine? current;
      for (final line in lines) {
        if (!skipMerging &&
            current != null &&
            _overlapsEnough(current.bounds, line.bounds)) {
          current.absorb(line);
        } else {
          current = _MergedLine(line);
          result.add(current);
        }
      }
    }
    return result;
  }

  static bool _overlapsEnough(PdfBox a, Rect b) {
    final overlap = (a.bottom < b.bottom ? a.bottom : b.bottom) -
        (a.top > b.top ? a.top : b.top);
    final minHeight = a.height < b.height ? a.height : b.height;
    if (minHeight <= 0) return false;
    return overlap >= 0.4 * minHeight;
  }

  /// Exam-shell chrome that must not leak into question blocks: page
  /// footers ("עמוד 2 מתוך 6") and the header band at the very top of the
  /// page (form code, "מבחן", "קוד"...). Left inside a block, a footer
  /// both pollutes answer text and fakes a huge vertical gap that flips
  /// text questions to the visual path.
  static final _footer = RegExp(r'^\s*עמוד\s+\d+\s+מתוך\s+\d+\s*$');
  static const _headerBandFraction = 0.07;

  static bool _isTemplateNoise(String text, double top, Size pageSize) {
    if (_footer.hasMatch(text)) return true;
    return top < pageSize.height * _headerBandFraction;
  }

  // Some templates render "שאלה מספר N:" inside a narrow box that wraps
  // into two stacked lines ("שאלה" above "מספר N:"). Rejoin them so the
  // question detector sees the full header.
  static final _bareQuestionWord = RegExp(r'^\s*שאלה\s*$');
  static final _numberFragment = RegExp(r'^\s*מספר\s*:?\s*\d+\s*:?\s*$');

  static List<LineBox> _coalesceSplitHeaders(List<LineBox> lines) {
    final result = <LineBox>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final next = i + 1 < lines.length ? lines[i + 1] : null;
      if (next != null &&
          next.pageIndex == line.pageIndex &&
          _bareQuestionWord.hasMatch(line.text) &&
          _numberFragment.hasMatch(next.text)) {
        result.add(LineBox(
          text: 'שאלה ${next.text.trim()}',
          pageIndex: line.pageIndex,
          bounds: PdfBox(
            left: line.bounds.left < next.bounds.left
                ? line.bounds.left
                : next.bounds.left,
            top: line.bounds.top,
            width: line.bounds.width > next.bounds.width
                ? line.bounds.width
                : next.bounds.width,
            height: next.bounds.bottom - line.bounds.top,
          ),
        ));
        i++;
      } else {
        result.add(line);
      }
    }
    return result;
  }

  /// Candidate A — extractor keeps each word's characters in logical order
  /// (Syncfusion's behavior): assemble words right-to-left by position,
  /// then restore left-to-right order inside runs of consecutive LTR words
  /// (multi-word English/numeric phrases).
  ///
  /// Some templates yield *degenerate geometry*: every word on the line
  /// reports the same left coordinate, so positional sorting is
  /// meaningless. For such lines the content stream itself holds the words
  /// in reverse reading order — reverse it instead of sorting.
  static String _logicalWordsText(_MergedLine line) {
    if (line.words.isEmpty) return line.fallbackText;
    final List<TextWord> words;
    if (_hasDegenerateGeometry(line.words)) {
      words = line.words.reversed.toList();
    } else {
      words = [...line.words]
        ..sort((a, b) => b.bounds.left.compareTo(a.bounds.left));
    }
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
  static String _fixedVisualText(_MergedLine line) {
    String text;
    if (line.words.isEmpty) {
      text = line.fallbackText;
    } else {
      final words = [...line.words]
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

  /// True when the words carry no usable x-positions (all lefts equal).
  static bool _hasDegenerateGeometry(List<TextWord> words) {
    if (words.length < 3) return false;
    var min = words.first.bounds.left;
    var max = min;
    for (final w in words) {
      if (w.bounds.left < min) min = w.bounds.left;
      if (w.bounds.left > max) max = w.bounds.left;
    }
    return max - min < 1.0;
  }

  /// Fill-in blanks ("____") carry no content; questions made only of them
  /// (open-question exams) must not survive parsing.
  static final _underscoreRun = RegExp(r'_{3,}');

  static String _sanitize(String text) =>
      text.replaceAll(_underscoreRun, ' ').replaceAll(RegExp(r'  +'), ' ');

  static ParsedQuestionDraft? _buildQuestion({
    required LineBox startLine,
    required String remainder,
    required List<LineBox> blockLines,
    required List<Size> pageSizes,
    double? nextStartTop,
    bool untrustedGeometry = false,
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
      ...blockTexts.sublist(0, firstBulletIndex ?? blockTexts.length),
    ].map(_sanitize).where((t) => t.trim().isNotEmpty);
    final questionText = questionBodyLines.join('\n').trim();

    // Skip stray matches with no real content (numbered fill-in blanks on
    // open-question pages, orphan numbers).
    if (questionText.isEmpty && extracted.isEmpty) return null;

    // Integrity guard: in a Zero-Exam the correct answer is the "א"
    // bullet. If extraction produced answers but the first one is not א,
    // the real correct answer was lost to layout mangling — flagging a
    // distractor as correct would be worse than falling back to images.
    final firstBulletIsAleph =
        extracted.isEmpty || extracted.first.letter == 'א';

    final isVisual = !firstBulletIsAleph ||
        BlockClassifier.isVisual(
          blockLines: samePageLines,
          answerBulletCount: extracted.length,
        );

    final pageSize = pageSizes[pageIndex];
    final pageWidth = pageSize.width;
    final pageHeight = pageSize.height;

    // Last resort before falling back to an image: on untrusted-geometry
    // documents, leading-bullet extraction fails when bullets are trailing
    // markers ("text ... . א"). Try that layout — but only when normal
    // extraction found nothing, and only when it yields a confident,
    // integrity-preserving result (א flagged correct). Otherwise stay
    // visual.
    if (isVisual && untrustedGeometry && extracted.length < 2) {
      final reconstructed =
          TrailingBulletReconstructor.reconstruct(blockLines);
      if (reconstructed != null) {
        // Truncate the body above the answers so it doesn't re-leak them
        // (trailing-bullet layouts have no leading bullet to cut at).
        final body = [
          if (remainder.isNotEmpty) remainder,
          for (final l in blockLines)
            if (l.bounds.top < reconstructed.firstAnswerTop) l.text,
        ].map(_sanitize).where((t) => t.trim().isNotEmpty).join('\n').trim();

        return ParsedQuestionDraft(
          questionText: body.isEmpty ? questionText : body,
          answers: reconstructed.answers,
          isShufflable: true,
          pageIndex: pageIndex,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
        );
      }
    }

    if (!isVisual) {
      // Geometry for a format-preserving, in-place answer shuffle: each
      // answer's full vertical band plus its bullet glyph. Null when the
      // answers can't be reordered (single answer, cross-page, or an
      // unlocatable bullet) — such questions are left untouched.
      final bands = _computeAnswerBands(
        extracted,
        blockLines,
        pageIndex,
        nextStartTop,
        pageHeight,
      );
      return ParsedQuestionDraft(
        questionText: questionText,
        answers: extracted.map((e) => e.answer).toList(),
        isShufflable: true,
        pageIndex: pageIndex,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        answerBands: bands?.bands,
        answerBullets: bands?.bullets,
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

  // A word that is purely a bullet marker: a letter, a dot/paren, or the
  // two joined ("א", "א.", "."). Used to locate the bullet glyph at the
  // right edge of an answer's first line.
  static final _bulletWord = RegExp(r'^\s*(?:[אבגד]\s*[.)]?|[.)])\s*$');

  /// Breathing room (points) added below the last answer so a wrapped final
  /// line is never clipped by the band's bottom.
  static const _bandBottomPadding = 2.0;

  /// Per-answer vertical bands and bullet-glyph boxes (both parallel to
  /// [extracted]) for a format-preserving, in-place reorder, or null when
  /// the question can't be reordered.
  ///
  /// Each band runs from an answer's bullet line down to the next answer's
  /// bullet line (the last runs to the bottom of its wrapped content), so
  /// the bands tile the answers region with no gaps or overlaps and can be
  /// restacked in any order without reflow. The bands share one horizontal
  /// window (the union of every answer line's extent) so they cover each
  /// other's footprint exactly. Handles multi-line answers of unequal
  /// height; the exporter reorders the bands and restamps the bullets in
  /// sequence from the original pixels.
  ///
  /// Returns null when there are fewer than two answers, an answer's bullet
  /// line is on another page, the bullet tops aren't strictly increasing, or
  /// a bullet glyph can't be located.
  static ({List<PdfBox> bands, List<PdfBox> bullets})? _computeAnswerBands(
    List<ExtractedAnswer> extracted,
    List<LineBox> blockLines,
    int pageIndex,
    double? nextStartTop,
    double pageHeight,
  ) {
    if (extracted.length < 2) return null;

    // Line bounds are unreliable on some RTL PDFs (the extractor reports a
    // line's left > right); word bounds are consistent, so all geometry here
    // is derived from words.
    final bulletTops = <double>[];
    final bulletBoxes = <PdfBox>[];

    final firstBulletLine = extracted.first.lineIndex;
    for (var k = 0; k < extracted.length; k++) {
      final li = extracted[k].lineIndex;
      if (li < 0 || li >= blockLines.length) return null;
      final line = blockLines[li];
      if (line.pageIndex != pageIndex) return null;

      final bullet = _bulletGlyphBox(line);
      final env = _wordEnvelope(line);
      if (bullet == null || env == null) return null;
      bulletBoxes.add(bullet);
      bulletTops.add(env.top);
    }

    // Horizontal window: the union of every answer line (bullets + wrapped
    // continuation) on this page, from the first bullet onward.
    var regionLeft = double.infinity;
    var regionRight = double.negativeInfinity;
    for (var li = firstBulletLine; li < blockLines.length; li++) {
      final line = blockLines[li];
      if (line.pageIndex != pageIndex) continue;
      final env = _wordEnvelope(line);
      if (env == null) continue;
      if (env.left < regionLeft) regionLeft = env.left;
      if (env.right > regionRight) regionRight = env.right;
    }
    if (!regionLeft.isFinite ||
        !regionRight.isFinite ||
        regionRight <= regionLeft) {
      return null;
    }

    // Bullet tops must be strictly increasing for the bands to tile.
    for (var i = 1; i < bulletTops.length; i++) {
      if (bulletTops[i] <= bulletTops[i - 1]) return null;
    }

    // Bottom of the last answer's content on this page.
    var regionBottom = double.negativeInfinity;
    for (var li = extracted.last.lineIndex; li < blockLines.length; li++) {
      final line = blockLines[li];
      if (line.pageIndex != pageIndex) continue;
      final env = _wordEnvelope(line);
      if (env != null && env.bottom > regionBottom) regionBottom = env.bottom;
    }
    if (!regionBottom.isFinite) return null;
    regionBottom += _bandBottomPadding;
    // Never spill past the next question or the page.
    if (nextStartTop != null && nextStartTop < regionBottom) {
      regionBottom = nextStartTop;
    }
    if (regionBottom > pageHeight) regionBottom = pageHeight;
    if (regionBottom <= bulletTops.last) return null;

    final bands = <PdfBox>[];
    for (var i = 0; i < bulletTops.length; i++) {
      final top = bulletTops[i];
      final bottom =
          i + 1 < bulletTops.length ? bulletTops[i + 1] : regionBottom;
      if (bottom <= top) return null;
      bands.add(PdfBox(
        left: regionLeft,
        top: top,
        width: regionRight - regionLeft,
        height: bottom - top,
      ));
    }
    return (bands: bands, bullets: bulletBoxes);
  }

  /// The word-geometry envelope (left/top/right/bottom over all words) of a
  /// [line], or null when it has no words. Preferred over `line.bounds`,
  /// which some RTL PDFs report inverted.
  static ({double left, double top, double right, double bottom})?
      _wordEnvelope(LineBox line) {
    if (line.words.isEmpty) return null;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final w in line.words) {
      if (w.bounds.left < left) left = w.bounds.left;
      if (w.bounds.top < top) top = w.bounds.top;
      if (w.bounds.right > right) right = w.bounds.right;
      if (w.bounds.bottom > bottom) bottom = w.bounds.bottom;
    }
    return (left: left, top: top, right: right, bottom: bottom);
  }

  /// The bullet-glyph box on an answer's first [line] — the rightmost word
  /// that is a bare bullet marker. Null when there are no words, positions
  /// are degenerate (all one x), or no bullet word is present.
  static PdfBox? _bulletGlyphBox(LineBox line) {
    final words = line.words;
    if (words.isEmpty) return null;

    var minLeft = words.first.bounds.left;
    var maxLeft = minLeft;
    for (final w in words) {
      if (w.bounds.left < minLeft) minLeft = w.bounds.left;
      if (w.bounds.left > maxLeft) maxLeft = w.bounds.left;
    }
    if (maxLeft - minLeft < 1.0) return null;

    WordBox? bullet;
    for (final w in words) {
      if (_bulletWord.hasMatch(w.text) &&
          (bullet == null || w.bounds.left > bullet.bounds.left)) {
        bullet = w;
      }
    }
    return bullet?.bounds;
  }
}

/// One visual line assembled from one or more TextLine fragments.
class _MergedLine {
  _MergedLine(TextLine first)
      : pageIndex = first.pageIndex,
        words = [...first.wordCollection],
        fallbackText = first.text,
        bounds = PdfBox(
          left: first.bounds.left,
          top: first.bounds.top,
          width: first.bounds.width,
          height: first.bounds.height,
        );

  final int pageIndex;
  final List<TextWord> words;
  String fallbackText;
  PdfBox bounds;

  void absorb(TextLine line) {
    words.addAll(line.wordCollection);
    fallbackText = '$fallbackText ${line.text}';
    final left = bounds.left < line.bounds.left
        ? bounds.left
        : line.bounds.left;
    final top = bounds.top < line.bounds.top ? bounds.top : line.bounds.top;
    final right =
        bounds.right > line.bounds.right ? bounds.right : line.bounds.right;
    final bottom = bounds.bottom > line.bounds.bottom
        ? bounds.bottom
        : line.bounds.bottom;
    bounds = PdfBox(
        left: left, top: top, width: right - left, height: bottom - top);
  }
}
