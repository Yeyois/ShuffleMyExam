import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Tuning for the fingertip bird trail. Kept in one place so the feel can be
/// adjusted without touching the simulation or the painter.
abstract final class BirdTrailTuning {
  /// How long a single bird lives once spawned (jittered per bird).
  ///
  /// Longer than the 200–300 ms in the spec: at 300 ms the flock collapses
  /// onto the fingertip and never reads as a trail. The *visible* fade rule
  /// still holds — [releaseFade] drives the global alpha, so everything is
  /// gone within 400 ms of the finger lifting regardless of bird age.
  static const Duration particleLifespan = Duration(milliseconds: 700);

  /// Fade-out after the finger is lifted.
  static const Duration releaseFade = Duration(milliseconds: 400);

  /// Faster fade-out when the finger crosses into a card / interactive area.
  static const Duration boundaryFade = Duration(milliseconds: 200);

  /// Time between bird spawns while the emitter is live.
  static const Duration spawnInterval = Duration(milliseconds: 55);

  /// Hard cap on live birds — keeps the per-frame cost flat.
  static const int maxBirds = 18;

  /// Radius of the glow aura under the fingertip, in logical pixels. Kept
  /// close to a fingertip — larger reads as a smudge following the touch
  /// rather than a light at it.
  static const double glowRadius = 30;
}

/// A single bird in the trail. Mutable and reused per frame — the simulation
/// runs at 60 FPS, so allocations are kept out of the update loop.
class Bird {
  Bird({
    required this.position,
    required this.velocity,
    required this.lifespan,
    required this.scale,
    required this.wingPhase,
    required this.wander,
    required this.hue,
  });

  Offset position;
  Offset velocity;

  /// Smoothed flight direction, in radians. Birds bank toward their heading
  /// instead of snapping to the instantaneous velocity, which would spin them
  /// on the spot whenever they slow down.
  double heading = 0;

  /// Seconds this bird lives for.
  final double lifespan;

  /// Seconds since spawn.
  double age = 0;

  final double scale;

  /// Desynchronises wing beats across the flock.
  final double wingPhase;

  /// Signed [-1, 1] steering bias — gives each bird its own drift so the
  /// flock spreads instead of collapsing onto a single line.
  final double wander;

  /// Hue in degrees. Walked forward per spawn so the trail reads as a rainbow
  /// ribbon rather than a bag of random colours.
  final double hue;

  double get life => (age / lifespan).clamp(0.0, 1.0);

  bool get isDead => age >= lifespan;

  /// Smooth 0 → 1 → 0 envelope used for both alpha and scale, so birds fade
  /// in and out instead of popping.
  double get envelope => math.sin(life * math.pi);
}

/// The trail simulation: an emitter that follows the fingertip and spawns
/// birds which chase it with drag and a little flocking wander.
///
/// Pure logic (no widgets) so it can be unit-tested, and a [ChangeNotifier] so
/// the painter can repaint from it directly without rebuilding any widget.
class BirdTrailSystem extends ChangeNotifier {
  BirdTrailSystem({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  final List<Bird> _birds = [];

  /// Live birds. Exposed directly (not a copy) because the painter walks this
  /// every frame.
  List<Bird> get birds => _birds;

  Offset? _emitter;
  Offset? _glowCenter;
  Offset _moveDelta = Offset.zero;
  double _fade = 1;
  double _fadeRate = 0;
  double _sinceSpawn = 0;
  double _elapsed = 0;
  double _hue = 0;

  /// Where to draw the glow aura, or null when there is nothing to draw.
  Offset? get glowCenter => _glowCenter;

  /// Global alpha multiplier, driven down by [stop].
  double get fade => _fade;

  /// Seconds since the system started running — drives the glow pulse.
  double get elapsed => _elapsed;

  /// True while a finger is down inside the active zone.
  bool get isEmitting => _emitter != null;

  /// Nothing left to simulate or draw — the ticker can be stopped.
  bool get isIdle => _emitter == null && _birds.isEmpty && _fadeRate == 0;

  /// Touch down inside the active zone: light the glow and seed the flock.
  void begin(Offset point) {
    _emitter = point;
    _glowCenter = point;
    _moveDelta = Offset.zero;
    _fade = 1;
    _fadeRate = 0;
    _sinceSpawn = 0;
    // Every stroke starts somewhere new on the wheel.
    _hue = _random.nextDouble() * 360;
    _spawn(point);
    notifyListeners();
  }

  /// Touch move inside the active zone: the emitter chases the fingertip.
  void moveTo(Offset point) {
    if (_emitter == null) return;
    _moveDelta = point - _emitter!;
    _emitter = point;
    _glowCenter = point;
  }

  /// Release or boundary crossing: stop emitting and fade everything out over
  /// [fadeOut]. The birds keep flying (with no target) while they fade.
  void stop({required Duration fadeOut}) {
    if (_emitter == null && _fadeRate > 0) return;
    _emitter = null;
    final seconds = fadeOut.inMicroseconds / Duration.microsecondsPerSecond;
    _fadeRate = seconds <= 0 ? double.infinity : 1 / seconds;
    notifyListeners();
  }

  /// Drops everything immediately (used on dispose / when disabled).
  void reset() {
    _birds.clear();
    _emitter = null;
    _glowCenter = null;
    _fade = 1;
    _fadeRate = 0;
    notifyListeners();
  }

  /// Advances the simulation by [dt] seconds.
  void update(double dt) {
    if (isIdle) return;
    // Clamp so a dropped frame (or a backgrounded app) doesn't teleport birds.
    dt = dt.clamp(0.0, 0.05);
    _elapsed += dt;

    if (_fadeRate > 0) {
      _fade = math.max(0, _fade - _fadeRate * dt);
      if (_fade == 0) {
        reset();
        return;
      }
    }

    final target = _emitter;
    if (target != null) {
      _sinceSpawn += dt;
      final interval =
          BirdTrailTuning.spawnInterval.inMicroseconds /
              Duration.microsecondsPerSecond;
      while (_sinceSpawn >= interval) {
        _sinceSpawn -= interval;
        _spawn(target);
      }
      // Bleed off the recorded finger movement so a paused finger stops
      // throwing birds backwards.
      _moveDelta *= math.pow(0.02, dt).toDouble();
    }

    for (final bird in _birds) {
      _integrate(bird, dt, target);
    }
    _birds.removeWhere((bird) => bird.isDead);

    notifyListeners();
  }

  void _spawn(Offset at) {
    if (_birds.length >= BirdTrailTuning.maxBirds) return;
    final lifespan = BirdTrailTuning.particleLifespan.inMicroseconds /
        Duration.microsecondsPerSecond;
    // Birds are thrown behind the fingertip so the trail lags into a path.
    final velocity = -_moveDelta * 9 + _jitter(90);
    _birds.add(
      Bird(
        position: at + _jitter(34),
        velocity: velocity,
        lifespan: lifespan * (0.8 + _random.nextDouble() * 0.4),
        scale: 0.75 + _random.nextDouble() * 0.5,
        wingPhase: _random.nextDouble() * math.pi * 2,
        wander: _random.nextDouble() * 2 - 1,
        hue: _nextHue(),
      )..heading = velocity.direction,
    );
  }

  /// Advances the hue by a step that doesn't divide 360, so the trail cycles
  /// through the whole wheel without ever repeating a neighbour's colour.
  double _nextHue() {
    _hue = (_hue + 47) % 360;
    return _hue;
  }

  Offset _jitter(double magnitude) => Offset(
        (_random.nextDouble() - 0.5) * magnitude,
        (_random.nextDouble() - 0.5) * magnitude,
      );

  void _integrate(Bird bird, double dt, Offset? target) {
    bird.age += dt;

    if (target != null) {
      // Spring pull toward the fingertip; per-bird stiffness spreads the flock.
      // Eased off close in so the flock doesn't converge onto a single point,
      // but strong enough far out that stragglers chase rather than stall.
      final toTarget = target - bird.position;
      final closeness = (toTarget.distance / 90).clamp(0.5, 1.0);
      bird.velocity +=
          toTarget * (5 + bird.wander.abs() * 3) * closeness * dt;
    }

    final speed = bird.velocity.distance;
    if (speed > 1) {
      // Flocking wander: oscillate perpendicular to the flight direction.
      final direction = bird.velocity / speed;
      final perpendicular = Offset(-direction.dy, direction.dx);
      final swing = math.sin(bird.age * 9 + bird.wingPhase);
      bird.velocity += perpendicular * (swing * bird.wander * 140 * dt);
    }

    // Light drag — birds glide on rather than stopping dead.
    bird.velocity *= math.pow(0.45, dt).toDouble();
    bird.position += bird.velocity * dt;

    if (speed > 25) {
      // Ease the heading toward the direction of travel, the short way round.
      var delta = bird.velocity.direction - bird.heading;
      while (delta > math.pi) {
        delta -= 2 * math.pi;
      }
      while (delta < -math.pi) {
        delta += 2 * math.pi;
      }
      bird.heading += delta * (1 - math.pow(0.02, dt).toDouble());
    }
  }
}
