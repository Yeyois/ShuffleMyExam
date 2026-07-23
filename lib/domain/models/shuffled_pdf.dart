/// A generated, format-preserving shuffled PDF that was saved to the local
/// library so the user can re-download it later (current and past shuffles).
class ShuffledPdf {
  const ShuffledPdf({
    required this.id,
    required this.examTitle,
    required this.filePath,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;

  /// Title of the exam this shuffle was generated from.
  final String examTitle;

  /// Absolute path to the retained PDF file in the app's documents dir.
  final String filePath;

  final int sizeBytes;
  final DateTime createdAt;

  factory ShuffledPdf.fromJson(Map<String, dynamic> json) => ShuffledPdf(
        id: json['id'] as String,
        examTitle: json['examTitle'] as String,
        filePath: json['filePath'] as String,
        sizeBytes: json['sizeBytes'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'examTitle': examTitle,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}
