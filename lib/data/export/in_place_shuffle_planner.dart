import 'dart:math';

import '../parsing/geometry.dart';
import '../parsing/parsed_structures.dart';

/// One answer slot's redraw: clear the original text, then paint a source
/// answer's captured region into this slot. All boxes are in PDF page
/// points (top-left origin) on [QuestionDraw.pageIndex].
class AnswerDraw {
  const AnswerDraw({
    required this.clear,
    required this.source,
    required this.target,
  });

  /// The slot's own original text region, whited out before redrawing.
  final PdfBox clear;

  /// The region of the *original* page to capture (the answer being moved
  /// into this slot).
  final PdfBox source;

  /// Where the captured region is drawn — right-anchored inside the slot so
  /// the text still butts against the (untouched) bullet marker.
  final PdfBox target;
}

/// The in-place redraws for a single shuffled question.
class QuestionDraw {
  const QuestionDraw({required this.pageIndex, required this.answers});

  final int pageIndex;
  final List<AnswerDraw> answers;
}

/// A format-preserving shuffle plan: which answer regions to move on the
/// original pages, plus the answer key for the resulting document.
class InPlaceShufflePlan {
  const InPlaceShufflePlan({required this.questions, required this.answerKey});

  /// Only the questions actually shuffled in place. Visual questions and
  /// text questions that can't be swapped cleanly are absent (their pages
  /// are emitted unchanged).
  final List<QuestionDraw> questions;

  /// 1-based question number → the Hebrew letter now holding the correct
  /// answer. Text questions left untouched map to 'א' (the correct answer
  /// stays first); visual questions map to '—'.
  final Map<int, String> answerKey;
}

/// א, ב, ג, ד, … for a 0-based slot index.
String hebrewLetter(int index) => String.fromCharCode(0x05D0 + index);

/// Plans a fair, in-place shuffle of every shufflable question in
/// [structure] that carries swap geometry.
///
/// The permutation is a plain fair shuffle (every ordering equally likely,
/// including the identity) — matching `shuffleAnswers`, forcing the correct
/// answer out of the first slot would itself leak information. Answers move
/// between slots while the א/ב/ג/ד bullets stay fixed, so the source region
/// for slot j is drawn right-anchored inside slot j.
InPlaceShufflePlan planInPlaceShuffle(
  ParsedExamStructure structure, {
  Random? random,
}) {
  final rng = random ?? Random();
  final questions = <QuestionDraw>[];
  final answerKey = <int, String>{};

  for (var i = 0; i < structure.questions.length; i++) {
    final number = i + 1;
    final q = structure.questions[i];
    final boxes = q.answerTextBoxes;

    if (!q.isShufflable) {
      answerKey[number] = '—';
      continue;
    }
    if (boxes == null || boxes.length < 2) {
      // Left untouched: the correct answer (index 0) stays in slot 0 = א.
      answerKey[number] = hebrewLetter(0);
      continue;
    }

    final slotToAnswer = List<int>.generate(boxes.length, (j) => j)
      ..shuffle(rng);

    final draws = <AnswerDraw>[];
    for (var slot = 0; slot < boxes.length; slot++) {
      final sourceIndex = slotToAnswer[slot];
      final slotBox = boxes[slot];
      final sourceBox = boxes[sourceIndex];
      draws.add(AnswerDraw(
        clear: slotBox,
        source: sourceBox,
        target: PdfBox(
          left: slotBox.right - sourceBox.width,
          top: slotBox.top,
          width: sourceBox.width,
          height: sourceBox.height,
        ),
      ));
      // The originally-correct answer is index 0; record where it landed.
      if (sourceIndex == 0) answerKey[number] = hebrewLetter(slot);
    }

    questions.add(QuestionDraw(pageIndex: q.pageIndex, answers: draws));
  }

  return InPlaceShufflePlan(questions: questions, answerKey: answerKey);
}
