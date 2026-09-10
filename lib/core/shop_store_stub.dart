bool storeAvailable = false;
bool productsReady = false;

String? storePriceLabel(String productId) => null;

Future<void> warmup({
  required void Function(String productId) onGranted,
  void Function(String message)? onMessage,
}) async {}

Future<String?> buy(String productId) async =>
    'Play Billing needs a Play Store install.';

Future<String?> restore() async =>
    'Play Billing needs a Play Store install.';

Future<void> refreshProducts() async {}

Future<void> disposeStore() async {}
