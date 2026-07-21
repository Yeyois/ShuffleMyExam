import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/practice_session_controller.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/domain/models/exam.dart';
import 'package:jct_mixexam/presentation/screens/results_screen.dart';

import '../test_helpers.dart';

void main() {
  Exam twoTextQuestions() => Exam(
        id: 'e1',
        title: 'מבחן',
        questions: [textQuestion(id: 'q1'), textQuestion(id: 'q2')],
      );

  testWidgets('shows percentage and mistake breakdown in red/green',
      (tester) async {
    const session = PracticeSessionState(
      shuffledAnswers: {},
      selectedAnswerIds: {
        'q1': 'q1-a1', // correct
        'q2': 'q2-a3', // wrong
      },
    );

    await pumpScreen(
      tester,
      home: ResultsScreen(exam: twoTextQuestions(), session: session),
    );
    await tester.pump();

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 מתוך 2 תשובות נכונות'), findsOneWidget);
    expect(find.text(AppStrings.mistakesTitle), findsOneWidget);

    // Wrong answer text (32 ביט) and correct (16 ביט) both shown.
    expect(find.textContaining('32 ביט'), findsOneWidget);
    expect(find.textContaining('16 ביט'), findsOneWidget);
  });

  testWidgets('perfect score shows the no-mistakes card', (tester) async {
    const session = PracticeSessionState(
      shuffledAnswers: {},
      selectedAnswerIds: {'q1': 'q1-a1', 'q2': 'q2-a1'},
    );

    await pumpScreen(
      tester,
      home: ResultsScreen(exam: twoTextQuestions(), session: session),
    );
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    expect(find.text(AppStrings.noMistakes), findsOneWidget);
    expect(find.text(AppStrings.mistakesTitle), findsNothing);
  });

  testWidgets('unanswered question appears as a mistake without selection',
      (tester) async {
    const session = PracticeSessionState(
      shuffledAnswers: {},
      selectedAnswerIds: {'q1': 'q1-a1'},
    );

    await pumpScreen(
      tester,
      home: ResultsScreen(exam: twoTextQuestions(), session: session),
    );
    await tester.pump();

    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('לא נבחרה תשובה'), findsOneWidget);
  });
}
