import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  test('treasure floor clears via spatial timer', () {
    final treasure = DungeonRoom(
      floorNumber: 4,
      roomIndex: 0,
      type: RoomType.treasure,
      enemyLevel: 4,
      enemyCount: 0,
    );
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(
      currentRoom: treasure,
      dungeonFloor: <DungeonRoom>[treasure],
      enemies: const [],
    );
    var world = SpatialCombat.build(state);
    expect(world.isTreasure, isTrue);

    var cleared = false;
    for (var i = 0; i < 40; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
      if (step.roomCleared) {
        cleared = true;
        break;
      }
    }
    expect(cleared, isTrue);
  });

  test('combat floor map is multi-room and walkable', () {
    final room = DungeonGenerator.generateFloor(1).first;
    final map = RoomLayouts.forFloor(
      floorNumber: 1,
      room: room,
      dungeonId: 'sandy',
    );
    expect(map.roomCenters.length, greaterThanOrEqualTo(3));
    expect(map.enemySpawns, isNotEmpty);
    expect(map.isWalkable(map.spawnPoints.first.$1, map.spawnPoints.first.$2),
        isTrue);
  });

  test('god hand damages nearby enemies', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final world = SpatialCombat.build(state);
    expect(world.enemies, isNotEmpty);
    final target = world.enemies.first;
    final before = target.hp;
    SpatialCombat.godHand(
      world,
      state,
      tileX: target.x,
      tileY: target.y,
      baseDamage: 50,
    );
    expect(target.hp, lessThan(before));
  });

  test('weapon pattern fires spread projectiles', () {
    final weapon = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 5,
      bias: HeroRole.mage,
    ).copyWith(pattern: ProjectilePattern.spread);
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final heroes = [...state.heroes];
    final mageIndex = heroes.indexWhere((h) => h.role == HeroRole.mage);
    expect(mageIndex, greaterThanOrEqualTo(0));
    heroes[mageIndex] = heroes[mageIndex].copyWith(
      equipped: {
        ...heroes[mageIndex].equipped,
        EquipmentSlot.weapon: weapon,
      },
    );
    state = state.copyWith(heroes: heroes, attackBonus: 20);
    var world = SpatialCombat.build(state);
    // Soften the room so the mage lives long enough to cast.
    for (final e in world.enemies) {
      e.hp = 1;
      e.dormant = true;
    }
    final target = world.enemies.first;
    target.dormant = false;
    final mage = world.heroes.firstWhere((h) => h.heroRole == HeroRole.mage);
    mage
      ..x = target.x - 2.2
      ..y = target.y
      ..fireCooldown = 0;
    for (var i = 0; i < 30; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
      state = step.state;
      if (world.projectiles.isNotEmpty) {
        break;
      }
    }
    expect(world.projectiles, isNotEmpty);
  });

  test('heroes advance toward enemies and stay separated', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    var world = SpatialCombat.build(state);
    expect(world.heroes, isNotEmpty);
    expect(world.enemies, isNotEmpty);

    final start = [
      for (final h in world.heroes) (h.x, h.y),
    ];
    final enemy = world.enemies.first;
    final startDist = [
      for (final h in world.heroes)
        ((h.x - enemy.x).abs() + (h.y - enemy.y).abs()),
    ];

    for (var i = 0; i < 45; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
    }

    var moved = false;
    for (var i = 0; i < world.heroes.length; i++) {
      final h = world.heroes[i];
      if (!h.isAlive) continue;
      final dx = (h.x - start[i].$1).abs();
      final dy = (h.y - start[i].$2).abs();
      if (dx + dy > 0.2) moved = true;
      final dist =
          ((h.x - enemy.x).abs() + (h.y - enemy.y).abs());
      // Fire Blink can kite away once in range — allow slack for that kit.
      final blinkSlack =
          ClassKits.isUnlocked(AbilityId.blink, h.heroLevel) ? 3.0 : 0.05;
      expect(dist, lessThanOrEqualTo(startDist[i] + blinkSlack));
    }
    expect(moved, isTrue);

    // Soft separation: living heroes should not fully stack.
    for (var i = 0; i < world.heroes.length; i++) {
      for (var j = i + 1; j < world.heroes.length; j++) {
        final a = world.heroes[i];
        final b = world.heroes[j];
        if (!a.isAlive || !b.isAlive) continue;
        final d = ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
        expect(d, greaterThan(0.04));
      }
    }
  });

  test('god hand guides party toward tap point', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    var world = SpatialCombat.build(state);
    final hero = world.heroes.first;
    final targetX = (hero.x + 4).clamp(1.0, world.cols - 2.0);
    final targetY = hero.y;
    SpatialCombat.godHand(
      world,
      state,
      tileX: targetX,
      tileY: targetY,
      baseDamage: 1,
    );
    expect(world.guideTimer, greaterThan(0));

    final startX = hero.x;
    for (var i = 0; i < 20; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
    }
    expect((world.heroes.first.x - startX).abs(), greaterThan(0.15));
  });

  test('multi-room floors include chambers and gates', () {
    final room = DungeonGenerator.generateFloor(1).first;
    final map = RoomLayouts.forFloor(
      floorNumber: 1,
      room: room,
      dungeonId: 'sandy',
    );
    expect(map.chambers.length, greaterThanOrEqualTo(3));
    expect(map.gates, isNotEmpty);
    final gate = map.gates.first;
    expect(map.isWalkable(gate.x, gate.y), isFalse);
    expect(
      map.isWalkable(gate.x, gate.y, openGateIds: {gate.id}),
      isTrue,
    );
  });

  test('party reaches later chambers after clearing earlier ones', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    var world = SpatialCombat.build(state);
    for (var seed = 0; seed < 40 && world.map.gates.isEmpty; seed++) {
      state = state.copyWith(layoutSeed: seed);
      world = SpatialCombat.build(state);
    }
    expect(world.map.gates, isNotEmpty);

    // Clear every enemy in the starting combat chamber so the gate opens.
    final startChamber = world.activeChamber;
    for (final enemy in world.enemies) {
      if (enemy.chamberIndex <= startChamber) enemy.hp = 0;
    }
    SpatialCombat.step(world, state, dt: 0.05);
    expect(world.openGateIds, isNotEmpty);

    final later =
        world.enemies.where((e) => e.hp > 0 && !e.dormant);
    expect(later, isNotEmpty);

    // Heroes should be able to path into the next chamber.
    final hero = world.heroes.firstWhere((h) => h.isAlive);
    final target = later.first;
    var reached = false;
    for (var i = 0; i < 900; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
      state = step.state;
      if ((hero.x - target.x).abs() + (hero.y - target.y).abs() < 4.0) {
        reached = true;
        break;
      }
      if (world.allEnemiesDead) {
        reached = true;
        break;
      }
    }
    expect(reached, isTrue);
  });

  test('god hand applies cooldown after use', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final world = SpatialCombat.build(state);
    final target = world.enemies.first;
    SpatialCombat.godHand(
      world,
      state,
      tileX: target.x,
      tileY: target.y,
      baseDamage: 5,
    );
    expect(world.godHandCooldown, greaterThan(0));
    expect(world.pulseTimer, greaterThan(0));
  });

  test('kills spawn ground loot and combat floaters', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    var world = SpatialCombat.build(state);
    final target = world.enemies.firstWhere((e) => e.hp > 0 && !e.dormant);
    SpatialCombat.godHand(
      world,
      state,
      tileX: target.x,
      tileY: target.y,
      baseDamage: 9999,
    );
    expect(world.floaters, isNotEmpty);
    expect(
      world.floaters.any((f) => f.text.contains('g') || f.text == 'LOOT!'),
      isTrue,
    );
    expect(world.groundLoot, isNotEmpty);
    expect(world.groundLoot.first.kind, isNot(GroundLootKind.gold));

    // Walk a hero onto loot and step until pickup floats.
    final loot = world.groundLoot.first;
    world.heroes.first
      ..x = loot.x
      ..y = loot.y;
    for (var i = 0; i < 3; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
    }
    expect(
      world.floaters.any(
        (f) => f.text.contains('…') || f.text.length > 2,
      ),
      isTrue,
    );
  });

  test('useConsumable heals party and clears flask slot', () {
    final flask = GameLogic.createEquipment(
      slot: EquipmentSlot.consumable,
      rarity: LootRarity.common,
      battleNumber: 1,
    );
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    state = state.copyWith(
      heroes: [
        for (var i = 0; i < state.heroes.length; i++)
          state.heroes[i].copyWith(
            currentHp: (state.heroes[i].maxHp / 2).floor().clamp(
              1,
              state.heroes[i].maxHp,
            ),
            equipped: i == 0
                ? {EquipmentSlot.consumable: flask}
                : const <EquipmentSlot, EquipmentItem>{},
          ),
      ],
    );
    final before = state.heroes.first.currentHp;
    state = GameLogic.useConsumable(state);
    expect(state.heroes.first.itemIn(EquipmentSlot.consumable), isNull);
    expect(state.heroes.first.currentHp, greaterThan(before));
  });

  test('lifetime gold unlocks dungeons, not wallet gold', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(gold: 0, lifetimeGoldEarned: 6000);
    expect(
      DungeonCatalog.isUnlocked(
        'goblin',
        state.lifetimeGoldEarned,
        state.highestDungeonCleared,
      ),
      isTrue,
    );
  });

  test('party of 4 can clear exit without soft-lock', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(rogueUnlocked: true);
    state = GameLogic.ensureRogueHero(state);
    expect(state.heroes, hasLength(4));

    // Keep enemies in state so build creates a combat map (not treasure).
    var world = SpatialCombat.build(state);
    expect(world.isTreasure, isFalse);
    expect(world.map.spawnPoints.length, greaterThanOrEqualTo(4));

    for (final e in world.enemies) {
      e.hp = 0;
    }
    world.awaitingExit = true;
    world.exitWaitTimer = 0;
    world.clearedChambers.addAll(
      world.map.chambers.map((c) => c.index),
    );
    for (final gate in world.map.gates) {
      world.openGateIds.add(gate.id);
    }

    // Park party near exit with natural spread (simulates arrival).
    final ex = world.map.exitPoint.$1 + 0.5;
    final ey = world.map.exitPoint.$2 + 0.5;
    final offsets = <(double, double)>[
      (0.0, 0.0),
      (-0.9, 0.4),
      (0.9, 0.4),
      (0.0, -0.9),
    ];
    for (var i = 0; i < world.heroes.length; i++) {
      world.heroes[i].x = ex + offsets[i].$1;
      world.heroes[i].y = ey + offsets[i].$2;
      world.heroes[i].hp = world.heroes[i].maxHp;
    }

    var cleared = false;
    for (var i = 0; i < 90; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
      if (step.roomCleared) {
        cleared = true;
        break;
      }
    }
    expect(cleared, isTrue);
  });

  test('exit clears when one hero reaches stairs while others are far', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(rogueUnlocked: true);
    state = GameLogic.ensureRogueHero(state);
    var world = SpatialCombat.build(state);
    expect(world.isTreasure, isFalse);
    for (final e in world.enemies) {
      e.hp = 0;
    }
    world.awaitingExit = true;
    world.exitWaitTimer = 0;
    for (final gate in world.map.gates) {
      world.openGateIds.add(gate.id);
    }

    final ex = world.map.exitPoint.$1 + 0.5;
    final ey = world.map.exitPoint.$2 + 0.5;
    final spawn = world.map.spawnPoints.first;
    // One on stairs, three stuck far away near spawn.
    world.heroes[0].x = ex;
    world.heroes[0].y = ey;
    world.heroes[0].hp = world.heroes[0].maxHp;
    for (var i = 1; i < world.heroes.length; i++) {
      world.heroes[i].x = spawn.$1 + 0.5 + i * 0.2;
      world.heroes[i].y = spawn.$2 + 0.5;
      world.heroes[i].hp = world.heroes[i].maxHp;
    }

    var cleared = false;
    for (var i = 0; i < 30; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
      if (step.roomCleared) {
        cleared = true;
        break;
      }
    }
    expect(cleared, isTrue);
  });

  test('exit force-clears after long stuck wait', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4))
        .copyWith(rogueUnlocked: true);
    state = GameLogic.ensureRogueHero(state);
    var world = SpatialCombat.build(state);
    expect(world.isTreasure, isFalse);
    for (final e in world.enemies) {
      e.hp = 0;
    }
    world.awaitingExit = true;
    world.exitWaitTimer = 10.1; // already past failsafe
    for (final gate in world.map.gates) {
      world.openGateIds.add(gate.id);
    }
    final spawn = world.map.spawnPoints.first;
    for (final hero in world.heroes) {
      hero.x = spawn.$1 + 0.5;
      hero.y = spawn.$2 + 0.5;
      hero.hp = hero.maxHp;
    }

    final step = SpatialCombat.step(world, state, dt: 0.05);
    expect(step.roomCleared, isTrue);
  });
}
