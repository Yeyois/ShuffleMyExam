import 'geometry.dart';

/// Computes the crop boxes for a visual question (Path B).
///
/// - `full`: the whole question block, original answers included.
/// - `cropped`: the question body only — everything strictly above the
///   first answer bullet ("א."), so the Zero-Exam answers never leak into
///   the default view.
abstract final class SmartCropper {
  /// Breathing room added around the block (points).
  static const padding = 6.0;

  /// Computes both boxes, clamped to the page.
  ///
  /// [blockTop] / [blockBottom] delimit the question block on the page.
  /// [firstBulletTop] is the top Y of the first answer bullet line, or null
  /// when no bullet was found (answers drawn inside the graphic) — in that
  /// case `cropped` covers the whole block, which is the only safe option.
  static ({PdfBox full, PdfBox cropped}) computeCropBoxes({
    required double pageWidth,
    required double pageHeight,
    required double blockTop,
    required double blockBottom,
    double? firstBulletTop,
  }) {
    final top = _clamp(blockTop - padding, 0, pageHeight);
    final bottom = _clamp(blockBottom + padding, 0, pageHeight);

    final full = PdfBox(
      left: 0,
      top: top,
      width: pageWidth,
      height: bottom - top,
    );

    var croppedBottom = bottom;
    if (firstBulletTop != null) {
      croppedBottom = _clamp(firstBulletTop - padding, top, bottom);
    }

    final cropped = PdfBox(
      left: 0,
      top: top,
      width: pageWidth,
      height: croppedBottom - top,
    );

    return (full: full, cropped: cropped);
  }

  static double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);
}
