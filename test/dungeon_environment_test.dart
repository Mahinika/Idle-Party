import 'package:flutter_test/flutter_test.dart';

import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/ui/dungeon_environment.dart';
import 'package:idle_party/ui/kenney_assets.dart';

void main() {
  test('every dungeon has distinct ambient + atmosphere', () {
    final ambients = <int>{};
    final washes = <int>{};
    for (final def in DungeonCatalog.all) {
      ambients.add(DungeonEnvironment.ambient(def.id).toARGB32());
      washes.add(DungeonEnvironment.atmosphereWash(def.id).toARGB32());
      expect(KenneyAssets.floorVariantsForDungeon(def.id), isNotEmpty);
      expect(KenneyAssets.wallVariantsForDungeon(def.id), isNotEmpty);
      expect(KenneyAssets.propPoolForDungeon(def.id).length, greaterThanOrEqualTo(3));
    }
    expect(ambients.length, DungeonCatalog.all.length);
    expect(washes.length, DungeonCatalog.all.length);
    // Sand floors must not use the edged lip tile (30).
    expect(KenneyAssets.floorSand, isNot(KenneyAssets.tile(30)));
    expect(KenneyAssets.floorSand, KenneyAssets.tile(48));
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
}
