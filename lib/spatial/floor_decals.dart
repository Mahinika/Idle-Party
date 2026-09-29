import 'dart:math';

import 'floor_blueprint.dart';
import 'floor_theme.dart';
import 'tile_map.dart';

/// Walkable floor detail + one focal anchor per purposeful room
/// (docs/FLOOR_BLUEPRINT.md). Detail is clumped like moss or cracks in a real
/// cave, never sprinkled evenly, and never sits on a gate or the stairs.
class FloorDecalPlan {
  const FloorDecalPlan({required this.decals, required this.anchors});

  final List<FloorDecal> decals;

  /// Chamber index → cell where that room's hero prop should stand
  /// (dais top, rune centre, starlight centre).
  final Map<int, (int, int)> anchors;

  static FloorDecalPlan build({
    required int cols,
    required int rows,
    required List<TileKind> tiles,
    required (int, int) exitPoint,
    required List<Chamber> chambers,
    required FloorBlueprint blueprint,
    required ZoneFloorStyle style,
    required Random rng,
  }) {
    final decals = <FloorDecal>[];
    final anchors = <int, (int, int)>{};
    final taken = <int>{};

    bool paintable(int x, int y) {
      if (x < 1 || y < 1 || x >= cols - 1 || y >= rows - 1) return false;
      if (x == exitPoint.$1 && y == exitPoint.$2) return false;
      final t = tiles[y * cols + x];
      return t == TileKind.floor || t == TileKind.spawn;
    }

    bool rectFree(int x, int y, int w, int h) {
      for (var yy = y; yy < y + h; yy++) {
        for (var xx = x; xx < x + w; xx++) {
          if (!paintable(xx, yy) || taken.contains(yy * cols + xx)) {
            return false;
          }
        }
      }
      return true;
    }

    void addRect(FloorDecalKind kind, int x, int y, int w, int h) {
      decals.add(FloorDecal(x: x, y: y, kind: kind, w: w, h: h));
      for (var yy = y; yy < y + h; yy++) {
        for (var xx = x; xx < x + w; xx++) {
          taken.add(yy * cols + xx);
        }
      }
    }

    void addCell(FloorDecalKind kind, int x, int y) {
      if (!paintable(x, y) || !taken.add(y * cols + x)) return;
      decals.add(FloorDecal(x: x, y: y, kind: kind));
    }

    /// Random-walk clump: dense core, ragged edge (mid-range fractal look).
    void clump(FloorDecalKind kind, int sx, int sy, int size) {
      var x = sx;
      var y = sy;
      for (var i = 0; i < size * 2 && size > 0; i++) {
        if (paintable(x, y) && !taken.contains(y * cols + x)) {
          addCell(kind, x, y);
          size--;
        }
        switch (rng.nextInt(4)) {
          case 0:
            x++;
          case 1:
            x--;
          case 2:
            y++;
          default:
            y--;
        }
        if (rng.nextDouble() < 0.25) {
          x = sx + rng.nextInt(3) - 1;
          y = sy + rng.nextInt(3) - 1;
        }
      }
    }

    /// Centred multi-cell decal; nudges a cell or two if the centre is busy.
    (int, int)? placeCentred(
      FloorDecalKind kind,
      int cx,
      int cy,
      int w,
      int h,
    ) {
      for (final o in const <(int, int)>[(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final x = cx - w ~/ 2 + o.$1;
        final y = cy - h ~/ 2 + o.$2;
        if (rectFree(x, y, w, h)) {
          addRect(kind, x, y, w, h);
          return (x + w ~/ 2, y + h ~/ 2);
        }
      }
      return null;
    }

    /// Raised dais against the back (north) wall with a runner to the door.
    (int, int)? placeDais(Chamber c, {int w = 3, bool carpet = false}) {
      for (var y = c.y + 1; y < c.cy; y++) {
        final x = c.cx - w ~/ 2;
        if (!rectFree(x, y, w, 2)) continue;
        addRect(FloorDecalKind.dais, x, y, w, 2);
        if (carpet) {
          for (var yy = y + 2; yy < c.y + c.h - 1; yy++) {
            if (!paintable(c.cx, yy)) break;
            addCell(FloorDecalKind.carpet, c.cx, yy);
          }
        }
        return (c.cx, y);
      }
      return null;
    }

    final theme = blueprint.theme;
    for (final c in chambers) {
      final beat = c.beatKind;
      switch (beat) {
        case FloorBeatKind.shrine:
          final a = placeCentred(FloorDecalKind.runeCircle, c.cx, c.cy, 3, 3);
          if (a != null) anchors[c.index] = a;
        case FloorBeatKind.wonder:
          final kind = switch (blueprint.wonder) {
            WonderKind.starfall => FloorDecalKind.starlight,
            WonderKind.soulWell => FloorDecalKind.runeCircle,
            WonderKind.hoard => FloorDecalKind.coins,
            WonderKind.giantSkeleton || null => FloorDecalKind.boneDust,
          };
          if (kind == FloorDecalKind.coins || kind == FloorDecalKind.boneDust) {
            clump(kind, c.cx, c.cy, 16);
            anchors[c.index] = (c.cx, c.cy);
          } else {
            final a = placeCentred(kind, c.cx, c.cy, 3, 3);
            if (a != null) anchors[c.index] = a;
          }
        case FloorBeatKind.setpiece:
          final carpet = style.setpieceDecal == FloorDecalKind.carpet;
          final a = placeDais(c, carpet: carpet);
          if (a != null) anchors[c.index] = a;
          if (!carpet) {
            clump(style.setpieceDecal, c.cx - 2, c.cy + 1, 10);
            clump(style.setpieceDecal, c.cx + 3, c.cy - 1, 8);
          }
        case FloorBeatKind.boss:
          final a = placeDais(c, w: 5, carpet: style.setpieceDecal == FloorDecalKind.carpet);
          if (a != null) anchors[c.index] = a;
        default:
          break;
      }

      // Theme clumps: ~7% of the room, a few ragged patches, not a sprinkle.
      var floorCells = 0;
      for (var y = c.y; y < c.y + c.h; y++) {
        for (var x = c.x; x < c.x + c.w; x++) {
          if (paintable(x, y)) floorCells++;
        }
      }
      final budget = (floorCells * 0.07).round();
      var spent = 0;
      for (var tries = 0; spent < budget && tries < 12; tries++) {
        final size = 3 + rng.nextInt(5);
        final sx = c.x + 1 + rng.nextInt(max(1, c.w - 2));
        final sy = c.y + 1 + rng.nextInt(max(1, c.h - 2));
        if (!paintable(sx, sy)) continue;
        final kind = theme.decals[rng.nextInt(theme.decals.length)];
        clump(kind, sx, sy, size);
        spent += size;
      }
    }

    // Corridors: sparse runs so halls between rooms are not bare.
    final corridorKind = switch (theme) {
      FloorTheme.stormlit || FloorTheme.frozen => FloorDecalKind.bridge,
      FloorTheme.gilded || FloorTheme.clockwork => FloorDecalKind.grate,
      _ => theme.decals.first,
    };
    bool inAnyChamber(int x, int y) => chambers.any((c) => c.containsTile(x, y));
    for (var y = 1; y < rows - 1; y++) {
      for (var x = 1; x < cols - 1; x++) {
        if (tiles[y * cols + x] != TileKind.floor) continue;
        if (inAnyChamber(x, y)) continue;
        final h = (x * 73856093 ^ y * 19349663 ^ blueprint.theme.index) & 0xFF;
        if (h < 9) clump(corridorKind, x, y, 2 + rng.nextInt(2));
      }
    }

    return FloorDecalPlan(
      decals: List<FloorDecal>.unmodifiable(decals),
      anchors: Map<int, (int, int)>.unmodifiable(anchors),
    );
  }
}
