/// Detects the start of a question block in extracted (and bidi-normalized)
/// exam text.
///
/// Recognized formats, per the PRD:
///  - "שאלה מספר X:" (with or without the colon)
///  - "X." / "X)" at the start of a line
///  - ".X " at the start of a raw line (the reversed artifact called out in
///    the PRD, for lines that slipped through orientation detection)
class QuestionStartMatch {
  const QuestionStartMatch({required this.number, required this.remainder});

  /// The question number as printed in the document.
  final int number;

  /// Text following the question marker on the same line (often the start
  /// of the question body).
  final String remainder;
}

abstract final class QuestionDetector {
  // The colon may precede the number (":1") — a neutral-character artifact
  // of RTL extraction.
  static final _explicit =
      RegExp(r'^\s*שאלה\s+מספר\s*:?\s*(\d+)\s*:?\s*(.*)$');
  static final _numberedDot = RegExp(r'^\s*(\d{1,3})[.)]\s+(\S.*)$');
  static final _numberedBare = RegExp(r'^\s*(\d{1,3})[.)]\s*$');
  static final _reversedDot = RegExp(r'^\s*\.(\d{1,3})(?:\s+(.*))?$');

  /// Matches [line] against all known question-start formats.
  /// [line] should already be bidi-normalized where applicable.
  static QuestionStartMatch? match(String line) {
    final explicit = _explicit.firstMatch(line);
    if (explicit != null) {
      return QuestionStartMatch(
        number: int.parse(explicit.group(1)!),
        remainder: explicit.group(2)!.trim(),
      );
    }

    final numbered =
        _numberedDot.firstMatch(line) ?? _numberedBare.firstMatch(line);
    if (numbered != null) {
      return QuestionStartMatch(
        number: int.parse(numbered.group(1)!),
        remainder: (numbered.groupCount >= 2 ? numbered.group(2) ?? '' : '')
            .trim(),
      );
    }

    final reversed = _reversedDot.firstMatch(line);
    if (reversed != null) {
      return QuestionStartMatch(
        number: int.parse(reversed.group(1)!),
        remainder: (reversed.group(2) ?? '').trim(),
      );
    }

    return null;
  }
}
