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

  /// What the 24h window may feature, best first. Every id here is a
  /// Play Console SKU that is activated and sold from the SHOP shelf.
  /// Hour packs (`starter_boost_6h` …) are restore-only, and `cinder_pouch` /
  /// `season_pass_premium` still say Unavailable, so none of them belong here.
  static const List<String> featuredLadder = [
    'ad_free',
    'supporter_qol',
    'long_away',
  ];

  /// True when the SHOP can open a buy sheet for [item] today.
  static bool sellable(ShopCatalogItem item) =>
      item.kind != ShopOfferKind.boostHours &&
      featuredLadder.contains(item.id) &&
      ShopCatalog.mayBuy(item.id, playLists: false);

  /// The pack the window highlights, or null to hide the offer.
  ///
  /// Walks [featuredLadder] and returns the first pack that is [sellable],
  /// not owned yet, and (once Play has answered) listed by Play. Never a pack
  /// the player cannot buy. [playListed] overrides the live Play catalog in
  /// tests; null means ask [ShopStore].
  static ShopCatalogItem? featuredItem(
    GameState state, {
    DateTime? now,
    Set<String>? playListed,
  }) {
    if (!windowOpen(state, now: now)) return null;
    final listed = playListed ??
        (ShopStore.productsReady
            ? {
                for (final id in featuredLadder)
                  if (ShopStore.storeLists(id)) id,
              }
            : null);
    for (final id in featuredLadder) {
      final item = ShopCatalog.byId[id];
      if (item == null || !sellable(item)) continue;
      if (ShopBilling.isOwned(state, item)) continue;
      if (listed != null && !listed.contains(id)) continue;
      return item;
    }
    return null;
  }

  static String featuredTitle(ShopCatalogItem item) {
    if (item.id == 'supporter_qol') return "Delver's Kit";
    return item.name;
  }
}
