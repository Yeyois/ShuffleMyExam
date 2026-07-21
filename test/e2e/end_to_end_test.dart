import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/providers.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/data/parsing/exam_import_service.dart';
import 'package:jct_mixexam/data/parsing/parsed_structures.dart';
import 'package:jct_mixexam/main.dart';
import 'package:jct_mixexam/presentation/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/parsing/pdf_fixtures.dart';
import '../test_helpers.dart';

/// Uses the REAL parse isolate; only the pdfx render stage (which needs a
/// device) is replaced with tiny placeholder PNGs.
class _HostRenderImportService extends ExamImportService {
  const _HostRenderImportService();

  @override
  Future<Map<String, Map<String, String>>> renderVisualQuestions({
    required ParsedExamStructure structure,
    required String pdfPath,
    required String imagesDir,
  }) async {
    final images = <String, Map<String, String>>{};
    await Directory(imagesDir).create(recursive: true);
    for (var i = 0; i < structure.questions.length; i++) {
      if (structure.questions[i].isShufflable) continue;
      final cropped = File('$imagesDir/q${i}_cropped.png')
        ..writeAsBytesSync(kTinyPng);
      final full = File('$imagesDir/q${i}_full.png')
        ..writeAsBytesSync(kTinyPng);
      images['$i'] = {'cropped': cropped.path, 'full': full.path};
    }
    return images;
  }
}

class _FakePicker extends PdfPickerService {
  const _FakePicker(this.path, this.title);

  final String path;
  final String title;

  @override
  Future<({String path, String title})?> pickPdf() async =>
      (path: path, title: title);
}

void main() {
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('e2e');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpApp(WidgetTester tester, String pdfPath,
      InMemoryExamRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          examRepositoryProvider.overrideWithValue(repo),
          imagesRootDirProvider.overrideWithValue('${tempDir.path}/images'),
          examImportServiceProvider
              .overrideWithValue(const _HostRenderImportService()),
          pdfPickerProvider
              .overrideWithValue(_FakePicker(pdfPath, 'מבחן אמיתי')),
        ],
        child: const MixExamApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the FAB and lets the real parse isolate finish. pumpAndSettle
  /// cannot be used while the indefinite progress spinner animates, so poll
  /// with real-async slices until the import state resolves.
  Future<void> importViaFab(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (var i = 0;
        i < 100 && tester.any(find.byType(CircularProgressIndicator));
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the parse isolate never reported back');
    await tester.pumpAndSettle();
  }

  testWidgets(
      'E2E text-only PDF: import -> parse -> practice -> results -> home',
      (tester) async {
    final pdfPath = '${tempDir.path}/exam.pdf';
    File(pdfPath).writeAsBytesSync(PdfFixtures.textOnlyExam());
    final repo = InMemoryExamRepository();

    await pumpApp(tester, pdfPath, repo);
    expect(find.text(AppStrings.emptyHome), findsOneWidget);

    await importViaFab(tester);

    // Success summary from the REAL parser: 2 questions.
    expect(find.text(AppStrings.extractionSucceeded), findsOneWidget);
    expect(find.text(AppStrings.questionsFound(2)), findsOneWidget);

    await tester.tap(find.text(AppStrings.startPractice));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeScreen), findsOneWidget);

    // Real parsed Hebrew answers on screen; pick the correct one.
    expect(find.text('16 ביט'), findsOneWidget);
    await tester.tap(find.text('16 ביט'));
    await tester.pump();

    // Next question: answer wrong.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('זיכרון RAM'), findsOneWidget);
    await tester.tap(find.text('זיכרון RAM'));
    await tester.pump();

    await tester.tap(find.text(AppStrings.finishPractice));
    await tester.pumpAndSettle();

    // 1 of 2 correct.
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('ALU הוא הרכיב הנכון'), findsOneWidget);

    await tester.tap(find.text(AppStrings.backToHome));
    await tester.pumpAndSettle();

    // Exam persisted and listed on home.
    expect(find.text('מבחן אמיתי'), findsOneWidget);
    expect(await repo.getExams(), hasLength(1));
  });

  testWidgets(
      'E2E visual PDF: cropped image by default, full only after reveal, '
      'silent UX preserved', (tester) async {
    final pdfPath = '${tempDir.path}/visual.pdf';
    File(pdfPath).writeAsBytesSync(PdfFixtures.visualExam());
    final repo = InMemoryExamRepository();

    await pumpApp(tester, pdfPath, repo);
    await importViaFab(tester);

    expect(find.text(AppStrings.questionsFound(3)), findsOneWidget);

    await tester.tap(find.text(AppStrings.startPractice));
    await tester.pumpAndSettle();

    // Question 1 is visual: image + reveal button, NO answer tiles and no
    // eye helper — and nothing announcing the question isn't shuffled.
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, contains('cropped'),
        reason: 'default must be the cropped image');
    expect(find.text(AppStrings.revealOriginalAnswers), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text(AppStrings.revealCorrectAnswer), findsNothing);

    await tester.tap(find.text(AppStrings.revealOriginalAnswers));
    await tester.pump();
    final revealed = tester.widget<Image>(find.byType(Image));
    expect((revealed.image as FileImage).file.path, contains('full'));

    // Question 2 is a regular text question — same card chrome.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('0 תמיד'), findsOneWidget);
    await tester.tap(find.text('0 תמיד'));
    await tester.pump();

    await tester.tap(find.text(AppStrings.finishPractice));
    await tester.pumpAndSettle();

    // Only the single text question is scored: 1/1 = 100%.
    expect(find.text('100%'), findsOneWidget);
    expect(find.text(AppStrings.noMistakes), findsOneWidget);
  });
}
