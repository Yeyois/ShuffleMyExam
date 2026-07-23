import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/practice_session_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/motion.dart';
import '../../domain/models/exam.dart';
import '../../domain/models/question.dart';
import '../widgets/text_question_card.dart';
import '../widgets/visual_question_card.dart';
import 'results_screen.dart';

/// Swipeable-card practice flow. Both question types render inside the
/// same page/card chrome so nothing visually separates shuffled from
/// non-shuffled questions (Silent UX rule).
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.exam});

  final Exam exam;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  /// How long the correct-answer feedback stays on screen before the flow
  /// moves on by itself — long enough for the tile pop and banner to land.
  static const _autoAdvanceDelay = Duration(milliseconds: 1100);

  final _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _autoAdvanceTimer?.cancel();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  /// Commits the answer and, when it is the correct one, schedules a hands-free
  /// jump to the next question. A wrong pick stays put so the user can study
  /// the highlighted correct answer.
  void _selectAnswer(Question question, int index, String answerId) {
    ref
        .read(practiceSessionProvider(widget.exam).notifier)
        .selectAnswer(question.id, answerId);

    final correct = question.textAnswers
        .any((a) => a.id == answerId && a.isOriginalCorrect);
    final isLast = index == widget.exam.questions.length - 1;
    if (!correct || isLast) return;

    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, () {
      // Skip if the user already navigated away themselves.
      if (!mounted || _currentPage != index) return;
      _goToPage(index + 1);
    });
  }

  void _openResults(Exam exam) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(
          exam: exam,
          session: ref.read(practiceSessionProvider(exam)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final session = ref.watch(practiceSessionProvider(exam));
    final controller = ref.read(practiceSessionProvider(exam).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(exam.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.questionOf(
                    _currentPage + 1, exam.questions.length),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProgressBar(
                  value: (_currentPage + 1) / exam.questions.length,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: exam.questions.length,
        onPageChanged: (page) {
          _autoAdvanceTimer?.cancel();
          setState(() => _currentPage = page);
        },
        itemBuilder: (context, index) {
          final question = exam.questions[index];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: question.isShufflable
                ? TextQuestionCard(
                    question: question,
                    answers: session.shuffledAnswers[question.id] ?? const [],
                    selectedAnswerId:
                        session.selectedAnswerIds[question.id],
                    onSelect: (answerId) =>
                        _selectAnswer(question, index, answerId),
                  )
                : VisualQuestionCard(
                    question: question,
                    showFullImage:
                        session.fullImageQuestionIds.contains(question.id),
                    onToggleFullImage: () =>
                        controller.toggleFullImage(question.id),
                  ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _NavBar(
            isFirst: _currentPage == 0,
            isLast: _currentPage == exam.questions.length - 1,
            onPrevious: () => _goToPage(_currentPage - 1),
            onNext: () => _goToPage(_currentPage + 1),
            onFinish: () => _openResults(exam),
          ),
        ),
      ),
    );
  }
}

/// Previous / Next controls. On the last question, Next becomes the "finish
/// and show score" action.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.isFirst,
    required this.isLast,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final bool isFirst;
  final bool isLast;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: isFirst ? null : onPrevious,
          icon: const Icon(Icons.arrow_back), // mirrors → points right in RTL
          label: const Text(AppStrings.previousQuestion),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isLast
              ? FilledButton.icon(
                  onPressed: onFinish,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text(AppStrings.finishPractice),
                )
              : FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward), // → left in RTL
                  label: const Text(AppStrings.nextQuestion),
                ),
        ),
      ],
    );
  }
}

/// A rounded progress bar whose fill glides to [value] whenever it changes.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: Motion.medium,
        curve: Motion.easeOut,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 8,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      ),
    );
  }
}
