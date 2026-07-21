import '../models/exam.dart';

/// Contract for persisting parsed exams locally.
///
/// Implementations must be 100% offline.
abstract interface class ExamRepository {
  /// All saved exams, most recently imported first.
  Future<List<Exam>> getExams();

  Future<Exam?> getExam(String id);

  Future<void> saveExam(Exam exam);

  /// Removes the exam and any image files its questions reference.
  Future<void> deleteExam(String id);
}
