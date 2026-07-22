import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/parsing/parsed_structures.dart';
import 'package:jct_mixexam/data/parsing/pdf_exam_parser.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_fixtures.dart';

/// Serializes through JSON exactly like data crossing an isolate boundary.
ParsedExamStructure structureRoundTrip(ParsedExamStructure structure) =>
    ParsedExamStructure.fromJson(
        jsonDecode(jsonEncode(structure.toJson())) as Map<String, dynamic>);

/// Finds the page top-Y of the first extracted line whose rightmost word is
/// the given bullet ("א." etc.) — ground truth for crop assertions.
double bulletLineTop(List<int> bytes, String bullet, {double after = 0}) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    for (final line in PdfTextExtractor(document).extractTextLines()) {
      if (line.bounds.top <= after) continue;
      final words = [...line.wordCollection]
        ..sort((a, b) => b.bounds.left.compareTo(a.bounds.left));
      if (words.isNotEmpty && words.first.text.trim() == bullet) {
        return line.bounds.top;
      }
    }
  } finally {
    document.dispose();
  }
  fail('no line starting with $bullet found');
}

/// The physical left-X of the [bullet] marker word on its answer line.
double bulletWordLeft(List<int> bytes, String bullet) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    for (final line in PdfTextExtractor(document).extractTextLines()) {
      for (final w in line.wordCollection) {
        if (w.text.trim() == bullet) return w.bounds.left;
      }
    }
  } finally {
    document.dispose();
  }
  fail('no word "$bullet" found');
}

void main() {
  group('PdfExamParser — pure text exam', () {
    test('finds all questions with bidi-corrected text and answers', () {
      final structure = PdfExamParser.parseBytes(PdfFixtures.textOnlyExam());

      expect(structure.questions, hasLength(2));
      expect(structure.questions.every((q) => q.isShufflable), isTrue);

      final q1 = structure.questions[0];
      expect(q1.questionText, contains('מהו גודל המילה במעבד'));
      expect(q1.answers.map((a) => a.text).toList(),
          ['16 ביט', '8 ביט', '32 ביט', '64 ביט']);
      expect(q1.answers.first.isOriginalCorrect, isTrue);
      expect(q1.answers.skip(1).any((a) => a.isOriginalCorrect), isFalse);
      expect(q1.croppedBox, isNull);
      expect(q1.fullBox, isNull);

      final q2 = structure.questions[1];
      expect(q2.questionText, contains('איזה רכיב מבצע פעולות חשבון'));
      expect(q2.answers.first.text, 'ALU הוא הרכיב הנכון');
      expect(q2.answers.first.isOriginalCorrect, isTrue);
      expect(q2.answers, hasLength(4));
    });

    test('captures per-answer text boxes that exclude the bullet marker', () {
      final bytes = PdfFixtures.textOnlyExam();
      final structure = PdfExamParser.parseBytes(bytes);
      final q1 = structure.questions[0];

      final boxes = q1.answerTextBoxes;
      expect(boxes, isNotNull,
          reason: 'single-line, equal-height answers are shufflable in place');
      expect(boxes, hasLength(4));

      // All answer rows share one height (within tolerance) so their text
      // regions can be swapped without vertical overlap.
      final h0 = boxes!.first.height;
      for (final b in boxes) {
        expect((b.height - h0).abs(), lessThan(5.0));
        expect(b.width, greaterThan(0));
      }

      // The box must stop left of the "א." bullet so the marker stays put
      // when the answer text is moved.
      final alephLeft = bulletWordLeft(bytes, 'א.');
      expect(boxes.first.right, lessThanOrEqualTo(alephLeft + 0.5),
          reason: 'answer text region must not cover its bullet');
    });
  });

  group('PdfExamParser — exam with visual questions', () {
    test('classifies diagram questions as visual and text as shufflable',
        () {
      final structure = PdfExamParser.parseBytes(PdfFixtures.visualExam());

      expect(structure.questions, hasLength(3));
      expect(structure.questions[0].isShufflable, isFalse);
      expect(structure.questions[1].isShufflable, isTrue);
      expect(structure.questions[2].isShufflable, isFalse);

      // Visual questions never carry text answers (Path B).
      expect(structure.questions[0].answers, isEmpty);
      expect(structure.questions[2].answers, isEmpty);

      // The text question in between still parses fully.
      expect(structure.questions[1].answers, hasLength(4));
      expect(structure.questions[1].answers.first.text, '0 תמיד');
    });

    test('smart crop cuts strictly above the "א." bullet of the visual '
        'question, while the full box keeps the answers', () {
      final bytes = PdfFixtures.visualExam();
      final structure = PdfExamParser.parseBytes(bytes);
      final visual = structure.questions[0];

      final firstBulletTop = bulletLineTop(bytes, 'א.');

      expect(visual.croppedBox!.bottom, lessThan(firstBulletTop),
          reason: 'cropped image must end above the first answer bullet');
      expect(visual.fullBox!.bottom, greaterThan(firstBulletTop),
          reason: 'full image must include the original answers');
      expect(visual.croppedBox!.top, visual.fullBox!.top);
    });

    test('a trailing diagram (answers inside the graphic) stays inside the '
        'block even with no text below it', () {
      final structure = PdfExamParser.parseBytes(PdfFixtures.visualExam());
      final lastQuestion = structure.questions[2];

      // The question has a single text line (~15pt); the block must extend
      // far enough beyond it to contain the 180pt-tall diagram.
      expect(lastQuestion.fullBox!.height, greaterThan(180));
      // No bullet to crop at: cropped falls back to the full block.
      expect(lastQuestion.croppedBox!.height, lastQuestion.fullBox!.height);
    });

    test('real-world template quirks: split headers, spaced bullets, '
        'footer noise, decoy numbering, and the א-integrity guard', () {
      final structure =
          PdfExamParser.parseBytes(PdfFixtures.realWorldStyleExam());

      // The bare-numbered instruction line is not a question — the
      // document uses explicit headers.
      expect(structure.questions, hasLength(2));

      final q1 = structure.questions[0];
      expect(q1.isShufflable, isTrue);
      expect(q1.questionText, contains('מהו רכיב החישוב המרכזי'));
      expect(q1.questionText, isNot(contains('עמוד')),
          reason: 'page footers must never leak into question text');
      expect(q1.answers.map((a) => a.text).toList(),
          ['המעבד', 'הזיכרון', 'הדיסק', 'המסך']);
      expect(q1.answers.first.isOriginalCorrect, isTrue);

      // Q2 lost its א bullet: flagging ב as "correct" would be a lie, so
      // it must fall back to the visual path.
      final q2 = structure.questions[1];
      expect(q2.isShufflable, isFalse);
      expect(q2.answers, isEmpty);
      expect(q2.croppedBox, isNotNull);
    });

    test('degenerate geometry (all words share one x): stream order is '
        'reversed instead of position-sorted', () {
      final structure =
          PdfExamParser.parseBytes(PdfFixtures.degenerateGeometryExam());

      expect(structure.questions, hasLength(2));

      final q1 = structure.questions[0];
      expect(q1.isShufflable, isTrue);
      expect(q1.questionText, contains('מהו רכיב החישוב המרכזי'));
      expect(q1.answers.map((a) => a.text).toList(),
          ['המעבד', 'הזיכרון', 'הדיסק', 'המסך']);
      expect(q1.answers.first.isOriginalCorrect, isTrue);

      final q2 = structure.questions[1];
      expect(q2.isShufflable, isTrue);
      expect(q2.answers.map((a) => a.text).toList(),
          ['16 ביט', '8 ביט', '32 ביט', '64 ביט']);

      // Degenerate word positions can't separate bullet from text, so these
      // questions carry no swap geometry — the exporter leaves them as-is.
      expect(q1.answerTextBoxes, isNull);
      expect(q2.answerTextBoxes, isNull);
    });

    test('question drafts survive isolate-style JSON round-trip', () {
      final structure = PdfExamParser.parseBytes(PdfFixtures.visualExam());
      final restored = structureRoundTrip(structure);

      expect(restored.questions, hasLength(structure.questions.length));
      expect(restored.questions[0].isShufflable, isFalse);
      expect(restored.questions[0].croppedBox!.bottom,
          structure.questions[0].croppedBox!.bottom);
      expect(restored.questions[1].answers.map((a) => a.text),
          structure.questions[1].answers.map((a) => a.text));
    });
  });
}
