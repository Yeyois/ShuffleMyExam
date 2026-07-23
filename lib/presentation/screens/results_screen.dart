import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../application/practice_results.dart';
import '../../application/practice_session_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/motion.dart';
import '../../domain/models/exam.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/score_ring.dart';

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
    final celebrate = results.totalScored > 0 && results.percentage >= 80;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.resultsTitle)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ScoreHeader(results: results),
              const SizedBox(height: 16),
              _StatsCard(results: results),
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
                    .animate()
                    .fadeIn(duration: Motion.medium)
                    .scaleXY(begin: 0.9, curve: Motion.spring)
              else if (results.mistakes.isNotEmpty) ...[
                Text(AppStrings.mistakesTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < results.mistakes.length; i++)
                  _MistakeCard(mistake: results.mistakes[i])
                      .animate(delay: (500 + i * 90).ms)
                      .fadeIn(duration: Motion.medium)
                      .slideY(begin: 0.2, curve: Motion.spring),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home_outlined),
                label: const Text(AppStrings.backToHome),
              ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.3),
            ],
          ),
          if (celebrate)
            const Positioned.fill(
              child: ConfettiBurst(),
            ),
        ],
      ),
    );
  }
}

/// Headline that matches how well the student did.
String _headline(int percentage) {
  if (percentage >= 90) return 'מצוין! 🎉';
  if (percentage >= 75) return 'כל הכבוד! 👏';
  if (percentage >= 50) return 'יפה מאוד!';
  return 'ממשיכים להתאמן! 💪';
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.results});

  final PracticeResults results;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            ScoreRing(percentage: results.percentage)
                .animate()
                .scaleXY(begin: 0.7, curve: Motion.pop, duration: 900.ms)
                .fadeIn(duration: Motion.fast),
            const SizedBox(height: 16),
            Text(
              _headline(results.percentage),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ).animate(delay: 650.ms).fadeIn().scaleXY(
                  begin: 0.5,
                  curve: Motion.pop,
                  duration: 700.ms,
                ),
            const SizedBox(height: 6),
            Text(
              '${results.correctCount} מתוך ${results.totalScored} תשובות נכונות',
              style: Theme.of(context).textTheme.bodyLarge,
            ).animate(delay: 800.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.results});

  final PracticeResults results;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _StatRow(
        icon: Icons.check_circle,
        color: ResultsScreen._correctGreen,
        label: AppStrings.statCorrect,
        value: results.correctCount,
      ),
      _StatRow(
        icon: Icons.cancel,
        color: ResultsScreen._wrongRed,
        label: AppStrings.statWrong,
        value: results.wrongCount,
      ),
      if (results.unansweredCount > 0)
        _StatRow(
          icon: Icons.remove_circle_outline,
          color: Theme.of(context).colorScheme.outline,
          label: AppStrings.statUnanswered,
          value: results.unansweredCount,
        ),
      if (results.visualCount > 0)
        _StatRow(
          icon: Icons.image_outlined,
          color: Theme.of(context).colorScheme.secondary,
          label: AppStrings.statVisual,
          value: results.visualCount,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.statsTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < rows.length; i++)
              rows[i]
                  .animate(delay: (900 + i * 110).ms)
                  .fadeIn(duration: Motion.medium)
                  .slideX(begin: 0.2, curve: Motion.spring),
          ],
        ),
      ),
    ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.15, curve: Motion.easeOut);
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
        ],
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
