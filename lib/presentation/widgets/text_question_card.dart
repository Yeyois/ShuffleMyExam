import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../domain/models/answer.dart';
import '../../domain/models/question.dart';

/// Interactive card for a shufflable text question: selectable answers plus
/// the "reveal correct answer" eye helper.
class TextQuestionCard extends StatelessWidget {
  const TextQuestionCard({
    super.key,
    required this.question,
    required this.answers,
    required this.selectedAnswerId,
    required this.revealCorrect,
    required this.onSelect,
    required this.onToggleReveal,
  });

  final Question question;

  /// Session-shuffled presentation order.
  final List<Answer> answers;

  final String? selectedAnswerId;
  final bool revealCorrect;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleReveal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              question.questionText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final answer in answers) ...[
          _AnswerTile(
            answer: answer,
            selected: answer.id == selectedAnswerId,
            highlightCorrect: revealCorrect && answer.isOriginalCorrect,
            onTap: () => onSelect(answer.id),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onToggleReveal,
            icon: Icon(
                revealCorrect ? Icons.visibility_off : Icons.visibility),
            label: const Text(AppStrings.revealCorrectAnswer),
            style: TextButton.styleFrom(foregroundColor: scheme.secondary),
          ),
        ),
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.answer,
    required this.selected,
    required this.highlightCorrect,
    required this.onTap,
  });

  final Answer answer;
  final bool selected;
  final bool highlightCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const revealGreen = Color(0xFF2E7D32);

    final Color? tileColor;
    final BorderSide side;
    if (highlightCorrect) {
      tileColor = revealGreen.withValues(alpha: 0.15);
      side = const BorderSide(color: revealGreen, width: 2);
    } else if (selected) {
      tileColor = scheme.primaryContainer;
      side = BorderSide(color: scheme.primary, width: 2);
    } else {
      tileColor = null;
      side = BorderSide(color: scheme.outlineVariant);
    }

    return Card(
      margin: EdgeInsets.zero,
      color: tileColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: side,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(answer.text)),
              if (highlightCorrect)
                const Icon(Icons.check_circle, color: revealGreen),
            ],
          ),
        ),
      ),
    );
  }
}
