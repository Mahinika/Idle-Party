part of 'spatial_dungeon_view.dart';

extension DungeonPaintFloaters on _TileRoomPainter {
  void paintDungeonFloaters(
    Canvas canvas,
    double tile,
    double originX,
    double originY,
  ) {
    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

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
            Paint()
              ..color = const Color(0xE6100C08).withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(5.5, tile * 0.32)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawArc(
            rect,
            start,
            sweepDraw,
            false,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(3.2, tile * 0.2)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.72),
            start,
            sweepDraw,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.8, tile * 0.09)
              ..strokeCap = StrokeCap.round,
          );
          final tipAng = start + sweepDraw * 0.9;
          canvas.drawCircle(
            Offset(c.dx + math.cos(tipAng) * r, c.dy + math.sin(tipAng) * r),
            math.max(2.2, tile * 0.09),
            Paint()..color = Colors.white.withValues(alpha: alpha),
          );
        } else if (kind == SpatialBurstKind.ring) {
          final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.55 + (1 - alpha) * 0.7);
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = const Color(0xCC100C08).withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(4.2, tile * 0.2),
          );
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.95)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2.4, tile * 0.11),
          );
          canvas.drawCircle(
            c,
            r * 0.7,
            Paint()
              ..color = Colors.white.withValues(alpha: alpha * 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.4, tile * 0.055),
          );
        } else if (kind == SpatialBurstKind.cone && burst.angle != null) {
          final alpha = (burst.life / 0.45).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.85 + (1 - alpha) * 0.35);
          final sweep = 1.15;
          final start = burst.angle! - sweep * 0.5;
          final path = Path()
            ..moveTo(c.dx, c.dy)
            ..arcTo(Rect.fromCircle(center: c, radius: r), start, sweep, false)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.45),
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = Color(burst.argb).withValues(alpha: alpha * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, tile * 0.08),
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
              Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.9),
            );
          }
        } else if (kind == SpatialBurstKind.spark) {
          final alpha = (burst.life / 0.5).clamp(0.0, 1.0);
          final c = center(burst.x, burst.y);
          final r = tile * burst.radius * (0.4 + alpha * 0.4);
          canvas.drawCircle(
            c,
            r,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.9),
          );
          canvas.drawCircle(
            c,
            r * 0.4,
            Paint()..color = Colors.white.withValues(alpha: alpha),
          );
          for (var i = 0; i < 4; i++) {
            final a = i * math.pi / 2 + burst.life * 8;
            canvas.drawCircle(
              Offset(
                c.dx + math.cos(a) * r * 1.3,
                c.dy + math.sin(a) * r * 1.3,
              ),
              r * 0.25,
              Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.7),
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
            Paint()..color = const Color(0xAA100C08).withValues(alpha: alpha * 0.85),
          );
          canvas.drawCircle(
            c,
            r * 0.82,
            Paint()..color = Color(burst.argb).withValues(alpha: alpha * 0.7),
          );
          canvas.drawCircle(
            c,
            r * 0.42,
            Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
          );
        }
      }
    }

    if (showBursts || showPriorityFloaters) {
      final floaters = world.floaters;
      final tp = _TileRoomPainter._floaterPainter;
      final maxW = tile * 4.4;
      for (var i = 0; i < floaters.length; i++) {
        final floater = floaters[i];
        if (!showBursts && floater.priority < 2) continue;
        if (!_inView(floater.x, floater.y, pad: 0.5)) continue;
        final speech = floater.kind == SpatialFloaterKind.speech;
        final fadeFor = speech
            ? 1.35
            : (floater.priority >= 1 ? 1.15 : 0.7);
        final alpha = (floater.life / fadeFor).clamp(0.0, 1.0);
        final size = tile *
            (speech ? 0.28 : 0.32) *
            SpatialCombat.floaterReadScale(floater.priority);
        tp.text = TextSpan(
          text: floater.text,
          style: GameTheme.pixelCached(
            size: math.max(GameTheme.hudPixel, size),
            color: Color(floater.argb).withValues(alpha: alpha),
          ),
        );
        tp.layout(maxWidth: maxW);
        final c = center(floater.x, floater.y);
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
          _TileRoomPainter._fillPaint.color = const Color(0xCC1A1420).withValues(alpha: alpha);
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
    }
  }
}
