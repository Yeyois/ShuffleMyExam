import 'dart:math';

import '../../domain/models/answer.dart';

/// Shuffles answers for presentation.
///
/// This is a plain fair shuffle: every ordering is equally likely, so the
/// originally-correct answer (index 0 in extraction order) may land in any
/// position — including first. That is deliberate. Forcing the correct answer
/// away from slot 0 would actually leak information (slot 0 could be ruled out,
/// turning a 1-in-4 guess into 1-in-3); a fair shuffle gives nothing away
/// precisely because slot 0 might be correct. Lists with fewer than 2 answers
/// are returned as-is.
List<Answer> shuffleAnswers(List<Answer> answers, {Random? random}) {
  if (answers.length < 2) return List.of(answers);
  final rng = random ?? Random();
  return List.of(answers)..shuffle(rng);
}
