import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/practice_session_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/exam.dart';
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
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppStrings.questionOf(
                  _currentPage + 1, exam.questions.length),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: exam.questions.length,
        onPageChanged: (page) => setState(() => _currentPage = page),
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
                    revealCorrect:
                        session.revealedQuestionIds.contains(question.id),
                    onSelect: (answerId) =>
                        controller.selectAnswer(question.id, answerId),
                    onToggleReveal: () =>
                        controller.toggleReveal(question.id),
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
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ResultsScreen(
                  exam: exam,
                  session: ref.read(practiceSessionProvider(exam)),
                ),
              ),
            ),
            icon: const Icon(Icons.flag_outlined),
            label: const Text(AppStrings.finishPractice),
          ),
        ),
      ),
    );
  }
}
