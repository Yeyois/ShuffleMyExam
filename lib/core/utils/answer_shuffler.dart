import 'dart:math';

import '../../domain/models/answer.dart';

/// Shuffles answers for presentation.
///
/// Guarantee: the originally-correct answer (index 0 in extraction order)
/// never stays at index 0 after shuffling, so the Zero-Exam position gives
/// nothing away. Lists with fewer than 2 answers are returned as-is.
List<Answer> shuffleAnswers(List<Answer> answers, {Random? random}) {
  if (answers.length < 2) return List.of(answers);
  final rng = random ?? Random();
  final shuffled = List.of(answers);
  do {
    shuffled.shuffle(rng);
  } while (shuffled.first.isOriginalCorrect);
  return shuffled;
}
