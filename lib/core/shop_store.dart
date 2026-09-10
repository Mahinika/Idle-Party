import 'shop_store_stub.dart'
    if (dart.library.io) 'shop_store_io.dart' as impl;

/// Play Billing facade for bottom-tab SHOP.
///
/// No-op on web / tests / when Billing is unavailable (sideload).
abstract final class ShopStore {
  static bool get storeAvailable => impl.storeAvailable;

  static bool get productsReady => impl.productsReady;

  /// Localized Play price, or null if the SKU is not in the store response.
  static String? storePriceLabel(String productId) =>
      impl.storePriceLabel(productId);

  /// Listen to [purchaseStream] and query product details.
  static Future<void> warmup({
    required void Function(String productId) onGranted,
    void Function(String message)? onMessage,
  }) => impl.warmup(onGranted: onGranted, onMessage: onMessage);

  /// Start a buy sheet. Returns an error toast, or null if the sheet opened.
  static Future<String?> buy(String productId) => impl.buy(productId);

  /// Re-fetch Play product details (SHOP open / after Console activation).
  static Future<void> refreshProducts() => impl.refreshProducts();

  /// Restore non-consumables (ad-free / supporter / starter).
  static Future<String?> restore() => impl.restore();

  static Future<void> dispose() => impl.disposeStore();
}
