import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/shuffled_pdf.dart';

/// The shuffled-PDF library: every shuffle the user has generated (current and
/// past), newest first, ready to re-download/share or delete. All offline.
class ShuffledLibraryScreen extends ConsumerWidget {
  const ShuffledLibraryScreen({super.key});

  Future<void> _share(ShuffledPdf pdf) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(pdf.filePath, mimeType: 'application/pdf')],
        subject: AppStrings.sharePdfSubject,
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ShuffledPdf pdf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteFile),
        content: const Text(AppStrings.deleteFileConfirm),
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
    await ref.read(shuffledPdfRepositoryProvider).delete(pdf.id);
    ref.invalidate(shuffledPdfsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfs = ref.watch(shuffledPdfsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.libraryTitle)),
      body: pdfs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const _EmptyLibrary()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, index) => _ShuffledPdfTile(
                  pdf: list[index],
                  onShare: _share,
                  onDelete: (pdf) => _confirmDelete(context, ref, pdf),
                ),
              ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              AppStrings.emptyLibrary,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShuffledPdfTile extends StatelessWidget {
  const _ShuffledPdfTile({
    required this.pdf,
    required this.onShare,
    required this.onDelete,
  });

  final ShuffledPdf pdf;
  final Future<void> Function(ShuffledPdf) onShare;
  final Future<void> Function(ShuffledPdf) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_outlined)),
        title: Text(pdf.examTitle,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_formatDate(pdf.createdAt)} · ${_formatSize(pdf.sizeBytes)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: AppStrings.shareFile,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => onShare(pdf),
            ),
            IconButton(
              tooltip: AppStrings.deleteFile,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(pdf),
            ),
          ],
        ),
        onTap: () => onShare(pdf),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
