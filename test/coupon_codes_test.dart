import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/coupon_codes.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 9, 15, 12);

  test('FOREVERSCROLLS grants all shop forever scrolls once', () {
    var state = GameLogic.createInitialState(now: now);
    final first = CouponCodes.redeem(state, 'forever-scrolls');
    expect(first.status, CouponRedeemStatus.granted);
    state = first.state;
    expect(state.metaDepth.shopPermScrolls, AdBoost.permAll);
    expect(state.metaDepth.redeemedCoupons, contains('FOREVERSCROLLS'));
    for (final item in ShopCatalog.offered.where(
      (e) => e.kind == ShopOfferKind.permScroll,
    )) {
      expect(ShopBilling.isOwned(state, item), isTrue, reason: item.id);
    }

    final again = CouponCodes.redeem(state, 'FOREVERSCROLLS');
    expect(again.status, CouponRedeemStatus.alreadyUsed);
    expect(again.state.metaDepth.shopPermScrolls, AdBoost.permAll);
  });

  test('unknown coupon does not change the save', () {
    final state = GameLogic.createInitialState(now: now);
    final bad = CouponCodes.redeem(state, 'not-a-code');
    expect(bad.status, CouponRedeemStatus.unknown);
    expect(identical(bad.state, state), isTrue);
  });

  test('old saves default redeemedCoupons empty', () {
    expect(const MetaDepthState().redeemedCoupons, isEmpty);
    expect(MetaDepthState.fromJson(const {}).redeemedCoupons, isEmpty);
  });
}
