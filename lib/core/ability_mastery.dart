import 'game_state.dart';

/// Party-wide spellcraft from lifetime ability casts (kept on Ascend).
abstract final class AbilityMastery {
  static const int castsPerLevel = 350;
  static const int maxLevel = 30;

  static int levelForCasts(int lifetimeCasts) =>
      (lifetimeCasts ~/ castsPerLevel).clamp(0, maxLevel);

  static int level(GameState state) =>
      levelForCasts(state.metaDepth.lifetimeAbilityCasts);

  /// +0.5% ability damage per level (max +15%).
  static double damageMul(GameState state) => 1.0 + level(state) * 0.005;

  static String progressLine(GameState state) {
    final lv = level(state);
    final casts = state.metaDepth.lifetimeAbilityCasts;
    if (lv >= maxLevel) {
      return 'Spellcraft Lv$lv · +${(lv * 0.5).toStringAsFixed(1)}% ability damage (max)';
    }
    final nextAt = (lv + 1) * castsPerLevel;
    final need = nextAt - casts;
    return 'Spellcraft Lv$lv · +${(lv * 0.5).toStringAsFixed(1)}% · $need casts to Lv${lv + 1}';
  }
}
