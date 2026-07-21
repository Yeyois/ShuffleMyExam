import '../domain/models/answer.dart';
import '../domain/models/exam.dart';
import '../domain/models/question.dart';
import 'practice_session_controller.dart';

/// One scored mistake: what was picked (if anything) vs. what was correct.
class Mistake {
  const Mistake({
    required this.question,
    required this.selectedAnswer,
    required this.correctAnswer,
  });

  final Question question;

  /// null when the question was left unanswered.
  final Answer? selectedAnswer;

  final Answer correctAnswer;
}

/// Final score for a practice session. Only text (shufflable) questions are
/// scored — visual questions are self-checked by the student.
class PracticeResults {
  const PracticeResults({
    required this.totalScored,
    required this.correctCount,
    required this.mistakes,
  });

  final int totalScored;
  final int correctCount;
  final List<Mistake> mistakes;

  int get percentage =>
      totalScored == 0 ? 0 : ((correctCount / totalScored) * 100).round();

  static PracticeResults from(Exam exam, PracticeSessionState session) {
    var correct = 0;
    final mistakes = <Mistake>[];
    var scored = 0;

    for (final question in exam.questions) {
      if (!question.isShufflable) continue;
      final correctAnswer = question.textAnswers
          .firstWhere((a) => a.isOriginalCorrect);
      scored++;

      final selectedId = session.selectedAnswerIds[question.id];
      Answer? selected;
      if (selectedId != null) {
        selected = question.textAnswers
            .firstWhere((a) => a.id == selectedId);
      }

      if (selected != null && selected.isOriginalCorrect) {
        correct++;
      } else {
        mistakes.add(Mistake(
          question: question,
          selectedAnswer: selected,
          correctAnswer: correctAnswer,
        ));
      }
    }

    return PracticeResults(
      totalScored: scored,
      correctCount: correct,
      mistakes: mistakes,
    );
  }
}
