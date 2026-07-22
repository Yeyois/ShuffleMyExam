import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/export/in_place_shuffle_planner.dart';
import 'package:jct_mixexam/data/parsing/geometry.dart';
import 'package:jct_mixexam/data/parsing/parsed_structures.dart';
import 'package:jct_mixexam/domain/models/answer.dart';

/// Four answer rows stacked vertically, right-aligned at x=500, each 100pt
/// wide and 14pt tall — a clean, swappable layout.
List<PdfBox> _rows() => [
      for (var i = 0; i < 4; i++)
        PdfBox(left: 400, top: 100.0 + i * 20, width: 100, height: 14),
    ];

ParsedQuestionDraft _q({
  required bool shufflable,
  List<PdfBox>? boxes,
  int pageIndex = 0,
}) =>
    ParsedQuestionDraft(
      questionText: 'q',
      answers: [
        for (var i = 0; i < (boxes?.length ?? 0); i++)
          Answer(id: 'a$i', text: 't$i', isOriginalCorrect: i == 0),
      ],
      isShufflable: shufflable,
      pageIndex: pageIndex,
      pageWidth: 595,
      pageHeight: 842,
      answerTextBoxes: boxes,
    );

void main() {
  test('shuffles each answer region into exactly one slot, right-anchored',
      () {
    final boxes = _rows();
    final structure = ParsedExamStructure(questions: [
      _q(shufflable: true, boxes: boxes),
    ]);

    final plan = planInPlaceShuffle(structure, random: Random(1));

    expect(plan.questions, hasLength(1));
    final draws = plan.questions.single.answers;
    expect(draws, hasLength(4));

    // Every source region is used exactly once (a true permutation).
    final usedSources = draws.map((d) => d.source.top).toSet();
    expect(usedSources, boxes.map((b) => b.top).toSet());

    for (var slot = 0; slot < draws.length; slot++) {
      final d = draws[slot];
      // The slot is cleared at its own box.
      expect(d.clear.top, boxes[slot].top);
      // Right-anchored: source text still butts against the fixed bullet.
      expect(d.target.right, closeTo(boxes[slot].right, 1e-9));
      expect(d.target.width, d.source.width);
      expect(d.target.top, boxes[slot].top);
    }
  });

  test('answer key reports the letter where the correct answer landed', () {
    final boxes = _rows();
    final structure =
        ParsedExamStructure(questions: [_q(shufflable: true, boxes: boxes)]);

    final plan = planInPlaceShuffle(structure, random: Random(1));

    // Find the slot fed by source index 0 (the correct answer).
    final draws = plan.questions.single.answers;
    final correctSlot =
        draws.indexWhere((d) => d.source.top == boxes[0].top);
    expect(plan.answerKey[1], hebrewLetter(correctSlot));
  });

  test('visual and un-swappable text questions are left untouched', () {
    final structure = ParsedExamStructure(questions: [
      _q(shufflable: false), // visual
      _q(shufflable: true, boxes: null), // multi-line etc. → no geometry
      _q(shufflable: true, boxes: _rows()),
    ]);

    final plan = planInPlaceShuffle(structure, random: Random(3));

    // Only the last question produces redraws.
    expect(plan.questions, hasLength(1));
    // Visual → dash; un-swappable text keeps the correct answer at א.
    expect(plan.answerKey[1], '—');
    expect(plan.answerKey[2], 'א');
    expect(plan.answerKey[3], isNot('—'));
  });

  test('a fair shuffle can leave the correct answer in the first slot', () {
    // Over many seeds the identity permutation occurs — that is deliberate.
    var sawCorrectFirst = false;
    for (var seed = 0; seed < 200 && !sawCorrectFirst; seed++) {
      final structure = ParsedExamStructure(
          questions: [_q(shufflable: true, boxes: _rows())]);
      final plan = planInPlaceShuffle(structure, random: Random(seed));
      if (plan.answerKey[1] == 'א') sawCorrectFirst = true;
    }
    expect(sawCorrectFirst, isTrue,
        reason: 'forcing correct out of slot 0 would leak information');
  });
}
