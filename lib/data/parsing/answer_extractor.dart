import '../../core/utils/id_generator.dart';
import '../../domain/models/answer.dart';

/// One extracted answer plus the index of the line its bullet appeared on.
class ExtractedAnswer {
  const ExtractedAnswer({required this.answer, required this.lineIndex});

  final Answer answer;
  final int lineIndex;
}

/// Extracts Hebrew-bulleted answers (א. ב. ג. ד.) from the logical-order
/// lines of a question block.
abstract final class AnswerExtractor {
  static final _bullet = RegExp(r'^\s*([אבגד])[.)]\s*(.*)$');

  /// Scans [lines] (already bidi-normalized) and returns the answers in
  /// extraction order, bullets stripped. The first extracted answer is
  /// flagged [Answer.isOriginalCorrect] per the Zero-Exam convention.
  /// Lines between bullets are treated as continuations of the previous
  /// answer.
  static List<ExtractedAnswer> extract(List<String> lines) {
    final results = <ExtractedAnswer>[];
    final buffers = <StringBuffer>[];

    for (var i = 0; i < lines.length; i++) {
      final match = _bullet.firstMatch(lines[i]);
      if (match != null) {
        buffers.add(StringBuffer(match.group(2)!.trim()));
        results.add(
          ExtractedAnswer(
            answer: Answer(
              id: generateId(),
              text: '',
              isOriginalCorrect: results.isEmpty,
            ),
            lineIndex: i,
          ),
        );
      } else if (buffers.isNotEmpty && lines[i].trim().isNotEmpty) {
        buffers.last.write(' ${lines[i].trim()}');
      }
    }

    return [
      for (var i = 0; i < results.length; i++)
        ExtractedAnswer(
          answer: Answer(
            id: results[i].answer.id,
            text: buffers[i].toString().trim(),
            isOriginalCorrect: results[i].answer.isOriginalCorrect,
          ),
          lineIndex: results[i].lineIndex,
        ),
    ];
  }

  /// Index of the first bullet line within [lines], or null.
  static int? firstBulletLineIndex(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (_bullet.hasMatch(lines[i])) return i;
    }
    return null;
  }
}
