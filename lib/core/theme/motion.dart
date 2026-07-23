import 'package:flutter/material.dart';

/// Shared motion language for the app — a small, consistent set of durations
/// and curves so every screen animates with the same playful character.
abstract final class Motion {
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 750);

  /// Per-item delay for staggered list/element entrances.
  static const stagger = Duration(milliseconds: 70);

  /// Bouncy overshoot for "pop" entrances and feedback.
  static const pop = Curves.elasticOut;

  /// Gentle overshoot — snappy but not silly.
  static const spring = Curves.easeOutBack;

  static const easeOut = Curves.easeOutCubic;
}
