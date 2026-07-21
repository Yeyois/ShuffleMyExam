import 'dart:math';

final _random = Random();

/// Generates a unique-enough id for local, offline entities.
String generateId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final salt = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '$now-$salt';
}
