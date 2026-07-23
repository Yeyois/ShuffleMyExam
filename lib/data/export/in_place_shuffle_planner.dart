import 'dart:math';

import '../parsing/geometry.dart';
import '../parsing/parsed_structures.dart';

/// Moves one answer's whole vertical band to a new position.
class BandDraw {
  const BandDraw({required this.source, required this.target});

  /// The band's region on the original page.
  final PdfBox source;

  /// Where it is redrawn (same width/height, new top).
  final PdfBox target;
}

/// Restamps a sequential bullet glyph (א, ב, …) over a moved band, using the
/// original bullet pixels so the font matches exactly.
class BulletStamp {
  const BulletStamp({
    required this.clear,
    required this.source,
    required this.target,
  });

  /// The moved band's own (now out-of-sequence) bullet, whited out first.
  final PdfBox clear;

  /// The region of the *original* page holding the correct sequential
  /// bullet glyph for this slot.
  final PdfBox source;

  /// Where that glyph is drawn — right-anchored to the cleared bullet so it
  /// lines up with the answer text indent.
  final PdfBox target;
}

/// The in-place reorder for a single shuffled question: clear the answers
/// region, restack the answer bands, then restamp the bullets in order.
class QuestionReorder {
  const QuestionReorder({
    required this.pageIndex,
    required this.region,
    required this.bands,
    required this.bullets,
  });

  final int pageIndex;

  /// The whole answers region, whited out before the bands are restacked.
  final PdfBox region;

  /// Band moves, in final top-to-bottom order.
  final List<BandDraw> bands;

  /// Sequential bullet restamps, parallel to [bands].
  final List<BulletStamp> bullets;
}

/// A format-preserving shuffle plan.
class InPlaceShufflePlan {
  const InPlaceShufflePlan({required this.questions, required this.answerKey});

  /// Only the questions actually reordered. Visual questions and text
  /// questions without reorder geometry are absent (pages emitted unchanged).
  final List<QuestionReorder> questions;

  /// 1-based question number → the Hebrew letter now holding the correct
  /// answer. Text questions left untouched map to 'א' (correct stays first);
  /// visual questions map to '—'.
  final Map<int, String> answerKey;
}

/// א, ב, ג, ד, … for a 0-based slot index.
String hebrewLetter(int index) => String.fromCharCode(0x05D0 + index);

/// Plans a fair, in-place shuffle of every shufflable question in
/// [structure] that carries reorder geometry.
///
/// Each answer's whole band is restacked in a new order (a plain fair
/// shuffle — the identity is allowed, matching `shuffleAnswers`, because
/// forcing the correct answer out of the first slot would itself leak
/// information). The bands tile the same region, so no surrounding content
/// moves. Bullets are then restamped in sequence (slot 0 → א, …) from the
/// original glyph pixels, so the correct answer is not given away by keeping
/// the "א" label.
InPlaceShufflePlan planInPlaceShuffle(
  ParsedExamStructure structure, {
  Random? random,
}) {
  final rng = random ?? Random();
  final questions = <QuestionReorder>[];
  final answerKey = <int, String>{};

  for (var i = 0; i < structure.questions.length; i++) {
    final number = i + 1;
    final q = structure.questions[i];

    if (!q.isShufflable) {
      answerKey[number] = '—';
      continue;
    }
    final bands = q.answerBands;
    final bullets = q.answerBullets;
    if (bands == null ||
        bullets == null ||
        bands.length < 2 ||
        bullets.length != bands.length) {
      // Left untouched: the correct answer (index 0) stays in slot 0 = א.
      answerKey[number] = hebrewLetter(0);
      continue;
    }

    final n = bands.length;
    final slotToAnswer = List<int>.generate(n, (j) => j)..shuffle(rng);

    var regionBottom = bands.first.bottom;
    for (final b in bands) {
      if (b.bottom > regionBottom) regionBottom = b.bottom;
    }
    final region = PdfBox(
      left: bands.first.left,
      top: bands.first.top,
      width: bands.first.width,
      height: regionBottom - bands.first.top,
    );

    final bandDraws = <BandDraw>[];
    final stamps = <BulletStamp>[];
    var cursorY = bands.first.top;
    for (var slot = 0; slot < n; slot++) {
      final a = slotToAnswer[slot];
      final band = bands[a];
      bandDraws.add(BandDraw(
        source: band,
        target: PdfBox(
          left: band.left,
          top: cursorY,
          width: band.width,
          height: band.height,
        ),
      ));

      // The moved band still carries answer a's own bullet; find where it
      // lands and cover it with the correct sequential glyph.
      final movedBulletTop = cursorY + (bullets[a].top - band.top);
      final moved = PdfBox(
        left: bullets[a].left,
        top: movedBulletTop,
        width: bullets[a].width,
        height: bullets[a].height,
      );
      final src = bullets[slot];
      stamps.add(BulletStamp(
        clear: moved,
        source: src,
        target: PdfBox(
          left: moved.right - src.width,
          top: movedBulletTop,
          width: src.width,
          height: src.height,
        ),
      ));

      if (a == 0) answerKey[number] = hebrewLetter(slot);
      cursorY += band.height;
    }

    questions.add(QuestionReorder(
      pageIndex: q.pageIndex,
      region: region,
      bands: bandDraws,
      bullets: stamps,
    ));
  }

  return InPlaceShufflePlan(questions: questions, answerKey: answerKey);
}
