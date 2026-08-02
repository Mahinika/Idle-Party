import 'dart:math';

import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// Shared SpatialCombat floor runner for balance / difficulty tools.
class FloorSimResult {
  const FloorSimResult({
    required this.cleared,
    required this.wiped,
    required this.timedOut,
    required this.seconds,
    required this.hpPct,
    required this.gold,
    required this.combatElapsed,
    required this.damageByHeroId,
    required this.damageBySpec,
    required this.hpPctByHeroId,
    required this.hpPctBySpec,
    required this.state,
  });

  final bool cleared;
  final bool wiped;
  final bool timedOut;
  final double seconds;
  final double hpPct;
  final int gold;
  final double combatElapsed;
  final Map<String, int> damageByHeroId;
  final Map<HeroSpecId, int> damageBySpec;
  final Map<String, double> hpPctByHeroId;
  final Map<HeroSpecId, double> hpPctBySpec;
  final GameState state;
}

/// Seed equipment rolls so forge/gear presets are deterministic across runs.
void seedEquipmentRng([int seed = 42]) {
  EquipmentFactory.random = Random(seed);
}

GameState createPartyState({
  required List<HeroSpecId> partySpecs,
  DateTime? now,
}) {
  assert(partySpecs.length == GameLogic.starterPartySize);
  return GameLogic.createInitialState(
    now: now ?? DateTime(2026, 8, 1),
    partySpecs: partySpecs,
  );
}

GameState levelPartyTo(GameState state, int level) {
  final lvl = level.clamp(1, 60);
  final leveled = [
    for (final h in state.heroes) h.copyWith(level: lvl),
  ];
  var next = state.copyWith(heroes: leveled);
  next = next.copyWith(
    heroes: [
      for (final h in next.heroes)
        h.copyWith(currentHp: next.effectiveHeroMaxHp(h)),
    ],
  );
  return next;
}

GameState fullHeal(GameState state) => state.copyWith(
      heroes: [
        for (final h in state.heroes)
          h.copyWith(currentHp: state.effectiveHeroMaxHp(h)),
      ],
    );

GameState withLightForge(GameState state) {
  var next = state.copyWith(gold: 50000);
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

/// Mid power without forcing a 4th (rogue) hero — keeps party size stable.
GameState withMidPower(GameState state) {
  var next = withLightForge(state).copyWith(gold: 200000, essence: 80);
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

GameState applyPowerBand(GameState state, String band) {
  return switch (band) {
    'fresh' => state,
    'light' => withLightForge(state),
    'mid' => withMidPower(state),
    _ => throw ArgumentError('Unknown band: $band'),
  };
}

GameState enterFloor(
  GameState base, {
  required String dungeonId,
  required int floor,
  required int seed,
}) {
  var state = GameLogic.enterDungeon(base, dungeonId: dungeonId);
  state = GameLogic.setDungeonMode(state, DungeonMode.push);
  if (floor > 1) {
    state = state.copyWith(highestFloorCleared: floor);
    if (GameLogic.canTravelToFloor(state, floor)) {
      state = GameLogic.travelToFloor(state, floor);
    }
  }
  state = state.copyWith(layoutSeed: seed);
  state = state.copyWith(
    enemies: GameLogic.createEnemyGroup(
      state.currentRoom,
      dungeonId: dungeonId,
      fromState: state,
    ),
  );
  return fullHeal(state);
}

FloorSimResult simulateFloor(
  GameState state, {
  double maxSeconds = 90,
  double dt = 0.05,
}) {
  var world = SpatialCombat.build(state);
  var current = state;
  var elapsed = 0.0;
  var gold = 0;

  Map<String, int> damageMap() => {
        for (final h in world.heroes) h.id: h.damageDealt,
      };

  Map<HeroSpecId, int> damageBySpec() {
    final out = <HeroSpecId, int>{};
    for (final h in world.heroes) {
      final id = h.heroSpecId;
      if (id == null) continue;
      out[id] = (out[id] ?? 0) + h.damageDealt;
    }
    return out;
  }

  Map<String, double> heroHpPct() {
    final out = <String, double>{};
    for (final actor in world.heroes) {
      final maxHp = actor.assetIndex >= 0 &&
              actor.assetIndex < current.heroes.length
          ? current.effectiveHeroMaxHp(current.heroes[actor.assetIndex])
          : actor.effectiveMaxHp;
      out[actor.id] = maxHp <= 0 ? 0 : 100.0 * actor.hp / maxHp;
    }
    return out;
  }

  Map<HeroSpecId, double> hpBySpec() {
    final out = <HeroSpecId, double>{};
    for (final actor in world.heroes) {
      final id = actor.heroSpecId;
      if (id == null) continue;
      final maxHp = actor.assetIndex >= 0 &&
              actor.assetIndex < current.heroes.length
          ? current.effectiveHeroMaxHp(current.heroes[actor.assetIndex])
          : actor.effectiveMaxHp;
      out[id] = maxHp <= 0 ? 0 : 100.0 * actor.hp / maxHp;
    }
    return out;
  }

  double partyHpPct() {
    var maxHp = 0;
    var hp = 0;
    for (final h in current.heroes) {
      maxHp += current.effectiveHeroMaxHp(h);
      hp += h.currentHp;
    }
    return maxHp == 0 ? 0 : 100.0 * hp / maxHp;
  }

  FloorSimResult finish({
    required bool cleared,
    required bool wiped,
    required bool timedOut,
    required double hpPct,
  }) {
    return FloorSimResult(
      cleared: cleared,
      wiped: wiped,
      timedOut: timedOut,
      seconds: elapsed,
      hpPct: hpPct,
      gold: gold,
      combatElapsed: world.combatElapsed,
      damageByHeroId: damageMap(),
      damageBySpec: damageBySpec(),
      hpPctByHeroId: heroHpPct(),
      hpPctBySpec: hpBySpec(),
      state: current,
    );
  }

  while (elapsed < maxSeconds) {
    final step = SpatialCombat.step(world, current, dt: dt);
    world = step.world;
    current = step.state;
    gold += step.goldFromKills;
    elapsed += dt;
    if (step.roomCleared) {
      return finish(
        cleared: true,
        wiped: false,
        timedOut: false,
        hpPct: partyHpPct(),
      );
    }
    if (step.partyWiped ||
        current.isPartyDefeated ||
        world.heroes.every((h) => !h.isAlive)) {
      return finish(
        cleared: false,
        wiped: true,
        timedOut: false,
        hpPct: 0,
      );
    }
  }
  return finish(
    cleared: false,
    wiped: false,
    timedOut: true,
    hpPct: 0,
  );
}

double percentile(List<double> sortedAsc, double p) {
  if (sortedAsc.isEmpty) return 0;
  if (sortedAsc.length == 1) return sortedAsc.first;
  final idx = (p * (sortedAsc.length - 1)).clamp(0, sortedAsc.length - 1);
  final lo = idx.floor();
  final hi = idx.ceil();
  if (lo == hi) return sortedAsc[lo];
  final t = idx - lo;
  return sortedAsc[lo] * (1 - t) + sortedAsc[hi] * t;
}

double medianOf(List<double> values) {
  if (values.isEmpty) return 0;
  final s = [...values]..sort();
  return percentile(s, 0.5);
}
