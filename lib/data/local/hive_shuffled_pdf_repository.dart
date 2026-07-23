import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

import '../../domain/models/shuffled_pdf.dart';
import '../../domain/repositories/shuffled_pdf_repository.dart';

/// Hive-backed [ShuffledPdfRepository]. Stores each record as a JSON string
/// keyed by its id; the PDF bytes themselves live as files on disk (referenced
/// by [ShuffledPdf.filePath]).
class HiveShuffledPdfRepository implements ShuffledPdfRepository {
  HiveShuffledPdfRepository(this._box);

  static const boxName = 'shuffled_pdfs';

  final Box<String> _box;

  static Future<HiveShuffledPdfRepository> open() async {
    final box = await Hive.openBox<String>(boxName);
    return HiveShuffledPdfRepository(box);
  }

  @override
  Future<List<ShuffledPdf>> getShuffledPdfs() async {
    final records = _box.values
        .map((raw) => ShuffledPdf.fromJson(
            jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<void> save(ShuffledPdf pdf) async {
    await _box.put(pdf.id, jsonEncode(pdf.toJson()));
  }

  @override
  Future<void> delete(String id) async {
    final raw = _box.get(id);
    if (raw != null) {
      final pdf =
          ShuffledPdf.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final file = File(pdf.filePath);
      if (await file.exists()) await file.delete();
    }
    await _box.delete(id);
  }
}
