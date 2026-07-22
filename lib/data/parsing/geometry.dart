/// Lightweight rectangle in PDF page coordinates (points, origin top-left).
///
/// Kept independent from dart:ui so the parsing engine stays pure Dart and
/// isolate-friendly.
class PdfBox {
  const PdfBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  Map<String, dynamic> toJson() =>
      {'left': left, 'top': top, 'width': width, 'height': height};

  factory PdfBox.fromJson(Map<String, dynamic> json) => PdfBox(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

/// A single word with its physical bounds on the page (points, top-left
/// origin). [text] is the extractor's raw token — used only to tell an
/// answer bullet ("א."/"ב.") apart from body words when carving out the
/// text region to shuffle in place.
class WordBox {
  const WordBox({required this.text, required this.bounds});

  final String text;
  final PdfBox bounds;
}

/// A single extracted text line with its bounds on the page.
///
/// [words] carries the line's per-word geometry when known (answer lines
/// need it to separate the fixed bullet marker from the swappable answer
/// text); it is empty for synthesized lines such as coalesced headers.
class LineBox {
  const LineBox({
    required this.text,
    required this.pageIndex,
    required this.bounds,
    this.words = const [],
  });

  final String text;
  final int pageIndex;
  final PdfBox bounds;
  final List<WordBox> words;
}
