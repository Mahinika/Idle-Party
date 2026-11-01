import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'app_analytics.dart';
import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'shop_billing.dart';
import 'shop_catalog.dart';

bool storeAvailable = false;
bool productsReady = false;

final Map<String, ProductDetails> _products = {};
StreamSubscription<List<PurchaseDetails>>? _sub;
Future<bool> Function({
  required String productId,
  required String purchaseId,
  required bool restored,
  bool recovered,
})?
_onGranted;
void Function(String message)? _onMessage;
bool _androidStore = false;
final Map<String, Future<void>> _settleTails = {};

String? storePriceLabel(String productId) => _products[productId]?.price;

bool storeLists(String productId) => _products.containsKey(productId);

bool get _platformOk {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

Future<void> warmup({
  required Future<bool> Function({
    required String productId,
    required String purchaseId,
    required bool restored,
    bool recovered,
  })
  onGranted,
  void Function(String message)? onMessage,
}) async {
  _onGranted = onGranted;
  _onMessage = onMessage;
  if (!_platformOk) {
    storeAvailable = false;
    productsReady = false;
    return;
  }
  final iap = InAppPurchase.instance;
  storeAvailable = await iap.isAvailable();
  if (!storeAvailable) {
    productsReady = false;
    return;
  }
  _androidStore = true;
  _sub ??= iap.purchaseStream.listen(
    (purchases) {
      unawaited(_handlePurchases(purchases));
    },
    onError: (Object e) {
      _onMessage?.call('Shop error — try again later.');
      debugPrint('ShopStore purchaseStream: $e');
    },
  );
  await _queryProducts();
  await _recoverUnfinishedPurchases();
}

Future<void> _queryProducts() async {
  if (!_androidStore) return;
  try {
    final response = await InAppPurchase.instance.queryProductDetails(
      ShopCatalog.productIds,
    );
    _products
      ..clear()
      ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
    productsReady = _products.isNotEmpty;
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('ShopStore missing Console SKUs: ${response.notFoundIDs}');
    }
    if (response.error != null) {
      debugPrint('ShopStore query error: ${response.error}');
    }
  } catch (e, st) {
    debugPrint('ShopStore queryProductDetails failed: $e\n$st');
    productsReady = _products.isNotEmpty;
  }
}

/// Re-fetch Play catalog (call when SHOP opens).
Future<void> refreshProducts() async {
  if (!_androidStore || !storeAvailable) return;
  await _queryProducts();
}

Future<String?> buy(String productId) async {
  if (!_platformOk || !storeAvailable) {
    return 'Play Billing needs a Play Store install.';
  }
  // Always re-query — newly activated Console SKUs can take hours to appear.
  await _queryProducts();
  final details = _products[productId];
  if (details == null) {
    return 'Play has not listed this pack yet. '
        'Activated SKUs can take a few hours — clear Play Store cache, '
        'fully close the app, and try again.';
  }
  final item = ShopCatalog.byId[productId];
  if (item == null) return 'Unknown pack.';
  final param = PurchaseParam(productDetails: details);
  // autoConsume would spend the pouch before we save the grant.
  final started = item.isConsumable
      ? await InAppPurchase.instance.buyConsumable(
          purchaseParam: param,
          autoConsume: false,
        )
      : await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  if (!started) return 'Could not open the buy sheet.';
  return null;
}

Future<String?> restore() async {
  if (!_platformOk || !storeAvailable) {
    return 'Play Billing needs a Play Store install.';
  }
  try {
    await InAppPurchase.instance.restorePurchases();
    return null;
  } catch (e) {
    debugPrint('ShopStore restore: $e');
    return 'Restore failed — try again later.';
  }
}

/// Unacknowledged consumables survive a process death. Grant them, save,
/// then consume. Play does not return a purchase after it is consumed.
Future<void> _recoverUnfinishedPurchases() async {
  if (!_androidStore) return;
  try {
    final addition = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) {
      debugPrint('ShopStore queryPastPurchases: ${response.error}');
    }
    // These rows keep status purchased. Treat them as existing so an old
    // ad-free or Long Away pack does not toast "Purchased" or log a buy.
    await _handlePurchases(response.pastPurchases, fromPastQuery: true);
  } catch (e, st) {
    debugPrint('ShopStore queryPastPurchases failed: $e\n$st');
  }
}

Future<void> _handlePurchases(
  List<PurchaseDetails> purchases, {
  bool fromPastQuery = false,
}) async {
  for (final purchase in purchases) {
    final key = _settleKey(purchase);
    final prev = _settleTails[key] ?? Future<void>.value();
    final next = prev.catchError((Object _) {}).then(
      (_) => _settlePurchase(purchase, fromPastQuery: fromPastQuery),
    );
    _settleTails[key] = next;
    await next;
  }
}

String _settleKey(PurchaseDetails purchase) {
  final id = _purchaseKey(purchase);
  if (id.isNotEmpty) return id;
  return '${purchase.productID}:${purchase.status.name}';
}

String _purchaseKey(PurchaseDetails purchase) {
  final order = (purchase.purchaseID ?? '').trim();
  if (order.isNotEmpty) return order;
  return purchase.verificationData.serverVerificationData.trim();
}

Future<void> _settlePurchase(
  PurchaseDetails purchase, {
  bool fromPastQuery = false,
}) async {
  switch (purchase.status) {
    case PurchaseStatus.pending:
      _onMessage?.call('Purchase pending…');
    case PurchaseStatus.error:
      _onMessage?.call(
        purchase.error?.message ?? 'Purchase canceled or failed.',
      );
      unawaited(AppAnalytics.storePurchaseCancel(purchase.productID));
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    case PurchaseStatus.canceled:
      unawaited(AppAnalytics.storePurchaseCancel(purchase.productID));
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    case PurchaseStatus.purchased:
    case PurchaseStatus.restored:
      final item = ShopCatalog.byId[purchase.productID];
      final purchaseId = _purchaseKey(purchase);
      var saved = true;
      if (item != null && _onGranted != null) {
        try {
          saved = await _onGranted!(
            productId: purchase.productID,
            purchaseId: purchaseId,
            restored: ShopBilling.countsAsExistingPurchase(
              fromPastQuery: fromPastQuery,
              statusRestored: purchase.status == PurchaseStatus.restored,
            ),
            recovered: fromPastQuery,
          );
        } catch (e, st) {
          debugPrint('ShopStore grant failed: $e\n$st');
          saved = false;
        }
      }
      if (!saved) return;
      if (item != null && item.isConsumable) {
        await _consumePurchase(purchase);
      } else if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
  }
}

Future<void> _consumePurchase(PurchaseDetails purchase) async {
  try {
    final addition = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final result = await addition.consumePurchase(purchase);
    if (result.responseCode != BillingResponse.ok) {
      debugPrint(
        'ShopStore consume ${purchase.productID}: '
        '${result.responseCode} ${result.debugMessage}',
      );
    }
  } catch (e, st) {
    debugPrint('ShopStore consume failed: $e\n$st');
  }
}

Future<void> disposeStore() async {
  await _sub?.cancel();
  _sub = null;
  _products.clear();
  _settleTails.clear();
  storeAvailable = false;
  productsReady = false;
  _androidStore = false;
}
