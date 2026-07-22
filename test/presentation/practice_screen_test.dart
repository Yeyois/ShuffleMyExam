import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/practice_session_controller.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/domain/models/exam.dart';
import 'package:jct_mixexam/presentation/screens/practice_screen.dart';
import 'package:jct_mixexam/presentation/screens/results_screen.dart';

import '../test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('practice_ui');
    PracticeSessionController.randomFactory = () => Random(7);
  });

  tearDown(() {
    PracticeSessionController.randomFactory = Random.new;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Exam mixedExam() => Exam(
        id: 'e1',
        title: 'מבחן משולב',
        questions: [
          textQuestion(id: 'q1'),
          visualQuestionWithFiles(tempDir, id: 'q2'),
        ],
      );

  String? currentImagePath(WidgetTester tester) {
    final images = tester.widgetList<Image>(find.byType(Image));
    for (final image in images) {
      if (image.image is FileImage) {
        return (image.image as FileImage).file.path;
      }
    }
    return null;
  }

  testWidgets('text question: shows all shuffled answers, selection works',
      (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    // All 4 answers are visible.
    for (final answer in ['16 ביט', '8 ביט', '32 ביט', '64 ביט']) {
      expect(find.text(answer), findsOneWidget);
    }
    expect(find.text(AppStrings.questionOf(1, 2)), findsOneWidget);

    // Selecting an answer marks it.
    await tester.tap(find.text('32 ביט'));
    await tester.pump();
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('eye button highlights the original correct answer in green',
      (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.tap(find.text(AppStrings.revealCorrectAnswer));
    await tester.pump();

    // Exactly one tile gets the green check — the isOriginalCorrect one.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final check = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(check.color, const Color(0xFF2E7D32));
  });

  testWidgets('visual question: cropped image by default, full only after '
      'reveal, and no shuffle indicator of any kind', (tester) async {
    final exam = mixedExam();
    await pumpScreen(tester, home: PracticeScreen(exam: exam));
    await tester.pump();

    // Swipe to the visual question. In RTL the next page enters from the
    // left, so fling toward the right.
    await tester.fling(
        find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.questionOf(2, 2)), findsOneWidget);

    // Default image is the CROPPED one.
    final visual = exam.questions[1];
    expect(currentImagePath(tester), visual.croppedImageUrl);
    expect(find.text(AppStrings.revealOriginalAnswers), findsOneWidget);

    // Silent UX: no radio buttons, no eye helper, no hint text about
    // shuffling on the visual page.
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(find.text(AppStrings.revealCorrectAnswer), findsNothing);
    expect(find.textContaining('מעורבב'), findsNothing);
    expect(find.textContaining('לא מעורבל'), findsNothing);

    // Reveal swaps to the full image; toggling back restores the crop.
    await tester.tap(find.text(AppStrings.revealOriginalAnswers));
    await tester.pump();
    expect(currentImagePath(tester), visual.fullImageUrl);
    expect(find.text(AppStrings.showCroppedAgain), findsOneWidget);

    await tester.tap(find.text(AppStrings.showCroppedAgain));
    await tester.pump();
    expect(currentImagePath(tester), visual.croppedImageUrl);
  });

  testWidgets('finish button opens the results screen', (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    await tester.tap(find.text(AppStrings.finishPractice));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsOneWidget);
  });
}
