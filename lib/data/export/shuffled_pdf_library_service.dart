import 'dart:io';

import '../../core/utils/id_generator.dart';
import '../../domain/models/exam.dart';
import '../../domain/models/shuffled_pdf.dart';
import '../../domain/repositories/shuffled_pdf_repository.dart';
import 'shuffled_pdf_export_service.dart';

/// Generates a shuffled PDF for an exam, retains it in the app's shuffled-PDF
/// library directory, and records it in the [ShuffledPdfRepository] so it can
/// be re-downloaded later. 100% offline.
class ShuffledPdfLibraryService {
  ShuffledPdfLibraryService({
    required this.exportService,
    required this.repository,
    required this.libraryDir,
  });

  final ShuffledPdfExportService exportService;
  final ShuffledPdfRepository repository;

  /// Directory where retained shuffled PDFs are stored.
  final String libraryDir;

  /// Generates a fresh shuffle of [exam], writes it to [libraryDir] under a
  /// human-readable file name, records it, and returns the saved record.
  Future<ShuffledPdf> generateAndSave(Exam exam) async {
    final bytes = await exportService.generate(exam);

    final dir = Directory(libraryDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final id = generateId();
    final file = File('${dir.path}/${_fileName(exam.title)}');
    await file.writeAsBytes(bytes, flush: true);

    final record = ShuffledPdf(
      id: id,
      examTitle: exam.title,
      filePath: file.path,
      sizeBytes: bytes.length,
      createdAt: DateTime.now(),
    );
    await repository.save(record);
    return record;
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
