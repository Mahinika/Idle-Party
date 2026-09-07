import 'dart:math';

import 'game_logic.dart';
import 'game_state.dart';
import 'shop_catalog.dart';

/// Apply a successful SHOP purchase to [state].
///
/// Play Billing wiring calls this after Google acknowledges a buy / restore.
/// Until Billing ships, SHOP UI stays **COMING LATER** and never invokes this
/// from the player path.
abstract final class ShopBilling {
  /// Flip when `in_app_purchase` + Console SKUs are live.
  static const billingReady = false;

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
        md = md.copyWith(adFree: true);
        // Welcome: +2 Ad Tickets (same power path as watching).
        md = md.copyWith(
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
        md = md.copyWith(
          shopBagBonusSlots: md.shopBagBonusSlots + item.bagSlots,
        );
        if (item.boostHours > 0) {
          md = GameLogic.grantFullBoostHours(
            md,
            item.boostHours,
            nowMs: clock.millisecondsSinceEpoch,
          );
        }
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
    };
  }
}
