import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/dungeon_room.dart';
import '../ui/kenney_assets.dart';
import 'floor_blueprint.dart';
import 'placement_plan.dart';
import 'zone_layout_kit.dart';

enum TileKind { wall, floor, spawn, exit, gate }

enum MapPropKind {
  barrel,
  crate,
  table,
  stool,
  torch,
  torchAlt,
  gravestone,
  fountain,
  trap,
  pot,
  bones,
  skull,
  hatch,
  water,
  lava,
  anvil,
  /// Stacked crates / shelf clutter.
  shelf,
  /// Iron bars / railing accent.
  fence,
  /// Tall stone/metal pillar accent.
  pillar,
  /// Floor debris / rubble pile.
  rubble,
  /// Interactive-looking room chest (also a GroundLoot socket).
  chest,
}

class MapProp {
  const MapProp({
    required this.x,
    required this.y,
    required this.kind,
  });

  final int x;
  final int y;
  final MapPropKind kind;
}

/// A carved room on the floor map.
class Chamber {
  const Chamber({
    required this.index,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final int index;
  final int x;
  final int y;
  final int w;
  final int h;

  int get cx => x + w ~/ 2;
  int get cy => y + h ~/ 2;

  bool containsTile(int tx, int ty) =>
      tx >= x && tx < x + w && ty >= y && ty < y + h;

  bool containsWorld(double wx, double wy) =>
      containsTile(wx.floor(), wy.floor());
}

/// Gate blocking a corridor until [opensAfterChamber] is cleared.
class GateInfo {
  const GateInfo({
    required this.id,
    required this.x,
    required this.y,
    required this.opensAfterChamber,
  });

  final int id;
  final int x;
  final int y;
  final int opensAfterChamber;
}

/// Discrete dungeon tile coordinates.
class TileMap {
  TileMap({
    required this.cols,
    required this.rows,
    required this.tiles,
    required this.spawnPoints,
    required this.exitPoint,
    required this.enemySpawns,
    this.roomCenters = const <(int, int)>[],
    this.chambers = const <Chamber>[],
    this.gates = const <GateInfo>[],
    this.enemyChamberIndices = const <int>[],
    this.props = const <MapProp>[],
    this.lootChestPoints = const <(int, int)>[],
    this.layoutSeed = 0,
  });

  final int cols;
  final int rows;
  final List<TileKind> tiles;
  final List<(int x, int y)> spawnPoints;
  final (int x, int y) exitPoint;
  final List<(int x, int y)> enemySpawns;
  final List<(int x, int y)> roomCenters;
  final List<Chamber> chambers;
  final List<GateInfo> gates;

  /// Parallel to [enemySpawns]: which chamber each spawn belongs to.
  final List<int> enemyChamberIndices;

  /// Decorative props (non-blocking).
  final List<MapProp> props;

  /// Room-reward chest sockets (world pickups spawned in SpatialCombat.build).
  final List<(int x, int y)> lootChestPoints;

  /// Seed used for floor/wall hash + prop scatter.
  final int layoutSeed;

  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;

  TileKind at(int x, int y) {
    if (!inBounds(x, y)) return TileKind.wall;
    return tiles[y * cols + x];
  }

  GateInfo? gateAt(int x, int y) {
    for (final g in gates) {
      if (g.x == x && g.y == y) return g;
    }
    return null;
  }

  bool isWalkable(int x, int y, {Set<int> openGateIds = const <int>{}}) {
    final t = at(x, y);
    if (t == TileKind.floor || t == TileKind.spawn || t == TileKind.exit) {
      return true;
    }
    if (t == TileKind.gate) {
      final g = gateAt(x, y);
      return g != null && openGateIds.contains(g.id);
    }
    return false;
  }

  bool isWalkableWorld(
    double x,
    double y, {
    Set<int> openGateIds = const <int>{},
  }) =>
      isWalkable(x.floor(), y.floor(), openGateIds: openGateIds);

  /// Walkable cells suitable for combat spawns (floor/spawn, not exit/gate).
  bool isSpawnable(int x, int y) {
    if (!inBounds(x, y)) return false;
    final t = at(x, y);
    return t == TileKind.floor || t == TileKind.spawn;
  }

  /// Snap tile coords to nearest spawnable cell (spiral search).
  (int, int) snapToSpawnable(int x, int y) {
    if (isSpawnable(x, y)) return (x, y);
    for (var r = 1; r <= 14; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (isSpawnable(nx, ny)) return (nx, ny);
        }
      }
    }
    for (var yy = 0; yy < rows; yy++) {
      for (var xx = 0; xx < cols; xx++) {
        if (isSpawnable(xx, yy)) return (xx, yy);
      }
    }
    return (x.clamp(1, cols - 2), y.clamp(1, rows - 2));
  }

  /// Spawnable tiles; [combatOnly] skips the party staging chamber when multi-room.
  List<(int, int)> spawnableCells({bool combatOnly = true}) {
    final out = <(int, int)>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (!isSpawnable(x, y)) continue;
        if (combatOnly && chambers.length > 1) {
          final ci = chamberIndexAt(x + 0.5, y + 0.5);
          if (ci < 1) continue;
        }
        out.add((x, y));
      }
    }
    if (out.isEmpty) {
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          if (isSpawnable(x, y)) out.add((x, y));
        }
      }
    }
    return out;
  }

  int chamberIndexAt(double wx, double wy) {
    for (final c in chambers) {
      if (c.containsWorld(wx, wy)) return c.index;
    }
    // Corridors: nearest chamber by center.
    if (chambers.isEmpty) return 0;
    var best = 0;
    var bestD = double.infinity;
    for (final c in chambers) {
      final dx = wx - c.cx;
      final dy = wy - c.cy;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = c.index;
      }
    }
    return best;
  }
}

class _Rect {
  _Rect(this.x, this.y, this.w, this.h);
  final int x, y, w, h;
  int get cx => x + w ~/ 2;
  int get cy => y + h ~/ 2;
  bool overlaps(_Rect o, {int pad = 1}) {
    return x - pad < o.x + o.w &&
        x + w + pad > o.x &&
        y - pad < o.y + o.h &&
        y + h + pad > o.y;
  }
}

/// Multi-room floor maps (cave / hideout / fort flavours).
abstract final class RoomLayouts {
  static TileMap forRoom(DungeonRoom room, {String dungeonId = 'sandy'}) {
    return forFloor(
      floorNumber: room.floorNumber,
      room: room,
      dungeonId: dungeonId,
    );
  }

  static TileMap forFloor({
    required int floorNumber,
    required DungeonRoom room,
    required String dungeonId,
    int layoutSeed = 0,
    int? enemyCountOverride,
  }) {
    final def = DungeonCatalog.byId(dungeonId);
    final seed =
        floorNumber * 7919 +
        dungeonId.hashCode +
        room.type.index * 131 +
        layoutSeed;
    final rng = Random(seed);
    final enemyCount = max(room.enemyCount, enemyCountOverride ?? 0);

    if (room.type == RoomType.treasure) {
      return _singleChamber(
        cols: 17,
        rows: 13,
        treasure: true,
        rng: rng,
        dungeonId: dungeonId,
        layoutSeed: seed,
        room: room,
      );
    }
    if (room.type == RoomType.boss) {
      return _bossArena(
        rng,
        dungeonId: dungeonId,
        layoutSeed: seed,
        enemyCount: enemyCount,
        room: room,
      );
    }

    if (def.layout == DungeonLayoutKind.arena) {
      return _combatArena(
        rng,
        dungeonId: dungeonId,
        layoutSeed: seed,
        enemyCount: enemyCount,
        room: room,
      );
    }

    final roomCount = switch (def.layout) {
      DungeonLayoutKind.cave => 6 + rng.nextInt(3),
      DungeonLayoutKind.hideout => 5 + rng.nextInt(3),
      DungeonLayoutKind.fort => 6 + rng.nextInt(3),
      // Arena handled above; keep a safe multi-room fallback.
      DungeonLayoutKind.arena => 5 + rng.nextInt(2),
    };

    return _multiRoomFloor(
      cols: def.layout == DungeonLayoutKind.hideout ? 36 : 42,
      rows: def.layout == DungeonLayoutKind.fort ? 30 : 28,
      roomCount: roomCount,
      rng: rng,
      fortStyle: def.layout == DungeonLayoutKind.fort,
      enemyCount: enemyCount,
      dungeonId: dungeonId,
      layoutSeed: seed,
      room: room,
    );
  }

  /// Apply FloorBlueprint + PlacementPlan (fallback to legacy scatter).
  static TileMap _composeMap({
    required int cols,
    required int rows,
    required List<TileKind> tiles,
    required List<(int x, int y)> spawnPoints,
    required (int x, int y) exitPoint,
    required List<(int x, int y)> enemySpawns,
    required List<int> enemyChamberIndices,
    required List<Chamber> chambers,
    required List<GateInfo> gates,
    required List<(int x, int y)> roomCenters,
    required String dungeonId,
    required int layoutSeed,
    required Random rng,
    required DungeonRoom room,
  }) {
    final blueprint = FloorBlueprint.forRoom(
      room,
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
    );
    final kit = ZoneLayoutKit.forId(dungeonId);
    final plan = PlacementPlan.build(
      cols: cols,
      rows: rows,
      tiles: tiles,
      spawnPoints: spawnPoints,
      exitPoint: exitPoint,
      enemySpawns: enemySpawns,
      chambers: chambers,
      blueprint: blueprint,
      kit: kit,
      rng: rng,
    );
    final props = plan.props.isNotEmpty
        ? plan.props
        : _scatterProps(
            cols: cols,
            rows: rows,
            tiles: tiles,
            spawnPoints: spawnPoints,
            exitPoint: exitPoint,
            enemySpawns: enemySpawns,
            chambers: chambers,
            dungeonId: dungeonId,
            layoutSeed: layoutSeed,
            rng: rng,
          );
    return TileMap(
      cols: cols,
      rows: rows,
      tiles: tiles,
      spawnPoints: spawnPoints,
      exitPoint: exitPoint,
      enemySpawns: enemySpawns,
      roomCenters: roomCenters,
      chambers: chambers,
      gates: gates,
      enemyChamberIndices: enemyChamberIndices,
      props: props,
      lootChestPoints: plan.lootChestPoints,
      layoutSeed: layoutSeed,
    );
  }

  static TileMap _bossArena(
    Random rng, {
    required String dungeonId,
    required int layoutSeed,
    required DungeonRoom room,
    int enemyCount = 6,
  }) {
    const cols = 25;
    const rows = 19;
    final tiles = List<TileKind>.filled(cols * rows, TileKind.wall);
    void set(int x, int y, TileKind k) {
      if (x >= 0 && y >= 0 && x < cols && y < rows) {
        tiles[y * cols + x] = k;
      }
    }

    for (var y = 2; y < rows - 2; y++) {
      for (var x = 2; x < cols - 2; x++) {
        set(x, y, TileKind.floor);
      }
    }
    for (final p in <(int, int)>[
      (6, 6),
      (6, 12),
      (18, 6),
      (18, 12),
      (12, 5),
      (12, 13),
    ]) {
      set(p.$1, p.$2, TileKind.wall);
    }
    set(3, rows ~/ 2, TileKind.spawn);
    set(cols - 3, rows ~/ 2, TileKind.exit);
    _carveExitPlaza(tiles, cols, rows, cols - 3, rows ~/ 2);

    final chamber = Chamber(
      index: 0,
      x: 2,
      y: 2,
      w: cols - 4,
      h: rows - 4,
    );

    final spawnPoints = _partySpawnCluster(
      tiles: tiles,
      cols: cols,
      rows: rows,
      anchorX: 3,
      anchorY: rows ~/ 2,
    );
    const exitPoint = (cols - 3, rows ~/ 2);

    bool spawnable(int x, int y) {
      if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
      final t = tiles[y * cols + x];
      if (t != TileKind.floor) return false;
      for (final p in spawnPoints) {
        if ((p.$1 - x).abs() <= 2 && (p.$2 - y).abs() <= 2) return false;
      }
      if ((x - exitPoint.$1).abs() + (y - exitPoint.$2).abs() <= 1) {
        return false;
      }
      return true;
    }

    final preferred = <(int, int)>[
      (cols ~/ 2, rows ~/ 2),
      (cols ~/ 2 - 3, rows ~/ 2 - 2),
      (cols ~/ 2 + 3, rows ~/ 2 + 2),
      (cols ~/ 2 - 2, rows ~/ 2 + 3),
      (cols ~/ 2 + 2, rows ~/ 2 - 3),
      (cols ~/ 2 + 4, rows ~/ 2),
      (cols ~/ 2 - 4, rows ~/ 2),
      (cols ~/ 2, rows ~/ 2 - 4),
      (cols ~/ 2, rows ~/ 2 + 4),
    ];
    final enemySpawns = <(int, int)>[];
    final seen = <String>{};
    void tryAdd(int x, int y) {
      if (!spawnable(x, y)) return;
      final key = '$x,$y';
      if (seen.contains(key)) return;
      seen.add(key);
      enemySpawns.add((x, y));
    }

    for (final p in preferred) {
      if (enemySpawns.length >= enemyCount) break;
      tryAdd(p.$1, p.$2);
    }
    // Fill remaining from floor ring around arena center.
    for (var r = 1; enemySpawns.length < enemyCount && r < 10; r++) {
      for (var a = 0; a < 16 && enemySpawns.length < enemyCount; a++) {
        final ang = a * pi / 8;
        tryAdd(
          (cols / 2 + cos(ang) * r * 1.4).round(),
          (rows / 2 + sin(ang) * r * 1.1).round(),
        );
      }
    }
    for (var y = 2; y < rows - 2 && enemySpawns.length < enemyCount; y++) {
      for (var x = 4; x < cols - 4 && enemySpawns.length < enemyCount; x++) {
        tryAdd(x, y);
      }
    }

    final chambersIdx = List<int>.filled(enemySpawns.length, 0);

    return _composeMap(
      cols: cols,
      rows: rows,
      tiles: tiles,
      spawnPoints: spawnPoints,
      exitPoint: exitPoint,
      enemySpawns: enemySpawns,
      enemyChamberIndices: chambersIdx,
      chambers: <Chamber>[chamber],
      gates: const <GateInfo>[],
      roomCenters: <(int, int)>[(cols ~/ 2, rows ~/ 2)],
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
      rng: rng,
      room: room,
    );
  }

  /// Crystal Spire-style arena: spawn south, exit north, enemies mid-floor.
  /// Avoids the old roomCount=1 bug where spawn and exit shared one cell.
  static TileMap _combatArena(
    Random rng, {
    required String dungeonId,
    required int layoutSeed,
    required DungeonRoom room,
    int enemyCount = 8,
  }) {
    const cols = 23;
    const rows = 29;
    final tiles = List<TileKind>.filled(cols * rows, TileKind.wall);
    void set(int x, int y, TileKind k) {
      if (x >= 0 && y >= 0 && x < cols && y < rows) {
        tiles[y * cols + x] = k;
      }
    }

    for (var y = 2; y < rows - 2; y++) {
      for (var x = 2; x < cols - 2; x++) {
        set(x, y, TileKind.floor);
      }
    }
    // Crystal pillars — leave a clear vertical lane for the climb.
    for (final p in <(int, int)>[
      (6, 8),
      (16, 8),
      (5, 14),
      (17, 14),
      (6, 20),
      (16, 20),
      (11, 11),
      (11, 17),
    ]) {
      set(p.$1, p.$2, TileKind.wall);
    }

    const spawnX = cols ~/ 2;
    const spawnY = rows - 4;
    const exitX = cols ~/ 2;
    const exitY = 3;
    set(spawnX, spawnY, TileKind.spawn);
    set(exitX, exitY, TileKind.exit);
    _carveExitPlaza(tiles, cols, rows, exitX, exitY);

    final chamber = Chamber(
      index: 0,
      x: 2,
      y: 2,
      w: cols - 4,
      h: rows - 4,
    );
    final spawnPoints = _partySpawnCluster(
      tiles: tiles,
      cols: cols,
      rows: rows,
      anchorX: spawnX,
      anchorY: spawnY,
    );
    const exitPoint = (exitX, exitY);
    final reserved = <String>{
      for (final p in spawnPoints) '${p.$1},${p.$2}',
      '$exitX,$exitY',
      // Keep a small pad clear around party start.
      for (var dy = -2; dy <= 2; dy++)
        for (var dx = -2; dx <= 2; dx++) '${spawnX + dx},${spawnY + dy}',
    };

    bool spawnable(int x, int y) {
      if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
      if (reserved.contains('$x,$y')) return false;
      return tiles[y * cols + x] == TileKind.floor;
    }

    final preferred = <(int, int)>[
      (cols ~/ 2, rows ~/ 2),
      (cols ~/ 2 - 3, rows ~/ 2 - 2),
      (cols ~/ 2 + 3, rows ~/ 2 + 2),
      (cols ~/ 2 - 2, rows ~/ 2 + 3),
      (cols ~/ 2 + 2, rows ~/ 2 - 3),
      (cols ~/ 2 + 4, rows ~/ 2),
      (cols ~/ 2 - 4, rows ~/ 2),
      (7, 12),
      (15, 12),
      (7, 18),
      (15, 18),
      (cols ~/ 2, 10),
      (cols ~/ 2, 16),
    ];
    final enemySpawns = <(int, int)>[];
    final seen = <String>{};
    void tryAdd(int x, int y) {
      if (!spawnable(x, y)) return;
      final key = '$x,$y';
      if (!seen.add(key)) return;
      enemySpawns.add((x, y));
    }

    for (final p in preferred) {
      if (enemySpawns.length >= enemyCount) break;
      tryAdd(p.$1, p.$2);
    }
    for (var r = 1; enemySpawns.length < enemyCount && r < 12; r++) {
      for (var a = 0; a < 16 && enemySpawns.length < enemyCount; a++) {
        final ang = a * pi / 8;
        tryAdd(
          (cols / 2 + cos(ang) * r * 1.3).round(),
          (rows / 2 + sin(ang) * r * 1.5).round(),
        );
      }
    }
    for (var y = 5; y < rows - 6 && enemySpawns.length < enemyCount; y++) {
      for (var x = 3; x < cols - 3 && enemySpawns.length < enemyCount; x++) {
        tryAdd(x, y);
      }
    }

    final chambersIdx = List<int>.filled(enemySpawns.length, 0);
    return _composeMap(
      cols: cols,
      rows: rows,
      tiles: tiles,
      spawnPoints: spawnPoints,
      exitPoint: exitPoint,
      enemySpawns: enemySpawns,
      enemyChamberIndices: chambersIdx,
      chambers: <Chamber>[chamber],
      gates: const <GateInfo>[],
      roomCenters: <(int, int)>[(cols ~/ 2, rows ~/ 2)],
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
      rng: rng,
      room: room,
    );
  }

  static TileMap _singleChamber({
    required int cols,
    required int rows,
    required bool treasure,
    required Random rng,
    required String dungeonId,
    required int layoutSeed,
    required DungeonRoom room,
  }) {
    final tiles = List<TileKind>.filled(cols * rows, TileKind.wall);
    void set(int x, int y, TileKind k) {
      if (x >= 0 && y >= 0 && x < cols && y < rows) {
        tiles[y * cols + x] = k;
      }
    }
    for (var y = 2; y < rows - 2; y++) {
      for (var x = 2; x < cols - 2; x++) {
        set(x, y, TileKind.floor);
      }
    }
    set(2, rows ~/ 2, TileKind.spawn);
    set(cols - 3, rows ~/ 2, TileKind.exit);
    _carveExitPlaza(tiles, cols, rows, cols - 3, rows ~/ 2);
    final chamber = Chamber(index: 0, x: 2, y: 2, w: cols - 4, h: rows - 4);
    final spawns = treasure
        ? const <(int, int)>[]
        : <(int, int)>[(cols ~/ 2, rows ~/ 2)];
    final spawnPoints = _partySpawnCluster(
      tiles: tiles,
      cols: cols,
      rows: rows,
      anchorX: 2,
      anchorY: rows ~/ 2,
    );
    final exitPoint = (cols - 3, rows ~/ 2);

    return _composeMap(
      cols: cols,
      rows: rows,
      tiles: tiles,
      spawnPoints: spawnPoints,
      exitPoint: exitPoint,
      enemySpawns: spawns,
      enemyChamberIndices: List<int>.filled(spawns.length, 0),
      chambers: <Chamber>[chamber],
      gates: const <GateInfo>[],
      roomCenters: <(int, int)>[(cols ~/ 2, rows ~/ 2)],
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
      rng: rng,
      room: room,
    );
  }

  static TileMap _multiRoomFloor({
    required int cols,
    required int rows,
    required int roomCount,
    required Random rng,
    required bool fortStyle,
    required int enemyCount,
    required String dungeonId,
    required int layoutSeed,
    required DungeonRoom room,
  }) {
    final tiles = List<TileKind>.filled(cols * rows, TileKind.wall);
    void set(int x, int y, TileKind k) {
      if (x < 0 || y < 0 || x >= cols || y >= rows) return;
      final i = y * cols + x;
      // Later corridor carves must not erase earlier chamber gates.
      if (k == TileKind.floor && tiles[i] == TileKind.gate) return;
      tiles[i] = k;
    }

    final rooms = <_Rect>[];
    var attempts = 0;
    while (rooms.length < roomCount && attempts < 160) {
      attempts++;
      final w = fortStyle ? 5 + rng.nextInt(4) : 5 + rng.nextInt(4);
      final h = fortStyle ? 5 + rng.nextInt(3) : 4 + rng.nextInt(4);
      final x = 1 + rng.nextInt(max(1, cols - w - 2));
      final y = 1 + rng.nextInt(max(1, rows - h - 2));
      final cand = _Rect(x, y, w, h);
      if (rooms.any((r) => r.overlaps(cand, pad: fortStyle ? 2 : 1))) {
        continue;
      }
      rooms.add(cand);
    }
    if (rooms.isEmpty) {
      rooms.add(_Rect(2, 2, 6, 5));
      rooms.add(_Rect(cols - 9, rows - 8, 6, 5));
    }

    for (final r in rooms) {
      for (var yy = r.y; yy < r.y + r.h; yy++) {
        for (var xx = r.x; xx < r.x + r.w; xx++) {
          set(xx, yy, TileKind.floor);
        }
      }
    }

    final gateList = <GateInfo>[];
    for (var i = 0; i < rooms.length - 1; i++) {
      final gateTiles = _carveCorridorWithGate(
        set,
        rooms[i].cx,
        rooms[i].cy,
        rooms[i + 1].cx,
        rooms[i + 1].cy,
      );
      for (final gatePos in gateTiles) {
        final gx = gatePos.$1;
        final gy = gatePos.$2;
        if (gx < 1 || gy < 1 || gx >= cols - 1 || gy >= rows - 1) {
          continue;
        }
        final ti = gy * cols + gx;
        if (tiles[ti] == TileKind.wall) continue;
        final id = gateList.length;
        set(gx, gy, TileKind.gate);
        gateList.add(
          GateInfo(
            id: id,
            x: gx,
            y: gy,
            opensAfterChamber: i,
          ),
        );
      }
    }

    final start = rooms.first;
    final end = rooms.last;
    set(start.cx, start.cy, TileKind.spawn);
    set(end.cx, end.cy, TileKind.exit);
    _carveExitPlaza(tiles, cols, rows, end.cx, end.cy);

    // Re-stamp gates so spawn/exit/corridor overlap cannot leave ghost GateInfo.
    for (final g in gateList) {
      if ((g.x, g.y) == (start.cx, start.cy) ||
          (g.x, g.y) == (end.cx, end.cy)) {
        continue;
      }
      tiles[g.y * cols + g.x] = TileKind.gate;
    }
    gateList.removeWhere(
      (g) =>
          (g.x, g.y) == (start.cx, start.cy) ||
          (g.x, g.y) == (end.cx, end.cy),
    );

    final spawnPoints = _partySpawnCluster(
      tiles: tiles,
      cols: cols,
      rows: rows,
      anchorX: start.cx,
      anchorY: start.cy,
    );

    final chambers = <Chamber>[
      for (var i = 0; i < rooms.length; i++)
        Chamber(
          index: i,
          x: rooms[i].x,
          y: rooms[i].y,
          w: rooms[i].w,
          h: rooms[i].h,
        ),
    ];

    // Enemies in chambers after the first (chamber 0 = spawn staging).
    // Only place on walkable floor — HM packs can request dozens of spawns.
    final enemySpawns = <(int, int)>[];
    final enemyChambers = <int>[];
    final seenSpawns = <String>{};
    final combatRooms = rooms.length == 1
        ? <(int, _Rect)>[(0, rooms.first)]
        : [
            for (var i = 1; i < rooms.length; i++) (i, rooms[i]),
          ];

    final partyPad = <String>{
      for (final p in spawnPoints) '${p.$1},${p.$2}',
      for (var dy = -1; dy <= 1; dy++)
        for (var dx = -1; dx <= 1; dx++)
          '${start.cx + dx},${start.cy + dy}',
    };

    bool tileSpawnable(int x, int y) {
      if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
      if (partyPad.contains('$x,$y')) return false;
      // Never place enemies on party spawn tiles or the exit.
      final t = tiles[y * cols + x];
      return t == TileKind.floor;
    }

    bool tryPlace(int x, int y, int chamberIdx) {
      if (!tileSpawnable(x, y)) return false;
      final key = '$x,$y';
      if (seenSpawns.contains(key)) return false;
      seenSpawns.add(key);
      enemySpawns.add((x, y));
      enemyChambers.add(chamberIdx);
      return true;
    }

    void fillRoom(_Rect r, int chamberIdx, int want) {
      if (want <= 0) return;
      final offsets = <(int, int)>[
        (0, 0),
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
        (1, 1),
        (-1, 1),
        (1, -1),
        (-1, -1),
        (2, 0),
        (-2, 0),
        (0, 2),
        (0, -2),
        (2, 1),
        (-2, 1),
        (1, 2),
        (-1, 2),
      ];
      var added = 0;
      for (final o in offsets) {
        if (added >= want) break;
        if (tryPlace(r.cx + o.$1, r.cy + o.$2, chamberIdx)) added++;
      }
      // Sweep room interior for remaining slots.
      for (var y = r.y + 1; y < r.y + r.h - 1 && added < want; y++) {
        for (var x = r.x + 1; x < r.x + r.w - 1 && added < want; x++) {
          if (tryPlace(x, y, chamberIdx)) added++;
        }
      }
    }

    if (combatRooms.isNotEmpty) {
      final first = combatRooms.first;
      final firstPack = (enemyCount * 0.55).ceil().clamp(1, enemyCount);
      fillRoom(first.$2, first.$1, firstPack);
      for (final entry in combatRooms.skip(1)) {
        if (enemySpawns.length >= enemyCount) break;
        final remaining = enemyCount - enemySpawns.length;
        final share = max(1, remaining ~/ max(1, combatRooms.length - 1));
        fillRoom(entry.$2, entry.$1, share);
      }
    }

    // Leftover: round-robin walkable cells in combat rooms.
    if (enemySpawns.length < enemyCount) {
      final pool = <(int x, int y, int ci)>[];
      for (final entry in combatRooms) {
        final r = entry.$2;
        for (var y = r.y + 1; y < r.y + r.h - 1; y++) {
          for (var x = r.x + 1; x < r.x + r.w - 1; x++) {
            if (tileSpawnable(x, y) && !seenSpawns.contains('$x,$y')) {
              pool.add((x, y, entry.$1));
            }
          }
        }
      }
      pool.shuffle(rng);
      for (final p in pool) {
        if (enemySpawns.length >= enemyCount) break;
        tryPlace(p.$1, p.$2, p.$3);
      }
    }

    final exitPoint = (end.cx, end.cy);
    final finalEnemySpawns = enemySpawns.take(enemyCount).toList();
    final finalChambers = enemyChambers.take(finalEnemySpawns.length).toList();

    return _composeMap(
      cols: cols,
      rows: rows,
      tiles: tiles,
      spawnPoints: spawnPoints,
      exitPoint: exitPoint,
      enemySpawns: finalEnemySpawns,
      enemyChamberIndices: finalChambers,
      chambers: chambers,
      gates: gateList,
      roomCenters: rooms.map((r) => (r.cx, r.cy)).toList(),
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
      rng: rng,
      room: room,
    );
  }

  static List<MapProp> _scatterProps({
    required int cols,
    required int rows,
    required List<TileKind> tiles,
    required List<(int x, int y)> spawnPoints,
    required (int x, int y) exitPoint,
    required List<(int x, int y)> enemySpawns,
    required List<Chamber> chambers,
    required String dungeonId,
    required int layoutSeed,
    required Random rng,
  }) {
    final pool = KenneyAssets.propPoolForDungeon(dungeonId);
    if (pool.isEmpty) return const [];

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

    bool inChamber(Chamber c, int x, int y) =>
        x >= c.x && x < c.x + c.w && y >= c.y && y < c.y + c.h;

    final edgeCells = <(int, int)>[];
    final openCells = <(int, int)>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (tiles[y * cols + x] != TileKind.floor) continue;
        if (blocked.contains('$x,$y')) continue;
        final cell = (x, y);
        if (touchesWall(x, y)) {
          edgeCells.add(cell);
        } else {
          openCells.add(cell);
        }
      }
    }

    final floorCount = edgeCells.length + openCells.length;
    // Dense enough to read in a zoomed-out camera (~12% of floor).
    final target = (floorCount * 0.12).floor().clamp(16, 80);
    final props = <MapProp>[];
    final used = <String>{};

    (int, int)? takeFrom(List<(int, int)> cells) {
      if (cells.isEmpty) return null;
      final idx = rng.nextInt(cells.length);
      return cells.removeAt(idx);
    }

    void placeAt((int, int) cell) {
      final key = '${cell.$1},${cell.$2}';
      if (used.contains(key)) return;
      used.add(key);
      props.add(
        MapProp(
          x: cell.$1,
          y: cell.$2,
          kind: pool[rng.nextInt(pool.length)],
        ),
      );
    }

    for (var i = 0; i < target; i++) {
      // Prefer wall-adjacent clutter so open fight space stays readable.
      final preferEdge = rng.nextDouble() < 0.75;
      var cell = preferEdge ? takeFrom(edgeCells) : takeFrom(openCells);
      cell ??= takeFrom(edgeCells) ?? takeFrom(openCells);
      if (cell == null) break;
      placeAt(cell);
    }

    // Guarantee each chamber has local clutter (corridors alone look empty).
    const perChamberMin = 6;
    for (final chamber in chambers) {
      var count = 0;
      for (final p in props) {
        if (inChamber(chamber, p.x, p.y)) count++;
      }
      if (count >= perChamberMin) continue;

      final localEdge = <(int, int)>[];
      final localOpen = <(int, int)>[];
      for (var y = chamber.y; y < chamber.y + chamber.h; y++) {
        for (var x = chamber.x; x < chamber.x + chamber.w; x++) {
          if (x < 0 || y < 0 || x >= cols || y >= rows) continue;
          if (tiles[y * cols + x] != TileKind.floor) continue;
          if (blocked.contains('$x,$y') || used.contains('$x,$y')) continue;
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
        placeAt(cell);
        count++;
      }
    }

    return props;
  }

  /// Ensure at least [count] walkable spawn cells around the party start.
  static List<(int, int)> _partySpawnCluster({
    required List<TileKind> tiles,
    required int cols,
    required int rows,
    required int anchorX,
    required int anchorY,
    int count = 5,
  }) {
    bool walkable(int x, int y) {
      if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
      final t = tiles[y * cols + x];
      return t == TileKind.floor || t == TileKind.spawn || t == TileKind.exit;
    }

    final offsets = <(int, int)>[
      (0, 0),
      (0, -1),
      (0, 1),
      (1, 0),
      (-1, 0),
      (1, -1),
      (1, 1),
      (-1, -1),
      (-1, 1),
      (2, 0),
      (0, 2),
    ];
    final points = <(int, int)>[];
    final seen = <String>{};
    for (final o in offsets) {
      if (points.length >= count) break;
      final x = anchorX + o.$1;
      final y = anchorY + o.$2;
      final key = '$x,$y';
      if (seen.contains(key)) continue;
      if (!walkable(x, y)) continue;
      seen.add(key);
      points.add((x, y));
      // Mark as spawn for clarity (exit stays exit).
      final i = y * cols + x;
      if (tiles[i] == TileKind.floor) tiles[i] = TileKind.spawn;
    }
    while (points.length < count) {
      points.add(points.isEmpty ? (anchorX, anchorY) : points.first);
    }
    return points;
  }

  /// Widen the stairs area so a 4-hero party can stand near the exit.
  static void _carveExitPlaza(
    List<TileKind> tiles,
    int cols,
    int rows,
    int ex,
    int ey,
  ) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final x = ex + dx;
        final y = ey + dy;
        if (x < 1 || y < 1 || x >= cols - 1 || y >= rows - 1) continue;
        final i = y * cols + x;
        if (tiles[i] == TileKind.wall || tiles[i] == TileKind.gate) {
          tiles[i] = TileKind.floor;
        }
      }
    }
    tiles[ey * cols + ex] = TileKind.exit;
  }

  /// Carve a 3-wide L-corridor; return gate tiles at the midpoint choke.
  static List<(int, int)> _carveCorridorWithGate(
    void Function(int, int, TileKind) set,
    int x0,
    int y0,
    int x1,
    int y1,
  ) {
    void carveWide(int x, int y, {required bool horizontal}) {
      set(x, y, TileKind.floor);
      if (horizontal) {
        set(x, y - 1, TileKind.floor);
        set(x, y + 1, TileKind.floor);
      } else {
        set(x - 1, y, TileKind.floor);
        set(x + 1, y, TileKind.floor);
      }
    }

    final path = <(int, int)>[];
    var x = x0;
    var y = y0;
    while (x != x1) {
      carveWide(x, y, horizontal: true);
      path.add((x, y));
      x += x1 > x ? 1 : -1;
    }
    while (y != y1) {
      carveWide(x, y, horizontal: false);
      path.add((x, y));
      y += y1 > y ? 1 : -1;
    }
    carveWide(x1, y1, horizontal: x0 != x1 && y0 == y1);
    path.add((x1, y1));
    if (path.length < 3) return const <(int, int)>[];

    final mid = path[path.length ~/ 2];
    final mx = mid.$1;
    final my = mid.$2;
    final midIndex = path.length ~/ 2;
    final prev = path[midIndex - 1];
    final horizontal = prev.$2 == my;
    if (horizontal) {
      return <(int, int)>[(mx, my - 1), (mx, my), (mx, my + 1)];
    }
    return <(int, int)>[(mx - 1, my), (mx, my), (mx + 1, my)];
  }
}
