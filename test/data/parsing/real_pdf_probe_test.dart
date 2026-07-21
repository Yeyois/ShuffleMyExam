import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/parsing/pdf_exam_parser.dart';

/// Dev harness: parses every PDF dropped into `pdf_exams_files/` (not in
/// git) and dumps the resulting structure for manual inspection. Skips
/// silently when the directory is absent.
void main() {
  test('probe real JCT zero-exam PDFs', () {
    final dir = Directory('pdf_exams_files');
    if (!dir.existsSync()) {
      markTestSkipped('pdf_exams_files/ not present');
      return;
    }
    final pdfs = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in pdfs) {
      // ignore: avoid_print
      print('\n########## ${file.path.split('/').last}');
      try {
        final structure = PdfExamParser.parseBytes(file.readAsBytesSync());
        // ignore: avoid_print
        print('== ${structure.questions.length} questions');
        for (var i = 0; i < structure.questions.length; i++) {
          final q = structure.questions[i];
          final text = q.questionText.replaceAll('\n', ' | ');
          final preview =
              text.length > 110 ? '${text.substring(0, 110)}…' : text;
          // ignore: avoid_print
          print('Q${i + 1} shuf=${q.isShufflable} page=${q.pageIndex} '
              'answers=${q.answers.length} "$preview"');
          for (final a in q.answers) {
            final at = a.text.length > 80
                ? '${a.text.substring(0, 80)}…'
                : a.text;
            // ignore: avoid_print
            print('    [${a.isOriginalCorrect ? '*' : ' '}] $at');
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('!! PARSE FAILED: $e');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
