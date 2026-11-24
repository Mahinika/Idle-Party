import 'game_logic.dart';
import 'game_state.dart';
import 'shop_billing.dart';
import 'shop_catalog.dart';
import 'shop_store.dart';

/// 24h hub SHOP highlight after first boss / Ascend unlock.
abstract final class ShopHubOffer {
  static const int windowMs = 24 * 60 * 60 * 1000;

  static GameState ensureWindow(GameState state, {DateTime? now}) {
    if (!GameLogic.showDailyChase(state)) return state;
    if (state.metaDepth.shopOfferStartedMs > 0) return state;
    final ms = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(shopOfferStartedMs: ms),
    );
  }

  static int endsAtMs(GameState state) =>
      state.metaDepth.shopOfferStartedMs + windowMs;

  static bool windowOpen(GameState state, {DateTime? now}) {
    final start = state.metaDepth.shopOfferStartedMs;
    if (start <= 0) return false;
    final ms = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    return ms < start + windowMs;
  }

  static bool showHubBadge(GameState state, {DateTime? now}) {
    if (!GameLogic.showDailyChase(state)) return false;
    if (!windowOpen(state, now: now)) return false;
    final item = featuredItem(state, now: now);
    if (item == null) return false;
    // A dot on SHOP means Play will sell this pack. Sideload and a
    // missing SKU stay quiet.
    if (!ShopStore.storeAvailable || !ShopStore.storeLists(item.id)) {
      return false;
    }
    return !ShopBilling.isOwned(state, item);
  }

  static String countdownLine(GameState state, {DateTime? now}) {
    if (!windowOpen(state, now: now)) return '';
    final left = endsAtMs(state) -
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final hours = (left / (3600 * 1000)).ceil().clamp(0, 48);
    if (hours <= 0) return 'Offer ends soon';
    return 'SHOP offer · ${hours}h left';
  }

  static ShopCatalogItem? featuredItem(
    GameState state, {
    DateTime? now,
    bool? playListsAdFree,
  }) {
    if (!windowOpen(state, now: now)) return null;
    final adFree = ShopCatalog.byId['ad_free'];
    final supporter = ShopCatalog.byId['supporter_qol'];
    if (adFree == null || supporter == null) return null;
    if (!ShopBilling.isOwned(state, adFree)) {
      final listed = playListsAdFree ??
          (ShopStore.storeAvailable && ShopStore.storeLists(adFree.id));
      if (listed) return adFree;
    }
    return supporter;
  }

  static String featuredTitle(ShopCatalogItem item) {
    if (item.id == 'supporter_qol') return "Delver's Kit";
    return item.name;
  }
}
