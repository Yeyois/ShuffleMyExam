import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/presentation/widgets/bird_trail/bird_trail_layer.dart';
import 'package:jct_mixexam/presentation/widgets/bird_trail/bird_trail_system.dart';

void main() {
  group('isPointInTrailZone', () {
    const size = Size(400, 800);

    test('accepts a point in the free bottom area', () {
      expect(
        isPointInTrailZone(
          point: const Offset(200, 700),
          size: size,
          zoneHeightFraction: 0.42,
          exclusions: const [],
        ),
        isTrue,
      );
    });

    test('a full-height zone accepts points near the top', () {
      expect(
        isPointInTrailZone(
          point: const Offset(200, 40),
          size: size,
          zoneHeightFraction: 1,
          exclusions: const [],
        ),
        isTrue,
      );
    });

    test('rejects points above a footer-only zone', () {
      expect(
        isPointInTrailZone(
          point: const Offset(200, 300),
          size: size,
          zoneHeightFraction: 0.42,
          exclusions: const [],
        ),
        isFalse,
      );
    });

    test('rejects points inside an excluded card', () {
      expect(
        isPointInTrailZone(
          point: const Offset(200, 700),
          size: size,
          zoneHeightFraction: 0.42,
          exclusions: [const Rect.fromLTWH(0, 650, 400, 100)],
        ),
        isFalse,
      );
    });

    test('keeps a small margin around excluded bounds', () {
      // 2 px above the card's top edge still counts as "on the card".
      expect(
        isPointInTrailZone(
          point: const Offset(200, 648),
          size: size,
          zoneHeightFraction: 0.42,
          exclusions: [const Rect.fromLTWH(0, 650, 400, 100)],
        ),
        isFalse,
      );
    });

    test('rejects points outside the layer', () {
      expect(
        isPointInTrailZone(
          point: const Offset(-5, 700),
          size: size,
          zoneHeightFraction: 0.42,
          exclusions: const [],
        ),
        isFalse,
      );
    });
  });

  group('BirdTrailLayer', () {
    late BirdTrailSystem system;

    setUp(() => system = BirdTrailSystem(random: Random(3)));
    tearDown(() => system.dispose());

    /// A screen with a tappable card pinned to the top and free space below.
    Future<void> pumpLayer(
      WidgetTester tester, {
      bool enabled = true,
      List<String>? log,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BirdTrailLayer(
            enabled: enabled,
            system: system,
            child: Scaffold(
              body: Column(
                children: [
                  TrailExclusion(
                    child: GestureDetector(
                      onTap: () => log?.add('tap'),
                      child: Container(
                        height: 300,
                        color: Colors.blue,
                        alignment: Alignment.center,
                        child: const Text('card'),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('dragging through the free bottom area spawns birds',
        (tester) async {
      await pumpLayer(tester);

      final gesture = await tester.startGesture(const Offset(200, 500));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(260, 520));
      await tester.pump(const Duration(milliseconds: 16));

      expect(system.birds, isNotEmpty);
      expect(system.glowCenter, isNotNull);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(system.isIdle, isTrue);
    });

    testWidgets('free space above the footer is live too', (tester) async {
      await pumpLayer(tester);

      // Just below the card — inside the old footer-only zone's dead area.
      final gesture = await tester.startGesture(const Offset(200, 330));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(250, 360));
      await tester.pump(const Duration(milliseconds: 16));

      expect(system.birds, isNotEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('touching a card never starts a trail', (tester) async {
      await pumpLayer(tester);

      final gesture = await tester.startGesture(const Offset(200, 150));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(210, 160));
      await tester.pump(const Duration(milliseconds: 16));

      expect(system.birds, isEmpty);
      expect(system.isIdle, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('card taps still work through the layer', (tester) async {
      final log = <String>[];
      await pumpLayer(tester, log: log);

      await tester.tap(find.text('card'));
      await tester.pump();

      expect(log, ['tap']);
    });

    testWidgets('crossing into a card stops emission and fades out',
        (tester) async {
      await pumpLayer(tester);

      final gesture = await tester.startGesture(const Offset(200, 560));
      await tester.pump(const Duration(milliseconds: 16));
      expect(system.isEmitting, isTrue);

      // Drag up over the card boundary.
      await gesture.moveTo(const Offset(200, 150));
      await tester.pump(const Duration(milliseconds: 16));

      expect(system.isEmitting, isFalse);

      // Everything fades out even though the finger is still down.
      await tester.pumpAndSettle();
      expect(system.birds, isEmpty);
      expect(system.isIdle, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('disabled layer never emits', (tester) async {
      await pumpLayer(tester, enabled: false);

      final gesture = await tester.startGesture(const Offset(200, 500));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(260, 520));
      await tester.pump(const Duration(milliseconds: 16));

      expect(system.birds, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('respects the reduce-animations accessibility setting',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: BirdTrailLayer(
              system: system,
              child: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(200, 500));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(const Offset(260, 520));
      await tester.pump(const Duration(milliseconds: 16));

      expect(system.birds, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
