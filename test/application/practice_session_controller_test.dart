import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/application/practice_results.dart';
import 'package:jct_mixexam/application/practice_session_controller.dart';
import 'package:jct_mixexam/domain/models/exam.dart';

import '../test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('practice_test');
  });

  tearDown(() {
    PracticeSessionController.randomFactory = Random.new;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Exam mixedExam() => Exam(
        id: 'e1',
        title: 'מבחן',
        questions: [
          textQuestion(id: 'q1'),
          visualQuestionWithFiles(tempDir, id: 'q2'),
          textQuestion(id: 'q3'),
        ],
      );

  group('PracticeSessionController', () {
    test('shuffles only text questions, once per session', () {
      final exam = mixedExam();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(practiceSessionProvider(exam));

      expect(state.shuffledAnswers.keys.toSet(), {'q1', 'q3'});
      expect(state.shuffledAnswers['q1'], hasLength(4));

      // Reading again returns the same session order.
      final again = container.read(practiceSessionProvider(exam));
      expect(again.shuffledAnswers['q1'], same(state.shuffledAnswers['q1']));
    });

    test('fair shuffle: correct answer may be presented in any position', () {
      var sawCorrectFirst = false;
      for (var seed = 0; seed < 100; seed++) {
        PracticeSessionController.randomFactory = () => Random(seed);
        final container = ProviderContainer();
        final state = container.read(practiceSessionProvider(mixedExam()));
        for (final answers in state.shuffledAnswers.values) {
          // Every session is a valid permutation of that question's answers.
          expect(answers.where((a) => a.isOriginalCorrect), hasLength(1),
              reason: 'seed $seed');
          if (answers.first.isOriginalCorrect) sawCorrectFirst = true;
        }
        container.dispose();
      }
      // Proves no derangement is applied: the correct answer does land first
      // for at least some seeds.
      expect(sawCorrectFirst, isTrue,
          reason: 'a fair shuffle must sometimes leave the correct answer first');
    });

    test('selectAnswer commits once (locked) and toggleFullImage updates '
        'state', () {
      final exam = mixedExam();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller =
          container.read(practiceSessionProvider(exam).notifier);

      controller.selectAnswer('q1', 'q1-a2');
      controller.toggleFullImage('q2');

      var state = container.read(practiceSessionProvider(exam));
      expect(state.selectedAnswerIds['q1'], 'q1-a2');
      expect(state.fullImageQuestionIds, contains('q2'));

      // Answering is final: a second selection is ignored.
      controller.selectAnswer('q1', 'q1-a3');
      state = container.read(practiceSessionProvider(exam));
      expect(state.selectedAnswerIds['q1'], 'q1-a2');

      controller.toggleFullImage('q2');
      state = container.read(practiceSessionProvider(exam));
      expect(state.fullImageQuestionIds, isEmpty);
    });
  });

  group('PracticeResults', () {
    test('scores correct, wrong and unanswered; ignores visual questions',
        () {
      final exam = mixedExam();
      const session = PracticeSessionState(
        shuffledAnswers: {},
        selectedAnswerIds: {
          'q1': 'q1-a1', // correct
          'q3': 'q3-a4', // wrong
          // visual q2 has no selection mechanism
        },
      );

      final results = PracticeResults.from(exam, session);

      expect(results.totalScored, 2);
      expect(results.correctCount, 1);
      expect(results.wrongCount, 1);
      expect(results.unansweredCount, 0);
      expect(results.visualCount, 1); // q2 is visual
      expect(results.percentage, 50);
      expect(results.mistakes, hasLength(1));
      expect(results.mistakes.single.question.id, 'q3');
      expect(results.mistakes.single.selectedAnswer!.id, 'q3-a4');
      expect(results.mistakes.single.correctAnswer.id, 'q3-a1');
    });

    test('unanswered questions count as mistakes with null selection', () {
      final exam = Exam(id: 'e', title: 't', questions: [textQuestion()]);
      const session = PracticeSessionState(shuffledAnswers: {});

      final results = PracticeResults.from(exam, session);

      expect(results.percentage, 0);
      expect(results.mistakes.single.selectedAnswer, isNull);
    });

    test('all-visual exam yields zero scored questions', () {
      final exam = Exam(
        id: 'e',
        title: 't',
        questions: [visualQuestionWithFiles(tempDir)],
      );
      const session = PracticeSessionState(shuffledAnswers: {});

      final results = PracticeResults.from(exam, session);
      expect(results.totalScored, 0);
      expect(results.percentage, 0);
      expect(results.mistakes, isEmpty);
    });
  });
}
