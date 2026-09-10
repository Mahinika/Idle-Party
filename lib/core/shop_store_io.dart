import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart' as test_env;
import 'shop_catalog.dart';

bool storeAvailable = false;
bool productsReady = false;

final Map<String, ProductDetails> _products = {};
StreamSubscription<List<PurchaseDetails>>? _sub;
void Function(String productId)? _onGranted;
void Function(String message)? _onMessage;
bool _androidStore = false;

String? storePriceLabel(String productId) => _products[productId]?.price;

bool get _platformOk {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

Future<void> warmup({
  required void Function(String productId) onGranted,
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
    _handlePurchases,
    onError: (Object e) {
      _onMessage?.call('Shop error — try again later.');
      debugPrint('ShopStore purchaseStream: $e');
    },
  );
  await _queryProducts();
}

Future<void> _queryProducts() async {
  if (!_androidStore) return;
  try {
    final response = await InAppPurchase.instance.queryProductDetails(
      ShopCatalog.productIds,
    );
    _products
      ..clear()
      ..addEntries(
        response.productDetails.map((p) => MapEntry(p.id, p)),
      );
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
  final started = item.isConsumable
      ? await InAppPurchase.instance.buyConsumable(purchaseParam: param)
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

Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
  for (final purchase in purchases) {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _onMessage?.call('Purchase pending…');
      case PurchaseStatus.error:
        _onMessage?.call(
          purchase.error?.message ?? 'Purchase canceled or failed.',
        );
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      case PurchaseStatus.canceled:
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        _onGranted?.call(purchase.productID);
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
    }
  }
}

Future<void> disposeStore() async {
  await _sub?.cancel();
  _sub = null;
  _products.clear();
  storeAvailable = false;
  productsReady = false;
  _androidStore = false;
}
