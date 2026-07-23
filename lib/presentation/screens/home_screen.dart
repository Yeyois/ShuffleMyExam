import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../application/theme_mode_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/motion.dart';
import '../../domain/models/exam.dart';
import '../widgets/bird_trail/bird_trail_layer.dart';
import 'practice_screen.dart';
import 'processing_screen.dart';
import 'shuffled_library_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _importPdf(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(pdfPickerProvider).pickPdf();
    if (picked == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(request: picked),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteExam),
        content: const Text(AppStrings.deleteExamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(examRepositoryProvider).deleteExam(exam.id);
    ref.invalidate(examsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examsProvider);
    final brightness = Theme.of(context).brightness;

    // The free space around the exam cards doubles as a playful canvas: a
    // finger dragged across it trails glowing birds. Cards, the app-bar
    // buttons and the FAB are excluded, so only empty space reacts.
    return BirdTrailLayer(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.homeTitle),
          actions: [
            TrailExclusion(
              child: IconButton(
                tooltip: AppStrings.openLibrary,
                icon: const Icon(Icons.folder_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ShuffledLibraryScreen(),
                  ),
                ),
              ),
            ),
            TrailExclusion(
              child: IconButton(
                tooltip: 'מצב תצוגה',
                icon: Icon(brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () => ref
                    .read(themeModeControllerProvider.notifier)
                    .toggle(brightness),
              ),
            ),
          ],
        ),
        body: exams.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => list.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96, top: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _ExamTile(exam: list[index], onDelete: _confirmDelete)
                          .animate(delay: (index.clamp(0, 10) * 60).ms)
                          .fadeIn(duration: Motion.medium)
                          .slideY(begin: 0.25, curve: Motion.spring)
                          .scaleXY(begin: 0.96, curve: Motion.easeOut),
                ),
        ),
        floatingActionButton: TrailExclusion(
          child: FloatingActionButton.extended(
            onPressed: () => _importPdf(context, ref),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.importExam),
          )
              .animate(delay: 250.ms)
              .slideY(begin: 1.4, curve: Motion.spring, duration: Motion.slow)
              .fadeIn(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                    size: 64, color: Theme.of(context).colorScheme.outline)
                .animate()
                .scaleXY(begin: 0.4, curve: Motion.pop, duration: 800.ms)
                .fadeIn(),
            const SizedBox(height: 16),
            Text(
              AppStrings.emptyHome,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }
}

class _ExamTile extends ConsumerStatefulWidget {
  const _ExamTile({required this.exam, required this.onDelete});

  final Exam exam;
  final Future<void> Function(BuildContext, WidgetRef, Exam) onDelete;

  @override
  ConsumerState<_ExamTile> createState() => _ExamTileState();
}

class _ExamTileState extends ConsumerState<_ExamTile> {
  bool _shuffling = false;

  /// Generates a fresh shuffled PDF for this exam, saves it to the library,
  /// and opens the share sheet.
  Future<void> _shuffle() async {
    if (_shuffling) return;
    setState(() => _shuffling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final record = await ref
          .read(shuffledPdfLibraryServiceProvider)
          .generateAndSave(widget.exam);
      ref.invalidate(shuffledPdfsProvider);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(record.filePath, mimeType: 'application/pdf')],
          subject: AppStrings.sharePdfSubject,
        ),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.exportFailed)),
      );
    } finally {
      if (mounted) setState(() => _shuffling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    // Only offer re-shuffle when the original PDF was retained (older exams
    // imported before retention can't be re-exported).
    final canShuffle = exam.originalPdfPath != null;

    return TrailExclusion(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.quiz_outlined)),
          title: Text(exam.title,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${exam.questions.length} שאלות'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canShuffle)
                IconButton(
                  tooltip: AppStrings.shuffleAgain,
                  icon: _shuffling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shuffle),
                  onPressed: _shuffling ? null : _shuffle,
                ),
              IconButton(
                tooltip: AppStrings.deleteExam,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => widget.onDelete(context, ref, exam),
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PracticeScreen(exam: exam),
            ),
          ),
        ),
      ),
    );
  }
}
