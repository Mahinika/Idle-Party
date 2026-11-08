import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../assets/custom_assets.dart';
import '../../../models/vfx_quality.dart';

/// Folk sheet from `tool/town_life_art.py` (96×112 cells).
///
/// The source is hero-sized. [displayW] and [displayH] are the on-screen
/// size beside the 42px party, a clean 2:1 nearest downsample.
abstract final class TownFolkSheet {
  static const cellW = 96;
  static const cellH = 112;
  static const displayW = 48.0;
  static const displayH = 56.0;
  static const frames = 5;
  static const people = 3;
  static const loop = Duration(milliseconds: 4800);
  static const step = Duration(milliseconds: 180);
}

/// One posed townsfolk. [u] runs along the yard, 0 to 1.
class TownFolkFrame {
  const TownFolkFrame({
    required this.person,
    required this.u,
    required this.column,
    required this.flip,
    required this.bob,
  });

  final int person;
  final double u;
  final int column;
  final bool flip;
  final int bob;
}

/// Daylight town motion. Minimal VFX and the system reduce-motion flag hold
/// the idle pose. The loop is deterministic from [t] in 0..1.
bool townFolkMotionEnabled({
  required VfxQuality quality,
  required bool disableAnimations,
}) => quality != VfxQuality.minimal && !disableAnimations;

double _ping(double t) {
  final x = t - t.floorToDouble();
  if (x < 0.5) return x * 2;
  return (1 - x) * 2;
}

List<TownFolkFrame> townFolkFrames(double t, {required bool moving}) {
  if (!moving) {
    return const [
      TownFolkFrame(person: 0, u: 0.12, column: 0, flip: false, bob: 0),
      TownFolkFrame(person: 1, u: 0.84, column: 0, flip: false, bob: 0),
      TownFolkFrame(person: 2, u: 0.48, column: 0, flip: false, bob: 0),
    ];
  }
  final loopMs = TownFolkSheet.loop.inMilliseconds;
  final step = math.max(1, TownFolkSheet.step.inMilliseconds);
  final column = 1 + ((t * loopMs) ~/ step) % 4;
  final bob = ((t * loopMs) ~/ 420) % 2;
  return [
    TownFolkFrame(
      person: 0,
      u: _ping(t),
      column: column,
      flip: (t - t.floorToDouble()) >= 0.5,
      bob: 0,
    ),
    TownFolkFrame(
      person: 1,
      u: _ping(t + 0.37),
      column: column,
      flip: ((t + 0.37) - (t + 0.37).floorToDouble()) >= 0.5,
      bob: 0,
    ),
    TownFolkFrame(person: 2, u: 0.56, column: 0, flip: false, bob: bob),
  ];
}

/// Walkers and one idler on the yard. The ticker stops when motion is off,
/// the route is offstage ([TickerMode]), or the app is backgrounded.
class TownFolkLayer extends StatefulWidget {
  const TownFolkLayer({
    super.key,
    required this.motion,
    required this.lane,
    required this.scale,
  });

  final bool motion;
  final Rect lane;
  final int scale;

  @override
  State<TownFolkLayer> createState() => _TownFolkLayerState();
}

class _TownFolkLayerState extends State<TownFolkLayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _clock;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _sheet;
  bool _resumed = true;

  bool get _allowMotion =>
      widget.motion &&
      widget.scale > 0 &&
      _resumed &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
    _syncTicker();
  }

  @override
  void didUpdateWidget(TownFolkLayer oldWidget) {
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

  void _resolveImage() {
    final stream = AssetImage(
      CustomAssets.townFolk,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    final listener = _listener ??= ImageStreamListener((info, _) {
      if (!mounted || identical(_sheet, info.image)) return;
      setState(() => _sheet = info.image);
    });
    _stream?.removeListener(listener);
    _stream = stream;
    stream.addListener(listener);
  }

  void _syncTicker() {
    if (!_allowMotion) {
      _clock?.stop();
      return;
    }
    _clock ??= AnimationController(vsync: this, duration: TownFolkSheet.loop);
    if (!_clock!.isAnimating) _clock!.repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        key: const ValueKey('town-folk'),
        child: CustomPaint(
          painter: _FolkPainter(
            sheet: _sheet,
            lane: widget.lane,
            scale: widget.scale,
            clock: _clock,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _FolkPainter extends CustomPainter {
  _FolkPainter({
    required this.sheet,
    required this.lane,
    required this.scale,
    required this.clock,
  }) : super(repaint: clock);

  final ui.Image? sheet;
  final Rect lane;
  final int scale;
  final AnimationController? clock;

  @override
  void paint(Canvas canvas, Size size) {
    final image = sheet;
    if (image == null || scale <= 0 || lane.width < 8 || lane.height < 8) {
      return;
    }
    final moving = clock?.isAnimating ?? false;
    final t = clock?.value ?? 0;
    final frames = townFolkFrames(t, moving: moving);
    // Nearest-neighbor down to the party. Shrink further only on a short yard.
    var spriteW = TownFolkSheet.displayW * scale;
    var spriteH = TownFolkSheet.displayH * scale;
    final maxH = lane.height - 1;
    if (spriteH > maxH) {
      final fit = maxH / spriteH;
      spriteH = maxH;
      spriteW *= fit;
    }
    final travel = lane.width - spriteW;
    if (travel < 4 || spriteH < 8 || spriteW < 6) return;
    final paint = Paint()..filterQuality = FilterQuality.none;
    for (final frame in frames) {
      final x = lane.left + frame.u * travel;
      final y = math.max(lane.top, lane.bottom - spriteH - frame.bob);
      final src = Rect.fromLTWH(
        frame.column * TownFolkSheet.cellW.toDouble(),
        frame.person * TownFolkSheet.cellH.toDouble(),
        TownFolkSheet.cellW.toDouble(),
        TownFolkSheet.cellH.toDouble(),
      );
      canvas.save();
      if (frame.flip) {
        canvas.translate(x + spriteW, y);
        canvas.scale(-1, 1);
        canvas.drawImageRect(image, src, Rect.fromLTWH(0, 0, spriteW, spriteH), paint);
      } else {
        canvas.drawImageRect(
          image,
          src,
          Rect.fromLTWH(x, y, spriteW, spriteH),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FolkPainter oldDelegate) =>
      oldDelegate.sheet != sheet ||
      oldDelegate.lane != lane ||
      oldDelegate.scale != scale ||
      oldDelegate.clock != clock;
}
