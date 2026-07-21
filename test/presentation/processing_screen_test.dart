import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/providers.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/core/errors/exam_parse_exception.dart';
import 'package:jct_mixexam/data/parsing/exam_import_service.dart';
import 'package:jct_mixexam/domain/models/exam.dart';
import 'package:jct_mixexam/presentation/screens/practice_screen.dart';
import 'package:jct_mixexam/presentation/screens/processing_screen.dart';

import '../test_helpers.dart';

class _FakeImportService extends ExamImportService {
  const _FakeImportService({this.exam, this.error});

  final Exam? exam;
  final Exception? error;

  @override
  Future<Exam> importPdf({
    required String pdfPath,
    required String title,
    required String imagesRootDir,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (error != null) throw error!;
    return exam!;
  }
}

const _request = (path: '/tmp/fake.pdf', title: 'מבחן חדש');

void main() {
  testWidgets('shows a progress indicator while parsing, then the summary',
      (tester) async {
    final repo = InMemoryExamRepository();
    await pumpScreen(
      tester,
      home: const ProcessingScreen(request: _request),
      overrides: [
        examRepositoryProvider.overrideWithValue(repo),
        imagesRootDirProvider.overrideWithValue('/tmp/images'),
        examImportServiceProvider.overrideWithValue(
          _FakeImportService(exam: textOnlyExam(title: 'מבחן חדש')),
        ),
      ],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.processingTitle), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.extractionSucceeded), findsOneWidget);
    expect(find.text(AppStrings.questionsFound(1)), findsOneWidget);
    expect(find.text(AppStrings.startPractice), findsOneWidget);

    // The parsed exam was persisted.
    expect(await repo.getExams(), hasLength(1));
  });

  testWidgets('start practice navigates to the practice screen',
      (tester) async {
    await pumpScreen(
      tester,
      home: const ProcessingScreen(request: _request),
      overrides: [
        examRepositoryProvider.overrideWithValue(InMemoryExamRepository()),
        imagesRootDirProvider.overrideWithValue('/tmp/images'),
        examImportServiceProvider.overrideWithValue(
          _FakeImportService(exam: textOnlyExam()),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.startPractice));
    await tester.pumpAndSettle();

    expect(find.byType(PracticeScreen), findsOneWidget);
  });

  testWidgets('shows the failure state when parsing throws', (tester) async {
    await pumpScreen(
      tester,
      home: const ProcessingScreen(request: _request),
      overrides: [
        examRepositoryProvider.overrideWithValue(InMemoryExamRepository()),
        imagesRootDirProvider.overrideWithValue('/tmp/images'),
        examImportServiceProvider.overrideWithValue(
          const _FakeImportService(
              error: ExamParseException('no questions found in document')),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.extractionFailed), findsOneWidget);
    expect(find.textContaining('no questions found'), findsOneWidget);
    expect(find.text(AppStrings.backHome), findsOneWidget);
  });
}
