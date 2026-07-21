import 'question.dart';

/// A parsed Zero-Exam, ready for practice.
class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.questions,
  });

  final String id;
  final String title;
  final List<Question> questions;

  factory Exam.fromJson(Map<String, dynamic> json) => Exam(
        id: json['id'] as String,
        title: json['title'] as String,
        questions: (json['questions'] as List<dynamic>)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}
