import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_theme.dart';

/// Autumn dusk life over the town square: falling leaves, a campfire glow
/// that breathes, a forge-mouth flicker, and low mist. One painter, a dozen
/// rects and about ten gradients a frame. The ticker stops when motion is off, the route is
/// offstage ([TickerMode]), or the app is backgrounded; then one still
/// frame is painted.
abstract final class TownAmbience {
  static const loop = Duration(seconds: 12);

  /// Still frame used when motion is off. Leaves sit mid-fall.
  static const stillT = 0.31;

  static const leafCount = 14;

  static const leafColors = <Color>[
    GameTheme.townLeafRed,
    GameTheme.townLeafOrange,
    GameTheme.townLeafGold,
    GameTheme.townLeafMaroon,
    GameTheme.townLeafRust,
  ];
}

/// One leaf at loop time [t] (0..1) in a [size] square. Deterministic.
/// Integer cycle counts keep the 12 s loop seamless.
({Offset at, int color, bool wide}) townLeafAt(int i, double t, Size size) {
  final phase = ((i * 0.6180339) % 1.0);
  final cycles = 1 + i % 3;
  final fall = (t * cycles + phase) % 1.0;
  final y = -8 + fall * (size.height + 16);
  final lane = (i * 0.37 + 0.11) % 1.0;
  final sway = math.sin((t * (2 + i % 2) + phase) * math.pi * 2);
  final x = lane * size.width + sway * (10 + (i % 4) * 4);
  final flip = math.sin((t * 6 + phase) * math.pi * 2) > 0;
  return (
    at: Offset(x.floorToDouble(), y.floorToDouble()),
    color: i % TownAmbience.leafColors.length,
    wide: flip,
  );
}

class TownAmbienceLayer extends StatefulWidget {
  const TownAmbienceLayer({
    super.key,
    required this.motion,
    required this.fire,
    required this.mistTop,
    this.hearth,
  });

  final bool motion;

  /// Forge fire mouth, in square coordinates. Gets its own flicker.
  final Offset? hearth;

  /// Campfire sprite rect. The glow centers on its flame.
  final Rect fire;

  /// Mist sits from here down to the party row.
  final double mistTop;

  @override
  State<TownAmbienceLayer> createState() => _TownAmbienceLayerState();
}

class _TownAmbienceLayerState extends State<TownAmbienceLayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _clock;
  bool _resumed = true;

  bool get _allowMotion =>
      widget.motion && _resumed && TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(TownAmbienceLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _resumed) return;
    setState(() {
      _resumed = resumed;
      _syncTicker();
    });
  }

  void _syncTicker() {
    if (!_allowMotion) {
      _clock?.stop();
      return;
    }
    _clock ??= AnimationController(vsync: this, duration: TownAmbience.loop);
    if (!_clock!.isAnimating) _clock!.repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        key: const ValueKey('town-ambience'),
        child: CustomPaint(
          painter: _AmbiencePainter(
            clock: _clock,
            fire: widget.fire,
            mistTop: widget.mistTop,
            hearth: widget.hearth,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AmbiencePainter extends CustomPainter {
  _AmbiencePainter({
    required this.clock,
    required this.fire,
    required this.mistTop,
    required this.hearth,
  }) : super(repaint: clock);

  final AnimationController? clock;
  final Rect fire;
  final double mistTop;
  final Offset? hearth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final moving = clock?.isAnimating ?? false;
    final t = moving ? clock!.value : TownAmbience.stillT;
    _mist(canvas, size, t);
    _glow(canvas, t);
    _leaves(canvas, size, t);
  }

  void _mist(Canvas canvas, Size size, double t) {
    final top = mistTop.clamp(0.0, size.height);
    final band = size.height - top;
    if (band < 24) return;
    // Fog that pools at the foot of the back row, behind the fire.
    for (var i = 0; i < 2; i++) {
      final drift = math.sin((t + i / 2) * math.pi * 2) * 14;
      final rect = Rect.fromCenter(
        center: Offset(size.width * (0.28 + i * 0.46) + drift, top - 6),
        width: size.width * 0.8,
        height: 40,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [GameTheme.townMistLow, GameTheme.townMistLow.withAlpha(0)],
          ).createShader(rect),
      );
    }
    // Low banks in the yard and along the shop fronts' feet. Kept off the
    // facades so the windows stay readable.
    const rows = [0.1, 0.16, 0.76, 0.82];
    for (var i = 0; i < rows.length; i++) {
      final drift = math.sin((t + i / 4) * math.pi * 2) * 18;
      final cy = top + band * rows[i];
      final rect = Rect.fromCenter(
        center: Offset(size.width * (i.isEven ? 0.26 : 0.74) + drift, cy),
        width: size.width * 0.9,
        height: 50,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [GameTheme.townMist, GameTheme.townMist.withAlpha(0)],
          ).createShader(rect),
      );
    }
  }

  void _glow(Canvas canvas, double t) {
    if (fire.isEmpty) return;
    final breath =
        0.5 +
        0.3 * math.sin(t * math.pi * 2 * 9) +
        0.2 * math.sin(t * math.pi * 2 * 23);
    final center = Offset(fire.center.dx, fire.top + fire.height * 0.62);
    // Wide warm wash over the square and the facades around the fire.
    final r = fire.width * (3.6 + 0.2 * breath);
    final rect = Rect.fromCircle(center: center, radius: r);
    final a = (0x5C + (0x20 * breath)).round().clamp(0, 255);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            GameTheme.townFireGlow.withAlpha(a),
            GameTheme.townFireGlow.withAlpha(0),
          ],
        ).createShader(rect),
    );
    // A flat pool of light on the cobbles under the fire.
    final pool = Rect.fromCenter(
      center: Offset(center.dx, fire.bottom - 4),
      width: fire.width * 4.2,
      height: fire.width * 1.3,
    );
    canvas.drawOval(
      pool,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            GameTheme.townFirePool.withAlpha((0x70 + 0x1C * breath).round()),
            GameTheme.townFirePool.withAlpha(0),
          ],
        ).createShader(pool),
    );
    final h = hearth;
    if (h != null) {
      final flick =
          0.5 +
          0.5 *
              math.sin(t * math.pi * 2 * 13 + 1.3) *
              math.sin(t * math.pi * 2 * 5);
      final hr = 30.0 + 4 * flick;
      canvas.drawCircle(
        h,
        hr,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            colors: [
              GameTheme.townFireGlow.withAlpha((0x46 + 0x20 * flick).round()),
              GameTheme.townFireGlow.withAlpha(0),
            ],
          ).createShader(Rect.fromCircle(center: h, radius: hr)),
      );
    }
    // Two sparks climb out of the flame.
    final spark = Paint()..color = GameTheme.townSpark;
    for (var k = 0; k < 2; k++) {
      final u = (t * (11 + k * 4) + k * 0.5) % 1.0;
      final sx = center.dx + math.sin((u + k) * math.pi * 3) * 6 + (k * 8 - 4);
      final sy = fire.top + fire.height * 0.3 - u * fire.height * 0.9;
      if (u < 0.85) {
        canvas.drawRect(
          Rect.fromLTWH(sx.floorToDouble(), sy.floorToDouble(), 2, 2),
          spark,
        );
      }
    }
  }

  void _leaves(Canvas canvas, Size size, double t) {
    final paint = Paint();
    final shade = Paint()..color = GameTheme.townLeafShade;
    for (var i = 0; i < TownAmbience.leafCount; i++) {
      final leaf = townLeafAt(i, t, size);
      final w = leaf.wide ? 4.0 : 2.0;
      final h = leaf.wide ? 2.0 : 3.0;
      paint.color = TownAmbience.leafColors[leaf.color];
      canvas.drawRect(
        Rect.fromLTWH(leaf.at.dx + 1, leaf.at.dy + 1, w, h),
        shade,
      );
      canvas.drawRect(Rect.fromLTWH(leaf.at.dx, leaf.at.dy, w, h), paint);
    }
  }

  @override
  bool shouldRepaint(_AmbiencePainter oldDelegate) =>
      oldDelegate.clock != clock ||
      oldDelegate.fire != fire ||
      oldDelegate.mistTop != mistTop ||
      oldDelegate.hearth != hearth;
}
