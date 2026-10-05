import 'ad_boost.dart';
import 'shop_catalog.dart';

/// Live knobs from Firebase Remote Config.
///
/// Shipped numbers are the game until a published value lands inside the
/// allowed range. Gold piles stay in code. Web, tests, and a missing
/// Firebase project never leave these defaults.
abstract final class RemoteTune {
  static const String keyDailyCap = 'wisp_daily_cap';
  static const String keyFirstDelaySec = 'wisp_first_delay_sec';
  static const String keyIntervalSec = 'wisp_interval_sec';
  static const String keyVisibleSec = 'wisp_visible_sec';
  static const String keyShopFeatured = 'shop_featured_id';

  static const int defaultDailyCap = 6;
  static const int defaultFirstDelaySec = 90;
  static const int defaultIntervalSec = 10 * 60;
  static const int defaultVisibleSec = 10;

  static int _dailyCap = defaultDailyCap;
  static int _firstDelaySec = defaultFirstDelaySec;
  static int _intervalSec = defaultIntervalSec;
  static int _visibleSec = defaultVisibleSec;
  static String _shopFeaturedId = '';
  static bool _wispFromRemote = false;

  static int get wispDailyCap => _dailyCap;
  static int get wispFirstDelayMs => _firstDelaySec * 1000;
  static int get wispIntervalMs => _intervalSec * 1000;
  static int get wispVisibleMs => _visibleSec * 1000;
  static String get shopFeaturedId => _shopFeaturedId;

  /// A published WISP number differed from the shipped default.
  /// Debug builds keep the fast lantern until this is true.
  static bool get wispFromRemote => _wispFromRemote;

  static Map<String, dynamic> get defaults => <String, dynamic>{
        keyDailyCap: defaultDailyCap,
        keyFirstDelaySec: defaultFirstDelaySec,
        keyIntervalSec: defaultIntervalSec,
        keyVisibleSec: defaultVisibleSec,
        keyShopFeatured: '',
      };

  /// [fromRemote] is true only after a fetch this process accepted.
  /// Out-of-range numbers and unknown shop ids fall back to shipped.
  static void apply({
    int? dailyCap,
    int? firstDelaySec,
    int? intervalSec,
    int? visibleSec,
    String? shopFeaturedId,
    bool fromRemote = false,
  }) {
    final cap = _inRange(dailyCap, 1, 12, defaultDailyCap);
    final first = _inRange(firstDelaySec, 15, 3600, defaultFirstDelaySec);
    final interval = _inRange(intervalSec, 60, 3600, defaultIntervalSec);
    final visible = _inRange(visibleSec, 5, 30, defaultVisibleSec);
    final id = (shopFeaturedId ?? '').trim();
    _dailyCap = cap;
    _firstDelaySec = first;
    _intervalSec = interval;
    _visibleSec = visible;
    _shopFeaturedId = ShopCatalog.byId.containsKey(id) ? id : '';
    _wispFromRemote = fromRemote &&
        (cap != defaultDailyCap ||
            first != defaultFirstDelaySec ||
            interval != defaultIntervalSec ||
            visible != defaultVisibleSec);
  }

  static void reset() => apply();

  /// Empty id keeps the forever-scrolls bundle as the lit row.
  static bool highlights(ShopCatalogItem item) {
    if (_shopFeaturedId.isEmpty) return item.permMask == AdBoost.permAll;
    return item.id == _shopFeaturedId;
  }

  /// Moves the featured SKU to the top of the list it already belongs to.
  static List<ShopCatalogItem> pin(List<ShopCatalogItem> items) {
    final id = _shopFeaturedId;
    if (id.isEmpty) return items;
    final index = items.indexWhere((item) => item.id == id);
    if (index <= 0) return items;
    return <ShopCatalogItem>[
      items[index],
      for (var i = 0; i < items.length; i++)
        if (i != index) items[i],
    ];
  }

  static int _inRange(int? raw, int min, int max, int fallback) {
    if (raw == null || raw < min || raw > max) return fallback;
    return raw;
  }
}
