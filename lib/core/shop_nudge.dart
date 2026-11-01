import 'ad_boost.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'shop_catalog.dart';

/// When to mention ad-free and Forever Rest. Existing SHOP rows only.
class ShopNudge {
  ShopNudge._();

  static const int afterAds = 3;
  static const Duration quietFor = Duration(days: 7);
  static const String adFreeId = 'ad_free';
  static const String restId = 'perm_scroll_rest';
  static const String speedTipId = 'speed_2x';

  static const String speedLine =
      'SPEED 2× plays this cave faster. Loot stays the same.';

  /// One line under the speed chip until the player taps it.
  /// 3× is not offered. Fight ticks are already the reason Lite VFX exists.
  static String? speedCoachLine(GameState state) {
    if (state.combatPace >= 2) return null;
    if (state.seenTips.contains(speedTipId)) return null;
    if (state.highestFloorCleared < 1 && state.ascensionLevel < 1) {
      return null;
    }
    return speedLine;
  }

  /// Count one finished rewarded ad. [offerIds] is empty unless this watch
  /// is the moment to show the card.
  static ({GameState state, List<String> offerIds}) noteRewardedAd(
    GameState state, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final md = state.metaDepth;
    final count = md.rewardedAdsWatched + 1;
    final due =
        count >= afterAds &&
        GameLogic.showDailyChase(state) &&
        _quiet(md.shopNudgeAtMs, clock);
    final offers = due ? offersFor(state) : const <String>[];
    final next = md.copyWith(
      rewardedAdsWatched: count,
      shopNudgeAtMs: offers.isEmpty ? null : clock.millisecondsSinceEpoch,
    );
    return (state: state.copyWith(metaDepth: next), offerIds: offers);
  }

  /// Catalog ids the player does not already own.
  static List<String> offersFor(GameState state) {
    final md = state.metaDepth;
    final out = <String>[];
    if (!md.adFree && ShopCatalog.byId.containsKey(adFreeId)) {
      out.add(adFreeId);
    }
    if (!AdBoost.hasPerm(md, AdBoost.permRest) &&
        ShopCatalog.byId.containsKey(restId)) {
      out.add(restId);
    }
    return out;
  }

  static bool _quiet(int lastMs, DateTime now) {
    if (lastMs <= 0) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return now.difference(last) >= quietFor;
  }
}
