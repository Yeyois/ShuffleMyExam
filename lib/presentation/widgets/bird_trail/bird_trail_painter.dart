import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bird_trail_system.dart';

/// Paints the glow aura and the bird flock. Repaints straight off the
/// simulation (`repaint: system`), so no widget rebuilds while the finger
/// moves — only the layer inside the enclosing `RepaintBoundary` redraws.
class BirdTrailPainter extends CustomPainter {
  BirdTrailPainter({
    required this.system,
    required this.glowColor,
    required this.birdColor,
  }) : super(repaint: system);

  final BirdTrailSystem system;
  final Color glowColor;
  final Color birdColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = system.fade;
    if (fade <= 0) return;

    final center = system.glowCenter;
    if (center != null) {
      _paintGlow(canvas, center, fade);
    }
    for (final bird in system.birds) {
      _paintBird(canvas, bird, fade);
    }
  }

  void _paintGlow(Canvas canvas, Offset center, double fade) {
    // Gentle breathing so a resting finger still feels alive.
    final radius = BirdTrailTuning.glowRadius *
        (0.92 + 0.08 * math.sin(system.elapsed * 5));
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Soft radial falloff instead of a blur filter — same bloom, far cheaper.
    final shader = RadialGradient(
      colors: [
        glowColor.withValues(alpha: 0.34 * fade),
        glowColor.withValues(alpha: 0.14 * fade),
        glowColor.withValues(alpha: 0),
      ],
      stops: const [0, 0.45, 1],
    ).createShader(rect);
    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  void _paintBird(Canvas canvas, Bird bird, double fade) {
    final envelope = bird.envelope;
    if (envelope <= 0.01) return;

    final span = bird.scale * (0.6 + 0.5 * envelope) * 9;
    final speed = bird.velocity.distance;
    final angle = speed > 1 ? bird.velocity.direction : 0.0;
    // Wing beat: 0 = wings level, 1 = wings raised.
    final flap = 0.5 + 0.5 * math.sin(bird.age * 26 + bird.wingPhase);
    final lift = span * (0.3 + 0.5 * flap);

    canvas.save();
    canvas.translate(bird.position.dx, bird.position.dy);
    canvas.rotate(angle);
    // Classic two-stroke gull silhouette.
    final path = Path()
      ..moveTo(-span, 0)
      ..quadraticBezierTo(-span * 0.5, -lift, 0, -span * 0.1)
      ..quadraticBezierTo(span * 0.5, -lift, span, 0);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, span * 0.17)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = birdColor.withValues(alpha: envelope * fade),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdTrailPainter old) =>
      old.system != system ||
      old.glowColor != glowColor ||
      old.birdColor != birdColor;
}
