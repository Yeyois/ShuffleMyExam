import 'dart:io';

import '../../domain/models/exam.dart';
import 'shuffled_pdf_export_service.dart';

/// Generates a shuffled PDF for an exam and writes it to [outputDir] under a
/// human-readable file name, ready to be handed to the system share/save
/// sheet. Nothing is retained or indexed — the file exists only so the OS can
/// copy it wherever the user chooses. 100% offline.
class ShuffledPdfDownloadService {
  ShuffledPdfDownloadService({
    required this.exportService,
    required this.outputDir,
  });

  final ShuffledPdfExportService exportService;

  /// Scratch directory the generated PDF is written to (a cache/temp dir).
  final String outputDir;

  /// Generates a fresh shuffle of [exam] and returns the written file.
  Future<File> generate(Exam exam) async {
    final bytes = await exportService.generate(exam);

    final dir = Directory(outputDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('${dir.path}/${_fileName(exam.title)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// A safe, human-readable, collision-resistant file name. The timestamp keeps
  /// repeated shuffles of the same exam from overwriting each other, and makes
  /// the name meaningful when the file is shared out of the app.
  String _fileName(String title) {
    final base = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final safeBase = base.isEmpty ? 'exam' : base;
    final now = DateTime.now();
    final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)}'
        '_${_two(now.hour)}-${_two(now.minute)}-${_two(now.second)}';
    return '${safeBase}_shuffled_$stamp.pdf';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
