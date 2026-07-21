import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jct_mixexam/data/local/hive_exam_repository.dart';
import 'package:jct_mixexam/domain/models/answer.dart';
import 'package:jct_mixexam/domain/models/exam.dart';
import 'package:jct_mixexam/domain/models/question.dart';

Exam exam(String id, {String? imagePath}) => Exam(
      id: id,
      title: 'מבחן $id',
      questions: [
        Question(
          id: '$id-q1',
          questionText: 'שאלה ראשונה',
          isShufflable: imagePath == null,
          textAnswers: imagePath == null
              ? const [
                  Answer(id: 'a1', text: 'נכון', isOriginalCorrect: true),
                  Answer(id: 'a2', text: 'לא נכון', isOriginalCorrect: false),
                ]
              : const [],
          croppedImageUrl: imagePath == null ? null : '${imagePath}_c.png',
          fullImageUrl: imagePath == null ? null : '${imagePath}_f.png',
        ),
      ],
    );

void main() {
  late Directory tempDir;
  late HiveExamRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    repo = await HiveExamRepository.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('HiveExamRepository CRUD', () {
    test('save and read back an exam', () async {
      await repo.saveExam(exam('e1'));

      final restored = await repo.getExam('e1');
      expect(restored, isNotNull);
      expect(restored!.title, 'מבחן e1');
      expect(restored.questions.single.textAnswers.first.isOriginalCorrect,
          isTrue);
    });

    test('getExams returns most recently saved first', () async {
      await repo.saveExam(exam('e1'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.saveExam(exam('e2'));

      final all = await repo.getExams();
      expect(all.map((e) => e.id).toList(), ['e2', 'e1']);
    });

    test('saving with an existing id overwrites', () async {
      await repo.saveExam(exam('e1'));
      await repo.saveExam(
        Exam(id: 'e1', title: 'כותרת חדשה', questions: const []),
      );

      final restored = await repo.getExam('e1');
      expect(restored!.title, 'כותרת חדשה');
      expect(await repo.getExams(), hasLength(1));
    });

    test('delete removes the exam and its image files', () async {
      final imageBase = '${tempDir.path}/q1';
      final cropped = await File('${imageBase}_c.png').create();
      final full = await File('${imageBase}_f.png').create();

      await repo.saveExam(exam('e1', imagePath: imageBase));
      await repo.deleteExam('e1');

      expect(await repo.getExam('e1'), isNull);
      expect(await cropped.exists(), isFalse);
      expect(await full.exists(), isFalse);
    });

    test('getExam returns null for unknown id', () async {
      expect(await repo.getExam('missing'), isNull);
    });
  });
}
