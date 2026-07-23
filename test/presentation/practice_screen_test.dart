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

  testWidgets('text question: shows all shuffled answers', (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    // All 4 answers are visible.
    for (final answer in ['16 ביט', '8 ביט', '32 ביט', '64 ביט']) {
      expect(find.text(answer), findsOneWidget);
    }
    expect(find.text(AppStrings.questionOf(1, 2)), findsOneWidget);
  });

  testWidgets('wrong pick gives immediate feedback and reveals the correct '
      'answer in green', (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsNothing);

    // Tap a wrong answer (correct is '16 ביט').
    await tester.tap(find.text('32 ביט'));
    await tester.pumpAndSettle();

    // Immediate "wrong" feedback, and the correct answer gets the green check.
    expect(find.text(AppStrings.answerWrong), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final check = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(check.color, const Color(0xFF2E7D32));

    // Locked: tapping another answer does not change the feedback.
    await tester.tap(find.text('8 ביט'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.answerCorrect), findsNothing);
  });

  testWidgets('correct pick gives immediate positive feedback',
      (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    await tester.tap(find.text('16 ביט')); // the isOriginalCorrect answer
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.answerCorrect), findsOneWidget);
    expect(find.text(AppStrings.answerWrong), findsNothing);
  });

  testWidgets('a correct pick auto-advances to the next question after the '
      'feedback has been seen', (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    await tester.tap(find.text('16 ביט'));
    await tester.pumpAndSettle();

    // The feedback is still on the same question right after the tap.
    expect(find.text(AppStrings.answerCorrect), findsOneWidget);
    expect(find.text(AppStrings.questionOf(1, 2)), findsOneWidget);

    // After the pause the flow moves on with no user action.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.questionOf(2, 2)), findsOneWidget);
  });

  testWidgets('a wrong pick does not auto-advance', (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    await tester.tap(find.text('32 ביט'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.questionOf(1, 2)), findsOneWidget);
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

    // Silent UX: no radio buttons and no hint text about shuffling on the
    // visual page.
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
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

  testWidgets('Next/Previous buttons navigate between questions',
      (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    // Start on Q1: Next is available, no Finish yet.
    expect(find.text(AppStrings.questionOf(1, 2)), findsOneWidget);
    expect(find.text(AppStrings.nextQuestion), findsOneWidget);
    expect(find.text(AppStrings.finishPractice), findsNothing);

    // Advance with the Next button (no swiping needed).
    await tester.tap(find.text(AppStrings.nextQuestion));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.questionOf(2, 2)), findsOneWidget);

    // Last question shows Finish; go back with Previous.
    expect(find.text(AppStrings.finishPractice), findsOneWidget);
    await tester.tap(find.text(AppStrings.previousQuestion));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.questionOf(1, 2)), findsOneWidget);
  });

  testWidgets('finish button on the last question opens results',
      (tester) async {
    await pumpScreen(tester, home: PracticeScreen(exam: mixedExam()));
    await tester.pump();

    await tester.tap(find.text(AppStrings.nextQuestion));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.finishPractice));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsOneWidget);
  });
}
