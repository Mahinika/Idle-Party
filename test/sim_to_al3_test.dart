import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// SpatialCombat loop probe through Ascension Level 3.
void main() {
  test('sim play loop reaches AL3', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 2));
    final issues = <String>[];
    var totalBosses = 0;
    var totalWipes = 0;

    while (state.ascensionLevel < 3) {
      final al = state.ascensionLevel;
      final need = GameLogic.bossesRequiredForAscension(al);

      if (al == 0 && state.heroes.first.level < 3) {
        state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
        state = GameLogic.setDungeonMode(state, DungeonMode.farm);
        for (var i = 0; i < 12; i++) {
          final r = _simulateFloor(state);
          if (r.wiped || r.timedOut) break;
          state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
          state = _fullHeal(state);
          state = _spendGold(state);
        }
        state = state.copyWith(inDungeon: false);
      }

      var pushAttempts = 0;
      while (!GameLogic.canAscend(state) && pushAttempts < 12) {
        pushAttempts++;
        state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
        state = GameLogic.setDungeonMode(state, DungeonMode.push);
        var floor = 1;
        var wiped = false;
        while (state.inDungeon && floor <= 12) {
          final r = _simulateFloor(state);
          if (r.wiped || r.timedOut) {
            totalWipes++;
            wiped = true;
            issues.add('wipe AL$al push#$pushAttempts F$floor ${r.label}');
            state = r.state.copyWith(inDungeon: false);
            break;
          }
          final beforeBosses = state.bossVictories;
          state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
          state = _fullHeal(state);
          state = _spendGold(state);
          if (state.bossVictories > beforeBosses) totalBosses++;
          if (!state.inDungeon) break;
          floor++;
        }
        if (wiped) {
          state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
          state = GameLogic.setDungeonMode(state, DungeonMode.farm);
          for (var i = 0; i < 6; i++) {
            final r = _simulateFloor(state);
            if (r.wiped || r.timedOut) break;
            state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
            state = _fullHeal(state);
            state = _spendGold(state);
          }
          state = state.copyWith(inDungeon: false);
        }
      }

      expect(
        GameLogic.canAscend(state),
        isTrue,
        reason: 'stuck at AL$al after $pushAttempts pushes · bosses ${state.bossVictories}/$need · $issues',
      );
      state = GameLogic.ascend(state);
    }

    expect(state.ascensionLevel, 3);
    // Soft signal — wipes OK if we still reach AL3.
    // ignore: avoid_print
    print('AL3 OK · bosses=$totalBosses wipes=$totalWipes ess=${state.essence} issues=$issues');
  }, timeout: const Timeout(Duration(minutes: 20)));
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
          PartyUpgradeType.moveSpeed => GameLogic.upgradeMoveSpeed(s),
          PartyUpgradeType.attackSpeed => GameLogic.upgradeAttackSpeed(s),
          PartyUpgradeType.crit => GameLogic.upgradeCrit(s),
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
    required this.gold,
    required this.state,
    required this.label,
  });
  final bool wiped;
  final bool timedOut;
  final int gold;
  final GameState state;
  final String label;
}

_FloorResult _simulateFloor(GameState state) {
  var world = SpatialCombat.build(state, threatScale: 1.0, afkAssist: true);
  var s = state;
  var gold = 0;
  var t = 0.0;
  const dt = 1 / 30;
  // Room chests + multi-chamber grammar need headroom vs old 90s probe.
  const limit = 180.0;
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
        gold: gold,
        state: s,
        label: 'WIPE',
      );
    }
    // Combat clear = all foes down. Don't wait on exit walk / chest vacuum —
    // room chests + multi-chamber grammar made old 90s exit probes flake on CI.
    if (world.enemies.every((e) => e.hp <= 0)) {
      return _FloorResult(
        wiped: false,
        timedOut: false,
        gold: gold,
        state: s,
        label: 'CLEAR',
      );
    }
  }
  return _FloorResult(
    wiped: false,
    timedOut: true,
    gold: gold,
    state: s,
    label: 'TIMEOUT',
  );
}
