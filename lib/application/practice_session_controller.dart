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
    this.revealedQuestionIds = const {},
    this.fullImageQuestionIds = const {},
  });

  /// questionId -> answers in this session's presentation order.
  final Map<String, List<Answer>> shuffledAnswers;

  /// questionId -> selected answerId.
  final Map<String, String> selectedAnswerIds;

  /// Text questions whose correct answer is currently highlighted.
  final Set<String> revealedQuestionIds;

  /// Visual questions currently showing the full original image.
  final Set<String> fullImageQuestionIds;

  PracticeSessionState copyWith({
    Map<String, String>? selectedAnswerIds,
    Set<String>? revealedQuestionIds,
    Set<String>? fullImageQuestionIds,
  }) =>
      PracticeSessionState(
        shuffledAnswers: shuffledAnswers,
        selectedAnswerIds: selectedAnswerIds ?? this.selectedAnswerIds,
        revealedQuestionIds: revealedQuestionIds ?? this.revealedQuestionIds,
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

  void selectAnswer(String questionId, String answerId) {
    state = state.copyWith(
      selectedAnswerIds: {...state.selectedAnswerIds, questionId: answerId},
    );
  }

  void toggleReveal(String questionId) {
    final revealed = {...state.revealedQuestionIds};
    revealed.contains(questionId)
        ? revealed.remove(questionId)
        : revealed.add(questionId);
    state = state.copyWith(revealedQuestionIds: revealed);
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
