import '../../core/utils/id_generator.dart';
import '../../domain/models/answer.dart';
import 'geometry.dart';

/// Reconstructs answers from the "trailing bullet" layout seen in some
/// degenerate-geometry exam templates, where the normal extractor fails.
///
/// In that layout each answer's bullet is a *trailing* marker: a standalone
/// ". א" fragment sitting on (nearly) the same visual row as its answer
/// text, which the extractor split into a separate line — e.g.
///
///   "הוא חייב להיות ממומש בחומרת TPM..."   (top 116.8, answer א text)
///   ". א"                                  (top 117.5, answer א marker)
///   "לשינוי"                               (top 128.0, א continuation)
///   "הוא צריך להיות פשוט..."               (top 130.6, answer ב text)
///   ". ב"                                  (top 131.3, answer ב marker)
///   ...
///
/// This is fundamentally more fragile than leading-bullet extraction, so it
/// is deliberately conservative: it returns null (caller keeps the visual
/// fallback) unless it can identify an in-order run of markers starting at
/// א, and it always flags א as the correct answer — the Zero-Exam integrity
/// invariant is never guessed.
abstract final class TrailingBulletReconstructor {
  /// A line that is nothing but a trailing bullet marker: ". א" / "א ." etc.
  static final _markerOnly = RegExp(r'^\s*[.)]?\s*([אבגד])\s*[.)]\s*$|'
      r'^\s*[.)]\s*([אבגד])\s*$');

  /// The letterless final bullet ". text" (the ד whose letter was dropped).
  static final _dotText = RegExp(r'^\s*\.\s+(\S.*)$');

  static const _order = ['א', 'ב', 'ג', 'ד'];

  /// Rows within this many points share a baseline (same visual line).
  static const _sameRow = 5.0;

  /// Attempts reconstruction. Returns the answers in letter order (first =
  /// correct) plus [firstAnswerTop] — the page-Y where the answers begin,
  /// so the caller can truncate the question body above it and not re-leak
  /// the answers. Returns null when the pattern is not confidently present.
  static ({List<Answer> answers, double firstAnswerTop})? reconstruct(
      List<LineBox> blockLines) {
    final lines = [...blockLines]
      ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

    // Locate standalone letter markers, in reading order.
    final markers = <({int index, String letter})>[];
    for (var i = 0; i < lines.length; i++) {
      final letter = _markerLetter(lines[i].text);
      if (letter != null) markers.add((index: i, letter: letter));
    }
    if (markers.length < 2) return null;

    // Markers must be a gapless prefix of א,ב,ג,ד in order. Anything else
    // means we have misread the structure — bail rather than guess.
    for (var k = 0; k < markers.length; k++) {
      if (k >= _order.length || markers[k].letter != _order[k]) return null;
    }

    final isMarker = List<bool>.generate(
        lines.length, (i) => _markerLetter(lines[i].text) != null);

    // The "primary" text line for each marker: the nearest non-marker line
    // sharing the marker's baseline (its answer text was split off there).
    final primaryOf = <int, int>{};
    for (final marker in markers) {
      final markerTop = lines[marker.index].bounds.top;
      for (var j = marker.index - 1; j >= 0; j--) {
        if ((markerTop - lines[j].bounds.top).abs() > _sameRow) break;
        if (isMarker[j]) continue;
        primaryOf[marker.index] = j;
        break;
      }
    }
    // Every marker must have found its text — otherwise the association is
    // unreliable.
    if (primaryOf.length != markers.length) return null;

    // A possible letterless 4th answer (". text") somewhere below the last
    // letter marker — its own continuation lines may sit in between, so
    // scan forward past them for the first ". text" line.
    int? tailDotIndex;
    if (markers.length == 3) {
      for (var j = markers.last.index + 1; j < lines.length; j++) {
        if (isMarker[j]) continue;
        if (_dotText.hasMatch(lines[j].text)) {
          tailDotIndex = j;
          break;
        }
      }
    }

    // Answer boundaries in reading order: each answer owns its primary line
    // plus every following non-marker line, up to the next answer's primary
    // line (or the tail-dot / block end for the last one).
    final anchors = <int>[
      for (final m in markers) primaryOf[m.index]!,
      ?tailDotIndex,
    ];
    final letters = [
      for (final m in markers) m.letter,
      if (tailDotIndex != null) 'ד',
    ];

    final answers = <Answer>[];
    for (var a = 0; a < anchors.length; a++) {
      final start = anchors[a];
      final end = a + 1 < anchors.length ? anchors[a + 1] : lines.length;
      final buffer = StringBuffer();
      for (var i = start; i < end; i++) {
        if (isMarker[i]) continue;
        var text = lines[i].text.trim();
        // Strip the leading ". " from a letterless tail-dot answer line.
        if (i == tailDotIndex) {
          text = _dotText.firstMatch(text)?.group(1)?.trim() ?? text;
        }
        if (text.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(text);
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) return null; // an empty answer means we mis-grouped
      answers.add(Answer(
        id: generateId(),
        text: text,
        isOriginalCorrect: letters[a] == 'א',
      ));
    }

    // Sanity: at least 3 answers and exactly one flagged correct (the א).
    if (answers.length < 3) return null;
    if (answers.where((a) => a.isOriginalCorrect).length != 1) return null;
    return (answers: answers, firstAnswerTop: lines[anchors.first].bounds.top);
  }

  static String? _markerLetter(String text) {
    final m = _markerOnly.firstMatch(text);
    if (m == null) return null;
    return m.group(1) ?? m.group(2);
  }
}
