import 'geometry.dart';

/// Decides whether a question block is pure text (Path A, shufflable) or
/// contains visual content (Path B, image fallback).
///
/// `syncfusion_flutter_pdf` exposes no API for enumerating images or vector
/// drawings with bounds, so classification is inferred from text structure,
/// erring on the side of Path B (data integrity):
///  - fewer than [minAnswerBullets] Hebrew answer bullets found as text
///    means the answers (or the whole question) live inside a graphic;
///  - a vertical text-free gap much taller than the block's typical line
///    height means a diagram/image occupies that space.
abstract final class BlockClassifier {
  static const minAnswerBullets = 2;
  static const gapFactor = 2.5;
  static const minGapPoints = 40.0;

  /// [blockLines] are the block's text lines in top-to-bottom page order.
  /// [answerBulletCount] is how many א/ב/ג/ד bullets were extracted from
  /// the block's text.
  static bool isVisual({
    required List<LineBox> blockLines,
    required int answerBulletCount,
  }) {
    if (answerBulletCount < minAnswerBullets) return true;
    return maxVerticalGap(blockLines) >= _gapThreshold(blockLines);
  }

  /// Largest vertical distance between the bottom of one line and the top
  /// of the next.
  static double maxVerticalGap(List<LineBox> lines) {
    var maxGap = 0.0;
    for (var i = 1; i < lines.length; i++) {
      final gap = lines[i].bounds.top - lines[i - 1].bounds.bottom;
      if (gap > maxGap) maxGap = gap;
    }
    return maxGap;
  }

  static double _gapThreshold(List<LineBox> lines) {
    if (lines.isEmpty) return minGapPoints;
    final heights = lines.map((l) => l.bounds.height).toList()..sort();
    final median = heights[heights.length ~/ 2];
    final threshold = median * gapFactor;
    return threshold < minGapPoints ? minGapPoints : threshold;
  }
}
