import 'dart:math' as math;

import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// Full idle/combat simulation suite — run with:
///   dart run tool/sim_combat_scaling.dart
void main() {
  print('=== Idle Party FULL simulation suite ===\n');

  // 1) Push power ladder
  print('======== 1) PUSH RUNS ========\n');
  _simPushRun(
    label: 'FRESH party (no forge, 3 heroes)',
    state: GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
    dungeonId: 'sandy',
    maxFloors: 12,
  );
  _simPushRun(
    label: 'LIGHT forge (+train x3, ATK/DEF/VIT x2)',
    state: _lightForge(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
    dungeonId: 'sandy',
    maxFloors: 12,
  );
  _simPushRun(
    label: 'MID forge + gear + 4th hero',
    state: _midPower(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
    dungeonId: 'sandy',
    maxFloors: 14,
  );

  // 2) Zone F1 / boss
  print('======== 2) ZONE F1 / BOSS (fresh, 5 trials) ========\n');
  for (final id in ['sandy', 'goblin', 'king', 'underworld', 'dead', 'hell']) {
    final fresh = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
    _simSingleFloor(fresh, dungeonId: id, floor: 1, trials: 5);
    _simSingleFloor(
      fresh,
      dungeonId: id,
      floor: GameLogic.bossFloorFor(fresh),
      trials: 5,
    );
  }

  // 3) Budget
  print('\n======== 3) BUDGET CURVE (sandy) ========\n');
  _printBudgetTable('sandy');

  // 4) Farm vs Push
  print('\n======== 4) FARM vs PUSH (light forge @ sandy F1) ========\n');
  _simFarmVsPush(
    _lightForge(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
    dungeonId: 'sandy',
    floor: 1,
    loops: 8,
  );

  // 5) Mid-floor power gates
  print('\n======== 5) MID-FLOOR GATES (sandy, 8 trials) ========\n');
  for (final floor in [1, 5, 10, 15, 20]) {
    _simSingleFloor(
      GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
      dungeonId: 'sandy',
      floor: floor,
      trials: 8,
      labelPrefix: 'fresh',
    );
    _simSingleFloor(
      _lightForge(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
      dungeonId: 'sandy',
      floor: floor,
      trials: 8,
      labelPrefix: 'light',
    );
    _simSingleFloor(
      _midPower(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
      dungeonId: 'sandy',
      floor: floor,
      trials: 8,
      labelPrefix: 'mid  ',
    );
  }

  // 6) Offline
  print('\n======== 6) OFFLINE PROGRESSION ========\n');
  _simOffline(
    label: 'fresh@farm F1',
    state: GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
    dungeonId: 'sandy',
    mode: DungeonMode.farm,
    floor: 1,
  );
  _simOffline(
    label: 'light@farm F1',
    state: _lightForge(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
    dungeonId: 'sandy',
    mode: DungeonMode.farm,
    floor: 1,
  );
  _simOffline(
    label: 'mid@push',
    state: _midPower(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
    dungeonId: 'sandy',
    mode: DungeonMode.push,
    floor: 1,
  );

  // 7) Economy loop
  print('\n======== 7) ECONOMY LOOP (farm F1 → forge) ========\n');
  _simEconomyLoop(
    GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
    dungeonId: 'sandy',
    clears: 20,
  );

  // 8) Ascension
  print('\n======== 8) ASCENSION A0 vs A1 (light, sandy F1/boss) ========\n');
  final light = _lightForge(GameLogic.createInitialState(now: DateTime(2026, 7, 25)));
  _simSingleFloor(light, dungeonId: 'sandy', floor: 1, trials: 5, labelPrefix: 'A0');
  _simSingleFloor(
    light,
    dungeonId: 'sandy',
    floor: GameLogic.bossFloorFor(light),
    trials: 5,
    labelPrefix: 'A0',
  );
  final a1 = light.copyWith(
    ascensionLevel: 1,
    bossVictories: 0,
    highestFloorCleared: 0,
  );
  _simSingleFloor(a1, dungeonId: 'sandy', floor: 1, trials: 5, labelPrefix: 'A1');
  _simSingleFloor(
    a1,
    dungeonId: 'sandy',
    floor: GameLogic.bossFloorFor(a1),
    trials: 5,
    labelPrefix: 'A1',
  );

  // 9) Layout / pathing stress
  print('\n======== 9) LAYOUT STRESS (sandy F1, 60 seeds) ========\n');
  _simLayoutStress(
    GameLogic.createInitialState(now: DateTime(2026, 7, 25)),
    dungeonId: 'sandy',
    floor: 1,
    seeds: 60,
  );
  _simLayoutStress(
    _midPower(GameLogic.createInitialState(now: DateTime(2026, 7, 25))),
    dungeonId: 'sandy',
    floor: 1,
    seeds: 40,
    labelPrefix: 'mid4',
  );

  print('\n=== suite complete ===');
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

GameState _midPower(GameState s) {
  var next = _lightForge(s).copyWith(
    gold: 200000,
    essence: 80,
    rogueUnlocked: true,
  );
  next = GameLogic.ensureRogueHero(next);
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

void _simPushRun({
  required String label,
  required GameState state,
  required String dungeonId,
  required int maxFloors,
}) {
  print('## $label  [$dungeonId]');
  print(
    'party ATK=${_partyAtk(state)} DEF=${_partyDef(state)} '
    'HP=${_partyHp(state)} heroes=${state.heroes.length}',
  );
  print(
    '${'Fl'.padLeft(3)} ${'Type'.padRight(8)} ${'eHP'.padLeft(6)} '
    '${'eATK'.padLeft(5)} ${'sec'.padLeft(6)} ${'hp%'.padLeft(5)} result',
  );

  var current = GameLogic.enterDungeon(state, dungeonId: dungeonId);
  current = GameLogic.setDungeonMode(current, DungeonMode.push);

  for (var floor = 1; floor <= maxFloors; floor++) {
    if (!current.inDungeon) break;
    final room = current.currentRoom;
    final budget = GameLogic.roomCombatBudget(room, dungeonId: dungeonId);
    final result = _simulateFloor(current);

    print(
      '${floor.toString().padLeft(3)} ${room.type.name.padRight(8)} '
      '${budget.hp.toString().padLeft(6)} ${budget.attack.toString().padLeft(5)} '
      '${result.seconds.toStringAsFixed(1).padLeft(6)} '
      '${result.hpPct.toStringAsFixed(0).padLeft(4)}% '
      '${result.label}',
    );

    if (result.wiped || result.timedOut) {
      print(
        '  → push stops at floor $floor '
        '(aliveEnemies=${result.livingEnemies} '
        'dormant=${result.dormantEnemies})\n',
      );
      return;
    }

    current = GameLogic.completeCurrentRoom(
      result.state,
      goldGain: result.gold,
    );
    if (!current.inDungeon) {
      print('  → dungeon complete after floor $floor\n');
      return;
    }
    current = current.copyWith(
      heroes: [
        for (final h in current.heroes)
          h.copyWith(currentHp: current.effectiveHeroMaxHp(h)),
      ],
    );
  }
  print('  → survived $maxFloors floors\n');
}

void _simSingleFloor(
  GameState base, {
  required String dungeonId,
  required int floor,
  required int trials,
  String labelPrefix = '',
}) {
  var clears = 0;
  var wipes = 0;
  var timeouts = 0;
  var secs = 0.0;
  var hp = 0.0;
  for (var t = 0; t < trials; t++) {
    var state = GameLogic.enterDungeon(base, dungeonId: dungeonId);
    // Unlock travel for mid-floor probes.
    if (floor > state.highestFloorCleared) {
      state = state.copyWith(highestFloorCleared: floor);
    }
    if (GameLogic.canTravelToFloor(state, floor)) {
      state = GameLogic.travelToFloor(state, floor);
    } else {
      final room = DungeonGenerator.generateFloor(
        floor,
        dungeonId: dungeonId,
        ascensionLevel: state.ascensionLevel,
      ).first;
      state = state.copyWith(
        currentRoom: room,
        dungeonFloor: <DungeonRoom>[room],
        enemies: GameLogic.createEnemyGroup(room, dungeonId: dungeonId),
        dungeonId: dungeonId,
        inDungeon: true,
        layoutSeed: GameLogic.newLayoutSeed(),
      );
    }
    final r = _simulateFloor(state);
    if (r.wiped) {
      wipes++;
    } else if (r.timedOut) {
      timeouts++;
    } else {
      clears++;
    }
    secs += r.seconds;
    hp += r.hpPct;
  }
  final room = DungeonGenerator.generateFloor(
    floor,
    dungeonId: dungeonId,
    ascensionLevel: base.ascensionLevel,
  ).first;
  final b = GameLogic.roomCombatBudget(room, dungeonId: dungeonId);
  final tag = labelPrefix.isEmpty ? dungeonId.padRight(11) : labelPrefix.padRight(11);
  print(
    '$tag F${floor.toString().padLeft(2)} '
    '${room.type.name.padRight(8)} '
    'eHP=${b.hp.toString().padLeft(5)} eATK=${b.attack.toString().padLeft(4)}  '
    'OK $clears  WIPE $wipes  STUCK $timeouts /$trials  '
    'avg ${(secs / trials).toStringAsFixed(1)}s  '
    'hp ${(hp / trials).toStringAsFixed(0)}%',
  );
}

void _printBudgetTable(String dungeonId) {
  print(
    '${'Fl'.padLeft(3)} ${'Type'.padRight(8)} '
    '${'atk'.padLeft(5)} ${'hp'.padLeft(6)} ${'gold'.padLeft(5)} '
    '${'enemies'.padLeft(7)}',
  );
  for (var f = 1; f <= 20; f++) {
    final room = DungeonGenerator.generateFloor(f, dungeonId: dungeonId).first;
    final b = GameLogic.roomCombatBudget(room, dungeonId: dungeonId);
    print(
      '${f.toString().padLeft(3)} ${room.type.name.padRight(8)} '
      '${b.attack.toString().padLeft(5)} ${b.hp.toString().padLeft(6)} '
      '${b.gold.toString().padLeft(5)} '
      '${room.enemyCount.toString().padLeft(7)}',
    );
  }
}

class _FloorResult {
  _FloorResult({
    required this.wiped,
    required this.timedOut,
    required this.seconds,
    required this.hpPct,
    required this.gold,
    required this.state,
    required this.livingEnemies,
    required this.dormantEnemies,
  });

  final bool wiped;
  final bool timedOut;
  final double seconds;
  final double hpPct;
  final int gold;
  final GameState state;
  final int livingEnemies;
  final int dormantEnemies;

  String get label {
    if (wiped) return 'WIPE';
    if (timedOut) {
      return 'STUCK(e=$livingEnemies d=$dormantEnemies)';
    }
    return 'clear';
  }
}

_FloorResult _simulateFloor(GameState state) {
  var world = SpatialCombat.build(state);
  var current = state;
  const dt = 1 / 30;
  var t = 0.0;
  var gold = 0;
  const maxT = 90.0;

  while (t < maxT) {
    final step = SpatialCombat.step(world, current, dt: dt);
    world = step.world;
    current = step.state;
    gold += step.goldFromKills;
    t += dt;

    if (step.partyWiped) {
      return _FloorResult(
        wiped: true,
        timedOut: false,
        seconds: t,
        hpPct: 0,
        gold: gold,
        state: current,
        livingEnemies: world.enemies.where((e) => e.hp > 0).length,
        dormantEnemies:
            world.enemies.where((e) => e.hp > 0 && e.dormant).length,
      );
    }
    if (step.roomCleared) {
      return _FloorResult(
        wiped: false,
        timedOut: false,
        seconds: t,
        hpPct: _hpPct(current),
        gold: gold,
        state: current,
        livingEnemies: 0,
        dormantEnemies: 0,
      );
    }
  }

  return _FloorResult(
    wiped: false,
    timedOut: true,
    seconds: t,
    hpPct: _hpPct(current),
    gold: gold,
    state: current,
    livingEnemies: world.enemies.where((e) => e.hp > 0).length,
    dormantEnemies: world.enemies.where((e) => e.hp > 0 && e.dormant).length,
  );
}

int _partyAtk(GameState s) =>
    s.heroes.fold<int>(0, (a, h) => a + s.effectiveHeroAttack(h));

int _partyDef(GameState s) =>
    s.heroes.fold<int>(0, (a, h) => a + s.effectiveHeroDefense(h));

int _partyHp(GameState s) =>
    s.heroes.fold<int>(0, (a, h) => a + s.effectiveHeroMaxHp(h));

double _hpPct(GameState s) {
  final max = _partyHp(s);
  if (max <= 0) return 0;
  final cur = s.heroes.fold<int>(0, (a, h) => a + h.currentHp);
  return 100 * cur / max;
}

void _simFarmVsPush(
  GameState base, {
  required String dungeonId,
  required int floor,
  required int loops,
}) {
  for (final mode in [DungeonMode.farm, DungeonMode.push]) {
    var state = GameLogic.enterDungeon(base, dungeonId: dungeonId);
    state = GameLogic.setDungeonMode(state, mode);
    if (floor > 1) {
      state = state.copyWith(highestFloorCleared: floor);
      state = GameLogic.travelToFloor(state, floor);
    }
    var gold = 0;
    var clears = 0;
    var wipes = 0;
    var stuck = 0;
    var secs = 0.0;
    for (var i = 0; i < loops; i++) {
      if (!state.inDungeon) break;
      final r = _simulateFloor(state);
      secs += r.seconds;
      gold += r.gold;
      if (r.wiped) {
        wipes++;
        break;
      }
      if (r.timedOut) {
        stuck++;
        break;
      }
      clears++;
      state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
      state = state.copyWith(
        heroes: [
          for (final h in state.heroes)
            h.copyWith(currentHp: state.effectiveHeroMaxHp(h)),
        ],
      );
      if (!state.inDungeon) break;
    }
    final gph = secs > 0 ? (gold / secs * 3600).round() : 0;
    print(
      '${mode.name.padRight(4)}  clears=$clears wipe=$wipes stuck=$stuck  '
      'gold=$gold  time=${secs.toStringAsFixed(1)}s  '
      '~$gph g/h  endFloor=${state.currentRoom.floorNumber} '
      'inDungeon=${state.inDungeon}',
    );
  }
}

void _simOffline({
  required String label,
  required GameState state,
  required String dungeonId,
  required DungeonMode mode,
  required int floor,
}) {
  print('$label');
  int? prevGold;
  for (final minutes in [5, 30, 60, 480]) {
    var s = GameLogic.enterDungeon(state, dungeonId: dungeonId);
    s = GameLogic.setDungeonMode(s, mode);
    if (floor > 1) {
      s = s.copyWith(highestFloorCleared: floor);
      s = GameLogic.travelToFloor(s, floor);
    }
    final after = GameLogic.applyOfflineProgress(
      s,
      Duration(minutes: minutes),
    );
    final delta = after.goldGained;
    final trend = prevGold == null
        ? ''
        : (delta > prevGold
            ? '  ▲'
            : (delta == prevGold ? '  =' : '  ▼'));
    prevGold = delta;
    final labelMin = minutes >= 60 ? '${minutes ~/ 60}h' : '${minutes}m';
    print(
      '  ${labelMin.padLeft(3)}  '
      'Δgold=$delta$trend  '
      'clears=${after.roomsCleared}  '
      'budget=${GameLogic.offlineFloorBudget(minutes * 60)}  '
      'Δhighest=${after.highestFloorDelta}  '
      'Δboss=${after.bossDelta}  '
      'floor=${after.state.currentRoom.floorNumber}  '
      'inDungeon=${after.state.inDungeon}',
    );
  }
}

void _simEconomyLoop(
  GameState base, {
  required String dungeonId,
  required int clears,
}) {
  var state = GameLogic.enterDungeon(base, dungeonId: dungeonId);
  state = GameLogic.setDungeonMode(state, DungeonMode.farm);
  var spent = 0;
  var trains = 0;
  var upgrades = 0;
  var roomClears = 0;
  var goldEarned = 0;
  for (var i = 0; i < clears; i++) {
    final r = _simulateFloor(state);
    if (r.wiped || r.timedOut) {
      print('  stop early at clear $i: ${r.label}');
      break;
    }
    roomClears++;
    goldEarned += r.gold;
    state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
    state = state.copyWith(
      heroes: [
        for (final h in state.heroes)
          h.copyWith(currentHp: state.effectiveHeroMaxHp(h)),
      ],
    );

    // Spend greedily on level bumps then cheapest forge upgrade.
    var safety = 0;
    while (safety++ < 30) {
      final atk = GameLogic.upgradeCostFor(state, PartyUpgradeType.attack);
      final def = GameLogic.upgradeCostFor(state, PartyUpgradeType.defense);
      final vit = GameLogic.upgradeCostFor(state, PartyUpgradeType.vitality);
      if (trains < upgrades + 3) {
        state = state.copyWith(
          heroRoster: [
            for (final h in state.heroRoster)
              h.copyWith(
                level: math.min(GameLogic.maxHeroLevel, h.level + 1),
              ),
          ],
        );
        trains++;
        continue;
      }
      final options = <(int, void Function())>[
        (atk, () {
          state = GameLogic.upgradeAttack(state);
        }),
        (def, () {
          state = GameLogic.upgradeDefense(state);
        }),
        (vit, () {
          state = GameLogic.upgradeVitality(state);
        }),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      final cheapest = options.first;
      if (state.gold < cheapest.$1) break;
      cheapest.$2();
      spent += cheapest.$1;
      upgrades++;
    }
  }
  print(
    'clears=$roomClears  goldEarned≈$goldEarned  spent=$spent  '
    'wallet=${state.gold}  trains=$trains upgrades=$upgrades  '
    'ATK=${_partyAtk(state)} DEF=${_partyDef(state)} HP=${_partyHp(state)}',
  );
  // Can this economy beat the boss?
  var push = GameLogic.setDungeonMode(
    state.copyWith(highestFloorCleared: 5),
    DungeonMode.push,
  );
  push = GameLogic.travelToFloor(push, GameLogic.bossFloorFor(push));
  final boss = _simulateFloor(push);
  print(
    '  after $clears farm clears → boss: ${boss.label} '
    '(${boss.seconds.toStringAsFixed(1)}s, hp ${boss.hpPct.toStringAsFixed(0)}%)',
  );
}

void _simLayoutStress(
  GameState base, {
  required String dungeonId,
  required int floor,
  required int seeds,
  String labelPrefix = 'fresh',
}) {
  var clears = 0;
  var wipes = 0;
  var stuck = 0;
  var exitStuck = 0;
  var secs = 0.0;
  for (var seed = 0; seed < seeds; seed++) {
    var state = GameLogic.enterDungeon(base, dungeonId: dungeonId);
    if (floor > state.highestFloorCleared) {
      state = state.copyWith(highestFloorCleared: floor);
    }
    state = state.copyWith(layoutSeed: seed * 97 + 11);
    if (GameLogic.canTravelToFloor(state, floor)) {
      state = GameLogic.travelToFloor(state, floor);
      state = state.copyWith(layoutSeed: seed * 97 + 11);
      state = state.copyWith(
        enemies: GameLogic.createEnemyGroup(
          state.currentRoom,
          dungeonId: dungeonId,
        ),
      );
    }
    final r = _simulateFloor(state);
    secs += r.seconds;
    if (r.wiped) {
      wipes++;
    } else if (r.timedOut) {
      stuck++;
      if (r.livingEnemies == 0) exitStuck++;
    } else {
      clears++;
    }
  }
  print(
    '$labelPrefix  seeds=$seeds  OK=$clears WIPE=$wipes STUCK=$stuck '
    '(exitStuck=$exitStuck)  avg ${(secs / seeds).toStringAsFixed(1)}s  '
    'stuckRate=${(100 * stuck / seeds).toStringAsFixed(0)}%',
  );
}
