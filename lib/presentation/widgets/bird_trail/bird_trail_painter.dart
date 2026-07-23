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
    required this.birdLightness,
  }) : super(repaint: system);

  final BirdTrailSystem system;
  final Color glowColor;

  /// HSL lightness for the flock, picked by the layer from the current theme:
  /// bright birds glow on a dark surface, deeper ones stay legible on a light
  /// one. Hue and saturation come from the bird itself.
  final double birdLightness;

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
        glowColor.withValues(alpha: 0.55 * fade),
        glowColor.withValues(alpha: 0.20 * fade),
        glowColor.withValues(alpha: 0),
      ],
      stops: const [0, 0.3, 1],
    ).createShader(rect);
    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  void _paintBird(Canvas canvas, Bird bird, double fade) {
    final envelope = bird.envelope;
    if (envelope <= 0.01) return;

    final span = bird.scale * (0.6 + 0.5 * envelope) * 15;
    // Wing beat: 0 = wings level, 1 = wings raised.
    final flap = 0.5 + 0.5 * math.sin(bird.age * 22 + bird.wingPhase);
    // Wingtips ride from slightly up to well above the body — never below,
    // since drooped tips read as a smile rather than a bird.
    final tip = span * (-0.18 - 0.4 * flap);

    canvas.save();
    canvas.translate(bird.position.dx, bird.position.dy);
    // Birds stay upright, the way a gull reads against the sky — rotating the
    // silhouette to face its heading would swing the wingspan into the line of
    // travel and turn it into a squiggle. Only the bank varies: sin(heading) is
    // the vertical share of the smoothed flight direction, so a bird climbing
    // tips up and a diving one tips down.
    canvas.rotate(math.sin(bird.heading) * 0.35);
    // Classic gull silhouette. Each wing is an arc from the raised tip down to
    // the body, with its control point *above* the chord so the wing bulges
    // upward — the two humps and the notch between them are what make it read
    // as a bird instead of a wave.
    final path = Path()
      ..moveTo(-span, tip)
      ..quadraticBezierTo(-span * 0.5, tip * 1.15, 0, 0)
      ..quadraticBezierTo(span * 0.5, tip * 1.15, span, tip);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, span * 0.11)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = HSLColor.fromAHSL(
          envelope * fade,
          bird.hue,
          0.85,
          birdLightness,
        ).toColor(),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdTrailPainter old) =>
      old.system != system ||
      old.glowColor != glowColor ||
      old.birdLightness != birdLightness;
}
