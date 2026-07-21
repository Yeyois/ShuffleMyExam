import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../domain/models/question.dart';

/// Card for a visual (non-shufflable) question.
///
/// SILENT UX RULE: nothing here may hint that the question is not shuffled.
/// The card shows the cropped question image (body + diagram only) by
/// default; the full original image — which exposes the Zero-Exam answers —
/// appears only after the student taps "הצג פתרון מקורי".
class VisualQuestionCard extends StatelessWidget {
  const VisualQuestionCard({
    super.key,
    required this.question,
    required this.showFullImage,
    required this.onToggleFullImage,
  });

  final Question question;
  final bool showFullImage;
  final VoidCallback onToggleFullImage;

  @override
  Widget build(BuildContext context) {
    // Never default to the full image — croppedImageUrl unless toggled.
    final imagePath =
        showFullImage ? question.fullImageUrl : question.croppedImageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: imagePath == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      question.questionText,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (context, error, stack) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(question.questionText),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: onToggleFullImage,
          icon: Icon(showFullImage
              ? Icons.visibility_off_outlined
              : Icons.fact_check_outlined),
          label: Text(showFullImage
              ? AppStrings.showCroppedAgain
              : AppStrings.revealOriginalAnswers),
        ),
      ],
    );
  }
}
