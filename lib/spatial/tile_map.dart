import 'dart:math';

import '../core/dungeon_generator.dart';
import '../models/dungeon_def.dart';
import '../models/dungeon_room.dart';
import '../assets/kenney_assets.dart';
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
  const MapProp({required this.x, required this.y, required this.kind});

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
    this.beatKind,
  });

  final int index;
  final int x;
  final int y;
  final int w;
  final int h;

  /// Floor story beat for this chamber (null on legacy / special arenas).
  final FloorBeatKind? beatKind;

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
  }) => isWalkable(x.floor(), y.floor(), openGateIds: openGateIds);

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

enum _RoomSilhouette { rect, oval, diamond, el, plus, chamfer, blob }

/// Footprints below were tuned for a ~56×40 floor. A live map near 125×125
/// grows the same rooms on both axes so they stay a similar share of the cave.
(int, int) _scaledRoom(int cols, int rows, int w, int h) {
  final gw = max(4, (w * cols / 56).round());
  final gh = max(4, (h * rows / 40).round());
  return (min(gw, max(4, cols - 8)), min(gh, max(4, rows - 8)));
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
    int ascensionLevel = 0,
    int keyLevel = 0,
    int pressureBonus = 0,
    int extraCombatRooms = 0,
    bool tightRooms = false,
  }) {
    final def = DungeonCatalog.byId(dungeonId);
    final seed =
        floorNumber * 7919 +
        dungeonId.hashCode +
        room.type.index * 131 +
        layoutSeed;
    final rng = Random(seed);
    final enemyCount = max(room.enemyCount, enemyCountOverride ?? 0);

    final pressure =
        DungeonGenerator.layoutPressure(
          ascensionLevel: ascensionLevel,
          keyLevel: keyLevel,
        ) +
        pressureBonus.clamp(0, 12);
    if (room.type == RoomType.boss) {
      return _bossArena(
        rng,
        dungeonId: dungeonId,
        layoutSeed: seed,
        enemyCount: enemyCount,
        room: room,
        pressure: pressure,
      );
    }

    // Arena catalog zones used to be one open pit (samey late-path floors).
    // They now share beat-tagged multi-chamber grammar with cave/hideout/fort.
    // Treasure floors use the same winding grammar (hall + side vault).
    final bump = 2 + pressure.clamp(0, 4);
    final roomCount = switch (def.layout) {
      DungeonLayoutKind.cave => 7 + rng.nextInt(3) + bump,
      DungeonLayoutKind.hideout => 6 + rng.nextInt(3) + bump,
      DungeonLayoutKind.fort => 7 + rng.nextInt(3) + bump,
      DungeonLayoutKind.arena => 5 + rng.nextInt(2) + bump,
    };
    final extent = _mapExtent(def.layout, pressure);

    return _multiRoomFloor(
      cols: extent.$1,
      rows: extent.$2,
      fallbackRoomCount: roomCount,
      rng: rng,
      fortStyle: def.layout == DungeonLayoutKind.fort,
      enemyCount: enemyCount,
      dungeonId: dungeonId,
      layoutSeed: seed,
      room: room,
      extraCombatRooms: extraCombatRooms,
      tightRooms: tightRooms,
    );
  }

  static (int, int) _mapExtent(DungeonLayoutKind layout, int pressure) {
    final p = pressure.clamp(0, 10);
    // About 125×125. A little extra at high AL / KEY so later floors still grow.
    return switch (layout) {
      DungeonLayoutKind.hideout ||
      DungeonLayoutKind.arena ||
      DungeonLayoutKind.fort ||
      DungeonLayoutKind.cave => (125 + p * 2, 125 + p),
    };
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
    FloorBlueprint? blueprint,
  }) {
    final story =
        blueprint ??
        FloorBlueprint.forRoom(
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
      blueprint: story,
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
    int pressure = 0,
  }) {
    final extra = pressure.clamp(0, 6);
    final cols = 125 + extra * 2;
    final rows = 125 + extra;
    final tiles = List<TileKind>.filled(cols * rows, TileKind.wall);
    void set(int x, int y, TileKind k) {
      if (x >= 0 && y >= 0 && x < cols && y < rows) {
        tiles[y * cols + x] = k;
      }
    }

    // The old arena filled a ~36×28 map. Grow that room with this floor
    // instead of turning the whole cave into one oval.
    final arena = _scaledRoom(cols, rows, 36, 28);
    final rcx = (cols - 1) / 2.0;
    final rcy = (rows - 1) / 2.0;
    final rx = max(4.0, arena.$1 / 2.0);
    final ry = max(4.0, arena.$2 / 2.0);
    for (var y = 2; y < rows - 2; y++) {
      for (var x = 2; x < cols - 2; x++) {
        final dx = (x - rcx) / rx;
        final dy = (y - rcy) / ry;
        if (dx * dx + dy * dy <= 1.08) {
          set(x, y, TileKind.floor);
        }
      }
    }
    // North / south bays so the arena isn't a flat oval.
    final bayHalf = max(4, (5 * cols / 56).round());
    final arenaH = max(8, (ry * 2).round());
    var bayDepth = max(3, (4 * rows / 40).round());
    bayDepth = min(bayDepth, max(2, (rows - arenaH - 16) ~/ 2));
    final northLip = (rcy - ry).floor();
    final southLip = (rcy + ry).ceil();
    for (var y = northLip - bayDepth; y <= northLip; y++) {
      for (var x = (rcx - bayHalf).round(); x <= (rcx + bayHalf).round(); x++) {
        set(x, y, TileKind.floor);
      }
    }
    for (var y = southLip; y <= southLip + bayDepth; y++) {
      for (var x = (rcx - bayHalf).round(); x <= (rcx + bayHalf).round(); x++) {
        set(x, y, TileKind.floor);
      }
    }
    void pillar(int x, int y) {
      if (x < 1 || y < 1 || x >= cols - 1 || y >= rows - 1) return;
      if (tiles[y * cols + x] == TileKind.floor) set(x, y, TileKind.wall);
    }

    pillar((rcx - rx * 0.45).round(), (rcy - ry * 0.35).round());
    pillar((rcx - rx * 0.45).round(), (rcy + ry * 0.35).round());
    pillar((rcx + rx * 0.45).round(), (rcy - ry * 0.35).round());
    pillar((rcx + rx * 0.45).round(), (rcy + ry * 0.35).round());
    pillar(rcx.round(), (rcy - ry * 0.7).round());
    pillar(rcx.round(), (rcy + ry * 0.7).round());
    final spawnX = (rcx - rx + 3).round().clamp(2, cols - 3);
    final spawnY = rcy.round().clamp(2, rows - 3);
    final exitX = (rcx + rx - 3).round().clamp(2, cols - 3);
    final exitY = spawnY;
    _carveExitPlaza(tiles, cols, rows, spawnX, spawnY);
    _carveExitPlaza(tiles, cols, rows, exitX, exitY);
    set(spawnX, spawnY, TileKind.spawn);
    set(exitX, exitY, TileKind.exit);

    final left = max(1, (rcx - rx).floor() - 1);
    final right = min(cols - 2, (rcx + rx).ceil() + 1);
    final top = max(1, northLip - bayDepth - 1);
    final bottom = min(rows - 2, southLip + bayDepth + 1);
    final chamber = Chamber(
      index: 0,
      x: left,
      y: top,
      w: max(4, right - left + 1),
      h: max(4, bottom - top + 1),
    );

    final spawnPoints = _partySpawnCluster(
      tiles: tiles,
      cols: cols,
      rows: rows,
      anchorX: spawnX,
      anchorY: spawnY,
    );
    final exitPoint = (exitX, exitY);

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

  static _RoomSilhouette _silhouetteFor(
    FloorBeatKind kind,
    Random rng,
    ZoneLayoutKit kit,
  ) {
    if (kind == FloorBeatKind.choke) {
      if (kit.dungeonId == 'storm') return _RoomSilhouette.plus;
      return rng.nextBool() ? _RoomSilhouette.oval : _RoomSilhouette.chamfer;
    }
    if (kind == FloorBeatKind.treasure || kind == FloorBeatKind.decoy) {
      if (kit.dungeonId == 'rime') return _RoomSilhouette.oval;
      return switch (rng.nextInt(3)) {
        0 => _RoomSilhouette.oval,
        1 => _RoomSilhouette.el,
        _ => _RoomSilhouette.diamond,
      };
    }
    if (kit.dungeonId == 'storm') {
      return rng.nextBool() ? _RoomSilhouette.plus : _RoomSilhouette.chamfer;
    }
    if (kit.dungeonId == 'rime') {
      return rng.nextBool() ? _RoomSilhouette.oval : _RoomSilhouette.diamond;
    }
    if (kit.dungeonId == 'brass') {
      return rng.nextBool() ? _RoomSilhouette.rect : _RoomSilhouette.chamfer;
    }
    if (kit.dungeonId == 'hell') {
      return rng.nextBool() ? _RoomSilhouette.el : _RoomSilhouette.blob;
    }
    if (kit.dungeonId == 'crystal') {
      return rng.nextBool() ? _RoomSilhouette.diamond : _RoomSilhouette.plus;
    }
    if (kit.dungeonId == 'ember') {
      return rng.nextBool() ? _RoomSilhouette.chamfer : _RoomSilhouette.blob;
    }
    if (kit.dungeonId == 'fen') {
      return rng.nextBool() ? _RoomSilhouette.el : _RoomSilhouette.oval;
    }
    if (kit.dungeonId == 'tide') {
      return rng.nextBool() ? _RoomSilhouette.oval : _RoomSilhouette.el;
    }
    if (kit.dungeonId == 'underworld') {
      return rng.nextBool() ? _RoomSilhouette.plus : _RoomSilhouette.diamond;
    }
    if (kit.dungeonId == 'sandy') {
      return rng.nextBool() ? _RoomSilhouette.oval : _RoomSilhouette.chamfer;
    }
    if (kit.dungeonId == 'goblin') {
      return rng.nextBool() ? _RoomSilhouette.blob : _RoomSilhouette.el;
    }
    if (kit.dungeonId == 'king') {
      return rng.nextBool() ? _RoomSilhouette.rect : _RoomSilhouette.plus;
    }
    if (kit.dungeonId == 'dead') {
      return rng.nextBool() ? _RoomSilhouette.diamond : _RoomSilhouette.blob;
    }
    if (kit.dungeonId == 'grove') {
      return rng.nextBool() ? _RoomSilhouette.blob : _RoomSilhouette.oval;
    }
    if (kit.dungeonId == 'veil') {
      return rng.nextBool() ? _RoomSilhouette.el : _RoomSilhouette.plus;
    }
    return switch (rng.nextInt(7)) {
      0 => _RoomSilhouette.rect,
      1 => _RoomSilhouette.oval,
      2 => _RoomSilhouette.diamond,
      3 => _RoomSilhouette.el,
      4 => _RoomSilhouette.plus,
      5 => _RoomSilhouette.chamfer,
      _ => _RoomSilhouette.blob,
    };
  }

  static bool _inSilhouette(
    _Rect r,
    int x,
    int y,
    _RoomSilhouette silhouette,
    int salt,
  ) {
    final lx = x - r.x;
    final ly = y - r.y;
    if (lx < 0 || ly < 0 || lx >= r.w || ly >= r.h) return false;
    final mx = r.w ~/ 2;
    final my = r.h ~/ 2;
    if ((lx - mx).abs() <= 1 && (ly - my).abs() <= 1) return true;
    final dx = lx - (r.w - 1) / 2.0;
    final dy = ly - (r.h - 1) / 2.0;
    switch (silhouette) {
      case _RoomSilhouette.rect:
        return true;
      case _RoomSilhouette.oval:
        final rx = max(1.2, r.w / 2.0 - 0.15);
        final ry = max(1.2, r.h / 2.0 - 0.15);
        return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.06;
      case _RoomSilhouette.diamond:
        final nx = dx.abs() / max(1.0, r.w / 2.0);
        final ny = dy.abs() / max(1.0, r.h / 2.0);
        return nx + ny <= 1.12;
      case _RoomSilhouette.el:
        final thickW = max(3, r.w ~/ 2);
        final thickH = max(3, r.h ~/ 2);
        if (salt.isOdd) {
          return lx < thickW || ly < thickH;
        }
        return lx >= r.w - thickW || ly >= r.h - thickH;
      case _RoomSilhouette.plus:
        final armW = max(3, r.w ~/ 3);
        final armH = max(3, r.h ~/ 3);
        return dx.abs() <= armW / 2 || dy.abs() <= armH / 2;
      case _RoomSilhouette.chamfer:
        final cut = max(2, min(r.w, r.h) ~/ 4);
        final fromL = lx;
        final fromR = r.w - 1 - lx;
        final fromT = ly;
        final fromB = r.h - 1 - ly;
        if (fromL + fromT < cut) return false;
        if (fromR + fromT < cut) return false;
        if (fromL + fromB < cut) return false;
        if (fromR + fromB < cut) return false;
        return true;
      case _RoomSilhouette.blob:
        final rx = max(1.2, r.w / 2.0);
        final ry = max(1.2, r.h / 2.0);
        final ang = atan2(dy, dx);
        final wobble =
            0.14 * sin(ang * 3 + salt) + 0.08 * cos(ang * 5 + salt * 0.37);
        return (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 0.92 + wobble;
    }
  }

  static void _carveRoomFootprint(
    _Rect r,
    void Function(int x, int y, TileKind k) set,
    _RoomSilhouette silhouette,
    Random rng,
  ) {
    final salt = rng.nextInt(64);
    for (var yy = r.y; yy < r.y + r.h; yy++) {
      for (var xx = r.x; xx < r.x + r.w; xx++) {
        if (_inSilhouette(r, xx, yy, silhouette, salt)) {
          set(xx, yy, TileKind.floor);
        }
      }
    }
    set(r.cx, r.cy, TileKind.floor);
    if (silhouette == _RoomSilhouette.blob ||
        silhouette == _RoomSilhouette.oval) {
      final nubs = 1 + rng.nextInt(3);
      for (var i = 0; i < nubs; i++) {
        final nx = r.x + rng.nextInt(max(1, r.w));
        final ny = r.y + rng.nextInt(max(1, r.h));
        if ((nx - r.cx).abs() + (ny - r.cy).abs() <= max(r.w, r.h) ~/ 2 + 1) {
          set(nx, ny, TileKind.floor);
          set(nx + (rng.nextBool() ? 1 : 0), ny, TileKind.floor);
        }
      }
    }
  }

  static TileMap _multiRoomFloor({
    required int cols,
    required int rows,
    required int fallbackRoomCount,
    required Random rng,
    required bool fortStyle,
    required int enemyCount,
    required String dungeonId,
    required int layoutSeed,
    required DungeonRoom room,
    int extraCombatRooms = 0,
    bool tightRooms = false,
  }) {
    final blueprint = FloorBlueprint.forRoom(
      room,
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
      extraCombatRooms: extraCombatRooms,
    );
    final kit = ZoneLayoutKit.forId(dungeonId);
    final storyBeats = blueprint.storyChambers;
    final tiles = List<TileKind>.filled(cols * rows, TileKind.wall);
    void set(int x, int y, TileKind k) {
      if (x < 0 || y < 0 || x >= cols || y >= rows) return;
      final i = y * cols + x;
      // Later corridor carves must not erase earlier chamber gates.
      if (k == TileKind.floor && tiles[i] == TileKind.gate) return;
      tiles[i] = k;
    }

    final rooms = <_Rect>[];
    final roomBeats = <FloorBeatKind?>[];
    final sideFlags = <bool>[];
    final parentOf = <int?>[];
    final pad = fortStyle ? 3 : 2;

    bool inBounds(_Rect r) =>
        r.x >= 1 && r.y >= 1 && r.x + r.w <= cols - 2 && r.y + r.h <= rows - 2;

    (int, int) sizeFor(FloorBeatKind kind) {
      (int, int) fit(int w, int h) => _scaledRoom(cols, rows, w, h);
      if (tightRooms &&
          kind != FloorBeatKind.treasure &&
          kind != FloorBeatKind.exitHold) {
        return fit(6 + rng.nextInt(2), 8 + rng.nextInt(2));
      }
      switch (kind) {
        case FloorBeatKind.approach:
          return fit(
            11 + rng.nextInt(4),
            8 + rng.nextInt(3),
          ); // hall, not closet
        case FloorBeatKind.hub:
          return fit(14 + rng.nextInt(3), 10 + rng.nextInt(2));
        case FloorBeatKind.choke:
          // Still the tightest room — but a fight can stand in it.
          if (rng.nextBool()) {
            return fit(6 + rng.nextInt(2), 9 + rng.nextInt(3));
          }
          return fit(9 + rng.nextInt(3), 6 + rng.nextInt(2));
        case FloorBeatKind.elite:
          return fit(9 + rng.nextInt(3), 8 + rng.nextInt(3));
        case FloorBeatKind.treasure:
          return fit(7 + rng.nextInt(2), 6 + rng.nextInt(2)); // side vault
        case FloorBeatKind.decoy:
          return fit(6 + rng.nextInt(2), 5 + rng.nextInt(2));
        case FloorBeatKind.boss:
          return fit(12 + rng.nextInt(3), 10 + rng.nextInt(3));
        case FloorBeatKind.exitHold:
          return fit(8 + rng.nextInt(3), 8 + rng.nextInt(2));
      }
    }

    bool tryPlaceRoom(
      _Rect cand,
      FloorBeatKind beat, {
      bool side = false,
      int? parent,
    }) {
      if (!inBounds(cand)) return false;
      if (rooms.any((r) => r.overlaps(cand, pad: pad))) return false;
      rooms.add(cand);
      roomBeats.add(beat);
      sideFlags.add(side);
      parentOf.add(parent);
      return true;
    }

    // Beat-driven carve: main path zigzags east; side alcoves branch off hub/last main.
    if (storyBeats.length >= 2) {
      final mainBeats = [
        for (final b in storyBeats)
          if (!b.isSide) b,
      ];
      final sideBeats = [
        for (final b in storyBeats)
          if (b.isSide) b,
      ];
      final spine = mainBeats.isEmpty ? storyBeats : mainBeats;

      for (var i = 0; i < spine.length; i++) {
        final beat = spine[i];
        final size = sizeFor(beat.kind);
        final w = size.$1;
        final h = size.$2;
        final t = spine.length == 1 ? 0.0 : i / (spine.length - 1);
        final minX = 2;
        final maxX = max(minX, cols - w - 3);
        final preferX = (minX + t * (maxX - minX)).round();
        final north = i.isEven;
        final spread = kit.verticalSpreadBoost;
        final midRow = rows ~/ 2;
        final yLo = north ? 2 : max(2, midRow - spread);
        final yHi = north
            ? max(3, midRow - h - 1 - spread ~/ 2)
            : max(yLo + 1, rows - h - 3 - spread ~/ 2);
        var placed = false;
        for (var attempt = 0; attempt < 64; attempt++) {
          final jx = rng.nextInt(5) - 2;
          final x = (preferX + jx).clamp(1, cols - w - 2);
          final ySpan = max(1, yHi - yLo);
          final y = (yLo + rng.nextInt(ySpan)).clamp(1, rows - h - 2);
          if (tryPlaceRoom(_Rect(x, y, w, h), beat.kind)) {
            placed = true;
            break;
          }
        }
        if (!placed) {
          for (var attempt = 0; attempt < 80; attempt++) {
            final x = 1 + rng.nextInt(max(1, cols - w - 2));
            final y = 1 + rng.nextInt(max(1, rows - h - 2));
            if (tryPlaceRoom(_Rect(x, y, w, h), beat.kind)) {
              placed = true;
              break;
            }
          }
        }
        if (!placed) break;
      }

      if (rooms.isNotEmpty) {
        var parentIdx = 0;
        for (var i = 0; i < rooms.length; i++) {
          if (!sideFlags[i]) parentIdx = i;
        }
        for (final beat in sideBeats) {
          final sideParentIdx = beat.attach == FloorBeatAttach.sideHub
              ? 0
              : parentIdx;
          final parent = rooms[sideParentIdx.clamp(0, rooms.length - 1)];
          final size = sizeFor(beat.kind);
          final w = size.$1;
          final h = size.$2;
          final cx = parent.x + (parent.w - w) ~/ 2;
          final candidates = <_Rect>[
            _Rect(cx, parent.y - h - pad - 1, w, h),
            _Rect(cx, parent.y + parent.h + pad + 1, w, h),
            _Rect(parent.x - w - pad - 1, parent.y + (parent.h - h) ~/ 2, w, h),
            _Rect(
              parent.x + rng.nextInt(max(1, parent.w)),
              parent.y - h - pad - 1,
              w,
              h,
            ),
            _Rect(
              parent.x + rng.nextInt(max(1, parent.w)),
              parent.y + parent.h + pad + 1,
              w,
              h,
            ),
          ];
          var placed = false;
          for (final cand in candidates) {
            if (tryPlaceRoom(
              cand,
              beat.kind,
              side: true,
              parent: sideParentIdx,
            )) {
              placed = true;
              break;
            }
          }
          if (!placed) {
            for (var attempt = 0; attempt < 80; attempt++) {
              final x = 1 + rng.nextInt(max(1, cols - w - 2));
              final y = 1 + rng.nextInt(max(1, rows - h - 2));
              if (tryPlaceRoom(
                _Rect(x, y, w, h),
                beat.kind,
                side: true,
                parent: sideParentIdx,
              )) {
                break;
              }
            }
          }
        }
      }
    }

    // Legacy scatter if beat carve failed to get a path.
    if (rooms.length < 2) {
      rooms.clear();
      roomBeats.clear();
      sideFlags.clear();
      parentOf.clear();
      var attempts = 0;
      while (rooms.length < fallbackRoomCount && attempts < 160) {
        attempts++;
        final sized = _scaledRoom(
          cols,
          rows,
          8 + rng.nextInt(5),
          7 + rng.nextInt(4),
        );
        final w = sized.$1;
        final h = sized.$2;
        final x = 1 + rng.nextInt(max(1, cols - w - 2));
        final y = 1 + rng.nextInt(max(1, rows - h - 2));
        final cand = _Rect(x, y, w, h);
        if (!inBounds(cand)) continue;
        if (rooms.any((r) => r.overlaps(cand, pad: pad))) continue;
        rooms.add(cand);
        final bi = rooms.length - 1;
        final beat = bi < storyBeats.length
            ? storyBeats[bi].kind
            : FloorBeatKind.approach;
        roomBeats.add(beat);
        sideFlags.add(bi < storyBeats.length && storyBeats[bi].isSide);
        parentOf.add(null);
      }
    }
    if (rooms.isEmpty) {
      final sized = _scaledRoom(cols, rows, 10, 8);
      rooms.add(_Rect(2, 2, sized.$1, sized.$2));
      rooms.add(
        _Rect(
          max(2, cols - sized.$1 - 4),
          max(2, rows - sized.$2 - 4),
          sized.$1,
          sized.$2,
        ),
      );
      roomBeats.addAll([FloorBeatKind.approach, FloorBeatKind.choke]);
      sideFlags.addAll([false, false]);
      parentOf.addAll([null, null]);
    }
    while (roomBeats.length < rooms.length) {
      roomBeats.add(FloorBeatKind.approach);
      sideFlags.add(false);
      parentOf.add(null);
    }

    for (var i = 0; i < rooms.length; i++) {
      _carveRoomFootprint(
        rooms[i],
        set,
        _silhouetteFor(roomBeats[i] ?? FloorBeatKind.approach, rng, kit),
        rng,
      );
    }

    final gateList = <GateInfo>[];
    void connect(int from, int to) {
      final nextBeat = roomBeats[to];
      final fromBeat = roomBeats[from];
      final narrow =
          nextBeat == FloorBeatKind.choke ||
          (kit.preferChoke && nextBeat != FloorBeatKind.approach);
      final broad =
          !narrow &&
          (fromBeat == FloorBeatKind.approach ||
              nextBeat == FloorBeatKind.approach);
      final gateTiles = _carveCorridorWithGate(
        set,
        rooms[from].cx,
        rooms[from].cy,
        rooms[to].cx,
        rooms[to].cy,
        narrow: narrow,
        broad: broad,
        horizontalFirst: rng.nextBool(),
        winding: rng.nextDouble() < kit.corridorWindingChance,
        rng: rng,
        rooms: rooms,
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
        gateList.add(GateInfo(id: id, x: gx, y: gy, opensAfterChamber: from));
      }
    }

    var prevMain = -1;
    for (var i = 0; i < rooms.length; i++) {
      if (sideFlags[i]) {
        final parent = parentOf[i] ?? (prevMain >= 0 ? prevMain : 0);
        connect(parent, i);
      } else {
        if (prevMain >= 0) connect(prevMain, i);
        prevMain = i;
      }
    }

    final start = rooms.first;
    var endIdx = 0;
    for (var i = 0; i < rooms.length; i++) {
      if (!sideFlags[i]) endIdx = i;
    }
    final end = rooms[endIdx];
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
          (g.x, g.y) == (start.cx, start.cy) || (g.x, g.y) == (end.cx, end.cy),
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
          beatKind: roomBeats[i],
        ),
    ];

    // Enemies in chambers after the first (chamber 0 = spawn staging).
    // Budgets come from matching story beats when lengths align.
    final enemySpawns = <(int, int)>[];
    final enemyChambers = <int>[];
    final seenSpawns = <String>{};
    final combatRooms = rooms.length == 1
        ? <(int, _Rect)>[(0, rooms.first)]
        : [for (var i = 1; i < rooms.length; i++) (i, rooms[i])];

    final partyPad = <String>{
      for (final p in spawnPoints) '${p.$1},${p.$2}',
      for (var dy = -1; dy <= 1; dy++)
        for (var dx = -1; dx <= 1; dx++) '${start.cx + dx},${start.cy + dy}',
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

    final budgetByChamber = <int, int>{};
    if (rooms.length == storyBeats.length) {
      for (var i = 0; i < storyBeats.length; i++) {
        final want = storyBeats[i].enemyBudget;
        if (want > 0) budgetByChamber[i] = want;
      }
    }
    if (budgetByChamber.isEmpty && combatRooms.isNotEmpty && enemyCount > 0) {
      // Fallback even split when beat/chamber counts diverged.
      final first = combatRooms.first;
      final firstPack = (enemyCount * 0.55).ceil().clamp(1, enemyCount);
      budgetByChamber[first.$1] = firstPack;
      var left = enemyCount - firstPack;
      final rest = combatRooms.skip(1).toList();
      for (var i = 0; i < rest.length; i++) {
        if (left <= 0) break;
        final share = i == rest.length - 1
            ? left
            : max(1, left ~/ (rest.length - i));
        budgetByChamber[rest[i].$1] = share;
        left -= share;
      }
    }

    for (final entry in combatRooms) {
      final want = budgetByChamber[entry.$1] ?? 0;
      // Treasure/decoy alcoves stay quiet unless budget was assigned.
      final beatKind = roomBeats[entry.$1];
      if ((beatKind == FloorBeatKind.treasure ||
              beatKind == FloorBeatKind.decoy) &&
          want <= 0) {
        continue;
      }
      fillRoom(entry.$2, entry.$1, want);
    }

    // Leftover: round-robin walkable cells in combat rooms (skip empty treasure/decoy).
    if (enemySpawns.length < enemyCount) {
      final pool = <(int x, int y, int ci)>[];
      for (final entry in combatRooms) {
        final beatKind = roomBeats[entry.$1];
        if ((beatKind == FloorBeatKind.treasure ||
                beatKind == FloorBeatKind.decoy) &&
            (budgetByChamber[entry.$1] ?? 0) <= 0) {
          continue;
        }
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
      blueprint: blueprint,
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
    final target = (floorCount * 0.12).floor().clamp(16, 140);
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
        MapProp(x: cell.$1, y: cell.$2, kind: pool[rng.nextInt(pool.length)]),
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

  /// Widen the stairs area so a party can stand near the exit.
  static void _carveExitPlaza(
    List<TileKind> tiles,
    int cols,
    int rows,
    int ex,
    int ey,
  ) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
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

  /// Carve an L-corridor; return gate tiles at the midpoint choke.
  ///
  /// Chokes are 2 tiles wide. Every other hall is 5.
  static List<(int, int)> _carveCorridorWithGate(
    void Function(int, int, TileKind) set,
    int x0,
    int y0,
    int x1,
    int y1, {
    bool narrow = false,
    bool broad = false,
    bool horizontalFirst = true,
    bool winding = false,
    Random? rng,
    List<_Rect> rooms = const [],
  }) {
    // Approach halls share the 5-wide hall.
    final span = narrow ? 2 : (broad ? 5 : 5);
    final left = span ~/ 2;
    final right = span - left - 1;

    bool deepInRoom(int x, int y) {
      for (final r in rooms) {
        if (x > r.x && x < r.x + r.w - 1 && y > r.y && y < r.y + r.h - 1) {
          return true;
        }
      }
      return false;
    }

    void paint(int x, int y, {required bool center}) {
      if (!center && deepInRoom(x, y)) return;
      set(x, y, TileKind.floor);
    }

    void carveWide(int x, int y, {required bool horizontal}) {
      for (var d = -left; d <= right; d++) {
        if (horizontal) {
          paint(x, y + d, center: d == 0);
        } else {
          paint(x + d, y, center: d == 0);
        }
      }
    }

    void fillElbow(int x, int y) {
      for (var dy = -left; dy <= right; dy++) {
        for (var dx = -left; dx <= right; dx++) {
          paint(x + dx, y + dy, center: dx == 0 && dy == 0);
        }
      }
    }

    void carveSegment({
      required bool horizontal,
      required int fromX,
      required int fromY,
      required int toX,
      required int toY,
      required List<(int, int)> path,
    }) {
      var x = fromX;
      var y = fromY;
      if (horizontal) {
        while (x != toX) {
          carveWide(x, y, horizontal: true);
          path.add((x, y));
          x += toX > x ? 1 : -1;
        }
      } else {
        while (y != toY) {
          carveWide(x, y, horizontal: false);
          path.add((x, y));
          y += toY > y ? 1 : -1;
        }
      }
    }

    final path = <(int, int)>[];
    if (horizontalFirst) {
      carveSegment(
        horizontal: true,
        fromX: x0,
        fromY: y0,
        toX: x1,
        toY: y0,
        path: path,
      );
      if (x0 != x1 && y0 != y1) fillElbow(x1, y0);
      carveSegment(
        horizontal: false,
        fromX: x1,
        fromY: y0,
        toX: x1,
        toY: y1,
        path: path,
      );
    } else {
      carveSegment(
        horizontal: false,
        fromX: x0,
        fromY: y0,
        toX: x0,
        toY: y1,
        path: path,
      );
      if (x0 != x1 && y0 != y1) fillElbow(x0, y1);
      carveSegment(
        horizontal: true,
        fromX: x0,
        fromY: y1,
        toX: x1,
        toY: y1,
        path: path,
      );
    }
    carveWide(x1, y1, horizontal: x0 != x1 && y0 == y1);
    path.add((x1, y1));

    if (winding && rng != null && path.length >= 5 && !narrow) {
      final detourAt = path.length ~/ 3;
      final base = path[detourAt];
      final steps = 1 + rng.nextInt(2);
      final dir = rng.nextBool() ? 1 : -1;
      if (rng.nextBool()) {
        for (var s = 1; s <= steps; s++) {
          carveWide(base.$1, base.$2 + dir * s, horizontal: false);
        }
      } else {
        for (var s = 1; s <= steps; s++) {
          carveWide(base.$1 + dir * s, base.$2, horizontal: true);
        }
      }
    }
    if (path.length < 3) return const <(int, int)>[];

    final mid = path[path.length ~/ 2];
    final mx = mid.$1;
    final my = mid.$2;
    final midIndex = path.length ~/ 2;
    final prev = path[midIndex - 1];
    final horizontal = prev.$2 == my;
    final gates = <(int, int)>[];
    for (var d = -left; d <= right; d++) {
      final gx = horizontal ? mx : mx + d;
      final gy = horizontal ? my + d : my;
      if (d != 0 && deepInRoom(gx, gy)) continue;
      gates.add((gx, gy));
    }
    return gates;
  }
}
