import 'game_logic.dart';
import 'game_state.dart';

/// AL20 Blessing constellation — spend Ascend points on permanent nodes.
abstract final class BlessingConstellation {
  static const int maxLit = 6;

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

  static int pointsAvailable(GameState state) {
    final earned = state.metaDepth.ascendBlessings;
    return (earned - state.metaDepth.constellationPointsSpent).clamp(0, 999);
  }

  static bool isLit(GameState state, String id) =>
      state.metaDepth.constellationNodes.contains(id);

  static GameState lightNode(GameState state, String id) {
    if (!unlocked(state) || isLit(state, id)) return state;
    if (state.metaDepth.constellationNodes.length >= maxLit) return state;
    (String id, String label, String branch, int cost)? def;
    for (final n in nodes) {
      if (n.$1 == id) {
        def = n;
        break;
      }
    }
    if (def == null) return state;
    if (pointsAvailable(state) < def.$4) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        constellationNodes: [...state.metaDepth.constellationNodes, id],
        constellationPointsSpent:
            state.metaDepth.constellationPointsSpent + def.$4,
      ),
    );
  }

  static double atkMul(GameState state) {
    var m = 1.0;
    if (isLit(state, 'off_atk')) m += 0.03;
    if (isLit(state, 'off_boss')) m += 0.04;
    return m;
  }

  static double goldMul(GameState state) {
    var m = 1.0;
    if (isLit(state, 'for_gold')) m += 0.03;
    return m;
  }

  static double critAdd(GameState state) => isLit(state, 'off_crit') ? 2.0 : 0.0;

  static int staAdd(GameState state) => isLit(state, 'def_sta') ? 40 : 0;

  static int defAdd(GameState state) => isLit(state, 'def_armor') ? 12 : 0;
}
