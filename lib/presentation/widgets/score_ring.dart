import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';

/// A circular progress ring whose arc and centre percentage both animate up
/// from zero together on first build.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.percentage,
    this.size = 168,
    this.color,
  });

  final int percentage;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final arcColor = color ??
        (percentage >= 80
            ? const Color(0xFF00C853)
            : percentage >= 50
                ? scheme.primary
                : const Color(0xFFFF6D00));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percentage.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Motion.easeOut,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: v / 100,
            arcColor: arcColor,
            trackColor: scheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Text(
              '${v.round()}%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: arcColor,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.arcColor,
    required this.trackColor,
  });

  final double fraction;
  final Color arcColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * pi, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    // Start at the top, sweep clockwise.
    canvas.drawArc(rect, -pi / 2, 2 * pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.arcColor != arcColor;
}
