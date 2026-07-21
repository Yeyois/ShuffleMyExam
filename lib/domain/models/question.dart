import 'answer.dart';

/// A single question extracted from a Zero-Exam PDF.
///
/// Text questions ([isShufflable] == true) carry [textAnswers] in their
/// original extraction order (first answer is the correct one). Visual
/// questions ([isShufflable] == false) carry image paths instead:
/// [croppedImageUrl] shows the question body only, [fullImageUrl] the full
/// original layout including the Zero-Exam answers. The UI must never show
/// [fullImageUrl] by default.
class Question {
  const Question({
    required this.id,
    required this.questionText,
    required this.textAnswers,
    required this.isShufflable,
    this.croppedImageUrl,
    this.fullImageUrl,
  });

  final String id;
  final String questionText;

  /// Populated if [isShufflable] == true.
  final List<Answer> textAnswers;

  /// true if pure text, false if the question contains visuals.
  final bool isShufflable;

  /// Question body only (without answers).
  final String? croppedImageUrl;

  /// Full original question with answers.
  final String? fullImageUrl;

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        questionText: json['questionText'] as String,
        textAnswers: (json['textAnswers'] as List<dynamic>)
            .map((a) => Answer.fromJson(a as Map<String, dynamic>))
            .toList(),
        isShufflable: json['isShufflable'] as bool,
        croppedImageUrl: json['croppedImageUrl'] as String?,
        fullImageUrl: json['fullImageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'questionText': questionText,
        'textAnswers': textAnswers.map((a) => a.toJson()).toList(),
        'isShufflable': isShufflable,
        'croppedImageUrl': croppedImageUrl,
        'fullImageUrl': fullImageUrl,
      };
}
