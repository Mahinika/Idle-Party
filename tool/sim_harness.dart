import 'dart:math';

import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/proficiency.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// How closely the floor runner mirrors live / AFK director loops.
enum SimPlayMode {
  /// SpatialCombat only — no flask, God Hand, or mid-fight auto-equip.
  bare,

  /// Live director parity: 60 Hz, flask @35% HP, GH on CD, auto-equip loot.
  live,

  /// Offline catch-up parity: afkAssist, soft GH cadence, flask, auto-equip.
  afk,
}

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
    this.godHandCasts = 0,
    this.flaskUses = 0,
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
  final int godHandCasts;
  final int flaskUses;
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
  var next = state.copyWith(
    gold: 50000,
    heroRoster: [
      for (final h in state.heroRoster) h.copyWith(level: h.level + 3),
    ],
  );
  for (var i = 0; i < 2; i++) {
    next = GameLogic.upgradeAttack(next);
    next = GameLogic.upgradeDefense(next);
    next = GameLogic.upgradeVitality(next);
  }
  return next;
}

GameState withMidForge(GameState state) {
  var next = withLightForge(state).copyWith(gold: 200000, essence: 80);
  next = next.copyWith(
    heroRoster: [
      for (final h in next.heroRoster) h.copyWith(level: h.level + 8),
    ],
  );
  for (var i = 0; i < 6; i++) {
    next = GameLogic.upgradeAttack(next);
    next = GameLogic.upgradeDefense(next);
    next = GameLogic.upgradeVitality(next);
  }
  return next;
}

/// Outfit each hero with a full role-tagged kit (forced equip for sims).
///
/// Bypasses Auto Equip gates / stash caps so mid-band kits always land.
GameState outfitPartyGear(
  GameState state, {
  required int battleNumber,
  required LootRarity rarity,
}) {
  final bn = max(1, battleNumber);
  final slots = [
    for (final s in EquipmentSlot.values)
      if (s != EquipmentSlot.consumable) s,
  ];
  final heroes = <PartyHero>[];
  for (final hero in state.heroes) {
    final preferred = GameLogic.preferredArmorForSpec(hero.spec, hero.level);
    final eq = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
    EquipmentItem? weapon;
    for (final slot in slots) {
      final piece = GameLogic.createEquipment(
        slot: slot,
        rarity: rarity,
        battleNumber: bn,
        bias: hero.gearAffinity,
        preferredArmor: preferred,
        roleTag: hero.spec.roleTag,
      );
      if (slot == EquipmentSlot.offHand &&
          weapon != null &&
          ClassProficiency.weaponBlocksOffHand(weapon)) {
        continue;
      }
      eq[slot] = piece;
      if (slot == EquipmentSlot.weapon) weapon = piece;
    }
    heroes.add(hero.copyWith(equipped: eq));
  }
  return state.copyWith(heroes: heroes);
}

/// Flask on every hero + stash reserve (live/AFK mid-fight drinks).
GameState ensureCombatConsumables(
  GameState state, {
  int stashFlasks = 8,
}) {
  var salt = 0;
  final heroes = <PartyHero>[];
  for (final h in state.heroes) {
    final eq = Map<EquipmentSlot, EquipmentItem>.from(h.equipped);
    final cur = eq[EquipmentSlot.consumable];
    if (cur == null || cur.slot != EquipmentSlot.consumable) {
      eq[EquipmentSlot.consumable] =
          GameLogic.createMarketFlask(salt: salt++);
    }
    heroes.add(h.copyWith(equipped: eq));
  }
  final stash = <EquipmentItem>[...state.gearStash];
  for (var i = 0; i < stashFlasks; i++) {
    stash.add(GameLogic.createMarketFlask(salt: salt++));
  }
  return state.copyWith(
    heroes: heroes,
    gearStash: stash,
    gold: max(state.gold, 5000),
  );
}

/// Forge / train only — gear applied later at the party's actual level.
GameState applyPowerBand(GameState state, String band) {
  return switch (band) {
    'fresh' => state,
    'light' => withLightForge(state),
    'mid' => withMidForge(state),
    _ => throw ArgumentError('Unknown band: $band'),
  };
}

/// Level-scaled kits after [levelPartyTo] so ilvl matches the sweep.
///
/// - fresh: starter kits only
/// - light: early forge power (no full stash outfit) — matches first-dungeon gear
/// - mid: full rare role-tagged kits at party level — mid push reality
GameState applyGearBand(
  GameState state,
  String band, {
  required int battleNumber,
}) {
  return switch (band) {
    'fresh' || 'light' => state,
    'mid' => outfitPartyGear(
        state,
        battleNumber: battleNumber,
        rarity: LootRarity.rare,
      ),
    _ => throw ArgumentError('Unknown band: $band'),
  };
}

GameState enterFloor(
  GameState base, {
  required String dungeonId,
  required int floor,
  required int seed,

  /// When set, force a dense AoE trash pack (normal room, N bodies).
  /// Total combat budget stays floor-scaled; it is split across [aoeEnemyCount].
  int? aoeEnemyCount,
}) {
  var state = GameLogic.enterDungeon(base, dungeonId: dungeonId);
  state = GameLogic.setDungeonMode(state, DungeonMode.push);
  if (floor > 1) {
    // Unlock travel up to [floor], then jump there (AL boards e.g. F21).
    state = state.copyWith(highestFloorCleared: max(0, floor - 1));
    if (GameLogic.canTravelToFloor(state, floor)) {
      state = GameLogic.travelToFloor(state, floor);
    }
  }
  state = state.copyWith(layoutSeed: seed);
  final room = aoeEnemyCount != null
      ? state.currentRoom.copyWith(
          type: RoomType.normal,
          enemyCount: aoeEnemyCount.clamp(1, 40),
        )
      : state.currentRoom;
  state = state.copyWith(
    currentRoom: room,
    enemies: GameLogic.createEnemyGroup(
      room,
      dungeonId: dungeonId,
      fromState: state,
    ),
  );
  return fullHeal(state);
}

/// Wake every enemy and clump them around the party so cleave/AoE kits can
/// actually hit the full pack (multi-chamber dormancy would hide most of them).
void prepareAoePackWorld(SpatialWorld world) {
  if (world.heroes.isEmpty || world.enemies.isEmpty) return;
  for (final gate in world.map.gates) {
    world.openGateIds.add(gate.id);
  }
  final hx = world.heroes.first.x;
  final hy = world.heroes.first.y;
  final n = world.enemies.length;
  for (var i = 0; i < n; i++) {
    final e = world.enemies[i];
    e.dormant = false;
    final ang = (2 * pi * i) / n;
    final r = 1.35 + (i % 3) * 0.35;
    final tx = hx + r * cos(ang);
    final ty = hy + r * sin(ang);
    final snapped = world.map.snapToSpawnable(tx.round(), ty.round());
    e.x = snapped.$1 + 0.5;
    e.y = snapped.$2 + 0.5;
  }
}

/// Prepare a party the way live/AFK combat actually sees it.
GameState prepareSimParty(
  GameState state, {
  required String band,
  required int partyLevel,
}) {
  var next = applyPowerBand(state, band);
  next = levelPartyTo(next, partyLevel);
  next = applyGearBand(next, band, battleNumber: partyLevel);
  next = ensureCombatConsumables(next);
  return next;
}

FloorSimResult simulateFloor(
  GameState state, {
  double maxSeconds = 90,
  double? dt,
  SimPlayMode mode = SimPlayMode.live,

  /// Dense pack: wake + clump all enemies so AoE share is measurable.
  bool aoePack = false,
}) {
  final useAssist = mode == SimPlayMode.afk;
  final stepDt = dt ??
      (mode == SimPlayMode.afk
          ? 0.12
          : mode == SimPlayMode.live
              ? 1 / 60
              : 0.05);
  // Attentive GH whenever ready (mirrors live director). Offline soft cadence
  // lives in GameLogic.simulateSpatialOffline, not this floor harness.
  final ghIntervalSteps = 1;
  final flaskIntervalSteps = mode == SimPlayMode.afk
      ? max(1, (1.44 / stepDt).round())
      : max(1, (1.0 / stepDt).round());

  var world = SpatialCombat.build(state, afkAssist: useAssist);
  if (aoePack) {
    prepareAoePackWorld(world);
  }
  var current = state;
  var elapsed = 0.0;
  var gold = 0;
  var stepIndex = 0;
  var godHandCasts = 0;
  var flaskUses = 0;

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
      godHandCasts: godHandCasts,
      flaskUses: flaskUses,
    );
  }

  bool tryFlask() {
    if (!GameLogic.canUseConsumable(current)) return false;
    final living = <PartyHero>[
      for (final h in current.heroes)
        if (h.currentHp > 0) h,
    ];
    if (living.isEmpty) return false;
    var ratioSum = 0.0;
    for (final h in living) {
      final maxHp = current.effectiveHeroMaxHp(h);
      ratioSum += maxHp > 0 ? h.currentHp / maxHp : 0;
    }
    if (ratioSum / living.length >= 0.35) return false;
    final before = current;
    current = GameLogic.useConsumable(current);
    if (identical(current, before)) return false;
    world = SpatialCombat.syncPartyFromState(world, current);
    flaskUses++;
    return true;
  }

  bool tryGodHand() {
    if (world.godHandCooldown > 0) return false;
    final aim = OfflineProgress.godHandAim(world);
    if (aim == null) return false;
    final gh = SpatialCombat.godHand(
      world,
      current,
      tileX: aim.$1,
      tileY: aim.$2,
    );
    world = gh.world;
    current = gh.state;
    gold += gh.goldFromKills;
    godHandCasts++;
    return true;
  }

  while (elapsed < maxSeconds) {
    final stashLenBefore = current.gearStash.length;
    final step = SpatialCombat.step(world, current, dt: stepDt);
    world = step.world;
    current = step.state;
    gold += step.goldFromKills;
    elapsed += stepDt;
    stepIndex++;

    if (mode != SimPlayMode.bare &&
        current.gearStash.length > stashLenBefore) {
      current = GameLogic.autoEquipBetterGear(current);
      world = SpatialCombat.syncPartyFromState(world, current);
    }

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

    if (mode != SimPlayMode.bare) {
      if (stepIndex % flaskIntervalSteps == 0) {
        tryFlask();
      }
      if (stepIndex % ghIntervalSteps == 0) {
        tryGodHand();
      }
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
