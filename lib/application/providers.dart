import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/parsing/exam_import_service.dart';
import '../domain/models/exam.dart';
import '../domain/repositories/exam_repository.dart';

/// Bound at bootstrap (see main.dart) once Hive is initialized.
final examRepositoryProvider = Provider<ExamRepository>(
  (ref) => throw UnimplementedError('overridden at bootstrap'),
);

/// Root directory for cropped/full question images; bound at bootstrap.
final imagesRootDirProvider = Provider<String>(
  (ref) => throw UnimplementedError('overridden at bootstrap'),
);

final examImportServiceProvider =
    Provider<ExamImportService>((ref) => const ExamImportService());

/// All saved exams, newest first.
final examsProvider = FutureProvider<List<Exam>>(
  (ref) => ref.watch(examRepositoryProvider).getExams(),
);

/// Thin wrapper around file_picker so widget tests can fake it.
class PdfPickerService {
  const PdfPickerService();

  /// Returns the picked PDF's path and a title derived from its filename,
  /// or null if the user cancelled.
  Future<({String path, String title})?> pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final file = result?.files.singleOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;
    final title =
        file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    return (path: path, title: title.isEmpty ? file.name : title);
  }
}

final pdfPickerProvider =
    Provider<PdfPickerService>((ref) => const PdfPickerService());
