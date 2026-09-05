import 'game_logic.dart';
import 'game_state.dart';

/// AL20 Blessing constellation — spend earned points on permanent nodes.
///
/// Points are **not** Ascend Blessing stacks (those stay flat ATK/DEF/VIT/gold).
/// Earn constellation points from AL20 unlock, Ashen Crown tickets, and Apex Trial.
abstract final class BlessingConstellation {
  static const int maxLit = 6;
  static const int starterPointsAtAl20 = 3;
  static const int ashenCrownPointReward = 1;
  static const int apexTrialPointReward = 1;

  static const List<(String id, String label, String branch, int cost)> nodes =
      <(String, String, String, int)>[
        ('off_atk', 'Keen Edge', 'Offense', 1),
        ('off_crit', 'Fatal Eye', 'Offense', 1),
        ('off_boss', 'Boss Breaker', 'Offense', 2),
        ('def_armor', 'Iron Hide', 'Defense', 1),
        ('def_sta', 'Deep Breath', 'Defense', 1),
        ('def_block', 'Ward Wall', 'Defense', 2),
        ('for_gold', 'Gilded Path', 'Fortune', 1),
        ('for_loot', 'Lucky Find', 'Fortune', 2),
        ('for_key', 'Key Tempo', 'Fortune', 2),
      ];

  static bool unlocked(GameState state) => GameLogic.isMaxAscension(state);

  /// Migrate legacy saves that treated Blessing stacks as spendable points,
  /// then grant the AL20 starter pack once.
  static GameState ensure(GameState state) {
    if (!unlocked(state)) return state;
    var md = state.metaDepth;
    var earned = md.constellationPointsEarned;
    var changed = false;

    // Legacy: spent/lit without an earned counter — preserve lit nodes only.
    if (earned < md.constellationPointsSpent) {
      earned = md.constellationPointsSpent;
      changed = true;
    }

    if (!md.constellationStarterGranted) {
      earned += starterPointsAtAl20;
      changed = true;
      md = md.copyWith(constellationStarterGranted: true);
    }

    if (!changed && earned == md.constellationPointsEarned) return state;
    return state.copyWith(
      metaDepth: md.copyWith(constellationPointsEarned: earned),
    );
  }

  static GameState grantPoints(GameState state, int points) {
    if (points <= 0 || !unlocked(state)) return state;
    final next = ensure(state);
    return next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        constellationPointsEarned:
            next.metaDepth.constellationPointsEarned + points,
      ),
    );
  }

  static int pointsAvailable(GameState state) {
    final md = state.metaDepth;
    return (md.constellationPointsEarned - md.constellationPointsSpent)
        .clamp(0, 999);
  }

  static bool isLit(GameState state, String id) =>
      state.metaDepth.constellationNodes.contains(id);

  static GameState lightNode(GameState state, String id) {
    var next = ensure(state);
    if (!unlocked(next) || isLit(next, id)) return next;
    if (next.metaDepth.constellationNodes.length >= maxLit) return next;
    (String id, String label, String branch, int cost)? def;
    for (final n in nodes) {
      if (n.$1 == id) {
        def = n;
        break;
      }
    }
    if (def == null) return next;
    if (pointsAvailable(next) < def.$4) return next;
    return next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        constellationNodes: [...next.metaDepth.constellationNodes, id],
        constellationPointsSpent:
            next.metaDepth.constellationPointsSpent + def.$4,
      ),
    );
  }

  /// Global ATK — offense node only (boss breaker is [bossAtkMul]).
  static double atkMul(GameState state) {
    var m = 1.0;
    if (isLit(state, 'off_atk')) m += 0.03;
    return m;
  }

  /// Extra ATK mul vs [EnemyRole.boss] only.
  static double bossAtkMul(GameState state) {
    var m = 1.0;
    if (isLit(state, 'off_boss')) m += 0.04;
    return m;
  }

  static double goldMul(GameState state) {
    var m = 1.0;
    if (isLit(state, 'for_gold')) m += 0.03;
    return m;
  }

  /// Flat gold-find percent (same value as [goldMul] − 1, for percent stacks).
  static int goldFindPercent(GameState state) =>
      isLit(state, 'for_gold') ? 3 : 0;

  static double critAdd(GameState state) => isLit(state, 'off_crit') ? 2.0 : 0.0;

  static int staAdd(GameState state) => isLit(state, 'def_sta') ? 40 : 0;

  static int defAdd(GameState state) => isLit(state, 'def_armor') ? 12 : 0;

  static double blockChanceAdd(GameState state) =>
      isLit(state, 'def_block') ? 0.05 : 0.0;

  static int lootFindPercent(GameState state) =>
      isLit(state, 'for_loot') ? 5 : 0;

  static double keyParMul(GameState state) =>
      isLit(state, 'for_key') ? 1.05 : 1.0;
}
