import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/core/errors/exam_parse_exception.dart';
import 'package:jct_mixexam/data/parsing/exam_import_service.dart';
import 'package:jct_mixexam/data/parsing/parsed_structures.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('import_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('parseExamEntry via compute()', () {
    test('parses a text-only exam in a background isolate', () async {
      final pdfPath = '${tempDir.path}/exam.pdf';
      await File(pdfPath).writeAsBytes(PdfFixtures.textOnlyExam());

      final result = await compute(
          parseExamEntry, <String, dynamic>{'path': pdfPath});

      final structure = ParsedExamStructure.fromJson(result);
      expect(structure.questions, hasLength(2));
      expect(structure.questions.every((q) => q.isShufflable), isTrue);
    });
  });

  group('ExamImportService', () {
    test('builds a complete Exam from a text-only PDF', () async {
      final pdfPath = '${tempDir.path}/exam.pdf';
      await File(pdfPath).writeAsBytes(PdfFixtures.textOnlyExam());

      final exam = await const ExamImportService().importPdf(
        pdfPath: pdfPath,
        title: 'מבחן לדוגמה',
        imagesRootDir: '${tempDir.path}/images',
      );

      expect(exam.title, 'מבחן לדוגמה');
      expect(exam.questions, hasLength(2));
      expect(exam.questions[0].isShufflable, isTrue);
      expect(exam.questions[0].textAnswers, hasLength(4));
      expect(exam.questions[0].textAnswers.first.isOriginalCorrect, isTrue);
      expect(exam.questions[0].croppedImageUrl, isNull);
      expect(exam.questions[0].fullImageUrl, isNull);
      expect(exam.id, isNotEmpty);
      expect(exam.questions.map((q) => q.id).toSet(), hasLength(2),
          reason: 'question ids must be unique');

      // The original PDF is retained so the exporter can shuffle it in place.
      expect(exam.originalPdfPath, isNotNull);
      expect(File(exam.originalPdfPath!).existsSync(), isTrue);
      expect(File(exam.originalPdfPath!).lengthSync(),
          File(pdfPath).lengthSync());
    });

    test('throws ExamParseException when no questions are found', () async {
      final document = PdfDocument();
      document.pages.add();
      final pdfPath = '${tempDir.path}/empty.pdf';
      await File(pdfPath).writeAsBytes(document.saveSync());
      document.dispose();

      expect(
        () => const ExamImportService().importPdf(
          pdfPath: pdfPath,
          title: 'ריק',
          imagesRootDir: '${tempDir.path}/images',
        ),
        throwsA(isA<ExamParseException>()),
      );
    });
  });
}
