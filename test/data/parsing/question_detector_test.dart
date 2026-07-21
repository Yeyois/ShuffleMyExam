import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/parsing/question_detector.dart';

void main() {
  group('QuestionDetector.match', () {
    test('matches "שאלה מספר X:" with remainder text', () {
      final m = QuestionDetector.match('שאלה מספר 3: מהו גודל המילה?');
      expect(m, isNotNull);
      expect(m!.number, 3);
      expect(m.remainder, 'מהו גודל המילה?');
    });

    test('matches "שאלה מספר X" without colon', () {
      final m = QuestionDetector.match('שאלה מספר 12');
      expect(m!.number, 12);
      expect(m.remainder, isEmpty);
    });

    test('matches "X." numbering with text on the same line', () {
      final m = QuestionDetector.match('7. מהי פעולת ה-XOR?');
      expect(m!.number, 7);
      expect(m.remainder, 'מהי פעולת ה-XOR?');
    });

    test('matches "X)" numbering', () {
      final m = QuestionDetector.match('4) שאלה עם סוגריים');
      expect(m!.number, 4);
    });

    test('matches bare "X." line (question text on following lines)', () {
      final m = QuestionDetector.match('15.');
      expect(m!.number, 15);
      expect(m.remainder, isEmpty);
    });

    test('matches reversed ".X " artifact at line start', () {
      final m = QuestionDetector.match('.9 טסקט כלשהו');
      expect(m!.number, 9);
    });

    test('ignores answer bullet lines', () {
      expect(QuestionDetector.match('א. תשובה ראשונה'), isNull);
      expect(QuestionDetector.match('ב. תשובה שנייה'), isNull);
    });

    test('ignores plain text and year-like numbers', () {
      expect(QuestionDetector.match('טקסט רגיל בלי מספור'), isNull);
      expect(QuestionDetector.match('2024. הייתה שנה'), isNull);
      expect(QuestionDetector.match(''), isNull);
    });

    test('leading whitespace is tolerated', () {
      expect(QuestionDetector.match('   2. שאלה עם רווחים')!.number, 2);
    });
  });
}
