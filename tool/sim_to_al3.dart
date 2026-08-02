import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// Playtest probe: push/farm until Ascension Level 3.
///   dart run tool/sim_to_al3.dart
void main() {
  print('=== Sim to AL3 ===\n');
  var state = GameLogic.createInitialState(now: DateTime(2026, 8, 2));
  final issues = <String>[];
  var totalBosses = 0;
  var totalWipes = 0;
  var totalFarms = 0;

  while (state.ascensionLevel < 3) {
    final al = state.ascensionLevel;
    final need = GameLogic.bossesRequiredForAscension(al);
    print('--- AL$al · need $need bosses (have ${state.bossVictories}) ---');

    // Short farm for gold/train if early and weak.
    if (al == 0 && state.heroes.first.level < 3) {
      state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
      state = GameLogic.setDungeonMode(state, DungeonMode.farm);
      for (var i = 0; i < 12; i++) {
        final r = _simulateFloor(state);
        if (r.wiped || r.timedOut) break;
        totalFarms++;
        state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
        state = _fullHeal(state);
        state = _spendGold(state);
      }
      state = state.copyWith(inDungeon: false);
      print('  farmed $totalFarms floors · gold=${state.gold} Lv${state.heroes.first.level}');
    }

    // Push until ascend-ready or stuck.
    var pushAttempts = 0;
    while (!GameLogic.canAscend(state) && pushAttempts < 12) {
      pushAttempts++;
      state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
      state = GameLogic.setDungeonMode(state, DungeonMode.push);
      var floor = 1;
      var ok = true;
      while (state.inDungeon && floor <= 12) {
        final room = state.currentRoom;
        final r = _simulateFloor(state);
        final tag = room.type.name.padRight(8);
        print(
          '  push#$pushAttempts F$floor $tag '
          '${r.seconds.toStringAsFixed(1)}s hp=${r.hpPct.toStringAsFixed(0)}% ${r.label}',
        );
        if (r.wiped || r.timedOut) {
          totalWipes++;
          ok = false;
          issues.add('wipe AL$al push#$pushAttempts F$floor ${r.label}');
          state = r.state.copyWith(inDungeon: false);
          break;
        }
        final beforeBosses = state.bossVictories;
        state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
        state = _fullHeal(state);
        state = _spendGold(state);
        if (state.bossVictories > beforeBosses) {
          totalBosses++;
          print('  BOSS +1 → ${state.bossVictories}/$need');
        }
        if (!state.inDungeon) break;
        floor++;
      }
      if (!ok) {
        // Farm a bit after wipe then retry.
        state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
        state = GameLogic.setDungeonMode(state, DungeonMode.farm);
        for (var i = 0; i < 6; i++) {
          final r = _simulateFloor(state);
          if (r.wiped || r.timedOut) break;
          totalFarms++;
          state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
          state = _fullHeal(state);
          state = _spendGold(state);
        }
        state = state.copyWith(inDungeon: false);
      }
    }

    if (!GameLogic.canAscend(state)) {
      issues.add('stuck at AL$al after $pushAttempts pushes');
      print('STUCK at AL$al');
      break;
    }
    state = GameLogic.ascend(state);
    print('>>> ASCENDED to AL${state.ascensionLevel} · ess=${state.essence}\n');
  }

  print('=== result ===');
  print('AL=${state.ascensionLevel} bosses=$totalBosses wipes=$totalWipes farms=$totalFarms ess=${state.essence}');
  if (issues.isEmpty) {
    print('OK — reached AL3 with no hard blockers');
  } else {
    print('ISSUES (${issues.length}):');
    for (final i in issues) {
      print(' - $i');
    }
  }
}

GameState _spendGold(GameState state) {
  var s = state;
  var spent = true;
  while (spent) {
    spent = false;
    final train = GameLogic.partyTrainingCostFor(s);
    if (s.gold >= train && s.heroes.first.level < 10 + s.ascensionLevel * 2) {
      s = GameLogic.trainParty(s);
      spent = true;
      continue;
    }
    for (final type in PartyUpgradeType.values) {
      final cost = GameLogic.upgradeCostFor(s, type);
      if (s.gold >= cost) {
        s = switch (type) {
          PartyUpgradeType.attack => GameLogic.upgradeAttack(s),
          PartyUpgradeType.defense => GameLogic.upgradeDefense(s),
          PartyUpgradeType.vitality => GameLogic.upgradeVitality(s),
        };
        spent = true;
        break;
      }
    }
  }
  return s;
}

GameState _fullHeal(GameState s) => s.copyWith(
      heroes: [
        for (final h in s.heroes)
          h.copyWith(currentHp: s.effectiveHeroMaxHp(h)),
      ],
    );

class _FloorResult {
  _FloorResult({
    required this.wiped,
    required this.timedOut,
    required this.seconds,
    required this.hpPct,
    required this.gold,
    required this.state,
    required this.label,
  });
  final bool wiped;
  final bool timedOut;
  final double seconds;
  final double hpPct;
  final int gold;
  final GameState state;
  final String label;
}

_FloorResult _simulateFloor(GameState state) {
  var world = SpatialCombat.build(state, threatScale: 1.0);
  var s = state;
  var gold = 0;
  var t = 0.0;
  const dt = 1 / 30;
  const limit = 90.0;
  while (t < limit) {
    final step = SpatialCombat.step(world, s, dt: dt);
    world = step.world;
    s = step.state;
    gold += step.goldFromKills;
    t += dt;
    if (world.heroes.every((h) => !h.isAlive)) {
      return _FloorResult(
        wiped: true,
        timedOut: false,
        seconds: t,
        hpPct: 0,
        gold: gold,
        state: s,
        label: 'WIPE',
      );
    }
    if (world.awaitingExit ||
        (world.enemies.every((e) => e.hp <= 0) && world.groundLoot.isEmpty)) {
      final hp = world.heroes.where((h) => h.isAlive).fold<int>(0, (a, h) => a + h.hp);
      final max = world.heroes.fold<int>(0, (a, h) => a + h.effectiveMaxHp);
      return _FloorResult(
        wiped: false,
        timedOut: false,
        seconds: t,
        hpPct: max <= 0 ? 0 : 100 * hp / max,
        gold: gold,
        state: s,
        label: 'CLEAR',
      );
    }
  }
  return _FloorResult(
    wiped: false,
    timedOut: true,
    seconds: t,
    hpPct: 0,
    gold: gold,
    state: s,
    label: 'TIMEOUT',
  );
}
