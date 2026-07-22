import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/exam.dart';
import 'shuffled_pdf_exporter.dart';

/// Generates a shuffled, printable PDF of an [Exam].
///
/// Fonts are read from the asset bundle here (the main isolate) and handed to
/// [buildShuffledExamPdf], which does the heavy PDF work inside a `compute()`
/// isolate so the UI thread never blocks. 100% offline — no network access.
class ShuffledPdfExportService {
  const ShuffledPdfExportService();

  static const _regularFontAsset = 'assets/fonts/DejaVuSans.ttf';
  static const _boldFontAsset = 'assets/fonts/DejaVuSans-Bold.ttf';

  Future<Uint8List> generate(Exam exam, {int? seed}) async {
    final regular = await rootBundle.load(_regularFontAsset);
    final bold = await rootBundle.load(_boldFontAsset);
    final params = ShuffledPdfParams(
      exam: exam,
      regularFontBytes: regular.buffer.asUint8List(),
      boldFontBytes: bold.buffer.asUint8List(),
      seed: seed,
    );
    return compute(buildShuffledExamPdf, params);
  }
}
