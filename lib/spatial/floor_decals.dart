import 'dart:math';

import 'floor_blueprint.dart';
import 'floor_theme.dart';
import 'prop_vignettes.dart';
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

    void addCell(FloorDecalKind kind, int x, int y, {bool accent = false}) {
      if (!paintable(x, y) || !taken.add(y * cols + x)) return;
      decals.add(FloorDecal(x: x, y: y, kind: kind, accent: accent));
    }

    /// Chebyshev gap of at least 3 cells from every decal already placed.
    bool farFromExisting(int x, int y) {
      for (final d in decals) {
        for (var yy = d.y; yy < d.y + d.h; yy++) {
          for (var xx = d.x; xx < d.x + d.w; xx++) {
            final dx = (xx - x).abs();
            final dy = (yy - y).abs();
            if (max(dx, dy) < 4) return false;
          }
        }
      }
      return true;
    }

    /// 2–4 connected cells. Skips the spot when it would touch another clump.
    void placeClump(FloorDecalKind kind, int sx, int sy, {bool accent = false}) {
      const shapes = <List<(int, int)>>[
        [(0, 0), (1, 0), (0, 1), (1, 1)],
        [(0, 0), (1, 0), (0, 1)],
        [(0, 0), (1, 0), (2, 0)],
        [(0, 0), (0, 1)],
      ];
      for (final shape in shapes) {
        final cells = <(int, int)>[
          for (final o in shape) (sx + o.$1, sy + o.$2),
        ];
        final ok = cells.every(
          (c) =>
              paintable(c.$1, c.$2) &&
              !taken.contains(c.$2 * cols + c.$1) &&
              farFromExisting(c.$1, c.$2),
        );
        if (!ok) continue;
        for (final c in cells) {
          addCell(kind, c.$1, c.$2, accent: accent);
        }
        return;
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
      for (final o in const <(int, int)>[
        (0, 0),
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ]) {
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
          var n = 0;
          for (var yy = y + 2; yy < c.y + c.h - 1 && n < 4; yy++) {
            if (!paintable(c.cx, yy)) break;
            addCell(FloorDecalKind.carpet, c.cx, yy);
            n++;
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
            placeClump(kind, c.cx, c.cy);
            placeClump(kind, c.cx + 6, c.cy + 2);
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
            placeClump(style.setpieceDecal, c.cx - 2, c.cy + 1);
            placeClump(style.setpieceDecal, c.cx + 5, c.cy - 2);
          }
        case FloorBeatKind.boss:
          final a = placeDais(
            c,
            w: 5,
            carpet: style.setpieceDecal == FloorDecalKind.carpet,
          );
          if (a != null) anchors[c.index] = a;
        case FloorBeatKind.treasure:
          // Brighter setpiece cluster on the chest cell. The rest of the
          // room stays the plain tile (no theme salt on top).
          for (final o in const <(int, int)>[
            (0, 0),
            (1, 0),
            (-1, 0),
            (0, 1),
            (0, -1),
            (2, 1),
            (-2, 1),
          ]) {
            final before = decals.length;
            placeClump(
              style.setpieceDecal,
              c.cx + o.$1,
              c.cy + o.$2,
              accent: true,
            );
            if (decals.length > before) break;
          }
        default:
          break;
      }

      if (beat == FloorBeatKind.treasure) continue;

      // Theme clumps: ~7% of the room, a few ragged patches, not a sprinkle.
      var floorCells = 0;
      for (var y = c.y; y < c.y + c.h; y++) {
        for (var x = c.x; x < c.x + c.w; x++) {
          if (paintable(x, y)) floorCells++;
        }
      }
      // Sandy's first decal is sandDrift. A slightly denser budget there
      // only. Other themes stay at the shared 7%.
      final sandy =
          theme.decals.isNotEmpty &&
          theme.decals.first == FloorDecalKind.sandDrift;
      final budget = (floorCells * (sandy ? 0.20 : 0.07)).round();
      var spent = 0;
      for (var tries = 0; spent < budget && tries < 24; tries++) {
        final sx = c.x + 1 + rng.nextInt(max(1, c.w - 2));
        final sy = c.y + 1 + rng.nextInt(max(1, c.h - 2));
        if (!paintable(sx, sy)) continue;
        final kind = theme.decals[rng.nextInt(theme.decals.length)];
        final before = decals.length;
        placeClump(kind, sx, sy);
        spent += decals.length - before;
      }
    }

    // Corridors: sparse runs so halls between rooms are not bare.
    final corridorKind = switch (theme) {
      FloorTheme.stormlit || FloorTheme.frozen => FloorDecalKind.bridge,
      FloorTheme.gilded || FloorTheme.clockwork => FloorDecalKind.grate,
      _ => theme.decals.first,
    };
    bool inAnyChamber(int x, int y) =>
        chambers.any((c) => c.containsTile(x, y));
    for (var y = 1; y < rows - 1; y++) {
      for (var x = 1; x < cols - 1; x++) {
        if (tiles[y * cols + x] != TileKind.floor) continue;
        if (inAnyChamber(x, y)) continue;
        final h = (x * 73856093 ^ y * 19349663 ^ blueprint.theme.index) & 0xFF;
        if (h < 9) placeClump(corridorKind, x, y);
      }
    }

    if (style.setpieceDecal == FloorDecalKind.sandDrift && chambers.isNotEmpty) {
      PropVignettes.armFirstRoomNearHalf();
      final room = chambers.first;
      anchors.putIfAbsent(room.index, () {
        int fit(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
        final y = fit(room.y + (room.h * 5) ~/ 8, room.y + 1, room.y + room.h - 2);
        final x = fit(room.cx + room.w ~/ 5, room.x + 1, room.x + room.w - 2);
        return (x, y);
      });
    }

    return FloorDecalPlan(
      decals: List<FloorDecal>.unmodifiable(decals),
      anchors: Map<int, (int, int)>.unmodifiable(anchors),
    );
  }
}
