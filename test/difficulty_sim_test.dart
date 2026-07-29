import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// Difficulty probe + CI gates — run with:
///   flutter test test/difficulty_sim_test.dart --reporter expanded
void main() {
  test('difficulty probe: fresh / light / mid push win rates', () {
    final report = StringBuffer('\n=== DIFFICULTY PROBE ===\n');

    final rates = <String, Map<int, double>>{};

    void probe(String label, GameState base, {int trials = 10}) {
      report.writeln('\n## $label');
      rates[label] = <int, double>{};
      for (final floor in [1, 2, 3, 5, GameLogic.bossFloorFor(base)]) {
        var clears = 0;
        var wipes = 0;
        var timeouts = 0;
        var hpSum = 0.0;
        for (var t = 0; t < trials; t++) {
          var state = GameLogic.enterDungeon(base, dungeonId: 'sandy');
          state = GameLogic.setDungeonMode(state, DungeonMode.push);
          if (floor > 1) {
            state = state.copyWith(highestFloorCleared: floor);
            if (GameLogic.canTravelToFloor(state, floor)) {
              state = GameLogic.travelToFloor(state, floor);
            }
          }
          state = state.copyWith(layoutSeed: 1000 + t * 97 + floor * 13);
          state = state.copyWith(
            enemies: GameLogic.createEnemyGroup(
              state.currentRoom,
              dungeonId: 'sandy',
              fromState: state,
            ),
          );
          final r = _simulateFloor(state);
          if (r.cleared) {
            clears++;
            hpSum += r.hpPct;
          } else if (r.wiped) {
            wipes++;
          } else {
            timeouts++;
          }
        }
        final clearPct = clears / trials;
        rates[label]![floor] = clearPct;
        final avgHp = clears == 0 ? 0.0 : hpSum / clears;
        report.writeln(
          '  F${floor.toString().padLeft(2)}  '
          'clear=${(clearPct * 100).toStringAsFixed(0).padLeft(3)}%  '
          'wipe=${(wipes / trials * 100).toStringAsFixed(0).padLeft(3)}%  '
          'timeout=${(timeouts / trials * 100).toStringAsFixed(0).padLeft(3)}%  '
          'avgHpOnClear=${avgHp.toStringAsFixed(0)}%',
        );
      }
    }

    final fresh = GameLogic.createInitialState(now: DateTime(2026, 7, 27));
    probe('FRESH', fresh);
    probe('LIGHT', _lightForge(fresh));
    probe('GEAR10', _tenLootUpgrades(fresh));
    probe('MID', _midPower(fresh));

    final room = GameLogic.enterDungeon(fresh, dungeonId: 'sandy').currentRoom;
    final budget = GameLogic.roomCombatBudget(room, dungeonId: 'sandy');
    report.writeln(
      '\nF1 budget hp=${budget.hp} atk=${budget.attack} '
      'enemies=${room.enemyCount} type=${room.type.name}',
    );
    report.writeln(
      'fresh party ATK=${_partyAtk(fresh)} DEF=${_partyDef(fresh)} '
      'HP=${_partyHp(fresh)}',
    );
    report.writeln(
      'gearPressure FRESH='
      '${GameLogic.partyGearPressure(fresh).toStringAsFixed(2)} '
      'GEAR10=${GameLogic.partyGearPressure(_tenLootUpgrades(fresh)).toStringAsFixed(2)} '
      'MID=${GameLogic.partyGearPressure(_midPower(fresh)).toStringAsFixed(2)}',
    );
    // ignore: avoid_print
    print(report.toString());

    expect(budget.hp, greaterThan(400));
    expect(budget.attack, greaterThan(40));

    // —— CI gates (attrition difficulty, not one-shots / not trivia) ——
    final freshF1 = rates['FRESH']![1]!;
    final freshBoss = rates['FRESH']![GameLogic.bossFloorFor(fresh)]!;
    final gear10F1 = rates['GEAR10']![1]!;
    final gear10Boss = rates['GEAR10']![GameLogic.bossFloorFor(fresh)]!;
    final midF1 = rates['MID']![1]!;
    final midBoss = rates['MID']![GameLogic.bossFloorFor(fresh)]!;

    // Fresh can sometimes clear F1, but should not always wipe.
    expect(freshF1, greaterThanOrEqualTo(0.2));
    // Boss remains a wall for fresh parties.
    expect(freshBoss, lessThanOrEqualTo(0.3));
    // ~10 loot upgrades: early floors OK, boss not free.
    expect(gear10F1, greaterThanOrEqualTo(0.4));
    expect(gear10Boss, lessThanOrEqualTo(0.7));
    // Mid-power party can clear early floors.
    expect(midF1, greaterThanOrEqualTo(0.5));
    // Mid can at least sometimes clear boss (gear+forge matter).
    expect(midBoss, greaterThanOrEqualTo(0.3));
  });
}

GameState _lightForge(GameState s) {
  var next = s.copyWith(gold: 50000);
  for (var i = 0; i < 3; i++) {
    next = GameLogic.trainParty(next);
  }
  for (var i = 0; i < 2; i++) {
    next = GameLogic.upgradeAttack(next);
    next = GameLogic.upgradeDefense(next);
    next = GameLogic.upgradeVitality(next);
  }
  return next;
}

/// ~10 real loot upgrades on a fresh party (the "suddenly too easy" spike).
GameState _tenLootUpgrades(GameState s) {
  final stash = <EquipmentItem>[];
  final slots = [
    EquipmentSlot.weapon,
    EquipmentSlot.offHand,
    EquipmentSlot.cloak,
    EquipmentSlot.ring,
    EquipmentSlot.trinket,
    EquipmentSlot.chest,
    EquipmentSlot.hands,
    EquipmentSlot.boots,
    EquipmentSlot.neck,
    EquipmentSlot.head,
  ];
  for (var i = 0; i < slots.length; i++) {
    stash.add(
      GameLogic.createEquipment(
        slot: slots[i],
        rarity: i < 4 ? LootRarity.uncommon : LootRarity.common,
        battleNumber: 4 + (i % 3),
        bias: HeroRole.values[i % 3],
      ),
    );
  }
  return GameLogic.autoEquipBetterGear(s.copyWith(gearStash: stash));
}

GameState _midPower(GameState s) {
  var next = _lightForge(s).copyWith(
    gold: 200000,
    essence: 80,
    rogueUnlocked: true,
  );
  next = GameLogic.ensureRogueHero(next);
  for (var i = 0; i < 8; i++) {
    next = GameLogic.trainParty(next);
  }
  for (var i = 0; i < 6; i++) {
    next = GameLogic.upgradeAttack(next);
    next = GameLogic.upgradeDefense(next);
    next = GameLogic.upgradeVitality(next);
  }
  final stash = <EquipmentItem>[];
  for (final role in HeroRole.values) {
    for (final slot in [
      EquipmentSlot.weapon,
      EquipmentSlot.offHand,
      EquipmentSlot.cloak,
    ]) {
      stash.add(
        GameLogic.createEquipment(
          slot: slot,
          rarity: LootRarity.rare,
          battleNumber: 8,
          bias: role,
        ),
      );
    }
  }
  next = next.copyWith(gearStash: stash);
  return GameLogic.autoEquipBetterGear(next);
}

int _partyAtk(GameState s) =>
    s.heroes.fold(0, (n, h) => n + s.effectiveHeroAttack(h));
int _partyDef(GameState s) =>
    s.heroes.fold(0, (n, h) => n + s.effectiveHeroDefense(h));
int _partyHp(GameState s) =>
    s.heroes.fold(0, (n, h) => n + s.effectiveHeroMaxHp(h));

({bool cleared, bool wiped, bool timedOut, double hpPct}) _simulateFloor(
  GameState state, {
  double maxSeconds = 90,
}) {
  var world = SpatialCombat.build(state);
  var current = state;
  var elapsed = 0.0;
  const dt = 0.05;
  while (elapsed < maxSeconds) {
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
      return (
        cleared: true,
        wiped: false,
        timedOut: false,
        hpPct: maxHp == 0 ? 0 : hp * 100 / maxHp,
      );
    }
    if (current.isPartyDefeated || world.heroes.every((h) => !h.isAlive)) {
      return (cleared: false, wiped: true, timedOut: false, hpPct: 0);
    }
  }
  return (cleared: false, wiped: false, timedOut: true, hpPct: 0);
}
