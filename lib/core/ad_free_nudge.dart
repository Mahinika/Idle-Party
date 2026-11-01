import '../models/meta_depth.dart';
import 'ad_boost.dart';
import 'game_state.dart';
import 'shop_catalog.dart';

/// Where the Ad-free line is allowed to sit.
///
/// SCROLLS on the hub only. Welcome Back and the fight never qualify.
enum AdFreeNudgePlace { scrolls, welcomeBack, fight }

/// One quiet Ad-free line after the player has finished three rewarded ads.
///
/// Shown once, and only when Play has returned [productId]. Players who
/// already own Ad-free or Forever Rest never see it.
abstract final class AdFreeNudge {
  static const int watchThreshold = 3;

  /// Same Play product as the SHOP row.
  static const String productId = 'ad_free';

  static const String line = 'Tired of ads? Ad-free is a one-time purchase';

  /// Play returned [productId], or this binary is a sideload QA APK.
  ///
  /// Test APKs compile in a git SHA and ship as `com.idleparty.app.test`.
  /// Billing cannot return the Play app's SKU there. Play release builds
  /// omit the SHA, so a missing product still hides the line.
  static bool offerReady({
    required bool playListsAdFree,
    required bool sideloadQaBuild,
  }) => playListsAdFree || sideloadQaBuild;

  static bool show({
    required MetaDepthState meta,
    required bool playListsAdFree,
    AdFreeNudgePlace place = AdFreeNudgePlace.scrolls,
  }) {
    if (place != AdFreeNudgePlace.scrolls) return false;
    if (meta.adFreeNudgeShown) return false;
    if (meta.rewardedWatchCount < watchThreshold) return false;
    if (meta.adFree) return false;
    if (AdBoost.hasPerm(meta, AdBoost.permRest)) return false;
    if (!playListsAdFree) return false;
    final item = ShopCatalog.byId[productId];
    if (item == null || item.kind != ShopOfferKind.adFree) return false;
    return true;
  }

  /// One finished rewarded watch. Preview tickets do not call this.
  static GameState noteWatch(GameState state) {
    final next = state.metaDepth.rewardedWatchCount + 1;
    if (next > 9999) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(rewardedWatchCount: next),
    );
  }

  static GameState markShown(GameState state) {
    if (state.metaDepth.adFreeNudgeShown) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(adFreeNudgeShown: true),
    );
  }
}
