import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/export/in_place_shuffle_planner.dart';
import 'package:jct_mixexam/data/parsing/geometry.dart';
import 'package:jct_mixexam/data/parsing/parsed_structures.dart';
import 'package:jct_mixexam/domain/models/answer.dart';

/// Four contiguous answer bands of *unequal* height (single- and two-line
/// answers) right-aligned at x=512, tiling [100, 184).
const _heights = [14.0, 28.0, 14.0, 28.0];

List<PdfBox> _bands() {
  final out = <PdfBox>[];
  var top = 100.0;
  for (final h in _heights) {
    out.add(PdfBox(left: 400, top: top, width: 112, height: h));
    top += h;
  }
  return out;
}

List<PdfBox> _bullets() => [
      for (final b in _bands())
        PdfBox(left: 496, top: b.top + 1, width: 12, height: 12),
    ];

ParsedQuestionDraft _q({
  required bool shufflable,
  bool withGeometry = false,
  int pageIndex = 0,
}) =>
    ParsedQuestionDraft(
      questionText: 'q',
      answers: [
        for (var i = 0; i < (withGeometry ? 4 : 0); i++)
          Answer(id: 'a$i', text: 't$i', isOriginalCorrect: i == 0),
      ],
      isShufflable: shufflable,
      pageIndex: pageIndex,
      pageWidth: 595,
      pageHeight: 842,
      answerBands: withGeometry ? _bands() : null,
      answerBullets: withGeometry ? _bullets() : null,
    );

void main() {
  test('restacks every band once, tiling the region top-down', () {
    final structure =
        ParsedExamStructure(questions: [_q(shufflable: true, withGeometry: true)]);

    final plan = planInPlaceShuffle(structure, random: Random(1));
    expect(plan.questions, hasLength(1));
    final q = plan.questions.single;

    // Region spans the full tiled height.
    expect(q.region.top, 100);
    expect(q.region.bottom, closeTo(184, 1e-9));

    // Each source band is used exactly once (a true permutation).
    expect(q.bands.map((b) => b.source.top).toSet(),
        _bands().map((b) => b.top).toSet());

    // Targets tile contiguously from the region top with no gaps/overlaps.
    expect(q.bands.first.target.top, 100);
    for (var i = 0; i < q.bands.length; i++) {
      final d = q.bands[i];
      expect(d.target.height, d.source.height, reason: 'bands keep height');
      if (i > 0) {
        expect(d.target.top, closeTo(q.bands[i - 1].target.bottom, 1e-9));
      }
    }
    expect(q.bands.last.target.bottom, closeTo(184, 1e-9));
  });

  test('restamps sequential bullets right-anchored over the moved bands', () {
    final structure =
        ParsedExamStructure(questions: [_q(shufflable: true, withGeometry: true)]);
    final plan = planInPlaceShuffle(structure, random: Random(2));
    final q = plan.questions.single;

    expect(q.bullets, hasLength(4));
    final bullets = _bullets();
    for (var slot = 0; slot < 4; slot++) {
      final s = q.bullets[slot];
      // Slot j is stamped with the original glyph of answer j (= letter j).
      expect(s.source.top, bullets[slot].top);
      expect(s.source.left, bullets[slot].left);
      // Drawn right-anchored to the cleared (moved) bullet.
      expect(s.target.right, closeTo(s.clear.right, 1e-9));
      // The cleared bullet sits at the top of this slot's band.
      expect(s.clear.top, closeTo(q.bands[slot].target.top + 1, 1e-9));
    }
  });

  test('answer key reports the letter where the correct answer landed', () {
    final structure =
        ParsedExamStructure(questions: [_q(shufflable: true, withGeometry: true)]);
    final plan = planInPlaceShuffle(structure, random: Random(1));
    final q = plan.questions.single;

    // The correct answer is source index 0; find the slot it moved to.
    final correctSlot =
        q.bands.indexWhere((b) => b.source.top == _bands()[0].top);
    expect(plan.answerKey[1], hebrewLetter(correctSlot));
  });

  test('visual and geometry-less text questions are left untouched', () {
    final structure = ParsedExamStructure(questions: [
      _q(shufflable: false),
      _q(shufflable: true, withGeometry: false),
      _q(shufflable: true, withGeometry: true),
    ]);

    final plan = planInPlaceShuffle(structure, random: Random(3));

    expect(plan.questions, hasLength(1));
    expect(plan.answerKey[1], '—');
    expect(plan.answerKey[2], 'א');
    expect(plan.answerKey[3], isNot('—'));
  });

  test('a fair shuffle can leave the correct answer in the first slot', () {
    var sawCorrectFirst = false;
    for (var seed = 0; seed < 200 && !sawCorrectFirst; seed++) {
      final structure = ParsedExamStructure(
          questions: [_q(shufflable: true, withGeometry: true)]);
      final plan = planInPlaceShuffle(structure, random: Random(seed));
      if (plan.answerKey[1] == 'א') sawCorrectFirst = true;
    }
    expect(sawCorrectFirst, isTrue,
        reason: 'forcing correct out of slot 0 would leak information');
  });
}
