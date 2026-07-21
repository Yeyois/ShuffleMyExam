import 'package:flutter/material.dart';

import '../../application/practice_results.dart';
import '../../application/practice_session_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/exam.dart';

/// Final score plus a breakdown of every mistake (selected answer in red,
/// correct answer in green). Only text questions are scored.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.exam,
    required this.session,
  });

  final Exam exam;
  final PracticeSessionState session;

  static const _wrongRed = Color(0xFFC62828);
  static const _correctGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final results = PracticeResults.from(exam, session);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.resultsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ScoreHeader(results: results),
          const SizedBox(height: 24),
          if (results.mistakes.isEmpty && results.totalScored > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        color: _correctGreen, size: 32),
                    const SizedBox(width: 12),
                    Text(AppStrings.noMistakes,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            )
          else if (results.mistakes.isNotEmpty) ...[
            Text(AppStrings.mistakesTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final mistake in results.mistakes)
              _MistakeCard(mistake: mistake),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_outlined),
            label: const Text(AppStrings.backToHome),
          ),
        ],
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.results});

  final PracticeResults results;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '${results.percentage}%',
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: scheme.primary,
                      fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${results.correctCount} מתוך ${results.totalScored} תשובות נכונות',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.mistake});

  final Mistake mistake;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mistake.question.questionText,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _AnswerRow(
              icon: Icons.cancel_outlined,
              color: ResultsScreen._wrongRed,
              label: AppStrings.yourAnswer,
              text: mistake.selectedAnswer?.text ?? 'לא נבחרה תשובה',
            ),
            const SizedBox(height: 8),
            _AnswerRow(
              icon: Icons.check_circle_outline,
              color: ResultsScreen._correctGreen,
              label: AppStrings.correctAnswer,
              text: mistake.correctAnswer.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: text, style: TextStyle(color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
