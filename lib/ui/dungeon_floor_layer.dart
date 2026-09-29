part of 'spatial_dungeon_view.dart';

/// Static terrain (floor, wall rims + faces, beat tint, decals) baked once per
/// map at 16 px a tile, then blitted with the camera. Keeps the per-frame
/// cost flat while floors carry far more detail.
abstract final class _FloorLayerCache {
  static const double bakeTile = 16;

  static TileMap? _map;
  static ui.Image? _floorKey;
  static ui.Image? _wallKey;
  static RoomType? _roomType;
  static bool? _colorblind;
  static ui.Image? _image;
  static bool _failed = false;

  static ui.Image? imageFor(_TileRoomPainter p) {
    final map = p.world.map;
    final floorKey = p.floorVariants.isEmpty ? null : p.floorVariants.first;
    final wallKey = p.wallVariants.isEmpty ? null : p.wallVariants.first;
    final fresh =
        identical(_map, map) &&
        identical(_floorKey, floorKey) &&
        identical(_wallKey, wallKey) &&
        _roomType == p.roomType &&
        _colorblind == SpatialCombat.colorblindMode;
    if (fresh) return _failed ? null : _image;
    _image?.dispose();
    _image = null;
    _map = map;
    _floorKey = floorKey;
    _wallKey = wallKey;
    _roomType = p.roomType;
    _colorblind = SpatialCombat.colorblindMode;
    _failed = false;
    final w = (map.cols * bakeTile).round();
    final h = (map.rows * bakeTile).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    p.paintStaticTerrain(
      canvas,
      tile: bakeTile,
      originX: 0,
      originY: 0,
      x0: 0,
      x1: map.cols,
      y0: 0,
      y1: map.rows,
    );
    final picture = recorder.endRecording();
    try {
      _image = picture.toImageSync(w, h);
    } catch (_) {
      _failed = true;
    } finally {
      picture.dispose();
    }
    return _image;
  }
}

/// Per-map runtime look state (reveal fade, stairs finale). Never saved.
abstract final class _FloorLookState {
  static TileMap? _map;
  static final Map<int, int> revealedAt = <int, int>{};
  static final Map<int, Path> _carved = <int, Path>{};
  static int? exitOpenedAt;

  static void sync(TileMap map) {
    if (identical(_map, map)) return;
    _map = map;
    revealedAt.clear();
    _carved.clear();
    exitOpenedAt = null;
  }

  /// Carved cells of [c] in tile units (row runs), so the dim never spills
  /// onto the cave backdrop around a round room.
  static Path carvedPath(TileMap map, Chamber c) => _carved.putIfAbsent(c.index, () {
    final path = Path();
    for (var y = c.y; y < c.y + c.h; y++) {
      var run = -1;
      for (var x = c.x; x <= c.x + c.w; x++) {
        final carved = x < c.x + c.w && map.at(x, y) != TileKind.wall;
        if (carved && run < 0) run = x;
        if (!carved && run >= 0) {
          path.addRect(Rect.fromLTWH(run.toDouble(), y.toDouble(), (x - run).toDouble(), 1));
          run = -1;
        }
      }
    }
    return path;
  });
}

extension _DungeonFloorLayer on _TileRoomPainter {
  static const Color _faceTop = Color(0x30FFFFFF);
  static const Color _faceShade = Color(0x8C000000);
  static const Color _faceFoot = Color(0x48000000);

  Color? _beatTint(Chamber c) {
    final accent = Color(ZoneFloorStyle.byId(dungeonId).accentArgb);
    final map = world.map;
    if (c.containsTile(map.exitPoint.$1, map.exitPoint.$2) &&
        c.beatKind != FloorBeatKind.setpiece) {
      return const Color(0x0EFFB060);
    }
    return switch (c.beatKind) {
      FloorBeatKind.hub => const Color(0x0AFFE0A0),
      FloorBeatKind.choke => const Color(0x1A000818),
      FloorBeatKind.elite => const Color(0x14A01818),
      FloorBeatKind.treasure => const Color(0x18E0B030),
      FloorBeatKind.shrine => const Color(0x1C4888F0),
      FloorBeatKind.wonder => const Color(0x18B070F0),
      FloorBeatKind.setpiece => accent.withValues(alpha: 0.10),
      FloorBeatKind.boss => const Color(0x10B02010),
      _ => null,
    };
  }

  /// Floor, walls, tints and decals for cells [x0,x1) × [y0,y1).
  void paintStaticTerrain(
    Canvas canvas, {
    required double tile,
    required double originX,
    required double originY,
    required int x0,
    required int x1,
    required int y0,
    required int y1,
  }) {
    final map = world.map;
    final floorBlend = DungeonEnvironment.floorBlend(dungeonId);
    final corridorShade = DungeonEnvironment.corridorShade(dungeonId);
    final themeTint = map.floorTheme == null
        ? null
        : Color(map.floorTheme!.tintArgb);
    final bossPlate = roomType == RoomType.boss && floorVariants.length > 1;

    Chamber? chamberAt(int x, int y) {
      for (final c in map.chambers) {
        if (c.containsTile(x, y)) return c;
      }
      return null;
    }

    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final kind = map.at(x, y);
        final dst = Rect.fromLTWH(
          originX + x * tile,
          originY + y * tile,
          tile + 0.5,
          tile + 0.5,
        );
        if (kind == TileKind.wall) {
          if (wallVariants.isEmpty ||
              !DungeonEnvironment.wallTouchesCarved(map, x, y)) {
            continue;
          }
          final img = wallVariants[_TileRoomPainter._hashPick(
            x,
            y,
            layoutSeed + 17,
            wallVariants.length,
          )];
          _drawWallCaps(canvas, x, y, dst, tile, img);
          if (DungeonEnvironment.isCarved(map.at(x, y + 1))) {
            _drawWallFace(canvas, dst, tile, img);
          }
          continue;
        }

        final floorImg = bossPlate
            ? floorVariants[1]
            : floorVariants[_TileRoomPainter._hashPick(
                x,
                y,
                layoutSeed,
                floorVariants.length,
              )];
        _drawImage(canvas, floorImg, dst);
        _TileRoomPainter._fillPaint.color = floorBlend;
        canvas.drawRect(dst, _TileRoomPainter._fillPaint);
        final noise = DungeonEnvironment.floorNoise(x, y, layoutSeed);
        if (noise.a > 0) {
          _TileRoomPainter._fillPaint.color = noise;
          canvas.drawRect(dst, _TileRoomPainter._fillPaint);
        }
        if (themeTint != null && themeTint.a > 0) {
          _TileRoomPainter._fillPaint.color = themeTint;
          canvas.drawRect(dst, _TileRoomPainter._fillPaint);
        }
        final chamber = chamberAt(x, y);
        if (chamber == null) {
          if (kind != TileKind.spawn && kind != TileKind.exit) {
            _TileRoomPainter._fillPaint.color = corridorShade;
            canvas.drawRect(dst, _TileRoomPainter._fillPaint);
          }
        } else {
          final tint = _beatTint(chamber);
          if (tint != null) {
            _TileRoomPainter._fillPaint.color = tint;
            canvas.drawRect(dst, _TileRoomPainter._fillPaint);
          }
        }
        // Contact shadow under a wall face so rooms read as sunk into rock.
        if (map.at(x, y - 1) == TileKind.wall) {
          _TileRoomPainter._fillPaint.color = _faceFoot;
          canvas.drawRect(
            Rect.fromLTWH(dst.left, dst.top, dst.width, tile * 0.26),
            _TileRoomPainter._fillPaint,
          );
        }
        if (kind == TileKind.spawn) {
          _TileRoomPainter._fillPaint.color = const Color(0x14C88840);
          canvas.drawRect(dst, _TileRoomPainter._fillPaint);
        }
      }
    }

    final accent = DungeonEnvironment.projectileTint(dungeonId);
    for (final d in map.decals) {
      if (d.x + d.w < x0 || d.x > x1 || d.y + d.h < y0 || d.y > y1) continue;
      final r = Rect.fromLTWH(
        originX + d.x * tile,
        originY + d.y * tile,
        d.w * tile,
        d.h * tile,
      );
      _paintDecal(canvas, d, r, tile, accent);
    }
  }

  /// South-facing wall front: a lit lip over a shaded face (depth cue).
  void _drawWallFace(Canvas canvas, Rect dst, double tile, ui.Image wall) {
    final face = Rect.fromLTWH(
      dst.left,
      dst.top + tile * 0.30,
      dst.width,
      dst.height - tile * 0.30,
    );
    _drawImage(canvas, wall, face);
    _TileRoomPainter._fillPaint.color = _faceShade;
    canvas.drawRect(face, _TileRoomPainter._fillPaint);
    _TileRoomPainter._fillPaint.color = _faceTop;
    canvas.drawRect(
      Rect.fromLTWH(face.left, face.top, face.width, math.max(1, tile * 0.08)),
      _TileRoomPainter._fillPaint,
    );
    _TileRoomPainter._fillPaint.color = const Color(0x40000000);
    canvas.drawRect(
      Rect.fromLTWH(face.left, face.bottom - tile * 0.18, face.width, tile * 0.18),
      _TileRoomPainter._fillPaint,
    );
  }

  void _paintDecal(
    Canvas canvas,
    FloorDecal d,
    Rect r,
    double tile,
    Color accent,
  ) {
    final u = tile / 16;
    final h = (d.x * 73856093 ^ d.y * 19349663 ^ layoutSeed) & 0x7FFFFFFF;
    final paint = Paint()..isAntiAlias = false;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false
      ..strokeWidth = math.max(1, u);
    Offset at(double px, double py) => Offset(r.left + px * u, r.top + py * u);
    switch (d.kind) {
      case FloorDecalKind.cracks:
        stroke.color = const Color(0x70000000);
        final o = (h % 5).toDouble();
        canvas.drawPath(
          Path()
            ..moveTo(at(2 + o, 1).dx, at(2 + o, 1).dy)
            ..lineTo(at(6 + o, 6).dx, at(6 + o, 6).dy)
            ..lineTo(at(5 + o, 10).dx, at(5 + o, 10).dy)
            ..lineTo(at(9 + o, 15).dx, at(9 + o, 15).dy),
          stroke,
        );
        canvas.drawLine(at(6 + o, 6), at(11, 7), stroke);
      case FloorDecalKind.moss:
        paint.color = const Color(0x7048A030);
        for (var i = 0; i < 4; i++) {
          final px = ((h >> (i * 3)) % 12) + 2.0;
          final py = ((h >> (i * 3 + 7)) % 12) + 2.0;
          canvas.drawRect(Rect.fromLTWH(at(px, py).dx, at(px, py).dy, 3 * u, 2 * u), paint);
        }
        paint.color = const Color(0x5070C048);
        canvas.drawRect(Rect.fromLTWH(at(7, 7).dx, at(7, 7).dy, 2 * u, 2 * u), paint);
      case FloorDecalKind.puddle:
        paint.color = const Color(0x5A1C4868);
        canvas.drawOval(r.deflate(2.5 * u), paint);
        paint.color = const Color(0x40A8D8F0);
        canvas.drawRect(Rect.fromLTWH(at(5, 6).dx, at(5, 6).dy, 4 * u, u), paint);
      case FloorDecalKind.runeCircle:
        stroke.color = accent.withValues(alpha: 0.75);
        final c = r.center;
        final rad = r.shortestSide * 0.44;
        paint.color = accent.withValues(alpha: 0.14);
        canvas.drawCircle(c, rad, paint);
        canvas.drawCircle(c, rad, stroke);
        canvas.drawCircle(c, rad * 0.62, stroke);
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * rad * 0.62,
            c + Offset(math.cos(a), math.sin(a)) * rad,
            stroke,
          );
        }
      case FloorDecalKind.grate:
        paint.color = const Color(0x70000000);
        canvas.drawRect(r.deflate(2 * u), paint);
        stroke.color = const Color(0x60B0A890);
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(at(4 + i * 3.0, 3), at(4 + i * 3.0, 13), stroke);
        }
      case FloorDecalKind.lavaCrack:
        stroke
          ..color = const Color(0xB0FF6818)
          ..strokeWidth = 2 * u;
        final o = (h % 4).toDouble();
        canvas.drawPath(
          Path()
            ..moveTo(at(1, 4 + o).dx, at(1, 4 + o).dy)
            ..lineTo(at(6, 7 + o).dx, at(6, 7 + o).dy)
            ..lineTo(at(10, 5 + o).dx, at(10, 5 + o).dy)
            ..lineTo(at(15, 9 + o).dx, at(15, 9 + o).dy),
          stroke,
        );
        stroke
          ..color = const Color(0xE0FFD070)
          ..strokeWidth = math.max(1, u);
        canvas.drawLine(at(6, 7 + o), at(10, 5 + o), stroke);
      case FloorDecalKind.iceSheen:
        paint.color = const Color(0x16C8F0FF);
        canvas.drawRect(r, paint);
        stroke.color = const Color(0x50E8FAFF);
        canvas.drawLine(at(2, 12), at(8, 4), stroke);
        canvas.drawLine(at(8, 14), at(13, 8), stroke);
      case FloorDecalKind.bridge:
        paint.color = const Color(0xB0604024);
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(Rect.fromLTWH(r.left + u, r.top + (1 + i * 5) * u, r.width - 2 * u, 4 * u), paint);
        }
        paint.color = const Color(0x50000000);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, u, r.height), paint);
        canvas.drawRect(Rect.fromLTWH(r.right - u, r.top, u, r.height), paint);
      case FloorDecalKind.dais:
        paint.color = const Color(0x30FFFFFF);
        canvas.drawRect(r, paint);
        paint.color = const Color(0x40FFFFFF);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 2 * u), paint);
        paint.color = const Color(0x80000000);
        canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 3 * u, r.width, 3 * u), paint);
        stroke.color = accent.withValues(alpha: 0.5);
        canvas.drawRect(r.deflate(u), stroke);
      case FloorDecalKind.roots:
        stroke
          ..color = const Color(0xA05A3A1C)
          ..strokeWidth = 2 * u;
        canvas.drawPath(
          Path()
            ..moveTo(at(0, 5).dx, at(0, 5).dy)
            ..quadraticBezierTo(at(7, 1).dx, at(7, 1).dy, at(9, 8).dx, at(9, 8).dy)
            ..quadraticBezierTo(at(11, 14).dx, at(11, 14).dy, at(16, 11).dx, at(16, 11).dy),
          stroke,
        );
      case FloorDecalKind.cobweb:
        stroke.color = const Color(0x60E8E0F0);
        final corner = at(h.isEven ? 0 : 16, 0);
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(corner, at(3.0 + i * 4, 14 - i * 2.0), stroke);
        }
        canvas.drawLine(at(3, 5), at(10, 3), stroke);
      case FloorDecalKind.sandDrift:
        stroke.color = const Color(0x40F8E0A8);
        canvas.drawArc(Rect.fromLTWH(at(1, 4).dx, at(1, 4).dy, 12 * u, 6 * u), math.pi, math.pi, false, stroke);
        canvas.drawArc(Rect.fromLTWH(at(4, 9).dx, at(4, 9).dy, 11 * u, 5 * u), math.pi, math.pi, false, stroke);
      case FloorDecalKind.gearInlay:
        stroke.color = const Color(0x90C89830);
        final c = r.center;
        canvas.drawCircle(c, 5 * u, stroke);
        canvas.drawCircle(c, 2 * u, stroke);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * 5 * u,
            c + Offset(math.cos(a), math.sin(a)) * 7 * u,
            stroke,
          );
        }
      case FloorDecalKind.ash:
        paint.color = const Color(0x40706868);
        canvas.drawOval(Rect.fromLTWH(at(2, 5).dx, at(2, 5).dy, 11 * u, 6 * u), paint);
        paint.color = const Color(0x30A09890);
        canvas.drawRect(Rect.fromLTWH(at(6, 7).dx, at(6, 7).dy, 2 * u, u), paint);
      case FloorDecalKind.carpet:
        paint.color = const Color(0xB0781820);
        final inner = Rect.fromLTWH(r.left + 2 * u, r.top, r.width - 4 * u, r.height);
        canvas.drawRect(inner, paint);
        paint.color = const Color(0xD0D8B048);
        canvas.drawRect(Rect.fromLTWH(inner.left, r.top, u, r.height), paint);
        canvas.drawRect(Rect.fromLTWH(inner.right - u, r.top, u, r.height), paint);
      case FloorDecalKind.scorch:
        paint.color = const Color(0x50000000);
        canvas.drawOval(r.deflate(2 * u), paint);
        paint.color = const Color(0x30000000);
        canvas.drawOval(r.deflate(0.5 * u), paint);
      case FloorDecalKind.boneDust:
        paint.color = const Color(0x90E0D8C8);
        for (var i = 0; i < 3; i++) {
          final px = ((h >> (i * 4)) % 11) + 2.0;
          final py = ((h >> (i * 4 + 9)) % 11) + 2.0;
          canvas.drawRect(Rect.fromLTWH(at(px, py).dx, at(px, py).dy, 3 * u, u), paint);
        }
      case FloorDecalKind.coins:
        for (var i = 0; i < 4; i++) {
          final px = ((h >> (i * 3)) % 11) + 2.0;
          final py = ((h >> (i * 3 + 8)) % 11) + 2.0;
          paint.color = const Color(0xFFD8A830);
          canvas.drawRect(Rect.fromLTWH(at(px, py).dx, at(px, py).dy, 3 * u, 2 * u), paint);
          paint.color = const Color(0xFFFFE890);
          canvas.drawRect(Rect.fromLTWH(at(px, py).dx, at(px, py).dy, u, u), paint);
        }
      case FloorDecalKind.starlight:
        paint.shader = ui.Gradient.radial(
          r.center,
          r.shortestSide * 0.6,
          const [Color(0x60D8E8FF), Color(0x00D8E8FF)],
        );
        canvas.drawRect(r.inflate(tile), paint);
    }
  }

  /// Warm torch pools + the hero's accent light (dynamic, view-culled).
  void paintFloorLights(Canvas canvas, double tile, Offset Function(double, double) center) {
    if (vfxQuality == VfxQuality.minimal) return;
    final map = world.map;
    final accent = Color(ZoneFloorStyle.byId(dungeonId).accentArgb);
    final flicker = reducedVfx ? 1.0 : 0.92 + 0.08 * math.sin(visualFrame * 0.09);
    final finale = _FloorLookState.exitOpenedAt;
    final sinceExit = finale == null ? 9999 : visualFrame - finale;
    final flare = sinceExit < 120 ? 1.0 + 0.8 * (1 - sinceExit / 120) : 1.0;
    final paint = Paint()..blendMode = BlendMode.plus;
    for (final prop in map.props) {
      final torch = DungeonEnvironment.isTorchProp(prop.kind);
      if (!torch && !prop.hero) continue;
      if (!_inView(prop.x + 0.5, prop.y + 0.5, pad: 3)) continue;
      final c = center(prop.x + 0.5, prop.y + 0.5);
      var boost = 1.0;
      if (torch &&
          (prop.x - map.exitPoint.$1).abs() <= 1 &&
          (prop.y - map.exitPoint.$2).abs() <= 1) {
        boost = flare;
      }
      final radius = tile * (torch ? 2.2 : 2.8) * flicker * boost;
      final color = torch ? const Color(0x38F0A040) : accent.withValues(alpha: 0.26);
      paint.shader = ui.Gradient.radial(
        c,
        radius,
        [color, color.withValues(alpha: 0)],
      );
      canvas.drawCircle(c, radius, paint);
    }
    // Wonder starlight: a slow shaft from the broken ceiling.
    for (final d in map.decals) {
      if (d.kind != FloorDecalKind.starlight) continue;
      final c = center(d.x + d.w / 2, d.y + d.h / 2);
      if (!_inView(d.x + 0.5, d.y + 0.5, pad: 4)) continue;
      final breathe = reducedVfx ? 1.0 : 0.85 + 0.15 * math.sin(visualFrame * 0.015);
      paint.shader = ui.Gradient.linear(
        c.translate(0, -tile * 4),
        c,
        [const Color(0x00D8E8FF), const Color(0x38D8E8FF)],
      );
      canvas.drawRect(
        Rect.fromCenter(center: c.translate(0, -tile * 2), width: tile * 2.4 * breathe, height: tile * 4.5),
        paint,
      );
    }
  }

  /// Slow shimmer on water / lava props and wet decals (soft fascination).
  void paintShimmer(Canvas canvas, double tile, Offset Function(double, double) center) {
    if (reducedVfx) return;
    final map = world.map;
    final paint = Paint();
    for (final prop in map.props) {
      final water = prop.kind == MapPropKind.water;
      final lava = prop.kind == MapPropKind.lava;
      if (!water && !lava) continue;
      if (!_inView(prop.x + 0.5, prop.y + 0.5)) continue;
      final phase = visualFrame * 0.022 + prop.x * 0.7 + prop.y * 0.4;
      final a = 0.10 + 0.08 * math.sin(phase);
      paint.color = (lava ? const Color(0xFFFFB050) : const Color(0xFFD0F4FF)).withValues(alpha: a);
      final c = center(prop.x + 0.5, prop.y + 0.62);
      canvas.drawOval(Rect.fromCenter(center: c, width: tile * 0.62, height: tile * 0.22), paint);
    }
    for (final d in map.decals) {
      final wet = d.kind == FloorDecalKind.puddle;
      final hot = d.kind == FloorDecalKind.lavaCrack;
      if (!wet && !hot) continue;
      if (!_inView(d.x + 0.5, d.y + 0.5)) continue;
      final phase = visualFrame * 0.02 + d.x * 0.9 + d.y * 0.5;
      final a = (hot ? 0.10 : 0.07) * (0.5 + 0.5 * math.sin(phase));
      paint.color = (hot ? const Color(0xFFFF9030) : const Color(0xFFE0F8FF)).withValues(alpha: a);
      canvas.drawRect(
        Rect.fromLTWH(center(d.x.toDouble(), d.y.toDouble()).dx, center(d.x.toDouble(), d.y.toDouble()).dy, tile, tile),
        paint,
      );
    }
  }

  /// Rooms the party has not reached stay dim (a glimpse, not a black box)
  /// and fade up when a hero walks in.
  void paintChamberReveal(Canvas canvas, double tile, double originX, double originY) {
    final map = world.map;
    if (map.chambers.length < 2) return;
    _FloorLookState.sync(map);
    final revealed = _FloorLookState.revealedAt;
    revealed.putIfAbsent(0, () => visualFrame - 999);
    for (final h in world.heroes) {
      if (h.hp <= 0) continue;
      for (final c in map.chambers) {
        if (c.containsWorld(h.x, h.y)) {
          revealed.putIfAbsent(c.index, () => visualFrame);
        }
      }
    }
    for (final c in clearedChambers) {
      revealed.putIfAbsent(c, () => visualFrame - 999);
    }
    if (world.awaitingExit) {
      _FloorLookState.exitOpenedAt ??= visualFrame;
    }
    const fadeFrames = 24; // ~0.4 s at 60 Hz
    final paint = Paint()..isAntiAlias = false;
    for (final c in map.chambers) {
      final at = revealed[c.index];
      double dim;
      if (at == null) {
        dim = 0.55;
      } else {
        final t = ((visualFrame - at) / fadeFrames).clamp(0.0, 1.0);
        dim = 0.55 * (1 - t);
      }
      if (reducedVfx && at != null) dim = 0;
      if (dim <= 0.01) continue;
      if (!_inView(c.cx.toDouble(), c.cy.toDouble(), pad: math.max(c.w, c.h).toDouble())) {
        continue;
      }
      paint.color = Color.fromRGBO(4, 3, 8, dim);
      canvas.save();
      canvas.translate(originX, originY);
      canvas.scale(tile);
      canvas.drawPath(_FloorLookState.carvedPath(map, c), paint);
      canvas.restore();
    }
  }

  /// Stairs unlock: a soft ring rolls out once (peak-end — the finish is a scene).
  void paintExitFinale(Canvas canvas, double tile, Offset Function(double, double) center) {
    final opened = _FloorLookState.exitOpenedAt;
    if (opened == null || reducedVfx) return;
    final t = (visualFrame - opened) / 90.0;
    if (t < 0 || t > 1) return;
    final map = world.map;
    final c = center(map.exitPoint.$1 + 0.5, map.exitPoint.$2 + 0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, tile * 0.12)
      ..color = const Color(0xFFFFE8A0).withValues(alpha: 0.55 * (1 - t));
    canvas.drawCircle(c, tile * (0.6 + t * 4.5), paint);
    final fill = Paint()
      ..shader = ui.Gradient.radial(
        c,
        tile * 2.4,
        [
          const Color(0xFFFFE0A0).withValues(alpha: 0.30 * (1 - t)),
          const Color(0x00FFE0A0),
        ],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c, tile * 2.4, fill);
  }
}
