import 'dart:math';

import 'game_logic.dart';
import 'game_state.dart';
import 'shop_catalog.dart';

/// Apply a successful SHOP purchase to [state].
///
/// Play Billing wiring calls this after Google acknowledges a buy / restore.
abstract final class ShopBilling {
  /// Billing package + SHOP BUY path are live. Sideload / missing Console SKUs
  /// still soft-fail with a toast — Play-installed builds are the real path.
  static const billingReady = true;

  static GameState applyPurchase(
    GameState state,
    ShopCatalogItem item, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    var md = state.metaDepth;
    switch (item.kind) {
      case ShopOfferKind.boostHours:
        if (item.oneTime && md.shopStarterClaimed) return state;
        md = GameLogic.grantFullBoostHours(
          md,
          item.boostHours,
          nowMs: clock.millisecondsSinceEpoch,
        );
        if (item.oneTime) {
          md = md.copyWith(shopStarterClaimed: true);
        }
      case ShopOfferKind.adFree:
        // Restore must not re-grant welcome tickets.
        if (md.adFree) return state;
        md = md.copyWith(adFree: true, adTickets: min(9999, md.adTickets + 2));
        if (item.boostHours > 0) {
          md = GameLogic.grantFullBoostHours(
            md,
            item.boostHours,
            nowMs: clock.millisecondsSinceEpoch,
          );
        }
      case ShopOfferKind.supporterQol:
        // Restore must not stack bag slots again.
        if (md.shopBagBonusSlots > 0) return state;
        md = md.copyWith(shopBagBonusSlots: item.bagSlots);
        if (item.boostHours > 0) {
          md = GameLogic.grantFullBoostHours(
            md,
            item.boostHours,
            nowMs: clock.millisecondsSinceEpoch,
          );
        }
      case ShopOfferKind.cinders:
        if (item.cinderGrant <= 0) return state;
        md = md.copyWith(cinders: min(9999, md.cinders + item.cinderGrant));
      case ShopOfferKind.permScroll:
        if (item.permMask == 0) return state;
        if ((md.shopPermScrolls & item.permMask) == item.permMask) {
          return state;
        }
        md = md.copyWith(shopPermScrolls: md.shopPermScrolls | item.permMask);
      case ShopOfferKind.longAway:
        if (md.shopLongAway) return state;
        md = md.copyWith(shopLongAway: true);
    }
    return state.copyWith(metaDepth: md);
  }

  /// A Play restore re-applies a non-consumable once. A finished consumable
  /// is not paid again. An unfinished one is granted by [shouldGrantPurchase].
  static bool grantOnRestore(ShopCatalogItem item) => !item.isConsumable;

  /// Startup [queryPastPurchases] reports [purchased] for packs the player
  /// already owns. That row is an existing purchase, same as a restore.
  /// A live buy is neither, so it can toast and log store_purchase.
  static bool countsAsExistingPurchase({
    required bool fromPastQuery,
    required bool statusRestored,
  }) => fromPastQuery || statusRestored;

  static const int grantedPurchaseIdCap = 64;

  static bool alreadyGranted(GameState state, String purchaseId) {
    final id = purchaseId.trim();
    if (id.isEmpty) return false;
    return state.metaDepth.grantedShopPurchaseIds.contains(id);
  }

  /// Whether this Play event should add the pack.
  ///
  /// An unconsumed consumable is granted once per purchase id, including when
  /// startup [queryPastPurchases] or RESTORE surfaces it. A repeat of that id
  /// does not pay again. A consumable with no id is granted only on a fresh
  /// buy, never on restore.
  static bool shouldGrantPurchase({
    required ShopCatalogItem item,
    required bool restored,
    required String purchaseId,
    required bool alreadyGranted,
  }) {
    if (alreadyGranted) return false;
    if (item.isConsumable) {
      if (purchaseId.trim().isEmpty) return !restored;
      return true;
    }
    if (restored && !grantOnRestore(item)) return false;
    return true;
  }

  /// Grant [item] and remember [purchaseId] in the same state.
  /// A known id returns [state] unchanged.
  static GameState applyTrackedPurchase(
    GameState state,
    ShopCatalogItem item, {
    required String purchaseId,
    DateTime? now,
  }) {
    final id = purchaseId.trim();
    if (id.isNotEmpty && alreadyGranted(state, id)) return state;
    final granted = applyPurchase(state, item, now: now);
    if (id.isEmpty) return granted;
    final ids = <String>[...granted.metaDepth.grantedShopPurchaseIds];
    if (!ids.contains(id)) ids.add(id);
    final trimmed = ids.length > grantedPurchaseIdCap
        ? ids.sublist(ids.length - grantedPurchaseIdCap)
        : ids;
    return granted.copyWith(
      metaDepth: granted.metaDepth.copyWith(
        grantedShopPurchaseIds: List<String>.unmodifiable(trimmed),
      ),
    );
  }

  /// SKUs that should appear as owned / disabled after restore.
  static bool isOwned(GameState state, ShopCatalogItem item) {
    final md = state.metaDepth;
    return switch (item.kind) {
      ShopOfferKind.boostHours => item.oneTime && md.shopStarterClaimed,
      ShopOfferKind.adFree => md.adFree,
      ShopOfferKind.supporterQol => md.shopBagBonusSlots > 0,
      ShopOfferKind.cinders => false,
      ShopOfferKind.permScroll =>
        item.permMask != 0 &&
            (md.shopPermScrolls & item.permMask) == item.permMask,
      ShopOfferKind.longAway => md.shopLongAway,
    };
  }
}
