/// A single answer choice extracted from a Zero-Exam question.
///
/// In a Zero-Exam the first extracted answer is always the correct one, so
/// [isOriginalCorrect] is true only for the answer that appeared first in
/// the original PDF, regardless of the order answers are shown in.
class Answer {
  const Answer({
    required this.id,
    required this.text,
    required this.isOriginalCorrect,
  });

  final String id;
  final String text;
  final bool isOriginalCorrect;

  factory Answer.fromJson(Map<String, dynamic> json) => Answer(
        id: json['id'] as String,
        text: json['text'] as String,
        isOriginalCorrect: json['isOriginalCorrect'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isOriginalCorrect': isOriginalCorrect,
      };

  @override
  bool operator ==(Object other) =>
      other is Answer &&
      other.id == id &&
      other.text == text &&
      other.isOriginalCorrect == isOriginalCorrect;

  @override
  int get hashCode => Object.hash(id, text, isOriginalCorrect);
}
