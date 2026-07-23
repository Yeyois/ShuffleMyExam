import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/exam.dart';

/// Generates a shuffled PDF of [exam] and opens the system share sheet so the
/// user can save it (Files/Drive), print, or send it — all offline.
///
/// Shown after a successful import (and reusable elsewhere). Manages its own
/// busy state locally since generation is a one-shot fire-and-share action.
class DownloadShuffledPdfButton extends ConsumerStatefulWidget {
  const DownloadShuffledPdfButton({super.key, required this.exam});

  final Exam exam;

  @override
  ConsumerState<DownloadShuffledPdfButton> createState() =>
      _DownloadShuffledPdfButtonState();
}

class _DownloadShuffledPdfButtonState
    extends ConsumerState<DownloadShuffledPdfButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref
          .read(shuffledPdfDownloadServiceProvider)
          .generate(widget.exam);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: AppStrings.sharePdfSubject,
        ),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.exportFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _onPressed,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
      label: Text(_busy
          ? AppStrings.preparingPdf
          : AppStrings.downloadShuffledPdf),
    );
  }
}
