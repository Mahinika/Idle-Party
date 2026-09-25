part of 'spatial_dungeon_view.dart';

class _TileRoomPainter extends CustomPainter {
  _TileRoomPainter({
    required this.world,
    required this.party,
    required this.floorVariants,
    required this.wallVariants,
    required this.stairs,
    required this.stairsBoss,
    required this.doorClosed,
    required this.doorOpen,
    required this.propImages,
    required this.roomType,
    required this.dungeonId,
    required this.layoutSeed,
    required this.clearedChambers,
    required this.heroes,
    required this.heroesByClass,
    required this.heroesBySpec,
    required this.bodyByPath,
    required this.enemies,
    required this.chest,
    required this.coin,
    required this.sword,
    required this.vial,
    required this.lootByPath,
    required this.petsByPath,
    required this.camera,
    this.vfxQuality = VfxQuality.full,
    required this.visualFrame,
  });

  final SpatialWorld world;
  final List<PartyHero> party;
  final List<ui.Image> floorVariants;
  final List<ui.Image> wallVariants;
  final ui.Image stairs;
  final ui.Image stairsBoss;
  final ui.Image doorClosed;
  final ui.Image doorOpen;
  final Map<MapPropKind, ui.Image?> propImages;
  final RoomType roomType;
  final String dungeonId;
  final int layoutSeed;
  final Set<int> clearedChambers;
  final List<ui.Image?> heroes;
  final Map<HeroClassId, ui.Image?> heroesByClass;
  final Map<HeroSpecId, ui.Image?> heroesBySpec;
  final Map<String, ui.Image> bodyByPath;
  final List<ui.Image?> enemies;
  final ui.Image chest;
  final ui.Image coin;
  final ui.Image sword;
  final ui.Image vial;
  final Map<String, ui.Image> lootByPath;
  final Map<String, ui.Image> petsByPath;
  final _TileCamera camera;
  final VfxQuality vfxQuality;
  final int visualFrame;

  bool get reducedVfx => vfxQuality.reduced;
  bool get showAuras => vfxQuality.showActorAuras;
  bool get showGuide => vfxQuality.showGuideAndPulse;
  bool get showBursts => vfxQuality.showBurstsAndFloaters;
  bool get showPriorityFloaters => vfxQuality.showPriorityFloaters;
  bool get showGround => vfxQuality.showGroundFx;
  bool get showTrails => vfxQuality.showProjectileTrails;
  bool get showLootPulse => vfxQuality.showLootPulse;

  Size? _vignetteSize;
  String? _vignetteDungeonId;
  Paint? _vignettePaint;
  // Static so reuse survives CustomPainter recreation each frame.
  static final Paint _fillPaint = Paint();
  static final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  static final TextPainter _goLabelPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );
  static final TextPainter _floaterPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );
  static double? _goLabelTile;
  static TextStyle? _goLabelStyle;

  static int _hashPick(int x, int y, int seed, int len) {
    if (len <= 0) return 0;
    final h = x * 73856093 ^ y * 19349663 ^ seed;
    return ((h % len) + len) % len;
  }

  bool _inView(double tx, double ty, {double pad = 1.25}) {
    return tx >= camera.camX - pad &&
        tx <= camera.camX + camera.visibleCols + pad &&
        ty >= camera.camY - pad &&
        ty <= camera.camY + camera.visibleRows + pad;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = camera.tileSize;
    final originX = -camera.camX * tile;
    final originY = -camera.camY * tile;
    final ambient = DungeonEnvironment.ambient(dungeonId);
    // Let the painted zone backdrop show through void / wall space.
    _fillPaint.color = ambient.withValues(alpha: 0.55);
    canvas.drawRect(Offset.zero & size, _fillPaint);

    final startX = camera.camX.floor().clamp(0, world.cols - 1);
    final endX = (camera.camX + camera.visibleCols).ceil().clamp(0, world.cols);
    final startY = camera.camY.floor().clamp(0, world.rows - 1);
    final endY = (camera.camY + camera.visibleRows).ceil().clamp(0, world.rows);

    final floorBlend = DungeonEnvironment.floorBlend(dungeonId);
    final corridorShade = DungeonEnvironment.corridorShade(dungeonId);

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final kind = world.map.at(x, y);
        final gate = kind == TileKind.gate ? world.map.gateAt(x, y) : null;
        final gateOpen = gate != null && world.openGateIds.contains(gate.id);
        final dst = Rect.fromLTWH(
          originX + x * tile,
          originY + y * tile,
          tile + 0.5,
          tile + 0.5,
        );

        if (kind == TileKind.wall) {
          // Void fill + thin wall caps toward carved space (no solid brick mass).
          if (DungeonEnvironment.wallTouchesCarved(world.map, x, y) &&
              wallVariants.isNotEmpty) {
            final img =
                wallVariants[_hashPick(
                  x,
                  y,
                  layoutSeed + 17,
                  wallVariants.length,
                )];
            _drawWallCaps(canvas, x, y, dst, tile, img);
          }
          continue;
        }

        // Boss rooms use the second floor tile (the landmark plate).
        final bossPlate = roomType == RoomType.boss && floorVariants.length > 1;
        final floorImg = bossPlate
            ? floorVariants[1]
            : floorVariants[_hashPick(x, y, layoutSeed, floorVariants.length)];
        _drawImage(canvas, floorImg, dst);
        // Mute Kenney tile chroma so painted backdrop + zone wash dominate.
        _fillPaint.color = floorBlend;
        canvas.drawRect(dst, _fillPaint);

        final noise = DungeonEnvironment.floorNoise(x, y, layoutSeed);
        if (noise.a > 0) {
          _fillPaint.color = noise;
          canvas.drawRect(dst, _fillPaint);
        }

        if (!DungeonEnvironment.inChamber(world.map, x, y) &&
            kind != TileKind.spawn &&
            kind != TileKind.exit) {
          _fillPaint.color = corridorShade;
          canvas.drawRect(dst, _fillPaint);
        }

        if (kind == TileKind.gate) {
          // Only the center cell of a 3-wide gate strip draws a door sprite.
            if (_isGateDoorCenter(x, y)) {
            final door = gateOpen ? doorOpen : doorClosed;
            final eastWest = DungeonEnvironment.gateRunsEastWest(
              world.map,
              x,
              y,
            );
            _drawOrientedDoor(canvas, door, dst, rotate: eastWest);
            if (!gateOpen) {
              _fillPaint.color = const Color(0x44000000);
              canvas.drawRect(dst, _fillPaint);
            } else {
              // Open door always reads as progress (even Minimal VFX).
              _strokePaint
                ..color = const Color(0x88FFE08A)
                ..strokeWidth = math.max(1.5, tile * 0.06);
              canvas.drawRect(dst.deflate(tile * 0.08), _strokePaint);
            }
          } else if (!gateOpen) {
            // Side cells: sealed stubs, not extra door panels.
            _fillPaint.color = const Color(0x55000000);
            canvas.drawRect(dst, _fillPaint);
          }
        } else if (kind == TileKind.exit) {
          final exitImg = roomType == RoomType.boss ? stairsBoss : stairs;
          _drawImage(canvas, exitImg, dst);
          if (world.awaitingExit) {
            if (showGuide) {
              final pulse = 0.75 + 0.25 * math.sin(visualFrame * 0.18);
              _strokePaint
                ..color = const Color(0x6670E0A0)
                ..strokeWidth = math.max(2, tile * 0.08);
              canvas.drawCircle(
                dst.center,
                tile * 0.55 * pulse,
                _strokePaint,
              );
              _fillPaint.color = const Color(0x3380FFB0);
              canvas.drawCircle(
                dst.center,
                tile * 0.32 * pulse,
                _fillPaint,
              );
            }
            // GO stays visible even on Minimal VFX — stairs must stay obvious.
            final goStyle = GameTheme.pixelCached(
              size: math.max(GameTheme.hudPixelComfort, tile * 0.42),
              color: const Color(0xEE80FFB0),
            );
            if (_goLabelTile != tile || !identical(_goLabelStyle, goStyle)) {
              _goLabelTile = tile;
              _goLabelStyle = goStyle;
              _goLabelPainter.text = TextSpan(text: 'GO', style: goStyle);
              _goLabelPainter.layout();
            }
            _goLabelPainter.paint(
              canvas,
              Offset(
                dst.center.dx - _goLabelPainter.width / 2,
                dst.top - _goLabelPainter.height - 2,
              ),
            );
          }
        } else if (kind == TileKind.spawn) {
          _fillPaint.color = const Color(0x14C88840);
          canvas.drawRect(dst, _fillPaint);
        }
      }
    }

    // Zone atmosphere wash over terrain (under actors).
    _fillPaint.color = DungeonEnvironment.atmosphereWash(dungeonId);
    canvas.drawRect(Offset.zero & size, _fillPaint);

    // Soft vignette so the play space feels framed by the cave.
    if (_vignettePaint == null ||
        _vignetteSize != size ||
        _vignetteDungeonId != dungeonId) {
      _vignetteSize = size;
      _vignetteDungeonId = dungeonId;
      _vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.longestSide * 0.78,
          DungeonEnvironment.vignetteColors(dungeonId),
          const [0.28, 0.65, 1.0],
        );
    }
    canvas.drawRect(Offset.zero & size, _vignettePaint!);

    for (final chamber in world.map.chambers) {
      if (!clearedChambers.contains(chamber.index)) continue;
      // Soft clear wash only — no giant stamp clutter.
      _fillPaint.color = const Color(0x1818A050);
      canvas.drawRect(
        Rect.fromLTWH(
          originX + chamber.x * tile,
          originY + chamber.y * tile,
          chamber.w * tile,
          chamber.h * tile,
        ),
        _fillPaint,
      );
    }

    // Lasting ground discs under actors (Consecration / Bladestorm / etc.).
    // Lite keeps these; Minimal (reduce motion) hides them.
    if (showGround) {
      for (final g in world.groundFx) {
        if (!_inView(g.x, g.y, pad: g.radius)) continue;
        final frac = (g.life / g.maxLife).clamp(0.0, 1.0);
        final c = Offset(originX + g.x * tile, originY + g.y * tile);
        final r = tile * g.radius;
        final color = Color(g.argb);
        canvas.drawCircle(
          c,
          r,
          Paint()..color = color.withValues(alpha: 0.18 * frac),
        );
        _paintGroundKind(canvas, c, r, color, frac, tile, g.kind, g.life);
      }
    }

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

    for (final prop in world.map.props) {
      if (!_inView(prop.x + 0.5, prop.y + 0.5, pad: 0.75)) continue;
      final img = propImages[prop.kind];
      if (img == null) continue;
      final c = center(prop.x + 0.5, prop.y + 0.5);
      // Soft ground shadow so clutter reads against flat floor tiles.
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, tile * 0.18),
          width: tile * 0.55,
          height: tile * 0.22,
        ),
        Paint()..color = DungeonEnvironment.propShadow(dungeonId),
      );
      if (DungeonEnvironment.isTorchProp(prop.kind) && !reducedVfx) {
        final pulse = 0.85 + 0.15 * math.sin(visualFrame * 0.12);
        canvas.drawCircle(
          c.translate(0, -tile * 0.18),
          tile * 0.72 * pulse,
          Paint()
            ..shader = ui.Gradient.radial(
              c.translate(0, -tile * 0.18),
              tile * 0.72 * pulse,
              const [Color(0x55F0B038), Color(0x18E08828), Color(0x00E08828)],
              const [0.0, 0.45, 1.0],
            ),
        );
      }
      drawSprite(img, c, 0.80);
    }

    for (final loot in world.groundLoot) {
      if (!_inView(loot.x, loot.y)) continue;
      final bob = math.sin(loot.age * 9) * 0.12;
      final path = KenneyAssets.lootDropIconFor(loot.drop);
      final img =
          lootByPath[path] ??
          switch (loot.kind) {
            GroundLootKind.gold => coin,
            GroundLootKind.essence => vial,
            GroundLootKind.gear => sword,
            GroundLootKind.chest => chest,
          };
      final c = center(loot.x, loot.y + bob);
      final glow = switch (loot.drop.rarity) {
        LootRarity.common => const Color(0x66C8C0A8),
        LootRarity.uncommon => const Color(0x8870C050),
        LootRarity.rare => const Color(0x9950A0FF),
        LootRarity.epic => const Color(0xBBFFE08A),
        LootRarity.legendary => const Color(0xDDFF8C40),
      };
      final pulse = showLootPulse ? 0.85 + 0.15 * math.sin(loot.age * 6) : 1.0;
      _fillPaint.color = glow;
      canvas.drawCircle(
        c,
        tile * (0.32 + loot.drop.rarity.index * 0.04) * pulse,
        _fillPaint,
      );
      if (showLootPulse && loot.age > 0.28) {
        SpatialActor? magnet;
        var best = 4.6;
        for (final h in world.heroes) {
          if (h.hp <= 0) continue;
          final dx = h.x - loot.x;
          final dy = h.y - loot.y;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < best && d > 0.55) {
            best = d;
            magnet = h;
          }
        }
        if (magnet != null) {
          final hc = center(magnet.x, magnet.y);
          _strokePaint
            ..color = glow.withValues(alpha: 0.45)
            ..strokeWidth = math.max(1.2, tile * 0.055);
          canvas.drawLine(c, hc, _strokePaint);
        }
      }
      if (showLootPulse && loot.drop.rarity.index >= LootRarity.rare.index) {
        _strokePaint
          ..color = glow.withValues(alpha: 0.35)
          ..strokeWidth = 2;
        canvas.drawCircle(c, tile * 0.42 * pulse, _strokePaint);
      }
      drawSprite(img, c, loot.kind == GroundLootKind.chest ? 0.55 : 0.48);
    }

    // Smash ring paints on Minimal too — one pulse, not the aim guide.
    if (world.pulseTimer > 0 &&
        world.pulseX != null &&
        world.pulseY != null) {
      final progress = (1 - world.pulseTimer / 0.55).clamp(0.0, 1.0);
      final pc = center(world.pulseX!, world.pulseY!);
      final outer = tile * (0.55 + progress * 2.8);
      final smash = Color(world.godHandArgb);
      canvas.drawCircle(
        pc,
        outer,
        Paint()
          ..color = smash.withValues(alpha: 0.85 * (1 - progress * 0.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.5, tile * 0.12),
      );
      canvas.drawCircle(
        pc,
        outer * 0.55,
        Paint()
          ..color = Color.fromRGBO(255, 248, 200, 0.55 * (1 - progress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.8, tile * 0.08),
      );
      canvas.drawCircle(
        pc,
        tile * 0.35 * (1 - progress * 0.4),
        Paint()..color = Color.fromRGBO(255, 240, 180, 0.4 * (1 - progress)),
      );
    }

    // God Hand aim marker + radius while guiding the party.
    if (showGuide &&
        world.guideTimer > 0 &&
        world.guideX != null &&
        world.guideY != null) {
      final gc = center(world.guideX!, world.guideY!);
      final pulse = 0.85 + 0.15 * math.sin(world.guideTimer * 10);
      final r = tile * world.godHandRadius * pulse;
      final ring = Color(world.godHandArgb);
      canvas.drawCircle(
        gc,
        r,
        Paint()
          ..color = ring.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, tile * 0.06),
      );
      canvas.drawCircle(
        gc,
        tile * 0.22 * pulse,
        Paint()..color = ring.withValues(alpha: 0.75),
      );
      canvas.drawCircle(
        gc,
        tile * 0.1,
        Paint()..color = ring,
      );
    }

    paintDungeonProjectiles(canvas, tile, originX, originY);
    paintDungeonActors(canvas, tile, originX, originY);
    paintDungeonFloaters(canvas, tile, originX, originY);
  }

  void _paintGroundKind(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double frac,
    double tile,
    SpatialGroundFxKind kind,
    double life,
  ) {
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.6 * frac)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, tile * 0.06);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x99100C08).withValues(alpha: 0.85 * frac)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.2, tile * 0.11),
    );
    canvas.drawCircle(c, r, stroke);
    switch (kind) {
      case SpatialGroundFxKind.disc:
        return;
      case SpatialGroundFxKind.holy:
        // Consecration: spokes + inner ring.
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(c.dx + math.cos(a) * r * 0.2, c.dy + math.sin(a) * r * 0.2),
            Offset(c.dx + math.cos(a) * r * 0.92, c.dy + math.sin(a) * r * 0.92),
            Paint()
              ..color = const Color(0xAAFFF6C0).withValues(alpha: 0.55 * frac)
              ..strokeWidth = math.max(1.2, tile * 0.045)
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(
          c,
          r * 0.38,
          Paint()
            ..color = const Color(0x66FFF0A0).withValues(alpha: 0.45 * frac)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, tile * 0.05),
        );
      case SpatialGroundFxKind.frost:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + life * 0.4;
          final p = Path()
            ..moveTo(c.dx + math.cos(a) * r * 0.25, c.dy + math.sin(a) * r * 0.25)
            ..lineTo(
              c.dx + math.cos(a) * r * 0.88,
              c.dy + math.sin(a) * r * 0.88,
            )
            ..lineTo(
              c.dx + math.cos(a + 0.22) * r * 0.55,
              c.dy + math.sin(a + 0.22) * r * 0.55,
            )
            ..close();
          canvas.drawPath(
            p,
            Paint()..color = const Color(0x88C8F0FF).withValues(alpha: 0.45 * frac),
          );
        }
      case SpatialGroundFxKind.fire:
        for (var i = 0; i < 4; i++) {
          final a = i * 1.7 + life;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                c.dx + math.cos(a) * r * 0.35,
                c.dy + math.sin(a) * r * 0.28,
              ),
              width: r * 0.55,
              height: r * 0.38,
            ),
            Paint()..color = const Color(0x66FF5018).withValues(alpha: 0.4 * frac),
          );
        }
      case SpatialGroundFxKind.rain:
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final ox = math.cos(a) * r * 0.55;
          final oy = math.sin(a) * r * 0.55;
          final drop = ((life * 3 + i * 0.4) % 1.0);
          canvas.drawLine(
            Offset(c.dx + ox, c.dy + oy - r * 0.22 * drop),
            Offset(c.dx + ox, c.dy + oy + r * 0.12),
            Paint()
              ..color = color.withValues(alpha: 0.7 * frac)
              ..strokeWidth = math.max(1.2, tile * 0.04)
              ..strokeCap = StrokeCap.round,
          );
        }
      case SpatialGroundFxKind.shadow:
        canvas.drawCircle(
          c,
          r * 0.55,
          Paint()..color = const Color(0x55201040).withValues(alpha: 0.5 * frac),
        );
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.72),
          life,
          2.2,
          false,
          Paint()
            ..color = const Color(0xAA9050D0).withValues(alpha: 0.55 * frac)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07)
            ..strokeCap = StrokeCap.round,
        );
      case SpatialGroundFxKind.nature:
        for (var i = 0; i < 5; i++) {
          final a = i * 1.26 + 0.3;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                c.dx + math.cos(a) * r * 0.55,
                c.dy + math.sin(a) * r * 0.55,
              ),
              width: r * 0.28,
              height: r * 0.16,
            ),
            Paint()..color = const Color(0x882EAA55).withValues(alpha: 0.5 * frac),
          );
        }
      case SpatialGroundFxKind.poison:
        for (var i = 0; i < 4; i++) {
          final a = i * 1.6;
          canvas.drawCircle(
            Offset(
              c.dx + math.cos(a) * r * 0.45,
              c.dy + math.sin(a) * r * 0.45,
            ),
            r * 0.12,
            Paint()..color = const Color(0xAAE4F04A).withValues(alpha: 0.55 * frac),
          );
        }
      case SpatialGroundFxKind.steel:
        for (var i = 0; i < 3; i++) {
          final a = life * 6 + i * 2.1;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * (0.45 + i * 0.18)),
            a,
            1.4,
            false,
            Paint()
              ..color = const Color(0xCCFFE08A).withValues(alpha: 0.55 * frac)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, tile * 0.08)
              ..strokeCap = StrokeCap.round,
          );
        }
      case SpatialGroundFxKind.blood:
        canvas.drawCircle(
          c,
          r * 0.42,
          Paint()..color = color.withValues(alpha: 0.28 * frac),
        );
        for (var i = 0; i < 5; i++) {
          final a = i * 1.25 + 0.4;
          canvas.drawCircle(
            Offset(
              c.dx + math.cos(a) * r * 0.55,
              c.dy + math.sin(a) * r * 0.55,
            ),
            r * 0.1,
            Paint()..color = const Color(0xCCE03040).withValues(alpha: 0.7 * frac),
          );
        }
    }
  }

  void _paintSpellBurst(
    Canvas canvas,
    SpatialBurst burst,
    double tile,
    Offset Function(double, double) center,
  ) {
    final alpha = (burst.life / 0.55).clamp(0.0, 1.0);
    final c = center(burst.x, burst.y);
    final r = tile * burst.radius * (0.78 + (1 - alpha) * 0.32);
    final color = Color(burst.argb);
    final ink = Paint()
      ..color = const Color(0xE6100C08).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3.4, tile * 0.13)
      ..strokeCap = StrokeCap.round;
    switch (burst.kind) {
      case SpatialBurstKind.beam:
        final end = burst.x2 != null && burst.y2 != null
            ? center(burst.x2!, burst.y2!)
            : Offset(c.dx, c.dy - r * 2.4);
        final dx = end.dx - c.dx;
        final dy = end.dy - c.dy;
        final len = math.sqrt(dx * dx + dy * dy) + 0.001;
        final nx = -dy / len;
        final ny = dx / len;
        final zig = Path()..moveTo(c.dx, c.dy);
        for (var i = 1; i <= 4; i++) {
          final t = i / 5;
          final side = (i.isOdd ? 1.0 : -1.0) * r * 0.42;
          zig.lineTo(c.dx + dx * t + nx * side, c.dy + dy * t + ny * side);
        }
        zig.lineTo(end.dx, end.dy);
        canvas.drawPath(zig, ink);
        canvas.drawPath(
          zig,
          Paint()
            ..color = color.withValues(alpha: alpha * 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.4, tile * 0.09)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          zig,
          Paint()
            ..color = Colors.white.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.1, tile * 0.04)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          end,
          r * 0.42,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      case SpatialBurstKind.rain:
        for (var i = 0; i < 8; i++) {
          final a = i * 0.85;
          final ox = math.cos(a) * r * 0.75;
          final oy = math.sin(a) * r * 0.35;
          final fall = (1 - alpha) * r * 0.7;
          final a0 = Offset(c.dx + ox, c.dy + oy - r * 1.05 + fall);
          final a1 = Offset(c.dx + ox, c.dy + oy - r * 0.12 + fall);
          canvas.drawLine(
            a0,
            a1,
            Paint()
              ..color = const Color(0xCC100C08).withValues(alpha: alpha)
              ..strokeWidth = math.max(3.0, tile * 0.1)
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            a0,
            a1,
            Paint()
              ..color = color.withValues(alpha: alpha)
              ..strokeWidth = math.max(1.6, tile * 0.055)
              ..strokeCap = StrokeCap.round,
          );
        }
      case SpatialBurstKind.shards:
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + (1 - alpha) * 0.4;
          final p = Path()
            ..moveTo(
              c.dx + math.cos(a) * r * 1.25,
              c.dy + math.sin(a) * r * 1.25,
            )
            ..lineTo(
              c.dx + math.cos(a + 0.28) * r * 0.22,
              c.dy + math.sin(a + 0.28) * r * 0.22,
            )
            ..lineTo(
              c.dx + math.cos(a - 0.28) * r * 0.22,
              c.dy + math.sin(a - 0.28) * r * 0.22,
            )
            ..close();
          canvas.drawPath(
            p,
            Paint()..color = const Color(0xDD100C08).withValues(alpha: alpha),
          );
          canvas.drawPath(p, Paint()..color = color.withValues(alpha: alpha));
        }
        canvas.drawCircle(
          c,
          r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      case SpatialBurstKind.flame:
        // Petals bias upward so fire reads as rising, not a tinted disc.
        for (var i = 0; i < 5; i++) {
          final a = -1.15 + i * 0.55 + (1 - alpha) * 0.2;
          final lift = r * 0.35 * (1 - alpha);
          final p = Path()
            ..moveTo(c.dx, c.dy + r * 0.15)
            ..quadraticBezierTo(
              c.dx + math.cos(a + 0.35) * r * 0.45,
              c.dy + math.sin(a + 0.35) * r * 0.45 - lift,
              c.dx + math.cos(a) * r * 1.2,
              c.dy + math.sin(a) * r * 1.2 - lift,
            )
            ..quadraticBezierTo(
              c.dx + math.cos(a - 0.35) * r * 0.45,
              c.dy + math.sin(a - 0.35) * r * 0.45 - lift,
              c.dx,
              c.dy + r * 0.15,
            );
          canvas.drawPath(
            p,
            Paint()..color = const Color(0xBB100C08).withValues(alpha: alpha),
          );
          canvas.drawPath(
            p,
            Paint()..color = color.withValues(alpha: alpha * 0.88),
          );
        }
        canvas.drawCircle(
          c,
          r * 0.34,
          Paint()..color = const Color(0xFFFFF0A0).withValues(alpha: alpha),
        );
      case SpatialBurstKind.cross:
        final arm = r * 1.15;
        canvas.drawLine(
          Offset(c.dx, c.dy - arm),
          Offset(c.dx, c.dy + arm * 0.55),
          ink,
        );
        canvas.drawLine(
          Offset(c.dx - arm * 0.75, c.dy - arm * 0.12),
          Offset(c.dx + arm * 0.75, c.dy - arm * 0.12),
          ink,
        );
        final holy = Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeWidth = math.max(2.4, tile * 0.1)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(c.dx, c.dy - arm),
          Offset(c.dx, c.dy + arm * 0.55),
          holy,
        );
        canvas.drawLine(
          Offset(c.dx - arm * 0.75, c.dy - arm * 0.12),
          Offset(c.dx + arm * 0.75, c.dy - arm * 0.12),
          holy,
        );
        canvas.drawCircle(
          c,
          r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
      case SpatialBurstKind.poison:
        for (var i = 0; i < 5; i++) {
          final a = -0.4 + i * 0.55;
          final fall = r * 0.45 * (1 - alpha);
          final drip = Offset(
            c.dx + math.sin(a) * r * 0.55,
            c.dy + math.cos(a) * r * 0.15 + fall,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: drip,
              width: r * 0.32,
              height: r * 0.62,
            ),
            Paint()..color = const Color(0xCC100C08).withValues(alpha: alpha),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: drip,
              width: r * 0.24,
              height: r * 0.5,
            ),
            Paint()..color = color.withValues(alpha: alpha * 0.9),
          );
        }
        canvas.drawCircle(
          c,
          r * 0.26,
          Paint()..color = const Color(0xAAE8FFC0).withValues(alpha: alpha),
        );
      case SpatialBurstKind.skull:
        final head = Rect.fromCenter(
          center: Offset(c.dx, c.dy - r * 0.08),
          width: r * 1.55,
          height: r * 1.7,
        );
        canvas.drawOval(
          head.inflate(r * 0.08),
          Paint()..color = const Color(0xDD100C08).withValues(alpha: alpha),
        );
        canvas.drawOval(
          head,
          Paint()..color = color.withValues(alpha: alpha * 0.92),
        );
        canvas.drawCircle(
          Offset(c.dx - r * 0.3, c.dy - r * 0.18),
          r * 0.2,
          Paint()..color = const Color(0xFF100C08).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(c.dx + r * 0.3, c.dy - r * 0.18),
          r * 0.2,
          Paint()..color = const Color(0xFF100C08).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(c.dx - r * 0.3, c.dy - r * 0.18),
          r * 0.08,
          Paint()..color = const Color(0xFFFFE080).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(c.dx + r * 0.3, c.dy - r * 0.18),
          r * 0.08,
          Paint()..color = const Color(0xFFFFE080).withValues(alpha: alpha),
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * 0.32),
            width: r * 0.72,
            height: r * 0.42,
          ),
          0.25,
          math.pi - 0.5,
          false,
          Paint()
            ..color = const Color(0xEE100C08).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, tile * 0.07),
        );
      default:
        canvas.drawCircle(
          c,
          r,
          Paint()..color = color.withValues(alpha: alpha * 0.7),
        );
    }
  }

  bool _isGateDoorCenter(int x, int y) {
    final map = world.map;
    final left = map.at(x - 1, y) == TileKind.gate;
    final right = map.at(x + 1, y) == TileKind.gate;
    final up = map.at(x, y - 1) == TileKind.gate;
    final down = map.at(x, y + 1) == TileKind.gate;
    if ((left && right) || (up && down)) return true; // middle of 3-strip
    if (!left && !right && !up && !down) return true; // lone gate
    return false; // strip end — no door panel
  }

  void _drawWallCaps(
    Canvas canvas,
    int x,
    int y,
    Rect dst,
    double tile,
    ui.Image wall,
  ) {
    final map = world.map;
    final t = tile * 0.34;
    // Filled strips are cheaper than clip+blit per edge.
    void strip(Rect r) {
      _drawImage(canvas, wall, r);
      _fillPaint.color = const Color(0x66000000);
      canvas.drawRect(r, _fillPaint);
    }

    if (DungeonEnvironment.isCarved(map.at(x, y + 1))) {
      strip(Rect.fromLTWH(dst.left, dst.bottom - t, dst.width, t));
    }
    if (DungeonEnvironment.isCarved(map.at(x, y - 1))) {
      strip(Rect.fromLTWH(dst.left, dst.top, dst.width, t));
    }
    if (DungeonEnvironment.isCarved(map.at(x + 1, y))) {
      strip(Rect.fromLTWH(dst.right - t, dst.top, t, dst.height));
    }
    if (DungeonEnvironment.isCarved(map.at(x - 1, y))) {
      strip(Rect.fromLTWH(dst.left, dst.top, t, dst.height));
    }
  }

  void _drawOrientedDoor(
    Canvas canvas,
    ui.Image door,
    Rect dst, {
    required bool rotate,
  }) {
    // Crop baked wall lip from the top ~20% of Kenney door tiles.
    final src = Rect.fromLTWH(
      0,
      door.height * 0.18,
      door.width.toDouble(),
      door.height * 0.82,
    );
    final doorDst = Rect.fromCenter(
      center: dst.center.translate(0, dst.height * 0.04),
      width: dst.width * 0.92,
      height: dst.height * 0.88,
    );

    if (!rotate) {
      _drawImageSrc(canvas, door, src, doorDst);
      return;
    }
    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    canvas.rotate(math.pi / 2);
    _drawImageSrc(
      canvas,
      door,
      src,
      Rect.fromCenter(
        center: Offset.zero,
        width: doorDst.width,
        height: doorDst.height,
      ),
    );
    canvas.restore();
  }

  void _drawImageSrc(
    Canvas canvas,
    ui.Image image,
    Rect src,
    Rect dst, {
    double alpha = 1,
    Color? tint,
  }) {
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    canvas.drawImageRect(image, src, dst, paint);
  }

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect dst, {
    double alpha = 1,
    Color? tint,
  }) {
    _drawImageSrc(
      canvas,
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      alpha: alpha,
      tint: tint,
    );
  }

  @override
  bool shouldRepaint(covariant _TileRoomPainter oldDelegate) {
    return visualFrame != oldDelegate.visualFrame ||
        dungeonId != oldDelegate.dungeonId ||
        reducedVfx != oldDelegate.reducedVfx ||
        vfxQuality != oldDelegate.vfxQuality ||
        camera.camX != oldDelegate.camera.camX ||
        camera.camY != oldDelegate.camera.camY ||
        camera.tileSize != oldDelegate.camera.tileSize ||
        !identical(world, oldDelegate.world) ||
        !identical(floorVariants, oldDelegate.floorVariants) ||
        !identical(enemies, oldDelegate.enemies) ||
        !identical(heroesByClass, oldDelegate.heroesByClass) ||
        !identical(heroesBySpec, oldDelegate.heroesBySpec) ||
        !identical(bodyByPath, oldDelegate.bodyByPath);
  }
}
