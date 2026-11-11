import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../spatial/spatial_combat.dart';
import 'floater_banner_stack.dart';
import 'floater_label_cache.dart';
import 'game_theme.dart';

/// Holds a floater on screen for its authored life when 2× eats the sim timer.
@visibleForTesting
class HeldFloater {
  HeldFloater({
    required this.born,
    required this.span,
    required this.text,
    required this.argb,
    required this.priority,
    required this.speech,
    required this.x,
    required this.y,
  });

  final int born;
  final int span;
  final String text;
  final int argb;
  final int priority;
  final bool speech;
  double x;
  double y;
}

/// Syncs world floaters into a short-lived paint hold.
@visibleForTesting
abstract final class FloaterHold {
  static final Map<int, HeldFloater> live = {};

  static void reset() => live.clear();

  static void sync({
    required List<SpatialFloater> floaters,
    required int frame,
    required bool show,
  }) {
    if (!show) {
      live.clear();
      return;
    }
    final seen = <int>{};
    for (final floater in floaters) {
      final id = identityHashCode(floater);
      seen.add(id);
      final held = live[id];
      if (held == null) {
        live[id] = HeldFloater(
          born: frame,
          span: _spanFor(floater.life),
          text: floater.text,
          argb: floater.argb,
          priority: floater.priority,
          speech: floater.kind == SpatialFloaterKind.speech,
          x: floater.x,
          y: floater.y,
        );
      } else {
        held.x = floater.x;
        held.y = floater.y;
      }
    }
    live.removeWhere((id, held) {
      if (seen.contains(id)) return false;
      return frame - held.born >= held.span;
    });
  }

  static int _spanFor(double life) {
    final span = (life * 60).round();
    return span < 8 ? 8 : span;
  }
}

/// World-Y used as the paint anchor, including speech offset and rare lift.
double floaterDisplayY({
  required double y,
  required bool speech,
  required int priority,
}) {
  final lift = priority >= 3 ? 1.35 : 0.0;
  return y - (speech ? 0.55 : 0) - lift;
}

/// Screen-space top-left of a floater label, matching [paintFloaterLabels].
Offset floaterLabelAnchor({
  required Offset center,
  required bool speech,
  required double tile,
  required double width,
  required double height,
}) {
  return speech
      ? Offset(center.dx - width / 2, center.dy - height / 2)
      : Offset(center.dx + tile * 0.46 - width / 2, center.dy - tile * 0.22);
}

/// Screen-space rectangle of a floater label, matching [paintFloaterLabels].
Rect floaterLabelRect({
  required Offset center,
  required bool speech,
  required double tile,
  required double width,
  required double height,
}) {
  final anchor = floaterLabelAnchor(
    center: center,
    speech: speech,
    tile: tile,
    width: width,
    height: height,
  );
  return Rect.fromLTWH(anchor.dx, anchor.dy, width, height);
}

/// Clears paint-only floater hold and label cache. A new fight view must
/// not inherit the last fight's numbers.
void resetFloaterPaintState() {
  FloaterLabelCache.reset();
  FloaterHold.reset();
}

@visibleForTesting
void debugResetFloaterCaches() => resetFloaterPaintState();

/// Paints floater labels for one frame. Used by the dungeon painter and by
/// widget tests that drive a [PictureRecorder] or [CustomPaint] canvas.
void paintFloaterLabels({
  required Canvas canvas,
  required double tile,
  required double originX,
  required double originY,
  required List<SpatialFloater> floaters,
  required int visualFrame,
  required bool showBursts,
  required bool showPriorityFloaters,
  required bool Function(double x, double y, {double pad}) inView,
}) {
  final rareLoot = floaters.any((f) => f.priority >= 3);
  final show = showBursts || showPriorityFloaters || rareLoot;
  FloaterHold.sync(floaters: floaters, frame: visualFrame, show: show);
  FloaterLabelCache.beginFrame();
  if (!show) {
    FloaterLabelCache.endFrame();
    return;
  }
  try {

  Offset center(double tx, double ty) =>
      Offset(originX + tx * tile, originY + ty * tile);

  final maxW = tile * 4.4;
  final visible = <HeldFloater>[];
  for (final floater in FloaterHold.live.values) {
    final rare = floater.priority >= 3;
    if (!showBursts && !showPriorityFloaters && !rare) continue;
    if (!showBursts && floater.priority < 2) continue;
    if (!inView(floater.x, floater.y, pad: 0.5)) continue;
    visible.add(floater);
  }

  final pairs = <({TextPainter fill, TextPainter outline})>[];
  final stackSpecs = <FloaterBannerSpec>[];
  for (var i = 0; i < visible.length; i++) {
    final floater = visible[i];
    final speech = floater.speech;
    final age = (visualFrame - floater.born) / floater.span;
    final alpha = (1 - age).clamp(0.0, 1.0);
    final size =
        tile *
        (speech ? 0.28 : 0.32) *
        SpatialCombat.floaterReadScale(floater.priority);
    final snapped = (alpha * 10).round() / 10.0;
    final color = Color(floater.argb).withValues(alpha: snapped);
    final outline = GameTheme.lootInkShadow.withValues(alpha: snapped * 0.9);
    final pair = FloaterLabelCache.pair(
      text: floater.text,
      size: size < GameTheme.hudPixel ? GameTheme.hudPixel : size,
      color: color,
      outline: outline,
      maxWidth: maxW,
    );
    pairs.add(pair);
    final displayY = floaterDisplayY(
      y: floater.y,
      speech: speech,
      priority: floater.priority,
    );
    if (FloaterBannerStack.isStackable(
      speech: speech,
      priority: floater.priority,
      text: floater.text,
    )) {
      stackSpecs.add(
        FloaterBannerSpec(
          id: i,
          x: floater.x,
          y: displayY,
          priority: floater.priority,
          born: floater.born,
          heightTiles: pair.fill.height / tile,
        ),
      );
    }
  }
  final stackDy = FloaterBannerStack.dyById(stackSpecs);
  final bubbleFill = Paint()..style = PaintingStyle.fill;
  final bubbleStroke = Paint()..style = PaintingStyle.stroke;
  for (var i = 0; i < visible.length; i++) {
    final floater = visible[i];
    final speech = floater.speech;
    final age = (visualFrame - floater.born) / floater.span;
    final alpha = (1 - age).clamp(0.0, 1.0);
    final tp = pairs[i].fill;
    final tpOutline = pairs[i].outline;
    final displayY =
        floaterDisplayY(
          y: floater.y,
          speech: speech,
          priority: floater.priority,
        ) +
        (stackDy[i] ?? 0);
    final c = center(floater.x, displayY);
    if (speech) {
      final padX = tile * 0.12;
      final padY = tile * 0.06;
      final bubble = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          c.dx - tp.width / 2 - padX,
          c.dy - tp.height / 2 - padY,
          tp.width + padX * 2,
          tp.height + padY * 2,
        ),
        Radius.circular(tile * 0.12),
      );
      bubbleFill.color = const Color(0xCC1A1420).withValues(alpha: alpha);
      canvas.drawRRect(bubble, bubbleFill);
      bubbleStroke
        ..color = Color(floater.argb).withValues(alpha: alpha * 0.55)
        ..strokeWidth = tile * 0.03 < 1.0 ? 1.0 : tile * 0.03;
      canvas.drawRRect(bubble, bubbleStroke);
    }
    final anchor = floaterLabelAnchor(
      center: c,
      speech: speech,
      tile: tile,
      width: tp.width,
      height: tp.height,
    );
    for (final off in const [
      Offset(-1, 0),
      Offset(1, 0),
      Offset(0, -1),
      Offset(0, 1),
    ]) {
      tpOutline.paint(canvas, anchor + off);
    }
    tp.paint(canvas, anchor);
  }
  } finally {
    FloaterLabelCache.endFrame();
  }
}
