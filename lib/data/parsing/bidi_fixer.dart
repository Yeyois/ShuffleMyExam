/// Fixes Hebrew text extracted from PDFs in visual (reversed) order.
///
/// Many PDF text extractors return RTL lines in *visual* order: the whole
/// line is character-reversed relative to logical reading order, while
/// numbers and Latin words (which are LTR on screen) come out reversed as
/// well ("CPU" -> "UPC", "3.5" -> "5.3"). Converting visual back to logical
/// therefore means reversing the full line and then restoring every LTR run
/// (Latin letters, digits, and their internal separators) to its original
/// direction, mirroring paired brackets along the way.
abstract final class BidiFixer {
  static final _hebrew = RegExp(r'[֐-׿]');

  static const _mirrored = {
    '(': ')', ')': '(',
    '[': ']', ']': '[',
    '{': '}', '}': '{',
    '<': '>', '>': '<',
  };

  static bool hasHebrew(String s) => _hebrew.hasMatch(s);

  /// Converts a single visual-order line to logical order.
  ///
  /// LTR runs (Latin letters and digits, including internal `.`, `,`, `-`,
  /// `/`, `:` between alphanumerics such as "3.5", "I/O" or "16:9") keep
  /// their internal order.
  static String fixLine(String line) {
    if (line.isEmpty) return line;

    // Step 1: reverse the whole line, mirroring brackets.
    final reversed = line.split('').reversed.map((c) => _mirrored[c] ?? c);
    final chars = reversed.toList();

    // Step 2: LTR runs were reversed too by step 1 - flip them back.
    final buffer = StringBuffer();
    var i = 0;
    while (i < chars.length) {
      if (_isLtr(chars[i])) {
        var j = i;
        while (j < chars.length &&
            (_isLtr(chars[j]) || _isInternalSeparator(chars, j))) {
          j++;
        }
        // Trim trailing separators that are not between alphanumerics.
        while (j > i && !_isLtr(chars[j - 1])) {
          j--;
        }
        buffer.writeAll(chars.sublist(i, j).reversed);
        i = j;
      } else {
        buffer.write(chars[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  static bool _isLtr(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) || // 0-9
        (code >= 0x41 && code <= 0x5A) || // A-Z
        (code >= 0x61 && code <= 0x7A); // a-z
  }

  /// `.` `,` `-` `/` `:` count as part of an LTR run only when surrounded by
  /// LTR characters (keeps "3.5", "R2-D2", "I/O", "16:9" intact).
  static bool _isInternalSeparator(List<String> chars, int index) {
    const separators = {'.', ',', '-', '/', ':'};
    if (!separators.contains(chars[index])) return false;
    final hasPrev = index > 0 && _isLtr(chars[index - 1]);
    final hasNext = index + 1 < chars.length && _isLtr(chars[index + 1]);
    return hasPrev && hasNext;
  }
}

/// Picks, per document, which line-reconstruction family reads correctly:
///
/// - the *logical-words* family (words already in logical char order,
///   assembled right-to-left by position — what Syncfusion produces), or
/// - the *visual-chars* family (whole line in visual order run through
///   [BidiFixer.fixLine] — what char-reversing extractors produce, per the
///   PRD's "extraction often reverses Hebrew" model).
///
/// Both candidate renderings of every line are scored against strong exam
/// anchors (answer bullets, question headers); the family with more hits
/// wins document-wide.
abstract final class ReconstructionArbiter {
  static final _anchors = [
    RegExp(r'^\s*[אבגד]\s*[.)](\s|$)'),
    RegExp(r'^\s*שאלה\s'),
    RegExp(r'^\s*\d{1,3}\s*[.)]\s'),
    RegExp(r'^\s*[.):]{0,2}\d{1,3}[.):]{0,2}(\s|$)'),
  ];

  // Bullet/number anchors are nearly symmetric under reversal ("א . טקסט"
  // reversed still starts with "א ."), so they can't break ties alone.
  // Frequent Hebrew function words are strongly asymmetric — their
  // reversals are not words — and decide which family actually reads as
  // Hebrew.
  static const _commonWords = {
    'של', 'את', 'על', 'לא', 'מה', 'הוא', 'היא', 'אם', 'כל', 'גם', //
    'או', 'בין', 'מהו', 'מהי', 'איזה', 'איזו', 'כמה', 'אשר', 'יש',
    'אין', 'רק', 'כי', 'עם', 'זה', 'הבא', 'לפי', 'עבור', 'נתון',
    'שאלה', 'תשובה', 'תשובות', 'הנכונה', 'נכונה', 'נכונות',
  };

  static int score(Iterable<String> lines) {
    var hits = 0;
    for (final line in lines) {
      if (_anchors.any((r) => r.hasMatch(line))) hits += 2;
      for (final token in line.split(RegExp(r'\s+'))) {
        if (_commonWords.contains(token)) hits++;
      }
    }
    return hits;
  }

  /// Returns true when the logical-words candidates win (ties included —
  /// that is the behavior of the extractor actually in use).
  static bool preferLogicalWords({
    required Iterable<String> logicalWordCandidates,
    required Iterable<String> visualCharCandidates,
  }) {
    return score(logicalWordCandidates) >= score(visualCharCandidates);
  }
}
