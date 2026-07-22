import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show RootIsolateToken, rootBundle;

import '../../domain/models/exam.dart';
import 'shuffled_pdf_exporter.dart';

/// Thrown when an exam can't be exported because its original PDF is no
/// longer available (e.g. imported before the PDF was retained).
class ExportUnavailableException implements Exception {
  const ExportUnavailableException();
}

/// Generates a format-preserving, shuffled copy of an [Exam] by editing its
/// retained original PDF in place.
///
/// Fonts (for the answer-key page only) are read from the asset bundle here
/// (the main isolate) and handed to [buildShuffledExamPdf], which does the
/// heavy rasterization + compositing inside a `compute()` isolate so the UI
/// thread never blocks. 100% offline — no network access.
class ShuffledPdfExportService {
  const ShuffledPdfExportService();

  static const _regularFontAsset = 'assets/fonts/DejaVuSans.ttf';
  static const _boldFontAsset = 'assets/fonts/DejaVuSans-Bold.ttf';

  /// Throws [ExportUnavailableException] if [exam] has no retained original
  /// PDF to shuffle.
  Future<Uint8List> generate(Exam exam, {int? seed}) async {
    final path = exam.originalPdfPath;
    if (path == null) throw const ExportUnavailableException();

    final regular = await rootBundle.load(_regularFontAsset);
    final bold = await rootBundle.load(_boldFontAsset);
    final params = ShuffledPdfParams(
      originalPdfPath: path,
      regularFontBytes: regular.buffer.asUint8List(),
      boldFontBytes: bold.buffer.asUint8List(),
      token: RootIsolateToken.instance,
      seed: seed,
    );
    return compute(buildShuffledExamPdf, params);
  }
}
