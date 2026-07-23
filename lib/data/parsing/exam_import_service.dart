import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../../core/errors/exam_parse_exception.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/models/exam.dart';
import '../../domain/models/question.dart';
import 'geometry.dart';
import 'parsed_structures.dart';
import 'pdf_exam_parser.dart';

/// Isolate entry point for the structural parse: PDF load, regex scan,
/// bidi normalization and crop geometry — all CPU-bound, all off the UI
/// thread per the PRD's thread-safety directive.
///
/// [args] keys: `path`.
Future<Map<String, dynamic>> parseExamEntry(Map<String, dynamic> args) async {
  final bytes = await File(args['path'] as String).readAsBytes();
  return PdfExamParser.parseBytes(bytes).toJson();
}

/// Isolate entry point for rendering the cropped/full PNGs of visual
/// questions via pdfx. Needs a [RootIsolateToken] because pdfx talks over
/// platform channels.
///
/// [args] keys: `path`, `imagesDir`, `structure`, `token`.
/// Returns {questionIndex: {'full': path, 'cropped': path}}.
Future<Map<String, Map<String, String>>> renderVisualsEntry(
    Map<String, dynamic> args) async {
  final token = args['token'] as RootIsolateToken?;
  if (token != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }

  final path = args['path'] as String;
  final imagesDir = args['imagesDir'] as String;
  final structure = ParsedExamStructure.fromJson(
      args['structure'] as Map<String, dynamic>);

  final visualDrafts = <int, ParsedQuestionDraft>{};
  for (var i = 0; i < structure.questions.length; i++) {
    if (!structure.questions[i].isShufflable) {
      visualDrafts[i] = structure.questions[i];
    }
  }
  if (visualDrafts.isEmpty) return const {};

  final imagePaths = <String, Map<String, String>>{};
  await Directory(imagesDir).create(recursive: true);
  final document = await pdfx.PdfDocument.openFile(path);
  try {
    for (final entry in visualDrafts.entries) {
      final draft = entry.value;
      final page = await document.getPage(draft.pageIndex + 1);
      try {
        final fullPath = '$imagesDir/q${entry.key}_full.png';
        final croppedPath = '$imagesDir/q${entry.key}_cropped.png';
        await _renderBox(page, draft, draft.fullBox!, fullPath);
        await _renderBox(page, draft, draft.croppedBox!, croppedPath);
        imagePaths['${entry.key}'] = {
          'full': fullPath,
          'cropped': croppedPath,
        };
      } finally {
        await page.close();
      }
    }
  } finally {
    await document.close();
  }
  return imagePaths;
}

/// Renders [box] (PDF points) of [page] to a PNG at [outputPath].
/// pdfx expects the crop rect in pixels of the full-page render target.
Future<void> _renderBox(
  pdfx.PdfPage page,
  ParsedQuestionDraft draft,
  PdfBox box,
  String outputPath,
) async {
  const scale = 2.0; // ~144 dpi, sharp enough for phone screens.
  final image = await page.render(
    width: draft.pageWidth * scale,
    height: draft.pageHeight * scale,
    format: pdfx.PdfPageImageFormat.png,
    cropRect: Rect.fromLTWH(
      box.left * scale,
      box.top * scale,
      box.width * scale,
      box.height * scale,
    ),
  );
  if (image == null) {
    throw const ExamParseException('page render failed');
  }
  await File(outputPath).writeAsBytes(image.bytes);
}

/// Application-facing import service: runs both isolate stages and
/// assembles the final [Exam].
class ExamImportService {
  const ExamImportService();

  Future<Exam> importPdf({
    required String pdfPath,
    required String title,
    required String imagesRootDir,
  }) async {
    final examId = generateId();
    final structureJson = await compute(
        parseExamEntry, <String, dynamic>{'path': pdfPath});
    final structure = ParsedExamStructure.fromJson(structureJson);

    if (structure.questions.isEmpty) {
      throw const ExamParseException('no questions found in document');
    }

    final examDir = '$imagesRootDir/$examId';

    // Retain the original PDF so the exporter can produce a
    // format-preserving, in-place shuffled copy later.
    await Directory(examDir).create(recursive: true);
    final retainedPdfPath = '$examDir/original.pdf';
    await File(pdfPath).copy(retainedPdfPath);

    final images = await renderVisualQuestions(
      structure: structure,
      pdfPath: pdfPath,
      imagesDir: examDir,
    );

    final questions = <Question>[];
    for (var i = 0; i < structure.questions.length; i++) {
      final draft = structure.questions[i];
      questions.add(
        Question(
          id: generateId(),
          questionText: draft.questionText,
          textAnswers: draft.isShufflable ? draft.answers : const [],
          isShufflable: draft.isShufflable,
          croppedImageUrl: images['$i']?['cropped'],
          fullImageUrl: images['$i']?['full'],
        ),
      );
    }

    return Exam(
      id: examId,
      title: title,
      questions: questions,
      originalPdfPath: retainedPdfPath,
    );
  }

  /// Renders visual questions in a background isolate. Overridable so
  /// host-side tests (no pdfx plugin) can fake the rendering stage.
  @protected
  @visibleForOverriding
  Future<Map<String, Map<String, String>>> renderVisualQuestions({
    required ParsedExamStructure structure,
    required String pdfPath,
    required String imagesDir,
  }) {
    return compute(renderVisualsEntry, <String, dynamic>{
      'path': pdfPath,
      'imagesDir': imagesDir,
      'structure': structure.toJson(),
      'token': RootIsolateToken.instance,
    });
  }
}
