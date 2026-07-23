import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../domain/models/answer.dart';
import '../../domain/models/question.dart';

const _correctGreen = Color(0xFF2E7D32);
const _wrongRed = Color(0xFFC62828);

/// Interactive card for a shufflable text question.
///
/// Answering is a one-shot commit: as soon as a tile is tapped the card
/// locks and gives immediate feedback — the picked answer turns green
/// (correct) or red (wrong), and the correct answer is always highlighted
/// green with a check.
class TextQuestionCard extends StatelessWidget {
  const TextQuestionCard({
    super.key,
    required this.question,
    required this.answers,
    required this.selectedAnswerId,
    required this.onSelect,
  });

  final Question question;

  /// Session-shuffled presentation order.
  final List<Answer> answers;

  final String? selectedAnswerId;
  final ValueChanged<String> onSelect;

  bool get _answered => selectedAnswerId != null;

  bool get _answeredCorrectly =>
      _answered &&
      answers.any((a) => a.id == selectedAnswerId && a.isOriginalCorrect);

  @override
  Widget build(BuildContext context) {
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
            answered: _answered,
            onTap: _answered ? null : () => onSelect(answer.id),
          ),
          const SizedBox(height: 8),
        ],
        if (_answered) ...[
          const SizedBox(height: 4),
          _FeedbackBanner(correct: _answeredCorrectly),
        ],
      ],
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct ? _correctGreen : _wrongRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              correct ? AppStrings.answerCorrect : AppStrings.answerWrong,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          if (!correct)
            Flexible(
              child: Text(
                AppStrings.correctAnswerIs,
                style: TextStyle(color: color, fontSize: 12),
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.answer,
    required this.selected,
    required this.answered,
    required this.onTap,
  });

  final Answer answer;
  final bool selected;
  final bool answered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Feedback state: after answering, the correct answer is green and a
    // wrong pick is red; before answering, only the current selection is
    // emphasized.
    final showCorrect = answered && answer.isOriginalCorrect;
    final showWrongPick = answered && selected && !answer.isOriginalCorrect;

    final Color? tileColor;
    final BorderSide side;
    final Widget? trailing;
    if (showCorrect) {
      tileColor = _correctGreen.withValues(alpha: 0.15);
      side = const BorderSide(color: _correctGreen, width: 2);
      trailing = const Icon(Icons.check_circle, color: _correctGreen);
    } else if (showWrongPick) {
      tileColor = _wrongRed.withValues(alpha: 0.12);
      side = const BorderSide(color: _wrongRed, width: 2);
      trailing = const Icon(Icons.cancel, color: _wrongRed);
    } else if (selected) {
      tileColor = scheme.primaryContainer;
      side = BorderSide(color: scheme.primary, width: 2);
      trailing = null;
    } else {
      tileColor = null;
      side = BorderSide(color: scheme.outlineVariant);
      trailing = null;
    }

    final IconData leadingIcon;
    final Color leadingColor;
    if (showCorrect) {
      leadingIcon = Icons.radio_button_checked;
      leadingColor = _correctGreen;
    } else if (showWrongPick) {
      leadingIcon = Icons.radio_button_checked;
      leadingColor = _wrongRed;
    } else if (selected) {
      leadingIcon = Icons.radio_button_checked;
      leadingColor = scheme.primary;
    } else {
      leadingIcon = Icons.radio_button_unchecked;
      leadingColor = scheme.outline;
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
              Icon(leadingIcon, size: 20, color: leadingColor),
              const SizedBox(width: 12),
              Expanded(child: Text(answer.text)),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
