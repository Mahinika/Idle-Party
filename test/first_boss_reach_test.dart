import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// The opening boss is the door to tomorrow's job. A fresh party that
/// clears floor 1 at full health used to wipe on floor 2 every seed.
void main() {
  test('opening boss is three bodies, not the later six-pack', () {
    final room = DungeonGenerator.generateFloorRoom(
      floorNumber: 2,
      ascensionLevel: 0,
      dungeonId: 'sandy',
      bossFloor: 2,
    );
    expect(room.type, RoomType.boss);
    expect(room.enemyCount, 3);

    final later = DungeonGenerator.generateFloorRoom(
      floorNumber: 5,
      ascensionLevel: 0,
      dungeonId: 'sandy',
      bossFloor: 5,
    );
    expect(later.type, RoomType.boss);
    expect(later.enemyCount, greaterThanOrEqualTo(6));
  });

  test('a fresh party and a short forge can finish the opening boss', () {
    final fresh = GameLogic.createInitialState(now: DateTime(2026, 10, 9));
    final light = _lightForge(fresh);
    final freshRate = _clearRate(fresh, trials: 6);
    final lightRate = _clearRate(light, trials: 6);
    expect(freshRate.rate, greaterThanOrEqualTo(0.8));
    expect(freshRate.avgHp, inInclusiveRange(30, 85));
    expect(lightRate.rate, greaterThanOrEqualTo(0.8));
  });
}

GameState _lightForge(GameState s) {
  var next = s.copyWith(
    gold: 50000,
    heroRoster: [
      for (final h in s.heroRoster) h.copyWith(level: h.level + 3),
    ],
  );
  for (var i = 0; i < 2; i++) {
    next = GameLogic.upgradeAttack(next);
    next = GameLogic.upgradeDefense(next);
    next = GameLogic.upgradeVitality(next);
  }
  return next;
}

({int clears, double rate, double avgHp}) _clearRate(
  GameState base, {
  required int trials,
}) {
  var clears = 0;
  var hpSum = 0.0;
  for (var t = 0; t < trials; t++) {
    var state = GameLogic.enterDungeon(base, dungeonId: 'sandy');
    state = GameLogic.completeCurrentRoom(
      state,
      goldGain: 10,
      skipLootRoll: true,
    );
    expect(state.currentRoom.floorNumber, 2);
    expect(state.currentRoom.type, RoomType.boss);
    state = state.copyWith(layoutSeed: 1000 + t * 97);
    state = state.copyWith(
      enemies: GameLogic.createEnemyGroup(
        state.currentRoom,
        dungeonId: 'sandy',
        fromState: state,
      ),
    );
    final hp = _hpOnClear(state);
    if (hp != null) {
      clears++;
      hpSum += hp;
    }
  }
  return (
    clears: clears,
    rate: clears / trials,
    avgHp: clears == 0 ? 0 : hpSum / clears,
  );
}

double? _hpOnClear(GameState state) {
  var world = SpatialCombat.build(state);
  var current = state;
  var elapsed = 0.0;
  const dt = 0.05;
  while (elapsed < 90) {
    final step = SpatialCombat.step(world, current, dt: dt);
    world = step.world;
    current = step.state;
    elapsed += dt;
    if (step.roomCleared) {
      final maxHp = current.heroes.fold<int>(
        0,
        (n, h) => n + current.effectiveHeroMaxHp(h),
      );
      final hp = current.heroes.fold<int>(0, (n, h) => n + h.currentHp);
      return maxHp == 0 ? 0 : hp * 100 / maxHp;
    }
    if (current.isPartyDefeated || world.heroes.every((h) => !h.isAlive)) {
      return null;
    }
  }
  return null;
}
