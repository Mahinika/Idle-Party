import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/loot_pipeline.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/stats.dart';
import 'package:idle_party/models/zone_art.dart';
import 'package:idle_party/spatial/hideout_stash.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/assets/kenney_assets.dart';

void main() {
  test('goblin mid-pack sprites differ from king', () {
    final g = ZoneArt.byId('goblin').enemies;
    final k = ZoneArt.byId('king').enemies;
    expect(g.elite, isNot(k.elite));
    expect(
      g.forArchetype(EnemyArchetype.brute),
      isNot(k.forArchetype(EnemyArchetype.brute)),
    );
    expect(
      g.forArchetype(EnemyArchetype.tank),
      isNot(k.forArchetype(EnemyArchetype.tank)),
    );
    expect(
      g.forArchetype(EnemyArchetype.support),
      isNot(k.forArchetype(EnemyArchetype.support)),
    );
    expect(g.boss, CustomAssets.enemyBossGoblin);
    expect(g.trash, CustomAssets.enemyGoblinMite);
  });

  test('codex slinger matches combat bat', () {
    expect(
      KenneyAssets.enemySpriteForCodexName('Goblin Slinger'),
      CustomAssets.enemyBat,
    );
    expect(
      KenneyAssets.enemySpriteForArchetype(
        EnemyArchetype.ranged,
        dungeonId: 'goblin',
      ),
      CustomAssets.enemyBat,
    );
  });

  test('Hideout chest loot is richer and can add Stolen Coin', () {
    final room = DungeonRoom(
      floorNumber: 3,
      roomIndex: 0,
      type: RoomType.elite,
      enemyLevel: 6,
      enemyCount: 4,
    );
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 20))
        .copyWith(
          dungeonId: 'goblin',
          currentRoom: room,
          dungeonFloor: <DungeonRoom>[room],
        );
    final sandy = state.copyWith(dungeonId: 'sandy');
    var richer = false;
    var sawStolen = false;
    for (var seed = 0; seed < 40; seed++) {
      final g = LootPipeline.rollRoomChestLoot(
        state,
        random: Random(seed),
      );
      final s = LootPipeline.rollRoomChestLoot(
        sandy,
        random: Random(seed),
      );
      final gGold = g
          .where((d) => LootPipeline.isWalletGoldDrop(d))
          .fold<int>(0, (a, d) => a + d.amount);
      final sGold = s
          .where((d) => LootPipeline.isWalletGoldDrop(d))
          .fold<int>(0, (a, d) => a + d.amount);
      if (gGold > sGold) richer = true;
      if (g.any((d) => d.name == 'Stolen Coin')) sawStolen = true;
    }
    expect(richer, isTrue);
    expect(sawStolen, isTrue);
  });

  test('Hideout floors with chests spawn stash ambushes', () {
    // Treasure floors always socket a chest — ambush must appear.
    final room = DungeonRoom(
      floorNumber: 4,
      roomIndex: 0,
      type: RoomType.treasure,
      enemyLevel: 5,
      enemyCount: 2,
    );
    final enemies = [
      EnemyUnit(
        name: 'Goblin Scrapper',
        level: 5,
        currentHp: 40,
        stats: Stats.enemy(attack: 8, defense: 2, maxHp: 40),
        rewardGold: 5,
        role: EnemyRole.normal,
        archetype: EnemyArchetype.swarm,
      ),
      EnemyUnit(
        name: 'Hideout Runt',
        level: 5,
        currentHp: 35,
        stats: Stats.enemy(attack: 7, defense: 1, maxHp: 35),
        rewardGold: 4,
        role: EnemyRole.normal,
        archetype: EnemyArchetype.swarm,
      ),
    ];
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 20))
        .copyWith(
          dungeonId: 'goblin',
          currentRoom: room,
          dungeonFloor: <DungeonRoom>[room],
          enemies: enemies,
          layoutSeed: 42,
        );
    final map = RoomLayouts.forFloor(
      floorNumber: 4,
      room: room,
      dungeonId: 'goblin',
      layoutSeed: 42,
    );
    expect(map.lootChestPoints, isNotEmpty);

    final world = SpatialCombat.build(state);
    final stash = world.enemies.where(
      (e) => e.name == 'Stash Guard' || e.name == 'Loot Snatcher',
    );
    expect(stash.length, greaterThanOrEqualTo(map.lootChestPoints.length));
    expect(world.enemies.length, greaterThan(enemies.length));
  });

  test('planAmbushes scales with chest count', () {
    final map = RoomLayouts.forFloor(
      floorNumber: 6,
      room: DungeonRoom(
        floorNumber: 6,
        roomIndex: 0,
        type: RoomType.treasure,
        enemyLevel: 1,
        enemyCount: 0,
      ),
      dungeonId: 'goblin',
      layoutSeed: 11,
    );
    final plan = HideoutStash.planAmbushes(
      map: map,
      firstCombatChamber: 1,
      threatScale: 1,
      rng: Random(3),
    );
    expect(plan, isNotEmpty);
    expect(plan.length, greaterThanOrEqualTo(map.lootChestPoints.length));
  });
}
