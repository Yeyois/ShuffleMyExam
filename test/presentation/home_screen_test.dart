import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/providers.dart';
import 'package:jct_mixexam/core/constants/app_strings.dart';
import 'package:jct_mixexam/presentation/screens/home_screen.dart';
import 'package:jct_mixexam/presentation/screens/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows empty state when no exams are saved', (tester) async {
    await pumpScreen(
      tester,
      home: const HomeScreen(),
      overrides: [
        examRepositoryProvider.overrideWithValue(InMemoryExamRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.emptyHome), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('lists saved exams with question counts', (tester) async {
    final repo = InMemoryExamRepository();
    await repo.saveExam(textOnlyExam(id: 'e1', title: 'מבחן ארכיטקטורה'));
    await repo.saveExam(textOnlyExam(id: 'e2', title: 'מבחן ספרתיות'));

    await pumpScreen(
      tester,
      home: const HomeScreen(),
      overrides: [examRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    expect(find.text('מבחן ארכיטקטורה'), findsOneWidget);
    expect(find.text('מבחן ספרתיות'), findsOneWidget);
    expect(find.text('1 שאלות'), findsNWidgets(2));
  });

  testWidgets('tapping an exam opens the practice screen', (tester) async {
    final repo = InMemoryExamRepository();
    await repo.saveExam(textOnlyExam(title: 'מבחן ניווט'));

    await pumpScreen(
      tester,
      home: const HomeScreen(),
      overrides: [examRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('מבחן ניווט'));
    await tester.pumpAndSettle();

    expect(find.byType(PracticeScreen), findsOneWidget);
  });

  testWidgets('delete flow removes the exam after confirmation',
      (tester) async {
    final repo = InMemoryExamRepository();
    await repo.saveExam(textOnlyExam(title: 'מבחן למחיקה'));

    await pumpScreen(
      tester,
      home: const HomeScreen(),
      overrides: [examRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.deleteExamConfirm), findsOneWidget);

    await tester.tap(find.text(AppStrings.delete));
    await tester.pumpAndSettle();

    expect(find.text('מבחן למחיקה'), findsNothing);
    expect(find.text(AppStrings.emptyHome), findsOneWidget);
    expect(await repo.getExams(), isEmpty);
  });

  testWidgets('has a theme toggle button in the app bar', (tester) async {
    await pumpScreen(
      tester,
      home: const HomeScreen(),
      overrides: [
        examRepositoryProvider.overrideWithValue(InMemoryExamRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
  });
}
