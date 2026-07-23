import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/domain/models/answer.dart';
import 'package:jct_mixexam/domain/models/exam.dart';
import 'package:jct_mixexam/domain/models/question.dart';
import 'package:jct_mixexam/domain/repositories/exam_repository.dart';

/// In-memory repository for widget/controller tests.
class InMemoryExamRepository implements ExamRepository {
  final Map<String, Exam> _store = {};
  final List<Exam> _insertionOrder = [];

  @override
  Future<void> saveExam(Exam exam) async {
    if (!_store.containsKey(exam.id)) _insertionOrder.add(exam);
    _store[exam.id] = exam;
  }

  @override
  Future<Exam?> getExam(String id) async => _store[id];

  @override
  Future<List<Exam>> getExams() async =>
      _insertionOrder.reversed.where((e) => _store.containsKey(e.id)).toList();

  @override
  Future<void> deleteExam(String id) async => _store.remove(id);
}

/// A 1x1 transparent PNG.
final Uint8List kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Question textQuestion({String id = 'q-text', String? text}) => Question(
      id: id,
      questionText: text ?? 'מהו גודל המילה במעבד 8086?',
      isShufflable: true,
      textAnswers: [
        Answer(id: '$id-a1', text: '16 ביט', isOriginalCorrect: true),
        Answer(id: '$id-a2', text: '8 ביט', isOriginalCorrect: false),
        Answer(id: '$id-a3', text: '32 ביט', isOriginalCorrect: false),
        Answer(id: '$id-a4', text: '64 ביט', isOriginalCorrect: false),
      ],
    );

Question visualQuestion({
  String id = 'q-visual',
  required String croppedPath,
  required String fullPath,
}) =>
    Question(
      id: id,
      questionText: 'שאלה חזותית',
      isShufflable: false,
      textAnswers: const [],
      croppedImageUrl: croppedPath,
      fullImageUrl: fullPath,
    );

Exam textOnlyExam({String id = 'exam-1', String title = 'מבחן לדוגמה'}) =>
    Exam(id: id, title: title, questions: [textQuestion()]);

/// Writes tiny PNGs for a visual question into [dir] and returns the
/// question.
Question visualQuestionWithFiles(Directory dir, {String id = 'q-visual'}) {
  final cropped = File('${dir.path}/${id}_cropped.png')
    ..writeAsBytesSync(kTinyPng);
  final full = File('${dir.path}/${id}_full.png')..writeAsBytesSync(kTinyPng);
  return visualQuestion(
      id: id, croppedPath: cropped.path, fullPath: full.path);
}

/// Pumps [home] inside a ProviderScope + RTL MaterialApp shell.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: home,
      ),
    ),
  );
}
