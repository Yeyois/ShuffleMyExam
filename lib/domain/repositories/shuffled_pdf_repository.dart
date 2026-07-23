import '../models/shuffled_pdf.dart';

/// Contract for persisting the library of generated shuffled PDFs locally.
///
/// Implementations must be 100% offline.
abstract interface class ShuffledPdfRepository {
  /// All saved shuffled PDFs, most recently generated first.
  Future<List<ShuffledPdf>> getShuffledPdfs();

  Future<void> save(ShuffledPdf pdf);

  /// Removes the record and deletes the backing PDF file from disk.
  Future<void> delete(String id);
}
