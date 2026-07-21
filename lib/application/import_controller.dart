import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/exam.dart';
import 'providers.dart';

/// State of a single PDF import run.
sealed class ImportState {
  const ImportState();
}

class ImportProcessing extends ImportState {
  const ImportProcessing();
}

class ImportSuccess extends ImportState {
  const ImportSuccess(this.exam);

  final Exam exam;
}

class ImportFailure extends ImportState {
  const ImportFailure(this.message);

  final String message;
}

/// Runs the import pipeline (isolate parse + render, then persist) for one
/// picked file. Keyed by (path, title) so re-entering the screen restarts.
class ImportController extends Notifier<ImportState> {
  ImportController(this.request);

  final ({String path, String title}) request;

  @override
  ImportState build() {
    Future.microtask(_run);
    return const ImportProcessing();
  }

  Future<void> _run() async {
    try {
      final exam = await ref.read(examImportServiceProvider).importPdf(
            pdfPath: request.path,
            title: request.title,
            imagesRootDir: ref.read(imagesRootDirProvider),
          );
      await ref.read(examRepositoryProvider).saveExam(exam);
      ref.invalidate(examsProvider);
      if (!ref.mounted) return;
      state = ImportSuccess(exam);
    } on Exception catch (e) {
      if (!ref.mounted) return;
      state = ImportFailure(e.toString());
    }
  }
}

final importControllerProvider = NotifierProvider.autoDispose
    .family<ImportController, ImportState, ({String path, String title})>(
  ImportController.new,
);
