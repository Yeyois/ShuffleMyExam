import 'dart:math';

import 'package:flutter/material.dart';

/// A one-shot confetti burst: particles shoot up from the bottom-center,
/// arc under gravity, spin, and fade. Finite (plays once then stops) so it
/// never blocks `pumpAndSettle`. Purely painted — no dependencies.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.count = 90,
    this.duration = const Duration(milliseconds: 2200),
  });

  final int count;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Particle> _particles;

  static const _palette = [
    Color(0xFFFF5252),
    Color(0xFFFFB300),
    Color(0xFF00C853),
    Color(0xFF2979FF),
    Color(0xFFAA00FF),
    Color(0xFF00E5FF),
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(widget.count, (i) {
      // Launch angle clustered upward, with a spread to both sides.
      final angle = -pi / 2 + (rng.nextDouble() - 0.5) * 1.7;
      final speed = 0.9 + rng.nextDouble() * 0.8;
      return _Particle(
        angle: angle,
        speed: speed,
        color: _palette[rng.nextInt(_palette.length)],
        size: 6 + rng.nextDouble() * 8,
        spin: (rng.nextDouble() - 0.5) * 12,
        delay: rng.nextDouble() * 0.15,
        drift: (rng.nextDouble() - 0.5) * 0.6,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_particles, _controller.value),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.spin,
    required this.delay,
    required this.drift,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spin;
  final double delay;
  final double drift;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    // Launch reach scales with the viewport so it fills the screen.
    final reach = size.height * 0.9;

    for (final p in particles) {
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;

      final dx = cos(p.angle) * p.speed * reach * lt +
          p.drift * reach * lt * lt;
      // Upward launch, then gravity pulls back down (parabola).
      final dy = sin(p.angle) * p.speed * reach * lt +
          0.9 * reach * lt * lt;

      final pos = origin + Offset(dx, dy);
      final opacity = (1.0 - lt * lt).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * lt);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
