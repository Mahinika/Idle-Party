import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/enemy_flavor.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/enemy.dart';

void main() {
  test('pack jobs split a 9-body floor into swarm, backline, elite', () {
    expect(
      EnemyFlavor.packJobFor(index: 0, count: 9, type: RoomType.normal),
      PackJob.swarm,
    );
    expect(
      EnemyFlavor.packJobFor(index: 4, count: 9, type: RoomType.normal),
      PackJob.backline,
    );
    expect(
      EnemyFlavor.packJobFor(index: 8, count: 9, type: RoomType.normal),
      PackJob.elite,
    );
  });

  test('first chamber leans swarm, last chamber leans elites', () {
    const room = DungeonRoom(
      floorNumber: 8,
      roomIndex: 0,
      type: RoomType.normal,
      enemyLevel: 8,
      enemyCount: 9,
    );
    final group = GameLogic.createEnemyGroup(room, dungeonId: 'sandy');
    expect(group.length, 9);
    final first = group.take(3).map((e) => e.archetype).toList();
    final last = group.skip(6).map((e) => e.archetype).toList();
    final frontBrawlers = first
        .where(
          (a) => a == EnemyArchetype.swarm || a == EnemyArchetype.brute,
        )
        .length;
    final rearElites = last
        .where(
          (a) =>
              a == EnemyArchetype.tank ||
              a == EnemyArchetype.brute ||
              a == EnemyArchetype.glass,
        )
        .length;
    expect(frontBrawlers, greaterThanOrEqualTo(2));
    expect(rearElites, greaterThanOrEqualTo(2));
  });

  test('Brass mixes more tanks than Tide; Tide mixes more ranged', () {
    var brassTanks = 0;
    var tideTanks = 0;
    var brassRanged = 0;
    var tideRanged = 0;
    const n = 240;
    for (var i = 0; i < n; i++) {
      final brass = EnemyFlavor.pickArchetype(
        type: RoomType.normal,
        isBossUnit: false,
        dungeonId: 'brass',
        index: i % 9,
        count: 9,
        rng: Random(i + 17),
      );
      final tide = EnemyFlavor.pickArchetype(
        type: RoomType.normal,
        isBossUnit: false,
        dungeonId: 'tide',
        index: i % 9,
        count: 9,
        rng: Random(i + 17),
      );
      if (brass == EnemyArchetype.tank) brassTanks++;
      if (tide == EnemyArchetype.tank) tideTanks++;
      if (brass == EnemyArchetype.ranged) brassRanged++;
      if (tide == EnemyArchetype.ranged) tideRanged++;
    }
    expect(brassTanks, greaterThan(tideTanks));
    expect(tideRanged, greaterThan(brassRanged));
  });

  test('every zone has unique elite names, not generic Golem', () {
    for (final dungeon in DungeonCatalog.all) {
      final name = EnemyFlavor.eliteName(dungeon.id, EnemyArchetype.tank);
      expect(name, isNot(equals('Bulwark Golem')));
      expect(name, isNotEmpty);
    }
    expect(EnemyFlavor.eliteName('goblin', EnemyArchetype.tank), 'Stash Bulwark');
    expect(EnemyFlavor.eliteName('brass', EnemyArchetype.tank), 'Cog Ward');
    expect(EnemyFlavor.trashName('brass', EnemyArchetype.tank, 0), 'Brass Bulwark');
  });

  test('boss tells are unique per zone', () {
    expect(EnemyFlavor.bossTell('brass'), 'WIND-UP');
    expect(EnemyFlavor.bossTell('tide'), 'WAVE');
    expect(EnemyFlavor.bossTell('fen'), 'SPIT');
    expect(EnemyFlavor.bossTell('sandy'), 'SLAM');
    final tells = {for (final d in DungeonCatalog.all) EnemyFlavor.bossTell(d.id)};
    expect(tells.length, DungeonCatalog.all.length);
    expect(tells.contains('PULSE'), isFalse);
  });

  test('Gauntlet every-5 bosses cycle distinct cave tells', () {
    expect(EnemyFlavor.gauntletTellCycle.length, DungeonCatalog.all.length);
    expect(EnemyFlavor.gauntletTellCycle.toSet().length, 15);
    expect(EnemyFlavor.gauntletBossTell(5), 'SHARD');
    expect(EnemyFlavor.gauntletBossTell(10), 'WAVE');
    expect(EnemyFlavor.gauntletBossTell(15), 'WIND-UP');
    expect(EnemyFlavor.gauntletBossTell(10), isNot(EnemyFlavor.gauntletBossTell(5)));
    expect(EnemyFlavor.gauntletBossTell(80), 'SHARD');
  });

  test('week-1 Sandy leans brawlers; Goblin leans glass and support', () {
    var sandyBrawlers = 0;
    var goblinBrawlers = 0;
    var sandyGlassSupport = 0;
    var goblinGlassSupport = 0;
    const n = 240;
    for (var i = 0; i < n; i++) {
      final sandy = EnemyFlavor.pickArchetype(
        type: RoomType.normal,
        isBossUnit: false,
        dungeonId: 'sandy',
        index: i % 9,
        count: 9,
        rng: Random(i + 17),
      );
      final goblin = EnemyFlavor.pickArchetype(
        type: RoomType.normal,
        isBossUnit: false,
        dungeonId: 'goblin',
        index: i % 9,
        count: 9,
        rng: Random(i + 17),
      );
      bool brawler(EnemyArchetype a) =>
          a == EnemyArchetype.brute || a == EnemyArchetype.tank;
      bool glassSupport(EnemyArchetype a) =>
          a == EnemyArchetype.glass || a == EnemyArchetype.support;
      if (brawler(sandy)) sandyBrawlers++;
      if (brawler(goblin)) goblinBrawlers++;
      if (glassSupport(sandy)) sandyGlassSupport++;
      if (glassSupport(goblin)) goblinGlassSupport++;
    }
    expect(sandyBrawlers, greaterThan(goblinBrawlers));
    expect(goblinGlassSupport, greaterThan(sandyGlassSupport));
  });

  test('week-1 Sandy starter floor is not one cloned archetype', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 9, 13));
    expect(state.dungeonId, 'sandy');
    final types = state.enemies.map((e) => e.archetype).toSet();
    expect(state.enemies.length, greaterThanOrEqualTo(3));
    expect(types.length, greaterThan(1));
    expect(
      {for (final e in state.enemies) e.name}.length,
      greaterThan(1),
    );
  });
}
