import 'game_state.dart';
import 'shop_billing.dart';
import 'shop_catalog.dart';

enum CouponRedeemStatus { granted, alreadyUsed, alreadyOwned, unknown }

class CouponRedeemOutcome {
  const CouponRedeemOutcome({required this.state, required this.status});

  final GameState state;
  final CouponRedeemStatus status;
}

/// Local coupon catalog. Codes are normalized to A–Z / 0–9.
abstract final class CouponCodes {
  /// Unlocks every forever SHOP scroll on this save.
  static const String foreverScrolls = 'FOREVERSCROLLS';

  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  static CouponRedeemOutcome redeem(GameState state, String raw) {
    final id = normalize(raw);
    if (id.isEmpty || id != foreverScrolls) {
      return CouponRedeemOutcome(
        state: state,
        status: CouponRedeemStatus.unknown,
      );
    }
    final used = state.metaDepth.redeemedCoupons;
    if (used.contains(id)) {
      return CouponRedeemOutcome(
        state: state,
        status: CouponRedeemStatus.alreadyUsed,
      );
    }
    final bundle = ShopCatalog.offered.firstWhere(
      (e) => e.id == 'perm_scrolls_all',
    );
    // Already owned via SHOP — do not burn the code on this save.
    if (ShopBilling.isOwned(state, bundle)) {
      return CouponRedeemOutcome(
        state: state,
        status: CouponRedeemStatus.alreadyOwned,
      );
    }
    final stamped = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        redeemedCoupons: [...used, id],
      ),
    );
    return CouponRedeemOutcome(
      state: ShopBilling.applyPurchase(stamped, bundle),
      status: CouponRedeemStatus.granted,
    );
  }
}
