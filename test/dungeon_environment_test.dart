import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/spatial/zone_layout_kit.dart';
import 'package:idle_party/ui/dungeon_environment.dart';
import 'package:idle_party/assets/kenney_assets.dart';

void main() {
  test('every dungeon has distinct ambient + atmosphere', () {
    final ambients = <int>{};
    final washes = <int>{};
    for (final def in DungeonCatalog.all) {
      ambients.add(DungeonEnvironment.ambient(def.id).toARGB32());
      washes.add(DungeonEnvironment.atmosphereWash(def.id).toARGB32());
      expect(KenneyAssets.floorVariantsForDungeon(def.id), isNotEmpty);
      expect(KenneyAssets.wallVariantsForDungeon(def.id), isNotEmpty);
      expect(KenneyAssets.propPoolForDungeon(def.id).length, greaterThanOrEqualTo(6));
      expect(
        KenneyAssets.propPoolForDungeon(def.id).toSet().length,
        greaterThanOrEqualTo(5),
      );
    }
    expect(ambients.length, DungeonCatalog.all.length);
    expect(washes.length, DungeonCatalog.all.length);
    // Sand floors must not use the edged lip tile (30).
    expect(KenneyAssets.floorSand, isNot(KenneyAssets.tile(30)));
    expect(KenneyAssets.floorSand, KenneyAssets.tile(48));
    // Lava / torch accents must not alias trap / fountain art.
    expect(KenneyAssets.hazardLava, isNot(KenneyAssets.trapSpikes));
    expect(KenneyAssets.torchAlt, isNot(KenneyAssets.fountainSlime));
  });

  test('floors scatter denser wall-biased props for atmosphere', () {
    for (final def in DungeonCatalog.all) {
      final map = RoomLayouts.forFloor(
        floorNumber: 3,
        room: DungeonRoom(
          floorNumber: 3,
          roomIndex: 0,
          type: RoomType.normal,
          enemyLevel: 8,
          enemyCount: 8,
        ),
        dungeonId: def.id,
      );
      expect(map.props.length, greaterThanOrEqualTo(16));
      expect(map.props.length, lessThanOrEqualTo(100));
      // Most clutter hugs walls so mid-room fight space stays clear.
      var edge = 0;
      for (final p in map.props) {
        final nearWall = [
          (0, 1),
          (0, -1),
          (1, 0),
          (-1, 0),
        ].any((d) {
          final t = map.at(p.x + d.$1, p.y + d.$2);
          return t == TileKind.wall;
        });
        if (nearWall) edge++;
      }
      expect(edge, greaterThan(map.props.length ~/ 2));
      // Every carved chamber should feel furnished.
      for (final chamber in map.chambers) {
        final inRoom = map.props.where((p) {
          return p.x >= chamber.x &&
              p.x < chamber.x + chamber.w &&
              p.y >= chamber.y &&
              p.y < chamber.y + chamber.h;
        }).length;
        final kit = ZoneLayoutKit.forId(def.id);
        final minExpected = kit.clutterPerChamberMin.clamp(3, 12);
        expect(
          inRoom,
          greaterThanOrEqualTo(min(minExpected, max(3, chamber.w * chamber.h ~/ 8))),
          reason: def.id,
        );
      }
    }
  });

  test('wall rim detection and gate orientation', () {
    // 5x5: carved plus in the middle, walls around.
    final tiles = List<TileKind>.filled(25, TileKind.wall);
    tiles[12] = TileKind.floor; // 2,2
    tiles[13] = TileKind.gate; // 3,2 — east of floor
    tiles[14] = TileKind.floor; // 4,2
    final map = TileMap(
      cols: 5,
      rows: 5,
      tiles: tiles,
      spawnPoints: const [(2, 2)],
      exitPoint: (4, 2),
      enemySpawns: const [],
      chambers: const [Chamber(index: 0, x: 2, y: 2, w: 1, h: 1)],
      gates: const [GateInfo(id: 0, x: 3, y: 2, opensAfterChamber: 0)],
    );

    expect(DungeonEnvironment.wallTouchesCarved(map, 2, 1), isTrue);
    expect(DungeonEnvironment.wallTouchesCarved(map, 0, 0), isFalse);
    expect(DungeonEnvironment.inChamber(map, 2, 2), isTrue);
    expect(DungeonEnvironment.inChamber(map, 3, 2), isFalse);
    expect(DungeonEnvironment.gateRunsEastWest(map, 3, 2), isTrue);
  });

  test('Crystal Spire arena keeps spawn, exit, and enemies apart', () {
    final map = RoomLayouts.forFloor(
      floorNumber: 2,
      room: const DungeonRoom(
        floorNumber: 2,
        roomIndex: 0,
        type: RoomType.normal,
        enemyLevel: 10,
        enemyCount: 10,
      ),
      dungeonId: 'crystal',
    );
    expect(map.spawnPoints, isNotEmpty);
    expect(
      map.spawnPoints.first,
      isNot((map.exitPoint.$1, map.exitPoint.$2)),
    );
    expect(map.exitPoint.$2, lessThan(map.spawnPoints.first.$2));
    final spawnPad = {
      for (final p in map.spawnPoints) '${p.$1},${p.$2}',
    };
    for (final e in map.enemySpawns) {
      expect(spawnPad.contains('${e.$1},${e.$2}'), isFalse);
      expect(map.at(e.$1, e.$2), TileKind.floor);
    }
  });
}
