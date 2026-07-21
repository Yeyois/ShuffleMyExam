import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

import '../../domain/models/exam.dart';
import '../../domain/repositories/exam_repository.dart';

/// Hive-backed [ExamRepository]. Stores each exam as a JSON string keyed by
/// exam id, wrapped with a savedAt timestamp for ordering.
class HiveExamRepository implements ExamRepository {
  HiveExamRepository(this._box);

  static const boxName = 'exams';

  final Box<String> _box;

  static Future<HiveExamRepository> open() async {
    final box = await Hive.openBox<String>(boxName);
    return HiveExamRepository(box);
  }

  @override
  Future<List<Exam>> getExams() async {
    final records = _box.values
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .toList()
      ..sort(
        (a, b) => (b['savedAt'] as int).compareTo(a['savedAt'] as int),
      );
    return records
        .map((r) => Exam.fromJson(r['exam'] as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Exam?> getExam(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    final record = jsonDecode(raw) as Map<String, dynamic>;
    return Exam.fromJson(record['exam'] as Map<String, dynamic>);
  }

  @override
  Future<void> saveExam(Exam exam) async {
    final record = {
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'exam': exam.toJson(),
    };
    await _box.put(exam.id, jsonEncode(record));
  }

  @override
  Future<void> deleteExam(String id) async {
    final exam = await getExam(id);
    if (exam != null) {
      for (final question in exam.questions) {
        for (final path in [question.croppedImageUrl, question.fullImageUrl]) {
          if (path == null) continue;
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
    }
    await _box.delete(id);
  }
}
