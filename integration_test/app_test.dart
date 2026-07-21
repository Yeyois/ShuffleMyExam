import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jct_mixexam/application/providers.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/data/local/hive_exam_repository.dart';
import 'package:jct_mixexam/main.dart';
import 'package:jct_mixexam/presentation/screens/practice_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_pdfs.dart';

/// Fake only the file picker (the OS dialog can't be driven from a test);
/// everything else — Hive, parse isolate, pdfx render isolate — is real.
class _FixedPicker extends PdfPickerService {
  const _FixedPicker(this.path, this.title);

  final String path;
  final String title;

  @override
  Future<({String path, String title})?> pickPdf() async =>
      (path: path, title: title);
}

Future<void> _waitForImport(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  // Let the route transition into the processing screen play out.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));

  bool done() =>
      tester.any(find.text(AppStrings.extractionSucceeded)) ||
      tester.any(find.text(AppStrings.extractionFailed));

  for (var i = 0; i < 600 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  if (!tester.any(find.text(AppStrings.extractionSucceeded))) {
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      debugPrint('ON-SCREEN TEXT: ${t.data}');
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'ON-DEVICE: visual exam import with real pdfx render isolate, '
      'cropped-by-default practice, results', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Hive.initFlutter('integration_test_hive');
    final repository = await HiveExamRepository.open();
    final docs = await getApplicationDocumentsDirectory();

    final pdfPath = '${docs.path}/visual_exam.pdf';
    await File(pdfPath).writeAsBytes(base64Decode(visualExamPdfBase64));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          examRepositoryProvider.overrideWithValue(repository),
          imagesRootDirProvider.overrideWithValue('${docs.path}/exam_images'),
          pdfPickerProvider
              .overrideWithValue(_FixedPicker(pdfPath, 'מבחן חזותי')),
        ],
        child: const MixExamApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Import runs the REAL parse + pdfx render isolates.
    await _waitForImport(tester);
    expect(find.text(AppStrings.extractionSucceeded), findsOneWidget);
    expect(find.text(AppStrings.questionsFound(3)), findsOneWidget);

    await tester.tap(find.text(AppStrings.startPractice));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeScreen), findsOneWidget);

    // Question 1 is visual: the cropped PNG was really rendered by pdfx in
    // a background isolate and must exist, non-empty, on disk.
    final image = tester.widget<Image>(find.byType(Image));
    final croppedFile = (image.image as FileImage).file;
    expect(croppedFile.path, contains('cropped'));
    expect(croppedFile.existsSync(), isTrue);
    expect(croppedFile.lengthSync(), greaterThan(1000),
        reason: 'cropped PNG should be a real rendering');

    // Reveal swaps to the full image (also really rendered).
    await tester.tap(find.text(AppStrings.revealOriginalAnswers));
    await tester.pumpAndSettle();
    final full = tester.widget<Image>(find.byType(Image));
    final fullFile = (full.image as FileImage).file;
    expect(fullFile.path, contains('full'));
    expect(fullFile.lengthSync(), greaterThan(1000));
    expect(fullFile.lengthSync(), greaterThan(croppedFile.lengthSync()),
        reason: 'full image contains strictly more content than the crop');

    // Clean up device state for repeatable runs.
    await repository.deleteExam((await repository.getExams()).single.id);
    await Hive.deleteFromDisk();
  });
}
