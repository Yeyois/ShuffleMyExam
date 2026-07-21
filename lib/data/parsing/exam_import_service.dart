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

/// Isolate entry point: loads the PDF, parses its structure (regex + bidi +
/// geometry), renders and crops the images of visual questions, and writes
/// them to disk. Everything heavy happens here, off the UI thread, per the
/// PRD's thread-safety directive.
///
/// [args] keys: `path`, `imagesDir`, `token` (nullable RootIsolateToken —
/// required for pdfx platform channels in a background isolate).
Future<Map<String, dynamic>> parseAndRenderEntry(
    Map<String, dynamic> args) async {
  final token = args['token'] as RootIsolateToken?;
  if (token != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }

  final path = args['path'] as String;
  final imagesDir = args['imagesDir'] as String;

  final bytes = await File(path).readAsBytes();
  final structure = PdfExamParser.parseBytes(bytes);

  final imagePaths = <String, Map<String, String>>{};
  final visualDrafts = <int, ParsedQuestionDraft>{};
  for (var i = 0; i < structure.questions.length; i++) {
    if (!structure.questions[i].isShufflable) {
      visualDrafts[i] = structure.questions[i];
    }
  }

  if (visualDrafts.isNotEmpty) {
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
  }

  return {'structure': structure.toJson(), 'images': imagePaths};
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
  final targetWidth = draft.pageWidth * scale;
  final targetHeight = draft.pageHeight * scale;

  final image = await page.render(
    width: targetWidth,
    height: targetHeight,
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

/// Application-facing import service: wraps the isolate work and assembles
/// the final [Exam].
class ExamImportService {
  const ExamImportService();

  Future<Exam> importPdf({
    required String pdfPath,
    required String title,
    required String imagesRootDir,
  }) async {
    final examId = generateId();
    final result = await compute(parseAndRenderEntry, <String, dynamic>{
      'path': pdfPath,
      'imagesDir': '$imagesRootDir/$examId',
      'token': RootIsolateToken.instance,
    });

    final structure = ParsedExamStructure.fromJson(
        result['structure'] as Map<String, dynamic>);
    final images = (result['images'] as Map).map(
      (k, v) => MapEntry(k as String, (v as Map).cast<String, String>()),
    );

    if (structure.questions.isEmpty) {
      throw const ExamParseException('no questions found in document');
    }

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

    return Exam(id: examId, title: title, questions: questions);
  }
}
