import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/analytics_events.dart';
import 'package:idle_party/core/shop_billing.dart';

/// Play Billing settle helpers (IP-154 / IP-155). Full PurchaseDetails wiring
/// stays on device; these guard analytics and restore classification.
void main() {
  test('user-cancel Play codes route to store_purchase_cancel', () {
    expect(AnalyticsEvents.billingUserCanceled('1'), isTrue);
    expect(AnalyticsEvents.billingUserCanceled('USERCANCELED'), isTrue);
    expect(AnalyticsEvents.billingUserCanceled('7'), isFalse);
  });

  test('restore path treats past query as existing purchase', () {
    expect(
      ShopBilling.countsAsExistingPurchase(
        fromPastQuery: true,
        statusRestored: false,
      ),
      isTrue,
    );
    expect(
      ShopBilling.countsAsExistingPurchase(
        fromPastQuery: false,
        statusRestored: true,
      ),
      isTrue,
    );
    expect(
      ShopBilling.countsAsExistingPurchase(
        fromPastQuery: false,
        statusRestored: false,
      ),
      isFalse,
    );
  });
}