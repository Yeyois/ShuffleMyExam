import '../../domain/models/answer.dart';
import 'geometry.dart';

/// Intermediate parse result for a single question, before any image
/// rendering happens. JSON-safe so it can cross isolate boundaries.
class ParsedQuestionDraft {
  const ParsedQuestionDraft({
    required this.questionText,
    required this.answers,
    required this.isShufflable,
    required this.pageIndex,
    required this.pageWidth,
    required this.pageHeight,
    this.fullBox,
    this.croppedBox,
    this.answerBands,
    this.answerBullets,
  });

  final String questionText;

  /// Extraction order: first answer is the original correct one.
  final List<Answer> answers;

  final bool isShufflable;
  final int pageIndex;
  final double pageWidth;
  final double pageHeight;

  /// Set only for visual questions (Path B), in PDF page points.
  final PdfBox? fullBox;
  final PdfBox? croppedBox;

  /// For a format-preserving in-place shuffle: the full vertical band of
  /// each answer (bullet line through its last wrapped line), parallel to
  /// [answers], in PDF page points. The bands tile the answers region
  /// contiguously so they can be reordered without reflow. Null (together
  /// with [answerBullets]) when the question can't be reordered and must be
  /// left untouched.
  final List<PdfBox>? answerBands;

  /// The bullet-glyph box (א./ב./…) on each answer's first line, parallel to
  /// [answers]. Used to lift the original bullet pixels and restamp them in
  /// sequence after the bands are reordered. Non-null exactly when
  /// [answerBands] is.
  final List<PdfBox>? answerBullets;

  Map<String, dynamic> toJson() => {
        'questionText': questionText,
        'answers': answers.map((a) => a.toJson()).toList(),
        'isShufflable': isShufflable,
        'pageIndex': pageIndex,
        'pageWidth': pageWidth,
        'pageHeight': pageHeight,
        'fullBox': fullBox?.toJson(),
        'croppedBox': croppedBox?.toJson(),
        'answerBands': answerBands?.map((b) => b.toJson()).toList(),
        'answerBullets': answerBullets?.map((b) => b.toJson()).toList(),
      };

  factory ParsedQuestionDraft.fromJson(Map<String, dynamic> json) =>
      ParsedQuestionDraft(
        questionText: json['questionText'] as String,
        answers: (json['answers'] as List<dynamic>)
            .map((a) => Answer.fromJson(a as Map<String, dynamic>))
            .toList(),
        isShufflable: json['isShufflable'] as bool,
        pageIndex: json['pageIndex'] as int,
        pageWidth: (json['pageWidth'] as num).toDouble(),
        pageHeight: (json['pageHeight'] as num).toDouble(),
        fullBox: json['fullBox'] == null
            ? null
            : PdfBox.fromJson(json['fullBox'] as Map<String, dynamic>),
        croppedBox: json['croppedBox'] == null
            ? null
            : PdfBox.fromJson(json['croppedBox'] as Map<String, dynamic>),
        answerBands: (json['answerBands'] as List<dynamic>?)
            ?.map((b) => PdfBox.fromJson(b as Map<String, dynamic>))
            .toList(),
        answerBullets: (json['answerBullets'] as List<dynamic>?)
            ?.map((b) => PdfBox.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

/// The full structural parse of an exam PDF.
class ParsedExamStructure {
  const ParsedExamStructure({required this.questions});

  final List<ParsedQuestionDraft> questions;

  Map<String, dynamic> toJson() =>
      {'questions': questions.map((q) => q.toJson()).toList()};

  factory ParsedExamStructure.fromJson(Map<String, dynamic> json) =>
      ParsedExamStructure(
        questions: (json['questions'] as List<dynamic>)
            .map((q) =>
                ParsedQuestionDraft.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}
