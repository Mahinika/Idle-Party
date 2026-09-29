part of 'spatial_dungeon_view.dart';

/// Additive light under spells, plus the sparks those spells leave behind.
extension DungeonPaintSpellFx on _TileRoomPainter {
  static final Paint _glow = Paint()..blendMode = BlendMode.plus;
  static final Paint _spark = Paint();

  void paintSpellGlow(
    Canvas canvas,
    double tile,
    double originX,
    double originY,
  ) {
    if (vfxQuality == VfxQuality.minimal) return;
    final strength = vfxQuality == VfxQuality.full ? 0.5 : 0.22;
    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

    void pool(Offset c, double radius, Color color) {
      if (radius < 2) return;
      _glow.shader = ui.Gradient.radial(c, radius, [
        color.withValues(alpha: strength),
        color.withValues(alpha: 0),
      ]);
      canvas.drawCircle(c, radius, _glow);
    }

    for (final burst in world.bursts) {
      if (!_inView(burst.x, burst.y, pad: 2)) continue;
      final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
      final c = center(burst.x, burst.y);
      pool(
        c,
        tile * burst.radius * 2.4 * (0.85 + (1 - alpha) * 0.25),
        Color(burst.argb),
      );
    }
    for (final bolt in world.projectiles) {
      if (bolt.delay > 0) continue;
      if (!_inView(bolt.x, bolt.y, pad: 1.5)) continue;
      pool(
        center(bolt.x, bolt.y),
        tile * (0.85 + bolt.radius * 2.2),
        Color(SpatialCombat.burstArgbForStyle(bolt.style)),
      );
    }
    _glow.shader = null;
  }

  void paintSpellSparks(
    Canvas canvas,
    double tile,
    double originX,
    double originY,
  ) {
    if (vfxQuality == VfxQuality.minimal) return;
    final sparks = world.spellSparks;
    if (sparks.isEmpty) return;
    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

    for (final s in sparks) {
      if (!_inView(s.x, s.y, pad: 0.6)) continue;
      final alpha = (s.life / 0.4).clamp(0.0, 1.0);
      final c = center(s.x, s.y);
      final r = math.max(1.6, tile * s.size);
      final color = Color(s.argb);
      _spark
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: alpha * 0.4);
      canvas.drawCircle(c, r * 2.1, _spark);
      _spark
        ..blendMode = BlendMode.srcOver
        ..color = color.withValues(alpha: alpha);
      switch (s.kind) {
        case SpellSparkKind.ember:
        case SpellSparkKind.mote:
          canvas.drawCircle(c, r, _spark);
          _spark.color = const Color(0xFFFFF2C0).withValues(alpha: alpha);
          canvas.drawCircle(c, r * 0.4, _spark);
        case SpellSparkKind.flake:
          final p = Path()
            ..moveTo(c.dx, c.dy - r * 1.3)
            ..lineTo(c.dx + r * 0.45, c.dy)
            ..lineTo(c.dx, c.dy + r * 1.3)
            ..lineTo(c.dx - r * 0.45, c.dy)
            ..close();
          canvas.drawPath(p, _spark);
        case SpellSparkKind.leaf:
          canvas.drawOval(
            Rect.fromCenter(center: c, width: r * 1.8, height: r * 0.9),
            _spark,
          );
        case SpellSparkKind.smoke:
          _spark.color = color.withValues(alpha: alpha * 0.55);
          canvas.drawCircle(c, r * 1.6, _spark);
        case SpellSparkKind.spark:
          final len = math.sqrt(s.vx * s.vx + s.vy * s.vy) + 0.001;
          final tip = Offset(
            c.dx + s.vx / len * r * 2.2,
            c.dy + s.vy / len * r * 2.2,
          );
          _spark
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, r * 0.45)
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(c, tip, _spark);
          _spark.style = PaintingStyle.fill;
        case SpellSparkKind.rune:
          canvas.drawRect(
            Rect.fromCenter(center: c, width: r * 1.2, height: r * 1.2),
            _spark,
          );
          _spark
            ..color = Colors.white.withValues(alpha: alpha * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, tile * 0.02);
          canvas.drawRect(
            Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.7),
            _spark,
          );
          _spark.style = PaintingStyle.fill;
      }
    }
  }
}
