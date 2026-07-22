import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/export/shuffled_pdf_exporter.dart';
import 'package:jct_mixexam/domain/models/answer.dart';
import 'package:jct_mixexam/domain/models/exam.dart';
import 'package:jct_mixexam/domain/models/question.dart';

import '../../test_helpers.dart';

/// Loads the embedded font from disk (assets aren't bundled in unit tests).
Uint8List _font(String name) =>
    File('assets/fonts/$name').readAsBytesSync();

ShuffledPdfParams _params(Exam exam, {int seed = 7}) => ShuffledPdfParams(
      exam: exam,
      regularFontBytes: _font('DejaVuSans.ttf'),
      boldFontBytes: _font('DejaVuSans-Bold.ttf'),
      seed: seed,
    );

bool _isPdf(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x25 && // %
    bytes[1] == 0x50 && // P
    bytes[2] == 0x44 && // D
    bytes[3] == 0x46; // F

void main() {
  test('produces a valid, non-trivial PDF for a text exam', () async {
    final exam = Exam(id: 'e1', title: 'מבחן בדיקה', questions: [
      textQuestion(id: 'q1'),
      textQuestion(id: 'q2', text: 'שאלה שנייה?'),
    ]);

    final bytes = await buildShuffledExamPdf(_params(exam));

    expect(_isPdf(bytes), isTrue, reason: 'should start with %PDF header');
    // Embedded fonts + two questions + answer-key page ⇒ comfortably > 10KB.
    expect(bytes.length, greaterThan(10 * 1024));
  });

  test('renders a visual question from its cropped image without throwing',
      () async {
    final dir = Directory.systemTemp.createTempSync('shuffled_pdf_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final visual = visualQuestionWithFiles(dir, id: 'v1');

    final exam = Exam(id: 'e3', title: 'עם תמונה', questions: [
      textQuestion(id: 'q1'),
      visual,
    ]);

    final bytes = await buildShuffledExamPdf(_params(exam));
    expect(_isPdf(bytes), isTrue);
  });

  test('tolerates a visual question whose image file is missing', () async {
    final exam = Exam(id: 'e4', title: 'תמונה חסרה', questions: [
      const Question(
        id: 'v-missing',
        questionText: 'שאלה חזותית ללא קובץ',
        textAnswers: [],
        isShufflable: false,
        croppedImageUrl: '/no/such/file.png',
      ),
    ]);

    final bytes = await buildShuffledExamPdf(_params(exam));
    expect(_isPdf(bytes), isTrue);
  });

  test('single-answer question is emitted without shuffling or crashing',
      () async {
    final exam = Exam(id: 'e5', title: 'תשובה יחידה', questions: [
      const Question(
        id: 'q-one',
        questionText: 'שאלה?',
        isShufflable: true,
        textAnswers: [
          Answer(id: 'a', text: 'תשובה', isOriginalCorrect: true),
        ],
      ),
    ]);

    final bytes = await buildShuffledExamPdf(_params(exam));
    expect(_isPdf(bytes), isTrue);
  });
}
