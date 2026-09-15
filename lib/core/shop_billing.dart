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
        md = md.copyWith(
          adFree: true,
          adTickets: min(9999, md.adTickets + 2),
        );
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
      case ShopOfferKind.permScroll:
        if (item.permMask == 0) return state;
        if ((md.shopPermScrolls & item.permMask) == item.permMask) {
          return state;
        }
        md = md.copyWith(
          shopPermScrolls: md.shopPermScrolls | item.permMask,
        );
    }
    return state.copyWith(metaDepth: md);
  }

  /// SKUs that should appear as owned / disabled after restore.
  static bool isOwned(GameState state, ShopCatalogItem item) {
    final md = state.metaDepth;
    return switch (item.kind) {
      ShopOfferKind.boostHours => item.oneTime && md.shopStarterClaimed,
      ShopOfferKind.adFree => md.adFree,
      ShopOfferKind.supporterQol => md.shopBagBonusSlots > 0,
      ShopOfferKind.permScroll =>
        item.permMask != 0 &&
        (md.shopPermScrolls & item.permMask) == item.permMask,
    };
  }
}
