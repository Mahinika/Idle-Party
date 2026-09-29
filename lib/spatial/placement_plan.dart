import 'dart:math';

import '../models/dungeon_room.dart';
import 'floor_blueprint.dart';
import 'floor_theme.dart';
import 'prop_vignettes.dart';
import 'tile_map.dart';
import 'zone_layout_kit.dart';

/// Socketed placement for props + room chests (docs/FLOOR_BLUEPRINT.md).
///
/// Order: room chest → one hero per chamber (+ symmetric flank) → door and
/// stair torches → one vignette per room → sparse clumped clutter. The hero
/// is the only prop that is big and lit, so it stands out against a calm room.
class PlacementPlan {
  const PlacementPlan({
    required this.props,
    required this.lootChestPoints,
    required this.violations,
  });

  final List<MapProp> props;
  final List<(int x, int y)> lootChestPoints;
  final List<String> violations;

  bool get isValid => violations.isEmpty;

  /// Build props + chest sockets from carved geometry.
  static PlacementPlan build({
    required int cols,
    required int rows,
    required List<TileKind> tiles,
    required List<(int x, int y)> spawnPoints,
    required (int x, int y) exitPoint,
    required List<(int x, int y)> enemySpawns,
    required List<Chamber> chambers,
    required FloorBlueprint blueprint,
    required ZoneLayoutKit kit,
    required Random rng,
    List<GateInfo> gates = const <GateInfo>[],
    Map<int, (int, int)> anchors = const <int, (int, int)>{},
  }) {
    final violations = <String>[];
    final blocked = <int>{};
    int key(int x, int y) => y * cols + x;
    for (final p in spawnPoints) {
      blocked.add(key(p.$1, p.$2));
    }
    blocked.add(key(exitPoint.$1, exitPoint.$2));
    for (final p in enemySpawns) {
      blocked.add(key(p.$1, p.$2));
    }
    // Keep doorways clear so a prop never reads as a blocker.
    for (final g in gates) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          blocked.add(key(g.x + dx, g.y + dy));
        }
      }
    }

    bool inMap(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;

    bool isFloor(int x, int y) {
      if (!inMap(x, y)) return false;
      final t = tiles[key(x, y)];
      return t == TileKind.floor || t == TileKind.spawn || t == TileKind.exit;
    }

    bool isWall(int x, int y) => !inMap(x, y) || tiles[key(x, y)] == TileKind.wall;

    bool touchesWall(int x, int y) =>
        isWall(x + 1, y) || isWall(x - 1, y) || isWall(x, y + 1) || isWall(x, y - 1);

    final used = <int>{};
    final props = <MapProp>[];
    final chests = <(int, int)>[];

    bool free(int x, int y) =>
        isFloor(x, y) &&
        !blocked.contains(key(x, y)) &&
        !used.contains(key(x, y)) &&
        tiles[key(x, y)] != TileKind.exit;

    bool place(int x, int y, MapPropKind kind, {bool hero = false}) {
      if (!free(x, y)) return false;
      used.add(key(x, y));
      props.add(MapProp(x: x, y: y, kind: kind, hero: hero));
      return true;
    }

    /// Nearest free cell to (x, y) inside [c] (spiral).
    (int, int)? nearestFree(Chamber c, int x, int y, {bool edge = false}) {
      for (var r = 0; r <= max(c.w, c.h); r++) {
        for (var dy = -r; dy <= r; dy++) {
          for (var dx = -r; dx <= r; dx++) {
            if (dx.abs() != r && dy.abs() != r) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (!c.containsTile(nx, ny) || !free(nx, ny)) continue;
            if (edge && !touchesWall(nx, ny)) continue;
            return (nx, ny);
          }
        }
      }
      return null;
    }

    final torch = _torchFor(kit);

    // —— Room chest (loot socket) ——
    final wantChest =
        blueprint.wantsRoomChest ||
        (blueprint.legacyType == RoomType.elite && kit.eliteRoomChest) ||
        (blueprint.legacyType == RoomType.normal &&
            rng.nextDouble() < kit.normalRoomChestChance);
    final chestChambers = <int>{};
    if (wantChest) {
      Chamber? target;
      final preferredIdx = blueprint.preferredChestChamberIndex;
      if (preferredIdx != null &&
          preferredIdx >= 0 &&
          preferredIdx < chambers.length) {
        target = chambers[preferredIdx];
      }
      target ??= chambers.cast<Chamber?>().firstWhere(
        (c) =>
            c!.beatKind == FloorBeatKind.treasure ||
            c.beatKind == FloorBeatKind.elite,
        orElse: () => chambers.isEmpty ? null : chambers.last,
      );
      if (target != null && target.beatKind == FloorBeatKind.choke) {
        target = chambers.lastWhere(
          (c) => c.beatKind != FloorBeatKind.choke,
          orElse: () => target!,
        );
      }
      (int, int)? cell;
      if (target != null) {
        // Back wall, far from the party spawn: the room's goal.
        final back = (target.cx, target.y + 1);
        cell =
            nearestFree(target, back.$1, back.$2, edge: true) ??
            nearestFree(target, target.cx, target.cy);
      }
      if (cell == null) {
        for (var y = 0; y < rows && cell == null; y++) {
          for (var x = 0; x < cols && cell == null; x++) {
            if (free(x, y) && touchesWall(x, y)) cell = (x, y);
          }
        }
      }
      if (cell != null) {
        final isTreasureRoom = target?.beatKind == FloorBeatKind.treasure;
        place(cell.$1, cell.$2, MapPropKind.chest, hero: isTreasureRoom);
        chests.add(cell);
        if (target != null) chestChambers.add(target.index);
        if (isTreasureRoom) {
          place(cell.$1 - 1, cell.$2, torch);
          place(cell.$1 + 1, cell.$2, torch);
          place(cell.$1 - 2, cell.$2, MapPropKind.pot);
          place(cell.$1 + 2, cell.$2 + 1, MapPropKind.pot);
        }
      } else {
        violations.add('no_chest_socket');
      }
    }

    // —— One hero per chamber (+ symmetric flank) ——
    for (final c in chambers) {
      final beat = c.beatKind;
      if (beat == FloorBeatKind.treasure && chestChambers.contains(c.index)) {
        continue;
      }
      final heroKind = beat == FloorBeatKind.treasure
          ? MapPropKind.sacks
          : PropVignettes.heroFor(beat, kit, blueprint.wonder, rng);
      final centred =
          beat == FloorBeatKind.shrine || beat == FloorBeatKind.wonder;
      final anchor = anchors[c.index] ??
          (centred ? (c.cx, c.cy) : (c.cx, c.y + 1));
      final cell = nearestFree(c, anchor.$1, anchor.$2, edge: !centred && anchors[c.index] == null) ??
          nearestFree(c, anchor.$1, anchor.$2);
      if (cell == null) continue;
      place(cell.$1, cell.$2, heroKind, hero: true);
      final flank = PropVignettes.flankFor(beat, torch);
      if (flank != null) {
        place(cell.$1 - 2, cell.$2, flank);
        place(cell.$1 + 2, cell.$2, flank);
      }
      if (beat == FloorBeatKind.wonder) {
        _wonderExtras(blueprint.wonder, cell, place, rng);
      }
      if (beat == FloorBeatKind.boss && kit.landmarks.isNotEmpty) {
        // Arena ring of the zone's own landmark (pillars, anvils, fountains).
        final ring = kit.landmarks.first;
        final dx = c.w ~/ 3;
        final dy = c.h ~/ 4;
        for (final o in [(-dx, -dy), (dx, -dy), (-dx, dy), (dx, dy)]) {
          final spot = nearestFree(c, c.cx + o.$1, c.cy + o.$2);
          if (spot != null) place(spot.$1, spot.$2, ring);
        }
      }
    }

    // —— Door sconces: both sides of each gate run (wall cells) ——
    final wallTorches = <int>{};
    void sconce(int x, int y) {
      if (!inMap(x, y) || !isWall(x, y)) return;
      if (!wallTorches.add(key(x, y))) return;
      props.add(MapProp(x: x, y: y, kind: torch));
    }

    for (final run in _gateRuns(gates)) {
      final horizontal = run.every((g) => g.y == run.first.y);
      if (horizontal) {
        final xs = run.map((g) => g.x).toList()..sort();
        sconce(xs.first - 1, run.first.y);
        sconce(xs.last + 1, run.first.y);
      } else {
        final ys = run.map((g) => g.y).toList()..sort();
        sconce(run.first.x, ys.first - 1);
        sconce(run.first.x, ys.last + 1);
      }
    }

    // —— Stairs framed by torches (peak-end: the finish is a scene) ——
    place(exitPoint.$1 - 1, exitPoint.$2 - 1, torch);
    place(exitPoint.$1 + 1, exitPoint.$2 - 1, torch);

    // —— One vignette per room, against a wall ——
    final style = kit.style;
    for (final c in chambers) {
      final beat = c.beatKind;
      if (beat == FloorBeatKind.shrine || beat == FloorBeatKind.wonder) continue;
      final kind = beat == FloorBeatKind.elite
          ? PropVignetteKind.crypt
          : style.vignettes[rng.nextInt(style.vignettes.length)];
      final pieces = PropVignettes.build(kind, rng);
      _placeVignette(c, pieces, free, touchesWall, place, rng);
    }

    // —— Sparse clumped clutter (calm rooms so the hero stands out) ——
    final clutterPool = kit.edgeClutter.isNotEmpty
        ? [
            for (final k in kit.edgeClutter)
              if (k != MapPropKind.chest) k,
          ]
        : const [MapPropKind.rubble];
    bool wet(MapPropKind k) =>
        k == MapPropKind.water || k == MapPropKind.lava || k == MapPropKind.fountain;
    final perChamberMin = max(2, kit.clutterPerChamberMin - 1);
    for (final c in chambers) {
      var count = props.where((p) => c.containsTile(p.x, p.y)).length;
      final edges = <(int, int)>[];
      for (var y = c.y; y < c.y + c.h; y++) {
        for (var x = c.x; x < c.x + c.w; x++) {
          if (free(x, y) && touchesWall(x, y)) edges.add((x, y));
        }
      }
      edges.shuffle(rng);
      var guard = 0;
      while (count < perChamberMin + 2 && edges.isNotEmpty && guard++ < 24) {
        final seed = edges.removeLast();
        final clump = 1 + rng.nextInt(3);
        final kind = clutterPool[rng.nextInt(clutterPool.length)];
        var cx = seed.$1;
        var cy = seed.$2;
        for (var i = 0; i < clump; i++) {
          var k = kind;
          if (wet(k) && !touchesWall(cx, cy)) k = MapPropKind.rubble;
          if (place(cx, cy, i == 0 ? k : clutterPool[rng.nextInt(clutterPool.length)])) {
            count++;
          }
          final step = rng.nextBool() ? (1, 0) : (0, 1);
          cx += step.$1;
          cy += step.$2;
          if (!free(cx, cy) || !touchesWall(cx, cy)) break;
        }
      }
    }

    // Floor-wide minimum so small maps never look bare.
    final spare = <(int, int)>[
      for (var y = 0; y < rows; y++)
        for (var x = 0; x < cols; x++)
          if (free(x, y) && touchesWall(x, y)) (x, y),
    ]..shuffle(rng);
    // Most clutter hugs walls so mid-room fight space stays clear.
    var edgeCount = props.where((p) => touchesWall(p.x, p.y)).length;
    while ((props.length < 18 || edgeCount * 2 <= props.length) &&
        spare.isNotEmpty) {
      final s = spare.removeLast();
      if (place(s.$1, s.$2, clutterPool[rng.nextInt(clutterPool.length)])) {
        edgeCount++;
      }
    }

    for (final c in chests) {
      if (c.$1 == exitPoint.$1 && c.$2 == exitPoint.$2) {
        violations.add('chest_on_exit');
      }
      for (final s in spawnPoints) {
        if (c.$1 == s.$1 && c.$2 == s.$2) violations.add('chest_on_spawn');
      }
      for (final e in enemySpawns) {
        if (c.$1 == e.$1 && c.$2 == e.$2) violations.add('chest_on_enemy');
      }
      if (!isFloor(c.$1, c.$2)) violations.add('chest_not_floor');
    }

    return PlacementPlan(
      props: List<MapProp>.unmodifiable(props),
      lootChestPoints: List<(int, int)>.unmodifiable(chests),
      violations: List<String>.unmodifiable(violations),
    );
  }

  static MapPropKind _torchFor(ZoneLayoutKit kit) {
    final pool = kit.edgeClutter;
    final alt = pool.where((k) => k == MapPropKind.torchAlt).length;
    final plain = pool.where((k) => k == MapPropKind.torch).length;
    return alt > plain ? MapPropKind.torchAlt : MapPropKind.torch;
  }

  static void _wonderExtras(
    WonderKind? wonder,
    (int, int) at,
    bool Function(int, int, MapPropKind, {bool hero}) place,
    Random rng,
  ) {
    final (x, y) = at;
    switch (wonder) {
      case WonderKind.giantSkeleton:
        // A spine of bones trailing from the skull.
        for (var i = 1; i <= 5; i++) {
          place(x + i, y + (i.isEven ? 1 : 0), MapPropKind.bones);
        }
      case WonderKind.hoard:
        for (final o in const [(-1, 1), (1, 1), (0, 2), (-2, -1), (2, -1)]) {
          place(x + o.$1, y + o.$2, rng.nextBool() ? MapPropKind.pot : MapPropKind.sacks);
        }
      case WonderKind.soulWell:
        place(x, y - 2, MapPropKind.statue);
        place(x, y + 2, MapPropKind.statue);
      case WonderKind.starfall || null:
        place(x, y + 2, MapPropKind.crystalCluster);
        place(x, y - 2, MapPropKind.crystalCluster);
    }
  }

  static void _placeVignette(
    Chamber c,
    List<VignettePiece> pieces,
    bool Function(int, int) free,
    bool Function(int, int) touchesWall,
    bool Function(int, int, MapPropKind, {bool hero}) place,
    Random rng,
  ) {
    for (var attempt = 0; attempt < 40; attempt++) {
      final ax = c.x + 1 + rng.nextInt(max(1, c.w - 2));
      final ay = c.y + 1 + rng.nextInt(max(1, c.h - 2));
      if (!free(ax, ay) || !touchesWall(ax, ay)) continue;
      // Rows run along the wall: flip down/up so the second row sits inside.
      final down = !touchesWall(ax, ay + 1) || free(ax, ay + 1);
      var fits = 0;
      for (final p in pieces) {
        final px = ax + p.dx;
        final py = ay + (down ? p.dy : -p.dy);
        if (c.containsTile(px, py) && free(px, py)) fits++;
      }
      if (fits < (pieces.length * 0.7).ceil()) continue;
      for (final p in pieces) {
        place(ax + p.dx, ay + (down ? p.dy : -p.dy), p.kind);
      }
      return;
    }
  }

  /// Straight lines of gate cells (one corridor seal each).
  static List<List<GateInfo>> _gateRuns(List<GateInfo> gates) {
    final byKey = {for (final g in gates) (g.x, g.y): g};
    final seen = <(int, int)>{};
    final runs = <List<GateInfo>>[];
    for (final g in gates) {
      if (seen.contains((g.x, g.y))) continue;
      final run = <GateInfo>[];
      final stack = [g];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (!seen.add((cur.x, cur.y))) continue;
        run.add(cur);
        for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final n = byKey[(cur.x + d.$1, cur.y + d.$2)];
          if (n != null && !seen.contains((n.x, n.y))) stack.add(n);
        }
      }
      runs.add(run);
    }
    return runs;
  }
}
