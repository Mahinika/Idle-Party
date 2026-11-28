import 'dart:async';

import 'ad_boost.dart';
import 'live_event.dart';
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
    final found = percent <= 0
        ? baseGold
        : baseGold + (baseGold * percent) ~/ 100;
    final boosted = AdBoost.goldActive(state.metaDepth)
        ? found * AdBoost.goldMul
        : found;
    return LiveEvent.scaleGold(boosted, DateTime.now());
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
