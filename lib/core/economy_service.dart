import 'ad_boost.dart';
import 'game_state.dart';
/// Wallet mutations shared by combat, loot grant, and market — no upward
/// deps to [GameLogic].
abstract final class EconomyService {
  /// Gold-find percent per Ascend Blessing stack — keep in sync with
  /// [GameLogic.ascendBlessingGoldPct].
  static const int ascendBlessingGoldPct = 8;

  /// Applies Ascension + Sanctuary + Blessing + gear + pet gold bonuses.
  static int applyGoldGain(GameState state, int baseGold) {
    if (baseGold <= 0) {
      return baseGold;
    }
    final percent = state.effectiveGoldFindPercent;
    if (percent <= 0) {
      return AdBoost.goldActive(state.metaDepth)
          ? baseGold * AdBoost.goldMul
          : baseGold;
    }
    final found = baseGold + (baseGold * percent) ~/ 100;
    if (!AdBoost.goldActive(state.metaDepth)) return found;
    return found * AdBoost.goldMul;
  }
}
