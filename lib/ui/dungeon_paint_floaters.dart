part of 'spatial_dungeon_view.dart';

extension _DungeonPaintFloaters on _TileRoomPainter {
  void paintDungeonFloaters(
    Canvas canvas,
    double tile,
    double originX,
    double originY,
  ) {
    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);
    Paint fill(Color color) {
      _TileRoomPainter._fxFill
        ..style = PaintingStyle.fill
        ..color = color;
      return _TileRoomPainter._fxFill;
    }

    Paint stroke(Color color, double width, {StrokeCap cap = StrokeCap.butt}) {
      _TileRoomPainter._fxStroke
        ..style = PaintingStyle.stroke
        ..strokeCap = cap
        ..strokeWidth = width
        ..color = color;
      return _TileRoomPainter._fxStroke;
    }

    // Lite keeps enemy tells and flask rings. Minimal stays still.
    if (showBursts || showGround) {
      for (final burst in world.bursts) {
        final kind = burst.slash ? SpatialBurstKind.slash : burst.kind;
        if (kind == SpatialBurstKind.slash) {
          final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final sweep = 1.45;
          final start = (burst.angle ?? (burst.life * 9)) - sweep * 0.5;
          final r = tile * burst.radius * (0.75 + (1 - alpha) * 0.4);
          final rect = Rect.fromCircle(center: c, radius: r);
          final sweepDraw = sweep * alpha.clamp(0.45, 1.0);
          canvas.drawArc(
            rect,
            start,
            sweepDraw,
            false,
            stroke(
              const Color(0xE6100C08).withValues(alpha: alpha),
              math.max(5.5, tile * 0.32),
              cap: StrokeCap.round,
            ),
          );
          canvas.drawArc(
            rect,
            start,
            sweepDraw,
            false,
            stroke(
              Color(burst.argb).withValues(alpha: alpha),
              math.max(3.2, tile * 0.2),
              cap: StrokeCap.round,
            ),
          );
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.72),
            start,
            sweepDraw,
            false,
            stroke(
              Colors.white.withValues(alpha: alpha * 0.7),
              math.max(1.8, tile * 0.09),
              cap: StrokeCap.round,
            ),
          );
          final tipAng = start + sweepDraw * 0.9;
          canvas.drawCircle(
            Offset(c.dx + math.cos(tipAng) * r, c.dy + math.sin(tipAng) * r),
            math.max(2.2, tile * 0.09),
            fill(Colors.white.withValues(alpha: alpha)),
          );
        } else if (kind == SpatialBurstKind.ring) {
          final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.55 + (1 - alpha) * 0.7);
          canvas.drawCircle(
            c,
            r,
            stroke(
              const Color(0xCC100C08).withValues(alpha: alpha),
              math.max(4.2, tile * 0.2),
            ),
          );
          canvas.drawCircle(
            c,
            r,
            stroke(
              Color(burst.argb).withValues(alpha: alpha * 0.95),
              math.max(2.4, tile * 0.11),
            ),
          );
          canvas.drawCircle(
            c,
            r * 0.7,
            stroke(
              Colors.white.withValues(alpha: alpha * 0.45),
              math.max(1.4, tile * 0.055),
            ),
          );
        } else if (kind == SpatialBurstKind.cone && burst.angle != null) {
          final alpha = (burst.life / 0.45).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.85 + (1 - alpha) * 0.35);
          final sweep = 1.15;
          final start = burst.angle! - sweep * 0.5;
          final path = _TileRoomPainter._fxPath
            ..reset()
            ..moveTo(c.dx, c.dy)
            ..arcTo(Rect.fromCircle(center: c, radius: r), start, sweep, false)
            ..close();
          canvas.drawPath(
            path,
            fill(Color(burst.argb).withValues(alpha: alpha * 0.45)),
          );
          canvas.drawPath(
            path,
            stroke(
              Color(burst.argb).withValues(alpha: alpha * 0.9),
              math.max(2, tile * 0.08),
            ),
          );
        } else if (kind == SpatialBurstKind.leaf) {
          final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.55 + alpha * 0.35);
          for (var i = 0; i < 5; i++) {
            final a = i * 1.26 + burst.life * 2;
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(
                  c.dx + math.cos(a) * r * 0.7,
                  c.dy + math.sin(a) * r * 0.7,
                ),
                width: r * 0.55,
                height: r * 0.28,
              ),
              fill(Color(burst.argb).withValues(alpha: alpha * 0.9)),
            );
          }
        } else if (kind == SpatialBurstKind.spark) {
          final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.4 + alpha * 0.4);
          canvas.drawCircle(
            c,
            r,
            fill(Color(burst.argb).withValues(alpha: alpha * 0.9)),
          );
          canvas.drawCircle(
            c,
            r * 0.4,
            fill(Colors.white.withValues(alpha: alpha)),
          );
          for (var i = 0; i < 4; i++) {
            final a = i * math.pi / 2 + burst.life * 8;
            canvas.drawCircle(
              Offset(
                c.dx + math.cos(a) * r * 1.3,
                c.dy + math.sin(a) * r * 1.3,
              ),
              r * 0.25,
              fill(Color(burst.argb).withValues(alpha: alpha * 0.7)),
            );
          }
        } else if (kind == SpatialBurstKind.beam ||
            kind == SpatialBurstKind.rain ||
            kind == SpatialBurstKind.shards ||
            kind == SpatialBurstKind.flame ||
            kind == SpatialBurstKind.cross ||
            kind == SpatialBurstKind.poison ||
            kind == SpatialBurstKind.skull) {
          _paintSpellBurst(canvas, burst, tile, center);
        } else {
          final maxLife = 0.55;
          final alpha = (burst.life / maxLife).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (1.15 - alpha * 0.28);
          canvas.drawCircle(
            c,
            r,
            fill(const Color(0xAA100C08).withValues(alpha: alpha * 0.85)),
          );
          canvas.drawCircle(
            c,
            r * 0.82,
            fill(Color(burst.argb).withValues(alpha: alpha * 0.7)),
          );
          canvas.drawCircle(
            c,
            r * 0.42,
            fill(Colors.white.withValues(alpha: alpha * 0.9)),
          );
        }
        if (burst.crisp) {
          final crispAlpha = (burst.life / SpellVfx.bigImpactLife).clamp(
            0.0,
            1.0,
          );
          AbilityVfxPaint.paintCrispCore(
            canvas,
            center(burst.x, burst.y),
            tile * burst.radius * 0.42,
            crispAlpha,
          );
        }
      }
    }

    final rareLoot = world.floaters.any((f) => f.priority >= 3);
    if (showBursts || showPriorityFloaters || rareLoot) {
      _FloaterHold.sync(
        floaters: world.floaters,
        frame: visualFrame,
        show: true,
      );
      final maxW = tile * 4.4;
      for (final floater in _FloaterHold.live.values) {
        final rare = floater.priority >= 3;
        if (!showBursts && !showPriorityFloaters && !rare) continue;
        if (!showBursts && floater.priority < 2) continue;
        if (!_inView(floater.x, floater.y, pad: 0.5)) continue;
        final speech = floater.speech;
        final age = (visualFrame - floater.born) / floater.span;
        final alpha = (1 - age).clamp(0.0, 1.0);
        final size =
            tile *
            (speech ? 0.28 : 0.32) *
            SpatialCombat.floaterReadScale(floater.priority);
        final snapped = (alpha * 10).round() / 10.0;
        final color = Color(floater.argb).withValues(alpha: snapped);
        final tp = _FloaterLabels.of(
          text: floater.text,
          size: math.max(GameTheme.hudPixel, size),
          color: color,
          maxWidth: maxW,
        );
        final lift = rare ? 1.35 : 0.0;
        final c = center(floater.x, floater.y - (speech ? 0.55 : 0) - lift);
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
          _TileRoomPainter._fillPaint.color = const Color(
            0xCC1A1420,
          ).withValues(alpha: alpha);
          canvas.drawRRect(bubble, _TileRoomPainter._fillPaint);
          _TileRoomPainter._strokePaint
            ..color = Color(floater.argb).withValues(alpha: alpha * 0.55)
            ..strokeWidth = math.max(1.0, tile * 0.03);
          canvas.drawRRect(bubble, _TileRoomPainter._strokePaint);
        }
        final anchor = speech
            ? Offset(c.dx - tp.width / 2, c.dy - tp.height / 2)
            : Offset(c.dx + tile * 0.46 - tp.width / 2, c.dy - tile * 0.22);
        tp.paint(canvas, anchor);
      }
    } else {
      _FloaterHold.sync(floaters: const [], frame: visualFrame, show: false);
    }
  }
}

class _HeldFloater {
  _HeldFloater({
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

/// Keeps a number on screen for its authored life when 2× eats the sim timer.
abstract final class _FloaterHold {
  static final Map<int, _HeldFloater> live = {};

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
        live[id] = _HeldFloater(
          born: frame,
          span: math.max(8, (floater.life * 60).round()),
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
}

/// Layout cache for damage numbers. One painter per text, so two floaters
/// in the same frame cannot overwrite each other.
abstract final class _FloaterLabels {
  static const int _cap = 24;
  static final Map<String, TextPainter> _cache = {};

  static TextPainter of({
    required String text,
    required double size,
    required Color color,
    required double maxWidth,
  }) {
    final key =
        '${size.toStringAsFixed(2)}|${color.toARGB32()}|'
        '${maxWidth.toStringAsFixed(1)}|$text';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length >= _cap) {
      for (final painter in _cache.values) {
        painter.dispose();
      }
      _cache.clear();
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: GameTheme.pixelCached(size: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    _cache[key] = painter;
    return painter;
  }
}
