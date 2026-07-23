import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/answer_shuffler.dart';
import '../domain/models/answer.dart';
import '../domain/models/exam.dart';

/// Mutable per-practice-session state.
///
/// Answers are shuffled once per session (per the PRD, right before
/// presentation) — never persisted shuffled.
class PracticeSessionState {
  const PracticeSessionState({
    required this.shuffledAnswers,
    this.selectedAnswerIds = const {},
    this.fullImageQuestionIds = const {},
  });

  /// questionId -> answers in this session's presentation order.
  final Map<String, List<Answer>> shuffledAnswers;

  /// questionId -> selected answerId. A question is "answered" (and locked,
  /// with immediate feedback shown) once it has an entry here.
  final Map<String, String> selectedAnswerIds;

  /// Visual questions currently showing the full original image.
  final Set<String> fullImageQuestionIds;

  PracticeSessionState copyWith({
    Map<String, String>? selectedAnswerIds,
    Set<String>? fullImageQuestionIds,
  }) =>
      PracticeSessionState(
        shuffledAnswers: shuffledAnswers,
        selectedAnswerIds: selectedAnswerIds ?? this.selectedAnswerIds,
        fullImageQuestionIds:
            fullImageQuestionIds ?? this.fullImageQuestionIds,
      );
}

class PracticeSessionController extends Notifier<PracticeSessionState> {
  PracticeSessionController(this.exam);

  final Exam exam;

  /// Injectable for deterministic tests.
  static Random Function() randomFactory = Random.new;

  @override
  PracticeSessionState build() {
    final random = randomFactory();
    return PracticeSessionState(
      shuffledAnswers: {
        for (final q in exam.questions)
          if (q.isShufflable)
            q.id: shuffleAnswers(q.textAnswers, random: random),
      },
    );
  }

  /// Commits an answer. Answering is final — once a question has a selection
  /// it is locked so the immediate correct/wrong feedback stays meaningful
  /// and first-attempt scoring is honest.
  void selectAnswer(String questionId, String answerId) {
    if (state.selectedAnswerIds.containsKey(questionId)) return;
    state = state.copyWith(
      selectedAnswerIds: {...state.selectedAnswerIds, questionId: answerId},
    );
  }

  void toggleFullImage(String questionId) {
    final shown = {...state.fullImageQuestionIds};
    shown.contains(questionId) ? shown.remove(questionId) : shown.add(questionId);
    state = state.copyWith(fullImageQuestionIds: shown);
  }
}

final practiceSessionProvider = NotifierProvider.autoDispose
    .family<PracticeSessionController, PracticeSessionState, Exam>(
  PracticeSessionController.new,
);
