import 'dart:async';

import 'ad_boost.dart';
import 'app_analytics.dart';
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

  /// Gold wallet delta after a grant or spend (sampled in [AppAnalytics]).
  static void logGoldDelta(int delta, {required String source}) {
    if (delta == 0) return;
    unawaited(
      AppAnalytics.logVirtualCurrency(
        earn: delta > 0,
        name: 'gold',
        value: delta.abs(),
        source: source,
      ),
    );
  }
}
