part of 'spatial_dungeon_view.dart';

/// Slow zone motes over the map (snow, embers, spores…). Stateless: every
/// mote's spot is a pure function of its index and the frame, so there is no
/// list to tick. Kept sparse and faint — soft fascination, never a distraction.
extension _DungeonAmbientParticles on _TileRoomPainter {
  void paintAmbientParticles(Canvas canvas, Size size) {
    final count = switch (vfxQuality) {
      VfxQuality.full => 22,
      VfxQuality.lite => 10,
      VfxQuality.minimal => 0,
    };
    final kind = ZoneFloorStyle.byId(dungeonId).particles;
    if (count == 0 || kind == AmbientParticleKind.none) return;
    final tile = camera.tileSize;
    final w = size.width;
    final h = size.height;
    // Drift with the world a little (parallax) so motes feel in the cave.
    final parX = -camera.camX * tile * 0.35;
    final parY = -camera.camY * tile * 0.35;
    final paint = Paint()..isAntiAlias = false;
    final f = visualFrame.toDouble();

    double wrap(double v, double span) => ((v % span) + span) % span;

    for (var i = 0; i < count; i++) {
      final seedA = ((i * 2654435761) & 0xFFFF) / 65535.0;
      final seedB = ((i * 40503 + 977) & 0xFFFF) / 65535.0;
      final seedC = ((i * 9176 + 131) & 0xFF) / 255.0;
      final baseX = seedA * w;
      final baseY = seedB * h;
      double x;
      double y;
      double s = math.max(1.5, tile * 0.07);
      Color c;
      switch (kind) {
        case AmbientParticleKind.snow:
          x = baseX + math.sin(f * 0.012 + i) * tile * 0.6;
          y = baseY + f * (0.25 + seedC * 0.25);
          c = const Color(0x90F0FAFF);
        case AmbientParticleKind.embers:
          x = baseX + math.sin(f * 0.02 + i * 1.7) * tile * 0.4;
          y = baseY - f * (0.3 + seedC * 0.3);
          c = Color.lerp(const Color(0xA0FF7020), const Color(0xA0FFD060), seedC)!;
          s *= 0.8;
        case AmbientParticleKind.spores:
          x = baseX + math.sin(f * 0.008 + i) * tile * 0.9;
          y = baseY - f * (0.08 + seedC * 0.1);
          c = const Color(0x70D8F070);
        case AmbientParticleKind.bubbles:
          x = baseX + math.sin(f * 0.03 + i) * tile * 0.2;
          y = baseY - f * (0.2 + seedC * 0.2);
          c = const Color(0x70B0F0FF);
        case AmbientParticleKind.sparks:
          x = baseX + math.sin(f * 0.01 + i) * tile * 0.3;
          y = baseY + f * 0.05;
          final blink = math.sin(f * 0.06 + i * 2.3);
          if (blink < 0.55) continue;
          c = const Color(0xB0E8F0FF);
        case AmbientParticleKind.moths:
          x = baseX + math.sin(f * 0.011 + i) * tile * 1.4;
          y = baseY + math.sin(f * 0.023 + i * 0.6) * tile * 0.8;
          c = const Color(0x90F0E0FF);
          s *= 1.3;
        case AmbientParticleKind.dust:
          x = baseX + f * (0.1 + seedC * 0.1);
          y = baseY + math.sin(f * 0.01 + i) * tile * 0.3;
          c = const Color(0x50F0E0C0);
        case AmbientParticleKind.motes:
          x = baseX + math.sin(f * 0.009 + i) * tile * 0.7;
          y = baseY - f * 0.06;
          c = DungeonEnvironment.projectileTint(dungeonId).withValues(alpha: 0.45);
        case AmbientParticleKind.none:
          continue;
      }
      paint.color = c;
      final px = wrap(x + parX, w);
      final py = wrap(y + parY, h);
      canvas.drawRect(Rect.fromLTWH(px, py, s, s), paint);
      if (kind == AmbientParticleKind.moths) {
        canvas.drawRect(Rect.fromLTWH(px - s, py - s * 0.5, s, s * 0.6), paint);
        canvas.drawRect(Rect.fromLTWH(px + s, py - s * 0.5, s, s * 0.6), paint);
      }
    }
  }
}
