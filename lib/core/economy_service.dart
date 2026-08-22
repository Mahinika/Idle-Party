import 'ad_boost.dart';
import 'game_state.dart';
/// Wallet mutations shared by combat, loot grant, and market — no upward
/// deps to [GameLogic].
abstract final class EconomyService {
  /// Gold-find percent granted per Ascend Blessing stack.
  static const int ascendBlessingGoldPct = 3;

  /// Applies Ascension + Sanctuary + Blessing + gear + pet gold bonuses.
  static int applyGoldGain(GameState state, int baseGold) {
    if (baseGold <= 0) {
      return baseGold;
    }
    final percent =
        state.ascensionGoldBonusPercent +
        state.sanctuaryGoldBonusPercent +
        state.ascendBlessingGoldPercent +
        state.gearGoldFindPercent +
        state.petGoldFindPercent;
    if (percent <= 0) {
      return AdBoost.isActive(state.metaDepth.adBoostUntilMs)
          ? baseGold * 2
          : baseGold;
    }
    final found = baseGold + (baseGold * percent) ~/ 100;
    if (!AdBoost.isActive(state.metaDepth.adBoostUntilMs)) return found;
    return found * 2;
  }
}
