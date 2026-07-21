import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/import_controller.dart';
import '../../core/constants/app_strings.dart';
import 'practice_screen.dart';

/// Shown while the isolate parses the picked PDF; then a success summary
/// with a "Start Practice" button, or a failure message.
class ProcessingScreen extends ConsumerWidget {
  const ProcessingScreen({super.key, required this.request});

  final ({String path, String title}) request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider(request));

    return Scaffold(
      appBar: AppBar(title: Text(request.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (state) {
            ImportProcessing() => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(AppStrings.processingTitle),
                  SizedBox(height: 8),
                  Text(AppStrings.processingHint,
                      textAlign: TextAlign.center),
                ],
              ),
            ImportSuccess(:final exam) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(AppStrings.extractionSucceeded,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(AppStrings.questionsFound(exam.questions.length)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => PracticeScreen(exam: exam),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(AppStrings.startPractice),
                  ),
                ],
              ),
            ImportFailure(:final message) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(AppStrings.extractionFailed,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center, maxLines: 4),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.backHome),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
