import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'bird_trail_painter.dart';
import 'bird_trail_system.dart';

/// True when [point] may emit birds: inside the live zone of a [size] box and
/// clear of every excluded (interactive) rect.
///
/// [zoneHeightFraction] is the share of the height, measured up from the
/// bottom, that is live — 1 for the whole screen.
///
/// Pure geometry so the hit-test rule can be unit-tested on its own.
bool isPointInTrailZone({
  required Offset point,
  required Size size,
  required double zoneHeightFraction,
  required List<Rect> exclusions,
  double exclusionPadding = 4,
}) {
  if (point.dx < 0 ||
      point.dy < 0 ||
      point.dx > size.width ||
      point.dy > size.height) {
    return false;
  }
  if (point.dy < size.height * (1 - zoneHeightFraction)) return false;
  for (final rect in exclusions) {
    if (rect.inflate(exclusionPadding).contains(point)) return false;
  }
  return true;
}

/// Tracks the widgets that must never emit birds (cards, buttons, …) so the
/// layer can hit-test against their live bounds.
class TrailExclusionRegistry {
  final Set<BuildContext> _contexts = {};

  void register(BuildContext context) => _contexts.add(context);

  void unregister(BuildContext context) => _contexts.remove(context);

  /// Excluded bounds expressed in [layer]'s coordinate space. Off-screen or
  /// not-yet-laid-out entries are skipped.
  List<Rect> rectsIn(RenderBox layer) {
    final rects = <Rect>[];
    for (final context in _contexts) {
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final topLeft = layer.globalToLocal(box.localToGlobal(Offset.zero));
      rects.add(topLeft & box.size);
    }
    return rects;
  }
}

/// Hands the registry down to [TrailExclusion] descendants.
class _BirdTrailScope extends InheritedWidget {
  const _BirdTrailScope({required this.registry, required super.child});

  final TrailExclusionRegistry registry;

  static TrailExclusionRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_BirdTrailScope>()
      ?.registry;

  @override
  bool updateShouldNotify(_BirdTrailScope old) => old.registry != registry;
}

/// Marks its subtree as off-limits to the bird trail. Wrap cards, buttons and
/// anything else the user can act on; touches landing inside never start a
/// trail, and a drag entering one kills the trail on the spot.
///
/// A no-op when there is no [BirdTrailLayer] above it.
class TrailExclusion extends StatefulWidget {
  const TrailExclusion({super.key, required this.child});

  final Widget child;

  @override
  State<TrailExclusion> createState() => _TrailExclusionState();
}

class _TrailExclusionState extends State<TrailExclusion> {
  TrailExclusionRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = _BirdTrailScope.maybeOf(context);
    if (registry == _registry) return;
    _registry?.unregister(context);
    _registry = registry?..register(context);
  }

  @override
  void dispose() {
    _registry?.unregister(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wraps a screen with an interactive canvas: dragging a finger across the free
/// space emits a glowing aura and a trail of birds that chase the fingertip.
///
/// The layer never consumes gestures — it listens translucently, so scrolling
/// and taps behave exactly as they did without it. The whole screen is live by
/// default; what keeps the effect off the content is [TrailExclusion], which
/// blocks emission over every card, button and other interactive element in
/// the subtree.
class BirdTrailLayer extends StatefulWidget {
  const BirdTrailLayer({
    super.key,
    required this.child,
    this.zoneHeightFraction = 1,
    this.enabled = true,
    @visibleForTesting this.system,
  });

  final Widget child;

  /// Share of the screen height, measured up from the bottom, that is live.
  /// Defaults to the full screen; lower it to confine the canvas to a footer.
  final double zoneHeightFraction;

  final bool enabled;

  /// Injectable simulation, for tests to observe. Not disposed by the layer.
  final BirdTrailSystem? system;

  @override
  State<BirdTrailLayer> createState() => _BirdTrailLayerState();
}

class _BirdTrailLayerState extends State<BirdTrailLayer>
    with SingleTickerProviderStateMixin {
  final TrailExclusionRegistry _registry = TrailExclusionRegistry();
  late final BirdTrailSystem _system = widget.system ?? BirdTrailSystem();
  late final Ticker _ticker;

  Duration _lastTick = Duration.zero;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (widget.system == null) _system.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    _system.update(dt);
    // Idle costs nothing: the ticker only runs while there is something to
    // simulate.
    if (_system.isIdle) _ticker.stop();
  }

  void _startTicking() {
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  /// Whether trails are allowed at all — respects the platform's
  /// "remove animations" accessibility setting.
  bool get _active =>
      widget.enabled && !MediaQuery.disableAnimationsOf(context);

  bool _canEmitAt(Offset localPosition) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    return isPointInTrailZone(
      point: localPosition,
      size: box.size,
      zoneHeightFraction: widget.zoneHeightFraction,
      exclusions: _registry.rectsIn(box),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_active || _pointer != null) return;
    if (!_canEmitAt(event.localPosition)) return;
    _pointer = event.pointer;
    _system.begin(event.localPosition);
    _startTicking();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    if (!_canEmitAt(event.localPosition)) {
      // Crossed into a card or out of the zone — cut emission immediately.
      _end(BirdTrailTuning.boundaryFade);
      return;
    }
    _system.moveTo(event.localPosition);
  }

  void _onPointerUp(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _end(BirdTrailTuning.releaseFade);
  }

  void _end(Duration fadeOut) {
    _pointer = null;
    _system.stop(fadeOut: fadeOut);
    _startTicking();
  }

  /// A scroll means the finger belongs to the list, not to the canvas.
  bool _onScroll(ScrollNotification notification) {
    if (_pointer != null &&
        notification is ScrollUpdateNotification &&
        (notification.scrollDelta ?? 0) != 0) {
      _end(BirdTrailTuning.boundaryFade);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: _BirdTrailScope(
        registry: _registry,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: BirdTrailPainter(
                      system: _system,
                      glowColor: scheme.primary,
                      birdLightness: isDark ? 0.66 : 0.45,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
