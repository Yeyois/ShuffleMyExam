import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/export/shuffled_pdf_export_service.dart';
import 'package:jct_mixexam/domain/models/exam.dart';

import '../../test_helpers.dart';

// The compositing runner (buildShuffledExamPdf) rasterizes pages through
// pdfx, which needs platform channels — it is exercised on device/e2e, not
// in host unit tests. The pure shuffle logic lives in, and is tested by,
// in_place_shuffle_planner_test.dart. Here we only cover the service guard.
void main() {
  test('generate throws when the exam has no retained original PDF', () async {
    final exam = Exam(
      id: 'e1',
      title: 'ללא מקור',
      questions: [textQuestion()],
      // originalPdfPath omitted (e.g. an exam imported before it was kept).
    );

    expect(
      () => const ShuffledPdfExportService().generate(exam),
      throwsA(isA<ExportUnavailableException>()),
    );
  });
}
