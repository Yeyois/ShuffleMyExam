import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jct_mixexam/data/local/hive_shuffled_pdf_repository.dart';
import 'package:jct_mixexam/domain/models/shuffled_pdf.dart';

ShuffledPdf record(String id, {required String filePath, DateTime? createdAt}) =>
    ShuffledPdf(
      id: id,
      examTitle: 'מבחן $id',
      filePath: filePath,
      sizeBytes: 1234,
      createdAt: createdAt ?? DateTime.now(),
    );

void main() {
  late Directory tempDir;
  late HiveShuffledPdfRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_shuffled_test');
    Hive.init(tempDir.path);
    repo = await HiveShuffledPdfRepository.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('HiveShuffledPdfRepository', () {
    test('save and read back a record', () async {
      await repo.save(record('s1', filePath: '${tempDir.path}/s1.pdf'));

      final all = await repo.getShuffledPdfs();
      expect(all, hasLength(1));
      expect(all.single.id, 's1');
      expect(all.single.examTitle, 'מבחן s1');
      expect(all.single.sizeBytes, 1234);
    });

    test('getShuffledPdfs returns newest first', () async {
      final base = DateTime(2026, 1, 1);
      await repo.save(record('old',
          filePath: '${tempDir.path}/old.pdf', createdAt: base));
      await repo.save(record('new',
          filePath: '${tempDir.path}/new.pdf',
          createdAt: base.add(const Duration(minutes: 1))));

      final all = await repo.getShuffledPdfs();
      expect(all.map((p) => p.id).toList(), ['new', 'old']);
    });

    test('delete removes the record and its backing file', () async {
      final file = await File('${tempDir.path}/s1.pdf').create();
      await repo.save(record('s1', filePath: file.path));

      await repo.delete('s1');

      expect(await repo.getShuffledPdfs(), isEmpty);
      expect(await file.exists(), isFalse);
    });

    test('delete tolerates an already-missing file', () async {
      await repo.save(record('s1', filePath: '${tempDir.path}/gone.pdf'));

      await repo.delete('s1');

      expect(await repo.getShuffledPdfs(), isEmpty);
    });
  });
}
