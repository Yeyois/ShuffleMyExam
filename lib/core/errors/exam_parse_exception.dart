/// Thrown when a PDF yields no usable questions or cannot be processed.
class ExamParseException implements Exception {
  const ExamParseException(this.message);

  final String message;

  @override
  String toString() => 'ExamParseException: $message';
}
