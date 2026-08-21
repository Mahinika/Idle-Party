import 'dart:math';

import '../models/dungeon_room.dart';
import 'floor_blueprint.dart';
import 'tile_map.dart';
import 'zone_layout_kit.dart';

/// Socketed placement for props + room chests (docs/FLOOR_BLUEPRINT.md).
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
  }) {
    final violations = <String>[];
    final blocked = <String>{};
    void block(int x, int y) => blocked.add('$x,$y');
    for (final p in spawnPoints) {
      block(p.$1, p.$2);
    }
    block(exitPoint.$1, exitPoint.$2);
    for (final p in enemySpawns) {
      block(p.$1, p.$2);
    }

    bool touchesWall(int x, int y) {
      const dirs = <(int, int)>[(0, 1), (0, -1), (1, 0), (-1, 0)];
      for (final d in dirs) {
        final nx = x + d.$1;
        final ny = y + d.$2;
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) return true;
        if (tiles[ny * cols + nx] == TileKind.wall) return true;
      }
      return false;
    }

    bool isFloor(int x, int y) {
      if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
      final t = tiles[y * cols + x];
      return t == TileKind.floor || t == TileKind.spawn || t == TileKind.exit;
    }

    bool inChamber(Chamber c, int x, int y) =>
        x >= c.x && x < c.x + c.w && y >= c.y && y < c.y + c.h;

    final edgeCells = <(int, int)>[];
    final openCells = <(int, int)>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (!isFloor(x, y)) continue;
        if (blocked.contains('$x,$y')) continue;
        if (tiles[y * cols + x] == TileKind.exit) continue;
        final cell = (x, y);
        if (touchesWall(x, y)) {
          edgeCells.add(cell);
        } else {
          openCells.add(cell);
        }
      }
    }

    (int, int)? takeFrom(List<(int, int)> cells) {
      if (cells.isEmpty) return null;
      final idx = rng.nextInt(cells.length);
      return cells.removeAt(idx);
    }

    final used = <String>{};
    final props = <MapProp>[];
    final chests = <(int, int)>[];

    void placeProp((int, int) cell, MapPropKind kind) {
      final key = '${cell.$1},${cell.$2}';
      if (used.contains(key) || blocked.contains(key)) return;
      used.add(key);
      props.add(MapProp(x: cell.$1, y: cell.$2, kind: kind));
    }

    final wantChest =
        blueprint.wantsRoomChest ||
        (blueprint.legacyType == RoomType.elite && kit.eliteRoomChest) ||
        (blueprint.legacyType == RoomType.normal &&
            rng.nextDouble() < kit.normalRoomChestChance);
    if (wantChest) {
      final targetChamber = chambers.isEmpty
          ? null
          : chambers[chambers.length > 1 ? chambers.length - 1 : 0];
      final candidates = <(int, int)>[];
      for (final cell in edgeCells) {
        if (targetChamber != null &&
            !inChamber(targetChamber, cell.$1, cell.$2)) {
          continue;
        }
        if (cell.$1 == exitPoint.$1 && cell.$2 == exitPoint.$2) continue;
        candidates.add(cell);
      }
      if (candidates.isEmpty) {
        candidates.addAll(edgeCells);
      }
      final chest = takeFrom(candidates);
      if (chest != null) {
        chests.add(chest);
        used.add('${chest.$1},${chest.$2}');
        props.add(MapProp(x: chest.$1, y: chest.$2, kind: MapPropKind.chest));
        edgeCells.remove(chest);
      } else {
        violations.add('no_chest_socket');
      }
    }

    final landmarkPool = kit.landmarks.isNotEmpty
        ? kit.landmarks
        : kit.edgeClutter;
    for (final chamber in chambers) {
      final localEdge = <(int, int)>[];
      for (final cell in edgeCells) {
        if (used.contains('${cell.$1},${cell.$2}')) continue;
        if (inChamber(chamber, cell.$1, cell.$2)) localEdge.add(cell);
      }
      final want = kit.landmarkPerChamber.clamp(0, 3);
      for (var i = 0; i < want; i++) {
        final cell = takeFrom(localEdge);
        if (cell == null) break;
        edgeCells.remove(cell);
        final kind = landmarkPool[rng.nextInt(landmarkPool.length)];
        placeProp(cell, kind);
      }
    }

    final floorCount = edgeCells.length + openCells.length + used.length;
    final target = (floorCount * 0.12).floor().clamp(16, 80);
    final clutterPool = kit.edgeClutter.isNotEmpty
        ? kit.edgeClutter
        : landmarkPool;
    while (props.length < target) {
      final preferEdge = rng.nextDouble() < 0.75;
      var cell = preferEdge ? takeFrom(edgeCells) : takeFrom(openCells);
      cell ??= takeFrom(edgeCells) ?? takeFrom(openCells);
      if (cell == null) break;
      final kind = clutterPool[rng.nextInt(clutterPool.length)];
      placeProp(cell, kind);
    }

    const perChamberMin = 6;
    for (final chamber in chambers) {
      var count = props.where((p) => inChamber(chamber, p.x, p.y)).length;
      if (count >= perChamberMin) continue;
      final localEdge = <(int, int)>[];
      final localOpen = <(int, int)>[];
      for (var y = chamber.y; y < chamber.y + chamber.h; y++) {
        for (var x = chamber.x; x < chamber.x + chamber.w; x++) {
          if (!isFloor(x, y)) continue;
          if (blocked.contains('$x,$y') || used.contains('$x,$y')) continue;
          if (x == exitPoint.$1 && y == exitPoint.$2) continue;
          final cell = (x, y);
          if (touchesWall(x, y)) {
            localEdge.add(cell);
          } else {
            localOpen.add(cell);
          }
        }
      }
      while (count < perChamberMin) {
        final preferEdge = rng.nextDouble() < 0.8;
        var cell = preferEdge ? takeFrom(localEdge) : takeFrom(localOpen);
        cell ??= takeFrom(localEdge) ?? takeFrom(localOpen);
        if (cell == null) break;
        final kind = clutterPool[rng.nextInt(clutterPool.length)];
        placeProp(cell, kind);
        count++;
      }
    }

    for (final c in chests) {
      if (c.$1 == exitPoint.$1 && c.$2 == exitPoint.$2) {
        violations.add('chest_on_exit');
      }
      for (final s in spawnPoints) {
        if (c.$1 == s.$1 && c.$2 == s.$2) {
          violations.add('chest_on_spawn');
        }
      }
      for (final e in enemySpawns) {
        if (c.$1 == e.$1 && c.$2 == e.$2) {
          violations.add('chest_on_enemy');
        }
      }
      if (!isFloor(c.$1, c.$2)) {
        violations.add('chest_not_floor');
      }
    }

    return PlacementPlan(
      props: List<MapProp>.unmodifiable(props),
      lootChestPoints: List<(int, int)>.unmodifiable(chests),
      violations: List<String>.unmodifiable(violations),
    );
  }
}
