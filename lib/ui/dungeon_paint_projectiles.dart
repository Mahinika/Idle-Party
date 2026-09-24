part of 'spatial_dungeon_view.dart';

extension DungeonPaintProjectiles on _TileRoomPainter {
  void paintDungeonProjectiles(
    Canvas canvas,
    double tile,
    double originX,
    double originY,
  ) {
    Offset center(double tx, double ty) =>
        Offset(originX + tx * tile, originY + ty * tile);

    void drawSprite(
      ui.Image image,
      Offset c,
      double scale, {
      double alpha = 1,
      Color? tint,
      bool flipX = false,
    }) {
      final s = tile * scale;
      final dst = Rect.fromCenter(center: c, width: s, height: s);
      if (flipX) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(-1, 1);
        canvas.translate(-c.dx, -c.dy);
        _drawImage(canvas, image, dst, alpha: alpha, tint: tint);
        canvas.restore();
      } else {
        _drawImage(canvas, image, dst, alpha: alpha, tint: tint);
      }
    }

    for (final p in world.projectiles) {
      if (p.delay > 0) continue;
      if (!_inView(p.x, p.y)) continue;
      final c = center(p.x, p.y);
      final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
      final angle = speed > 0.01 ? math.atan2(p.vy, p.vx) : 0.0;
      final baseColor = switch (p.style) {
        SpellBoltStyle.fire =>
          p.label == 'PYRO' ? const Color(0xFFFF4010) : const Color(0xFFFF3C10),
        SpellBoltStyle.holy => const Color(0xFFFFF8E0),
        SpellBoltStyle.frost => const Color(0xFF4EE4FF),
        SpellBoltStyle.arcane => const Color(0xFFE040FF),
        SpellBoltStyle.shadow => const Color(0xFF9040D0),
        SpellBoltStyle.demon => const Color(0xFF70FF40),
        SpellBoltStyle.nature => const Color(0xFF2EAA55),
        SpellBoltStyle.poison => const Color(0xFFE4F04A),
        SpellBoltStyle.lightning => const Color(0xFFB8F0FF),
        SpellBoltStyle.arrow => const Color(0xFFD8C070),
        SpellBoltStyle.weapon =>
          p.team == SpatialTeam.hero
              ? (p.isCrit ? const Color(0xFFFFF0C0) : const Color(0xFFFFE08A))
              : const Color(0xFFFF6A4A),
      };
      final zoneTint = DungeonEnvironment.projectileTint(dungeonId);
      final color = Color.lerp(baseColor, zoneTint, 0.10)!;
      final len = tile * (p.pierce ? 0.55 : (0.35 + p.radius));
      final thick = math.max(2.0, tile * (0.08 + p.radius * 0.45));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);

      void drawTrailBolt() {
        if (!showTrails) {
          // Lite/Minimal: short bright slash nub — readable on phone.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -len * 0.35,
                -thick * 0.55,
                len * 0.75,
                thick * 1.1,
              ),
              Radius.circular(thick * 0.45),
            ),
            Paint()..color = color,
          );
          canvas.drawCircle(
            Offset(len * 0.35, 0),
            thick * 0.65,
            Paint()..color = Colors.white.withValues(alpha: 0.9),
          );
          return;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.85, -thick * 1.05, len * 1.15, thick * 2.1),
            Radius.circular(thick),
          ),
          Paint()..color = color.withValues(alpha: 0.32),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-len * 0.55, -thick * 0.55, len, thick * 1.1),
            Radius.circular(thick * 0.5),
          ),
          Paint()..color = color,
        );
        canvas.drawCircle(
          Offset(len * 0.45, 0),
          thick * 0.85,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }

      void drawOrb({required double core, Color? glow}) {
        if (showTrails) {
          canvas.drawCircle(
            Offset(-len * 0.15, 0),
            thick * 1.5,
            Paint()..color = (glow ?? color).withValues(alpha: 0.22),
          );
        }
        canvas.drawCircle(Offset.zero, thick * core, Paint()..color = color);
        canvas.drawCircle(
          Offset.zero,
          thick * 0.4,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }

      void shadowEyes() {
        final slit = Paint()..color = const Color(0xFFFFE080);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(-thick * 0.28, -thick * 0.15),
              width: thick * 0.42,
              height: thick * 0.16,
            ),
            Radius.circular(thick * 0.08),
          ),
          slit,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(thick * 0.28, -thick * 0.15),
              width: thick * 0.42,
              height: thick * 0.16,
            ),
            Radius.circular(thick * 0.08),
          ),
          slit,
        );
      }

      switch (p.style) {
        case SpellBoltStyle.fire:
          // Fireball: orb + trailing flame wedge.
          drawOrb(core: p.label == 'PYRO' ? 1.35 : 1.05);
          final flame = Path()
            ..moveTo(-len * 0.85, 0)
            ..lineTo(-len * 0.15, -thick * 1.15)
            ..lineTo(-len * 0.05, 0)
            ..lineTo(-len * 0.15, thick * 1.15)
            ..close();
          canvas.drawPath(
            flame,
            Paint()..color = const Color(0xCCFF5010),
          );
        case SpellBoltStyle.holy:
          drawOrb(core: 1.1, glow: const Color(0xFFFFF8D0));
          canvas.drawLine(
            Offset(0, -thick * 1.4),
            Offset(0, thick * 1.4),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = math.max(1.4, thick * 0.35)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            Offset(-thick * 1.05, 0),
            Offset(thick * 1.05, 0),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..strokeWidth = math.max(1.4, thick * 0.35)
              ..strokeCap = StrokeCap.round,
          );
        case SpellBoltStyle.frost:
          // Icy shard / frostbolt orb
          canvas.drawCircle(
            Offset(-len * 0.2, 0),
            thick * 1.4,
            Paint()..color = color.withValues(alpha: 0.2),
          );
          final ice = Path()
            ..moveTo(len * 0.55, 0)
            ..lineTo(-len * 0.35, -thick * 1.1)
            ..lineTo(-len * 0.15, 0)
            ..lineTo(-len * 0.35, thick * 1.1)
            ..close();
          canvas.drawPath(ice, Paint()..color = color);
          canvas.drawCircle(
            Offset.zero,
            thick * 0.55,
            Paint()..color = const Color(0xFFE8F8FF),
          );
        case SpellBoltStyle.arcane:
          drawOrb(core: 1.15, glow: const Color(0xFFE0A0FF));
          canvas.drawCircle(
            Offset.zero,
            thick * 1.35,
            Paint()
              ..color = color.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.2, thick * 0.25),
          );
        case SpellBoltStyle.shadow:
          canvas.drawCircle(
            Offset(-len * 0.25, 0),
            thick * 1.7,
            Paint()..color = const Color(0x66201040),
          );
          drawOrb(core: 1.05, glow: const Color(0xFF602090));
          shadowEyes();
        case SpellBoltStyle.demon:
          canvas.drawCircle(
            Offset(-len * 0.2, 0),
            thick * 1.6,
            Paint()..color = const Color(0x66402010),
          );
          drawOrb(core: 1.1, glow: const Color(0xFF40C020));
          canvas.drawCircle(
            Offset.zero,
            thick * 0.35,
            Paint()..color = const Color(0xFFFFE080),
          );
        case SpellBoltStyle.nature:
          drawOrb(core: 1.05, glow: const Color(0xFFA0E080));
          // Leaf tip
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(len * 0.35, 0),
              width: thick * 1.4,
              height: thick * 0.7,
            ),
            Paint()..color = const Color(0xFFB8F090),
          );
        case SpellBoltStyle.poison:
          drawOrb(core: 1.0, glow: const Color(0xFFA0E040));
          canvas.drawCircle(
            Offset(len * 0.25, thick * 0.35),
            thick * 0.35,
            Paint()..color = const Color(0xAA70B020),
          );
          canvas.drawCircle(
            Offset(len * 0.4, -thick * 0.25),
            thick * 0.28,
            Paint()..color = const Color(0xAA90D040),
          );
        case SpellBoltStyle.lightning:
          // Zigzag bolt
          final zig = Path()
            ..moveTo(-len * 0.55, -thick * 0.2)
            ..lineTo(-len * 0.1, thick * 0.9)
            ..lineTo(len * 0.05, -thick * 0.6)
            ..lineTo(len * 0.55, thick * 0.15);
          canvas.drawPath(
            zig,
            Paint()
              ..color = color.withValues(alpha: 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = thick * 1.6
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawPath(
            zig,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = thick * 0.55
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(
            Offset(len * 0.55, 0),
            thick * 0.65,
            Paint()..color = Colors.white,
          );
        case SpellBoltStyle.arrow:
          // Shaft
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                -len * 0.65,
                -thick * 0.28,
                len * 1.05,
                thick * 0.56,
              ),
              Radius.circular(thick * 0.2),
            ),
            Paint()..color = const Color(0xFF8A6230),
          );
          // Fletching
          final fletch = Path()
            ..moveTo(-len * 0.55, 0)
            ..lineTo(-len * 0.85, -thick * 1.15)
            ..lineTo(-len * 0.4, 0)
            ..lineTo(-len * 0.85, thick * 1.15)
            ..close();
          canvas.drawPath(fletch, Paint()..color = const Color(0xFFC05040));
          // Arrowhead
          final head = Path()
            ..moveTo(len * 0.55, 0)
            ..lineTo(len * 0.15, -thick * 1.05)
            ..lineTo(len * 0.2, 0)
            ..lineTo(len * 0.15, thick * 1.05)
            ..close();
          canvas.drawPath(head, Paint()..color = const Color(0xFFD0D4D8));
        case SpellBoltStyle.weapon:
          drawTrailBolt();
      }
      canvas.restore();
    }

    if (world.isTreasure) {
      final ex = world.map.exitPoint;
      drawSprite(chest, center(ex.$1 + 0.5, ex.$2 + 0.5), 1.1);
    }
  }
}
