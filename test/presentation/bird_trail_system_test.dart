import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/presentation/widgets/bird_trail/bird_trail_system.dart';

/// Advances the simulation by [seconds] in 60 FPS steps, like a real ticker.
void _run(BirdTrailSystem system, double seconds) {
  const step = 1 / 60;
  for (var t = 0.0; t < seconds; t += step) {
    system.update(step);
  }
}

void main() {
  late BirdTrailSystem system;

  setUp(() => system = BirdTrailSystem(random: Random(7)));
  tearDown(() => system.dispose());

  group('emission', () {
    test('begin seeds a bird and lights the glow at the touch point', () {
      system.begin(const Offset(50, 400));

      expect(system.birds, hasLength(1));
      expect(system.glowCenter, const Offset(50, 400));
      expect(system.isEmitting, isTrue);
      expect(system.isIdle, isFalse);
    });

    test('holding the finger down keeps spawning birds', () {
      system.begin(const Offset(50, 400));
      _run(system, 0.15);

      expect(system.birds.length, greaterThan(1));
    });

    test('never exceeds the particle cap', () {
      system.begin(const Offset(50, 400));
      for (var i = 0; i < 600; i++) {
        system.moveTo(Offset(50 + i.toDouble(), 400));
        system.update(1 / 60);
      }

      expect(system.birds.length,
          lessThanOrEqualTo(BirdTrailTuning.maxBirds));
    });

    test('moveTo before begin is ignored', () {
      system.moveTo(const Offset(10, 10));

      expect(system.birds, isEmpty);
      expect(system.isIdle, isTrue);
    });
  });

  group('flight', () {
    test('birds trail toward the fingertip', () {
      system.begin(const Offset(0, 400));
      final bird = system.birds.single;
      final start = (bird.position - const Offset(300, 400)).distance;

      system.moveTo(const Offset(300, 400));
      _run(system, 0.1);

      expect((bird.position - const Offset(300, 400)).distance,
          lessThan(start));
    });

    test('birds die once past their lifespan', () {
      system.begin(const Offset(50, 400));
      // A very long fade so death is what clears the flock, not the fade.
      system.stop(fadeOut: const Duration(seconds: 10));
      final lifespan = BirdTrailTuning.particleLifespan.inMilliseconds / 1000;
      _run(system, lifespan * 1.5);

      expect(system.birds, isEmpty);
    });

    test('alpha envelope rises then falls over a bird lifetime', () {
      system.begin(const Offset(50, 400));
      final bird = system.birds.single;

      bird.age = bird.lifespan * 0.05;
      final early = bird.envelope;
      bird.age = bird.lifespan * 0.5;
      final middle = bird.envelope;
      bird.age = bird.lifespan * 0.95;
      final late = bird.envelope;

      expect(early, lessThan(middle));
      expect(late, lessThan(middle));
    });
  });

  group('termination', () {
    test('release fades out over the release duration', () {
      system.begin(const Offset(50, 400));
      system.stop(fadeOut: BirdTrailTuning.releaseFade);

      expect(system.isEmitting, isFalse);

      _run(system, 0.2);
      expect(system.fade, lessThan(1));
      expect(system.fade, greaterThan(0));

      _run(system, 0.3);
      expect(system.isIdle, isTrue);
      expect(system.glowCenter, isNull);
    });

    test('boundary exit clears faster than a release', () {
      final boundary = BirdTrailSystem(random: Random(1))
        ..begin(const Offset(50, 400))
        ..stop(fadeOut: BirdTrailTuning.boundaryFade);
      final release = BirdTrailSystem(random: Random(1))
        ..begin(const Offset(50, 400))
        ..stop(fadeOut: BirdTrailTuning.releaseFade);

      _run(boundary, 0.25);
      _run(release, 0.25);

      expect(boundary.isIdle, isTrue);
      expect(release.isIdle, isFalse);

      boundary.dispose();
      release.dispose();
    });

    test('stopping twice does not restart the fade', () {
      system.begin(const Offset(50, 400));
      system.stop(fadeOut: BirdTrailTuning.releaseFade);
      _run(system, 0.2);
      final faded = system.fade;

      system.stop(fadeOut: BirdTrailTuning.releaseFade);

      expect(system.fade, faded);
    });
  });

  group('scheduling', () {
    test('an idle system stays idle when updated', () {
      system.update(1 / 60);

      expect(system.isIdle, isTrue);
      expect(system.birds, isEmpty);
    });

    test('a long frame gap does not teleport birds', () {
      system.begin(const Offset(50, 400));
      system.moveTo(const Offset(400, 400));
      final bird = system.birds.first;

      // A 2 s stall (app backgrounded) is clamped to a single small step.
      system.update(2);

      expect(bird.position.dx, lessThan(400));
      expect(bird.position.dx.isFinite, isTrue);
    });
  });
}
