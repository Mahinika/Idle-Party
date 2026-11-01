import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/gear_set.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('slow fight ticks ease Full to Lite, and a player pick stays', () async {
    final director = GameDirector.preview();
    await director.boot();
    director.enterDungeon();
    expect(director.state.inDungeon, isTrue);
    expect(director.state.vfxQuality, VfxQuality.full);

    for (var i = 0; i < 11; i++) {
      director.debugNoteFightBudget(49);
    }
    expect(director.state.vfxQuality, VfxQuality.full);

    director.debugNoteFightBudget(49);
    expect(director.state.vfxQuality, VfxQuality.lite);

    director.setVfxQuality(VfxQuality.full);
    for (var i = 0; i < 20; i++) {
      director.debugNoteFightBudget(80);
    }
    expect(director.state.vfxQuality, VfxQuality.full);
    director.dispose();
  });

  test('a fast tick forgives one slow tick, and the hub does not ease', () async {
    final fighting = GameDirector.preview();
    await fighting.boot();
    fighting.enterDungeon();
    for (var i = 0; i < 6; i++) {
      fighting.debugNoteFightBudget(49);
    }
    fighting.debugNoteFightBudget(10);
    for (var i = 0; i < 6; i++) {
      fighting.debugNoteFightBudget(49);
    }
    expect(fighting.state.vfxQuality, VfxQuality.full);
    fighting.debugNoteFightBudget(49);
    expect(fighting.state.vfxQuality, VfxQuality.lite);
    fighting.dispose();

    final hub = GameDirector.preview();
    await hub.boot();
    expect(hub.state.inDungeon, isFalse);
    for (var i = 0; i < 20; i++) {
      hub.debugNoteFightBudget(80);
    }
    expect(hub.state.vfxQuality, VfxQuality.full);
    hub.dispose();
  });

  test('ClassKits.defFor returns the first kit row for an id', () {
    final row = ClassKits.all.first;
    expect(ClassKits.defFor(row.id), same(row));
    expect(ClassKits.defFor(row.id), same(ClassKits.defFor(row.id)));
  });

  test('GearSets.wornCount follows the equipped map, not a later edit', () {
    EquipmentItem piece(EquipmentSlot slot) => EquipmentItem(
      id: slot.name,
      name: slot.name,
      slot: slot,
      rarity: LootRarity.rare,
      setId: 'sandy_plate',
    );

    final worn = {
      EquipmentSlot.head: piece(EquipmentSlot.head),
      EquipmentSlot.chest: piece(EquipmentSlot.chest),
    };
    expect(GearSets.wornCount(worn, 'sandy_plate'), 2);
    expect(GearSets.wornCount(worn, 'sandy_plate'), 2);
    expect(GearSets.wornCount(worn, 'other'), 0);

    final changed = Map<EquipmentSlot, EquipmentItem>.from(worn)
      ..[EquipmentSlot.legs] = piece(EquipmentSlot.legs);
    expect(GearSets.wornCount(changed, 'sandy_plate'), 3);
    expect(GearSets.wornCount(worn, 'sandy_plate'), 2);
  });

  test('the next step is cached until the goal or the gates change', () {
    SpatialCombat.debugClearWaypointCache();
    final map = _gapMap();
    final first = SpatialCombat.debugNextWaypoint(map, {}, 1.2, 2.2, 6.2, 2.2);
    final computes = SpatialCombat.debugWaypointComputes;
    expect(first, isNotNull);
    expect(SpatialCombat.debugNextWaypoint(map, {}, 1.4, 2.6, 6.1, 2.4), first);
    expect(SpatialCombat.debugWaypointComputes, computes);

    SpatialCombat.debugNextWaypoint(map, {}, 1.2, 2.2, 5.2, 1.2);
    expect(SpatialCombat.debugWaypointComputes, computes + 1);

    SpatialCombat.debugNextWaypoint(map, {3}, 1.2, 2.2, 6.2, 2.2);
    expect(SpatialCombat.debugWaypointComputes, computes + 2);
    SpatialCombat.debugClearWaypointCache();
  });
}

TileMap _gapMap() {
  const cols = 8;
  const rows = 5;
  final tiles = List<TileKind>.filled(cols * rows, TileKind.floor);
  for (var y = 0; y < rows; y++) {
    if (y == 1) continue;
    tiles[y * cols + 3] = TileKind.wall;
  }
  return TileMap(
    cols: cols,
    rows: rows,
    tiles: tiles,
    spawnPoints: const [(1, 2)],
    exitPoint: (6, 2),
    enemySpawns: const [(6, 2)],
  );
}
