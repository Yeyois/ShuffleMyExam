import 'question.dart';

/// A parsed Zero-Exam, ready for practice.
class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.questions,
    this.originalPdfPath,
  });

  final String id;
  final String title;
  final List<Question> questions;

  /// Path to a retained copy of the imported PDF. The exporter re-reads it
  /// to produce a format-preserving, in-place shuffled version. Null for
  /// exams imported before this was retained (they must be re-imported to
  /// export).
  final String? originalPdfPath;

  factory Exam.fromJson(Map<String, dynamic> json) => Exam(
        id: json['id'] as String,
        title: json['title'] as String,
        questions: (json['questions'] as List<dynamic>)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList(),
        originalPdfPath: json['originalPdfPath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
        'originalPdfPath': originalPdfPath,
      };
}
