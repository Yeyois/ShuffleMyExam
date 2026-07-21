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

  Map<String, dynamic> toJson() => {
        'questionText': questionText,
        'answers': answers.map((a) => a.toJson()).toList(),
        'isShufflable': isShufflable,
        'pageIndex': pageIndex,
        'pageWidth': pageWidth,
        'pageHeight': pageHeight,
        'fullBox': fullBox?.toJson(),
        'croppedBox': croppedBox?.toJson(),
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
