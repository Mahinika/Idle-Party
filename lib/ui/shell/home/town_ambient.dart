import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../assets/custom_assets.dart';
import '../../../models/vfx_quality.dart';
import 'town_life.dart';
import 'town_scene.dart';

class TownYardProp {
  const TownYardProp({required this.src, required this.dst});

  final Rect src;
  final Rect dst;
}

bool townAmbientMotionEnabled({
  required VfxQuality quality,
  required bool disableAnimations,
}) => townFolkMotionEnabled(quality: quality, disableAnimations: disableAnimations);

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

/// Static yard props (barrel, crate, laundry line).
class TownAmbientLayer extends StatefulWidget {
  const TownAmbientLayer({
    super.key,
    required this.layout,
    required this.size,
  });

  final TownSceneLayout layout;
  final Size size;

  @override
  State<TownAmbientLayer> createState() => _TownAmbientLayerState();
}

class _TownAmbientLayerState extends State<TownAmbientLayer> {
  ImageStream? _propStream;
  ImageStreamListener? _propListener;
  ui.Image? _props;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImages();
  }

  void _resolveImages() {
    final config = createLocalImageConfiguration(context);
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

  @override
  void dispose() {
    final propListener = _propListener;
    if (propListener != null) _propStream?.removeListener(propListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        key: const ValueKey('town-ambient'),
        child: CustomPaint(
          painter: _AmbientPainter(
            props: _props,
            layout: widget.layout,
            size: widget.size,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.props,
    required this.layout,
    required this.size,
  });

  final ui.Image? props;
  final TownSceneLayout layout;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final propImage = props;
    if (propImage == null) return;
    final paint = Paint()..filterQuality = FilterQuality.none;
    for (final mark in townYardProps(layout, size)) {
      canvas.drawImageRect(propImage, mark.src, mark.dst, paint);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.props != props ||
      oldDelegate.layout != layout ||
      oldDelegate.size != size;
}