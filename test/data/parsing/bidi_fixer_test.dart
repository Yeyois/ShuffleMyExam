import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/parsing/bidi_fixer.dart';

void main() {
  group('BidiFixer.fixLine', () {
    test('restores pure Hebrew reversed line', () {
      expect(BidiFixer.fixLine('םלוע םולש'), 'שלום עולם');
    });

    test('preserves numbers embedded in Hebrew text', () {
      // Logical: "בשנת 2024 היו 3.5 אחוזים"
      expect(
        BidiFixer.fixLine('םיזוחא 3.5 ויה 2024 תנשב'),
        'בשנת 2024 היו 3.5 אחוזים',
      );
    });

    test('preserves English words inside Hebrew text', () {
      // Logical: "המעבד CPU מהיר"
      expect(BidiFixer.fixLine('ריהמ CPU דבעמה'), 'המעבד CPU מהיר');
    });

    test('keeps mixed English/number tokens intact', () {
      // Logical: "ערך I/O של 16:9 בגרסה R2-D2"
      expect(
        BidiFixer.fixLine('R2-D2 הסרגב 16:9 לש I/O ךרע'),
        'ערך I/O של 16:9 בגרסה R2-D2',
      );
    });

    test('mirrors brackets back to logical positions', () {
      // Logical: "תשובה (נכונה) היא"
      expect(BidiFixer.fixLine('איה (הנוכנ) הבושת'), 'תשובה (נכונה) היא');
    });

    test('restores reversed question header with number', () {
      // Logical: "שאלה מספר 12:"
      expect(BidiFixer.fixLine(':12 רפסמ הלאש'), 'שאלה מספר 12:');
    });

    test('restores reversed answer bullet line', () {
      // Logical: "א. תשובה ראשונה"
      expect(BidiFixer.fixLine('הנושאר הבושת .א'), 'א. תשובה ראשונה');
    });

    test('is an involution: applying twice returns the input', () {
      const lines = [
        'שלום עולם',
        'בשנת 2024 היו 3.5 אחוזים',
        'המעבד CPU מהיר מאוד',
        'שאלה מספר 7: מה הערך של X-25 במערכת?',
        'א. תשובה (חלקית) עם ABC ו-123',
      ];
      for (final line in lines) {
        expect(BidiFixer.fixLine(BidiFixer.fixLine(line)), line);
      }
    });

    test('trailing punctuation next to numbers stays outside the LTR run',
        () {
      // Logical: "הערך הוא 42." (sentence-ending period after a number)
      // Visual form: ".42 אוה ךרעה"
      expect(BidiFixer.fixLine('.42 אוה ךרעה'), 'הערך הוא 42.');
    });

    test('handles empty and non-Hebrew lines', () {
      expect(BidiFixer.fixLine(''), '');
      expect(BidiFixer.hasHebrew('plain english 123'), isFalse);
      expect(BidiFixer.hasHebrew('שורה עם עברית'), isTrue);
    });
  });

  group('ReconstructionArbiter', () {
    const goodLines = [
      'שאלה מספר 1:',
      'מהו גודל המילה של המעבד?',
      'א. 16 ביט',
      'ב. 8 ביט',
      'ג. 32 ביט',
      'ד. 64 ביט',
    ];
    // What the same lines look like when the wrong family is picked:
    // Hebrew words char-reversed, anchors displaced.
    const garbledLines = [
      'הלאש רפסמ :1',
      'והמ לדוג הלימה לש דבעמה?',
      'טיב 16 .א',
      'טיב 8 .ב',
      'טיב 32 .ג',
      'טיב 64 .ד',
    ];

    test('scores exam anchors (bullets, question headers)', () {
      expect(ReconstructionArbiter.score(goodLines),
          greaterThan(ReconstructionArbiter.score(garbledLines)));
    });

    test('prefers the family whose lines read correctly', () {
      expect(
        ReconstructionArbiter.preferLogicalWords(
          logicalWordCandidates: goodLines,
          visualCharCandidates: garbledLines,
        ),
        isTrue,
      );
      expect(
        ReconstructionArbiter.preferLogicalWords(
          logicalWordCandidates: garbledLines,
          visualCharCandidates: goodLines,
        ),
        isFalse,
      );
    });

    test('ties resolve to the logical-words family', () {
      expect(
        ReconstructionArbiter.preferLogicalWords(
          logicalWordCandidates: ['סתם טקסט'],
          visualCharCandidates: ['טקסט סתם'],
        ),
        isTrue,
      );
    });
  });
}
