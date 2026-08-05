import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// Early-loop probe: hub → farm → forge → push boss.
///   dart run tool/sim_early_loop.dart
void main() {
  print('=== Early loop simulation ===\n');

  var state = GameLogic.createInitialState(now: DateTime(2026, 7, 25));
  _log('start', state);

  // Enter sandy in farm mode and clear rooms until forge-ready.
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  state = GameLogic.setDungeonMode(state, DungeonMode.farm);
  _log('enter farm F1', state);

  var farmClears = 0;
  var farmGold = 0;
  for (var i = 0; i < 25; i++) {
    final r = _simulateFloor(state);
    if (r.wiped || r.timedOut) {
      print('FARM STOP @ clear $i: ${r.label}');
      break;
    }
    farmClears++;
    farmGold += r.gold;
    state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
    state = _fullHeal(state);

    // Spend on train / forge while gold allows.
    var spent = true;
    while (spent) {
      spent = false;
      final train = GameLogic.partyTrainingCostFor(state);
      if (state.gold >= train && state.heroes.first.level < 4) {
        state = GameLogic.trainParty(state);
        spent = true;
        continue;
      }
      for (final type in PartyUpgradeType.values) {
        final cost = GameLogic.upgradeCostFor(state, type);
        if (state.gold >= cost) {
          state = switch (type) {
            PartyUpgradeType.attack => GameLogic.upgradeAttack(state),
            PartyUpgradeType.defense => GameLogic.upgradeDefense(state),
            PartyUpgradeType.vitality => GameLogic.upgradeVitality(state),
            PartyUpgradeType.moveSpeed => GameLogic.upgradeMoveSpeed(state),
            PartyUpgradeType.attackSpeed =>
              GameLogic.upgradeAttackSpeed(state),
            PartyUpgradeType.crit => GameLogic.upgradeCrit(state),
          };
          spent = true;
          break;
        }
      }
    }
  }
  print(
    'farm: $farmClears clears, +${farmGold}g raw, '
    'wallet=${state.gold} ATK=${_atk(state)} DEF=${_def(state)} '
    'HP=${_hp(state)}',
  );

  // Leave to hub (complete boss path via push).
  state = state.copyWith(inDungeon: false);
  _log('hub after farm', state);

  // Push for the boss.
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  state = GameLogic.setDungeonMode(state, DungeonMode.push);
  var floor = 1;
  var pushOk = true;
  while (state.inDungeon && floor <= 8) {
    final room = state.currentRoom;
    final r = _simulateFloor(state);
    print(
      'push F$floor ${room.type.name.padRight(8)} '
      '${r.seconds.toStringAsFixed(1)}s hp=${r.hpPct.toStringAsFixed(0)}% '
      '${r.label}',
    );
    if (r.wiped || r.timedOut) {
      pushOk = false;
      break;
    }
    state = GameLogic.completeCurrentRoom(r.state, goldGain: r.gold);
    state = _fullHeal(state);
    floor++;
  }

  _log(pushOk ? 'after push (ok)' : 'after push (failed)', state);

  if (GameLogic.canAscend(state)) {
    state = GameLogic.ascend(state);
    _log('ascended', state);
  } else {
    print(
      'ascend: blocked '
      '(bosses ${state.bossVictories}/'
      '${GameLogic.bossesRequiredForAscension(state.ascensionLevel)})',
    );
  }

  // Offline farm sample after loop.
  if (!state.inDungeon) {
    state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
    state = GameLogic.setDungeonMode(state, DungeonMode.farm);
  }
  final offline = GameLogic.applyOfflineProgress(
    state,
    const Duration(minutes: 20),
  );
  print(
    '\noffline 20m: ${offline.headline} '
    '(hasSummary=${offline.hasSummary})',
  );

  print('\n=== early loop done ===');
}

void _log(String label, GameState s) {
  print(
    '[$label] gold=${s.gold} ess=${s.essence} '
    'floor=${s.currentRoom.floorNumber} highest=${s.highestFloorCleared} '
    'boss=${s.bossVictories} A${s.ascensionLevel} '
    'inDungeon=${s.inDungeon} mode=${s.dungeonMode.name}',
  );
}

GameState _fullHeal(GameState s) => s.copyWith(
      heroes: [
        for (final h in s.heroes)
          h.copyWith(currentHp: s.effectiveHeroMaxHp(h)),
      ],
    );

int _atk(GameState s) =>
    s.heroes.fold<int>(0, (a, h) => a + s.effectiveHeroAttack(h));
int _def(GameState s) =>
    s.heroes.fold<int>(0, (a, h) => a + s.effectiveHeroDefense(h));
int _hp(GameState s) =>
    s.heroes.fold<int>(0, (a, h) => a + s.effectiveHeroMaxHp(h));

class _FloorResult {
  _FloorResult({
    required this.wiped,
    required this.timedOut,
    required this.seconds,
    required this.hpPct,
    required this.gold,
    required this.state,
  });
  final bool wiped;
  final bool timedOut;
  final double seconds;
  final double hpPct;
  final int gold;
  final GameState state;
  String get label => wiped
      ? 'WIPE'
      : timedOut
          ? 'STUCK'
          : 'clear';
}

_FloorResult _simulateFloor(GameState state) {
  var world = SpatialCombat.build(state);
  var current = state;
  const dt = 1 / 30;
  var t = 0.0;
  var gold = 0;
  while (t < 90) {
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
      );
    }
    if (step.roomCleared) {
      final maxHp = current.heroes.fold<int>(
        0,
        (a, h) => a + current.effectiveHeroMaxHp(h),
      );
      final cur = current.heroes.fold<int>(0, (a, h) => a + h.currentHp);
      return _FloorResult(
        wiped: false,
        timedOut: false,
        seconds: t,
        hpPct: maxHp == 0 ? 0 : 100 * cur / maxHp,
        gold: gold,
        state: current,
      );
    }
  }
  return _FloorResult(
    wiped: false,
    timedOut: true,
    seconds: t,
    hpPct: 0,
    gold: gold,
    state: current,
  );
}
