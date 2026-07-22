import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/core/utils/answer_shuffler.dart';
import 'package:jct_mixexam/data/parsing/answer_extractor.dart';
import 'package:jct_mixexam/domain/models/answer.dart';

void main() {
  group('AnswerExtractor.extract', () {
    test('extracts four bulleted answers, strips bullets, flags the first',
        () {
      final extracted = AnswerExtractor.extract([
        'א. 16 ביט',
        'ב. 8 ביט',
        'ג. 32 ביט',
        'ד. 64 ביט',
      ]);

      expect(extracted, hasLength(4));
      expect(extracted.map((e) => e.answer.text).toList(),
          ['16 ביט', '8 ביט', '32 ביט', '64 ביט']);
      expect(extracted.first.answer.isOriginalCorrect, isTrue);
      expect(
        extracted.skip(1).any((e) => e.answer.isOriginalCorrect),
        isFalse,
      );
    });

    test('supports ")" bullet style', () {
      final extracted = AnswerExtractor.extract(['א) כן', 'ב) לא']);
      expect(extracted.map((e) => e.answer.text).toList(), ['כן', 'לא']);
    });

    test('supports spaced bullets ("א .") as in real exam PDFs', () {
      final extracted = AnswerExtractor.extract([
        'א . המעבד',
        'ב . הזיכרון',
      ]);
      expect(extracted.map((e) => e.answer.text).toList(),
          ['המעבד', 'הזיכרון']);
      expect(extracted.map((e) => e.letter).toList(), ['א', 'ב']);
    });

    test('a letterless ". טקסט" line opens a new answer once bullets have '
        'started, but never before', () {
      final extracted = AnswerExtractor.extract([
        'א. ראשונה',
        '. שנייה בלי אות',
      ]);
      expect(extracted, hasLength(2));
      expect(extracted[1].answer.text, 'שנייה בלי אות');
      expect(extracted[1].letter, isNull);

      expect(AnswerExtractor.extract(['. לא תשובה']), isEmpty);
    });

    test('lines starting with parens stay continuations, not bullets', () {
      final extracted = AnswerExtractor.extract([
        'א. קוד',
        ') lw t0, 0 (a0',
        'ב. אחר',
      ]);
      expect(extracted, hasLength(2));
      expect(extracted[0].answer.text, 'קוד ) lw t0, 0 (a0');
    });

    test('joins continuation lines into the previous answer', () {
      final extracted = AnswerExtractor.extract([
        'א. תשובה ארוכה שנמשכת',
        'על פני שתי שורות',
        'ב. תשובה קצרה',
      ]);
      expect(extracted, hasLength(2));
      expect(extracted[0].answer.text, 'תשובה ארוכה שנמשכת על פני שתי שורות');
      expect(extracted[1].answer.text, 'תשובה קצרה');
    });

    test('records the bullet line index (needed for smart cropping)', () {
      final extracted = AnswerExtractor.extract([
        'שורת שאלה',
        '',
        'א. ראשונה',
        'ב. שנייה',
      ]);
      expect(extracted.first.lineIndex, 2);
      expect(AnswerExtractor.firstBulletLineIndex(
          ['טקסט', 'א. תשובה']), 1);
      expect(AnswerExtractor.firstBulletLineIndex(['טקסט בלבד']), isNull);
    });

    test('ignores text before the first bullet', () {
      final extracted = AnswerExtractor.extract([
        'זו שורת שאלה, לא תשובה',
        'א. תשובה אמיתית',
      ]);
      expect(extracted, hasLength(1));
      expect(extracted.single.answer.text, 'תשובה אמיתית');
    });
  });

  group('shuffleAnswers', () {
    const answers = [
      Answer(id: '1', text: 'נכונה', isOriginalCorrect: true),
      Answer(id: '2', text: 'ב', isOriginalCorrect: false),
      Answer(id: '3', text: 'ג', isOriginalCorrect: false),
      Answer(id: '4', text: 'ד', isOriginalCorrect: false),
    ];

    test('fair shuffle: the correct answer can land in any position', () {
      final firstOutcomes = <bool>{};
      for (var seed = 0; seed < 200; seed++) {
        final shuffled = shuffleAnswers(answers, random: Random(seed));
        // Always a valid permutation of the inputs.
        expect(shuffled.map((a) => a.id).toSet(), {'1', '2', '3', '4'});
        firstOutcomes.add(shuffled.first.isOriginalCorrect);
      }
      // Across seeds the correct answer sometimes stays first and sometimes
      // does not — no derangement constraint is imposed.
      expect(firstOutcomes, containsAll(<bool>{true, false}),
          reason: 'a fair shuffle must let the correct answer land first');
    });

    test('keeps all answers exactly once', () {
      final shuffled = shuffleAnswers(answers, random: Random(42));
      expect(shuffled.map((a) => a.id).toSet(), {'1', '2', '3', '4'});
      expect(shuffled, hasLength(4));
    });

    test('does not mutate the input list', () {
      final input = List.of(answers);
      shuffleAnswers(input, random: Random(1));
      expect(input.map((a) => a.id).toList(), ['1', '2', '3', '4']);
    });

    test('returns single-answer and empty lists unchanged', () {
      expect(shuffleAnswers([answers.first]), hasLength(1));
      expect(shuffleAnswers(const []), isEmpty);
    });
  });
}
