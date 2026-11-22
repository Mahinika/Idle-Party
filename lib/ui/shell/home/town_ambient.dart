import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../assets/custom_assets.dart';
import '../../../models/vfx_quality.dart';
import 'town_life.dart';
import 'town_scene.dart';

/// Small yard animals from `tool/town_life_art.py` (48×40 cells).
abstract final class TownCritterSheet {
  static const cellW = 56.0;
  static const cellH = 48.0;
  static const frames = 4;
  static const kinds = 3;
  static const loop = Duration(milliseconds: 3200);
  static const step = Duration(milliseconds: 120);
}

class TownCritterMark {
  const TownCritterMark({
    required this.kind,
    required this.u,
    required this.v,
    required this.flip,
    required this.column,
  });

  final int kind;
  final double u;
  final double v;
  final bool flip;
  final int column;
}

class TownYardProp {
  const TownYardProp({required this.src, required this.dst});

  final Rect src;
  final Rect dst;
}

bool townAmbientMotionEnabled({
  required VfxQuality quality,
  required bool disableAnimations,
}) => townFolkMotionEnabled(quality: quality, disableAnimations: disableAnimations);

int _critterColumn(double t) {
  final wrapped = t - t.floorToDouble();
  final step = math.max(1, TownCritterSheet.step.inMilliseconds);
  return ((wrapped * TownCritterSheet.loop.inMilliseconds) ~/ step) %
      TownCritterSheet.frames;
}

/// Shared freeze phase for goldens (folk + critters idle pose).
const double townGoldenFreezePhase = 0.3125;

List<TownCritterMark> townCritterMarks(double t, {required bool moving}) {
  final phase = moving ? t : townGoldenFreezePhase;
  if (!moving) {
    return const [
      TownCritterMark(kind: 0, u: 0.22, v: 0.55, flip: false, column: 0),
      TownCritterMark(kind: 0, u: 0.38, v: 0.62, flip: true, column: 0),
      TownCritterMark(kind: 1, u: 0.58, v: 0.48, flip: false, column: 0),
    ];
  }
  final colB = _critterColumn(phase + 0.31);
  return [
    TownCritterMark(
      kind: 0,
      u: 0.22 + 0.03 * math.sin(phase * math.pi * 2),
      v: 0.55,
      flip: phase >= 0.5,
      column: _critterColumn(phase),
    ),
    TownCritterMark(kind: 0, u: 0.38, v: 0.62, flip: true, column: colB),
    TownCritterMark(
      kind: 1,
      u: 0.58,
      v: 0.48,
      flip: false,
      column: _critterColumn(phase + 0.57),
    ),
  ];
}

List<TownYardProp> townYardProps(TownSceneLayout layout, Size size) {
  if (layout.front.length < 3) return const [];
  final forge = layout.front[0];
  final market = layout.front[1];
  final inn = layout.front[2];
  final lane = layout.lane;
  final props = <TownYardProp>[
    TownYardProp(
      src: const Rect.fromLTWH(4, 16, 20, 28),
      dst: Rect.fromLTWH(
        forge.left - 8,
        lane.top + lane.height * 0.55,
        22,
        28,
      ),
    ),
    TownYardProp(
      src: const Rect.fromLTWH(44, 20, 28, 24),
      dst: Rect.fromLTWH(
        market.right - 12,
        lane.top + 10,
        26,
        22,
      ),
    ),
    TownYardProp(
      src: const Rect.fromLTWH(88, 12, 72, 40),
      dst: Rect.fromLTWH(
        layout.well.right + 4,
        lane.top + lane.height * 0.28,
        56,
        28,
      ),
    ),
    TownYardProp(
      src: const Rect.fromLTWH(44, 20, 28, 24),
      dst: Rect.fromLTWH(
        inn.right + 6,
        lane.top + lane.height * 0.72,
        24,
        20,
      ),
    ),
  ];
  return props
      .where(
        (p) =>
            p.dst.bottom <= size.height - layout.party.height - 2 &&
            !layout.labels.any((label) => p.dst.overlaps(label.inflate(2))),
      )
      .toList(growable: false);
}

/// Yard props and critters. Props are static; critters loop like [TownFolkLayer].
class TownAmbientLayer extends StatefulWidget {
  const TownAmbientLayer({
    super.key,
    required this.motion,
    required this.layout,
    required this.size,
    this.drawProps = true,
    this.drawCritters = true,
  });

  final bool motion;
  final TownSceneLayout layout;
  final Size size;
  final bool drawProps;
  final bool drawCritters;

  @override
  State<TownAmbientLayer> createState() => _TownAmbientLayerState();
}

class _TownAmbientLayerState extends State<TownAmbientLayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AnimationController? _clock;
  ImageStream? _critterStream;
  ImageStream? _propStream;
  ImageStreamListener? _critterListener;
  ImageStreamListener? _propListener;
  ui.Image? _critters;
  ui.Image? _props;
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
    _resolveImages();
    _syncTicker();
  }

  @override
  void didUpdateWidget(TownAmbientLayer oldWidget) {
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

  void _resolveImages() {
    final config = createLocalImageConfiguration(context);
    final critters = AssetImage(CustomAssets.townCritters).resolve(config);
    if (critters.key != _critterStream?.key) {
      final listener = _critterListener ??= ImageStreamListener((info, _) {
        if (!mounted || identical(_critters, info.image)) return;
        setState(() => _critters = info.image);
      });
      _critterStream?.removeListener(listener);
      _critterStream = critters;
      critters.addListener(listener);
    }
    final props = AssetImage(CustomAssets.townYardProps).resolve(config);
    if (props.key != _propStream?.key) {
      final listener = _propListener ??= ImageStreamListener((info, _) {
        if (!mounted || identical(_props, info.image)) return;
        setState(() => _props = info.image);
      });
      _propStream?.removeListener(listener);
      _propStream = props;
      props.addListener(listener);
    }
  }

  void _syncTicker() {
    if (!_allowMotion) {
      _clock?.stop();
      return;
    }
    _clock ??=
        AnimationController(vsync: this, duration: TownCritterSheet.loop);
    if (!_clock!.isAnimating) _clock!.repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final critterListener = _critterListener;
    if (critterListener != null) _critterStream?.removeListener(critterListener);
    final propListener = _propListener;
    if (propListener != null) _propStream?.removeListener(propListener);
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        key: const ValueKey('town-ambient'),
        child: CustomPaint(
          painter: _AmbientPainter(
            critters: _critters,
            props: _props,
            layout: widget.layout,
            size: widget.size,
            clock: _clock,
            moving: _allowMotion,
            drawProps: widget.drawProps,
            drawCritters: widget.drawCritters,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.critters,
    required this.props,
    required this.layout,
    required this.size,
    required this.clock,
    required this.moving,
    required this.drawProps,
    required this.drawCritters,
  }) : super(repaint: clock);

  final ui.Image? critters;
  final ui.Image? props;
  final TownSceneLayout layout;
  final Size size;
  final AnimationController? clock;
  final bool moving;
  final bool drawProps;
  final bool drawCritters;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    final propImage = props;
    if (drawProps && propImage != null) {
      for (final mark in townYardProps(layout, size)) {
        canvas.drawImageRect(propImage, mark.src, mark.dst, paint);
      }
    }
    if (!drawCritters) return;
    final sheet = critters;
    if (sheet == null) return;
    final lane = layout.lane;
    if (lane.width < 40 || lane.height < 16) return;
    final spriteW = 42.0;
    final spriteH = spriteW * TownCritterSheet.cellH / TownCritterSheet.cellW;
    final t = clock?.value ?? 0;
    final marks = townCritterMarks(t, moving: moving);
    final spare = math.max(0.0, lane.height - spriteH);
    for (final mark in marks) {
      final x = lane.left + mark.u * (lane.width - spriteW);
      final y = lane.bottom - spriteH - mark.v * spare;
      final src = Rect.fromLTWH(
        mark.column * TownCritterSheet.cellW,
        mark.kind * TownCritterSheet.cellH,
        TownCritterSheet.cellW,
        TownCritterSheet.cellH,
      );
      if (mark.flip) {
        canvas.save();
        canvas.translate(x + spriteW, y);
        canvas.scale(-1, 1);
        canvas.drawImageRect(
          sheet,
          src,
          Rect.fromLTWH(0, 0, spriteW, spriteH),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawImageRect(
          sheet,
          src,
          Rect.fromLTWH(x, y, spriteW, spriteH),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.critters != critters ||
      oldDelegate.props != props ||
      oldDelegate.layout != layout ||
      oldDelegate.clock != clock ||
      oldDelegate.moving != moving ||
      oldDelegate.drawProps != drawProps ||
      oldDelegate.drawCritters != drawCritters;
}