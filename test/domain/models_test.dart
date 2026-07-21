import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/domain/models/answer.dart';
import 'package:jct_mixexam/domain/models/exam.dart';
import 'package:jct_mixexam/domain/models/question.dart';

Exam buildSampleExam() => Exam(
      id: 'exam-1',
      title: 'מבחן אפס — ארכיטקטורת מחשבים',
      questions: [
        const Question(
          id: 'q1',
          questionText: 'מהו גודל המילה במעבד 8086?',
          isShufflable: true,
          textAnswers: [
            Answer(id: 'a1', text: '16 ביט', isOriginalCorrect: true),
            Answer(id: 'a2', text: '8 ביט', isOriginalCorrect: false),
            Answer(id: 'a3', text: '32 ביט', isOriginalCorrect: false),
            Answer(id: 'a4', text: '64 ביט', isOriginalCorrect: false),
          ],
        ),
        const Question(
          id: 'q2',
          questionText: 'שאלה חזותית עם תרשים',
          isShufflable: false,
          textAnswers: [],
          croppedImageUrl: '/tmp/q2_cropped.png',
          fullImageUrl: '/tmp/q2_full.png',
        ),
      ],
    );

void main() {
  group('model serialization', () {
    test('round-trips an exam with text and visual questions', () {
      final exam = buildSampleExam();

      final restored = Exam.fromJson(exam.toJson());

      expect(restored.id, exam.id);
      expect(restored.title, exam.title);
      expect(restored.questions, hasLength(2));

      final text = restored.questions[0];
      expect(text.isShufflable, isTrue);
      expect(text.textAnswers, hasLength(4));
      expect(text.textAnswers.first.isOriginalCorrect, isTrue);
      expect(text.textAnswers.skip(1).any((a) => a.isOriginalCorrect), isFalse);
      expect(text.textAnswers[0].text, '16 ביט');
      expect(text.croppedImageUrl, isNull);
      expect(text.fullImageUrl, isNull);

      final visual = restored.questions[1];
      expect(visual.isShufflable, isFalse);
      expect(visual.textAnswers, isEmpty);
      expect(visual.croppedImageUrl, '/tmp/q2_cropped.png');
      expect(visual.fullImageUrl, '/tmp/q2_full.png');
    });

    test('answer equality is value-based', () {
      const a = Answer(id: 'x', text: 'טקסט', isOriginalCorrect: true);
      const b = Answer(id: 'x', text: 'טקסט', isOriginalCorrect: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
