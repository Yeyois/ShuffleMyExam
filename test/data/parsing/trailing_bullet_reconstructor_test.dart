import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/parsing/geometry.dart';
import 'package:jct_mixexam/data/parsing/trailing_bullet_reconstructor.dart';

/// Builds a block line at [top]. Trailing-bullet markers sit ~0.7pt below
/// their answer text (same visual row, split by the extractor).
LineBox line(String text, double top) => LineBox(
      text: text,
      pageIndex: 0,
      bounds: PdfBox(left: 80, top: top, width: 400, height: 11),
    );

void main() {
  group('TrailingBulletReconstructor', () {
    test('reconstructs the trailing-bullet layout, flagging א as correct',
        () {
      // Mirrors the real security-exam Q14 structure: text line, then a
      // ". letter" marker on the same row, then continuations.
      final block = [
        line('הוא חייב להיות ממומש', 116.8), // א text
        line('. א', 117.5), // א marker
        line('לשינוי', 128.0), // א continuation
        line('הוא צריך להיות פשוט', 130.6), // ב text
        line('. ב', 131.3), // ב marker
        line('ולאימות', 141.8), // ב continuation
        line('הוא חלק', 146.4), // ג text
        line('. ג', 147.2), // ג marker
        line('security kernel', 157.7), // ג continuation
        line('. הוא בין היתר פועל', 162.3), // ד (letterless ". text")
        line('בין תהליכים', 173.6), // ד continuation
      ];

      final result = TrailingBulletReconstructor.reconstruct(block);

      expect(result, isNotNull);
      final answers = result!.answers;
      expect(answers, hasLength(4));
      expect(answers[0].text, 'הוא חייב להיות ממומש לשינוי');
      expect(answers[0].isOriginalCorrect, isTrue);
      expect(answers[1].text, 'הוא צריך להיות פשוט ולאימות');
      expect(answers[1].isOriginalCorrect, isFalse);
      expect(answers[2].text, 'הוא חלק security kernel');
      // ד keeps its text, with the leading ". " stripped.
      expect(answers[3].text, 'הוא בין היתר פועל בין תהליכים');
      expect(answers.where((a) => a.isOriginalCorrect), hasLength(1));
      // The answers begin at the first answer's row (א text, top 116.8).
      expect(result.firstAnswerTop, 116.8);
    });

    test('reconstructs three answers when there is no letterless 4th', () {
      final block = [
        line('תשובה ראשונה', 100.0),
        line('. א', 100.6),
        line('תשובה שנייה', 120.0),
        line('. ב', 120.6),
        line('תשובה שלישית', 140.0),
        line('. ג', 140.6),
      ];

      final result = TrailingBulletReconstructor.reconstruct(block);
      expect(result, isNotNull);
      final answers = result!.answers;
      expect(answers, hasLength(3));
      expect(answers[0].text, 'תשובה ראשונה');
      expect(answers[0].isOriginalCorrect, isTrue);
      expect(answers[2].text, 'תשובה שלישית');
    });

    test('bails (returns null) when markers do not start at א', () {
      final block = [
        line('טקסט', 100.0),
        line('. ב', 100.6),
        line('טקסט אחר', 120.0),
        line('. ג', 120.6),
      ];
      expect(TrailingBulletReconstructor.reconstruct(block), isNull);
    });

    test('bails when markers are not a gapless prefix (א then ג)', () {
      final block = [
        line('טקסט', 100.0),
        line('. א', 100.6),
        line('טקסט אחר', 120.0),
        line('. ג', 120.6),
      ];
      expect(TrailingBulletReconstructor.reconstruct(block), isNull);
    });

    test('bails with fewer than two markers', () {
      final block = [line('טקסט', 100.0), line('. א', 100.6)];
      expect(TrailingBulletReconstructor.reconstruct(block), isNull);
    });

    test('bails when a marker has no same-row text line to attach to', () {
      // ". ב" is far from any text — no primary line within the same row.
      final block = [
        line('תשובה ראשונה', 100.0),
        line('. א', 100.6),
        line('. ב', 200.0),
      ];
      expect(TrailingBulletReconstructor.reconstruct(block), isNull);
    });
  });
}
