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
  static const String keyFirstClimbAutoContinue = 'first_climb_auto_continue';
  static const String keyFirstClimbPlayNow = 'first_climb_play_now';
  static const String keyWelcomeBackFirstReturnShort =
      'welcome_back_first_return_short';
  static const String keyTownEnabled = 'town_enabled';
  static const String keyGuaranteedFirstBoss = 'first_boss_guaranteed_drop';
  static const String keyVipPassListed = 'vip_pass_listed';
  static const String keyLiveEventId = 'live_event_id';
  static const String keyLiveEventMul = 'live_event_mul';
  static const String keyLiveEventStart = 'live_event_start_utc';
  static const String keyLiveEventEnd = 'live_event_end_utc';

  static const int defaultDailyCap = 8;
  static const bool defaultTownEnabled = true;
  static const int defaultFirstDelaySec = 90;
  static const int defaultIntervalSec = 8 * 60;
  static const int defaultVisibleSec = 10;

  static int _dailyCap = defaultDailyCap;
  static int _firstDelaySec = defaultFirstDelaySec;
  static int _intervalSec = defaultIntervalSec;
  static int _visibleSec = defaultVisibleSec;
  static String _shopFeaturedId = '';
  static bool _wispFromRemote = false;
  static bool _firstClimbAutoContinue = true;
  static bool _firstClimbPlayNow = true;
  static bool _welcomeBackFirstReturnShort = true;
  static bool _townEnabled = defaultTownEnabled;
  static bool _guaranteedFirstBoss = false;
  static bool _vipPassListed = false;
  static String _liveEventId = '';
  static double _liveEventMul = 1;
  static String _liveEventStart = '';
  static String _liveEventEnd = '';

  static int get wispDailyCap => _dailyCap;
  static int get wispFirstDelayMs => _firstDelaySec * 1000;
  static int get wispIntervalMs => _intervalSec * 1000;
  static int get wispVisibleMs => _visibleSec * 1000;
  static String get shopFeaturedId => _shopFeaturedId;
  static bool get firstClimbAutoContinue => _firstClimbAutoContinue;
  static bool get firstClimbPlayNow => _firstClimbPlayNow;
  static bool get welcomeBackFirstReturnShort => _welcomeBackFirstReturnShort;
  static bool get townEnabled => _townEnabled;

  /// Floor 2 first boss already ships. This adds a guaranteed blue drop.
  static bool get guaranteedFirstBossDrop => _guaranteedFirstBoss;

  /// VIP pass row. Off until a Play product exists. Not chargeable while off.
  static bool get vipPassListed => _vipPassListed;

  static String get liveEventId => _liveEventId;
  static double get liveEventMultiplier => _liveEventMul;

  /// True only inside a published window. Defaults are empty, so this is off.
  static bool liveEventActive(DateTime utcNow) {
    if (_liveEventId.isEmpty || _liveEventMul <= 1) return false;
    final start = DateTime.tryParse(_liveEventStart)?.toUtc();
    final end = DateTime.tryParse(_liveEventEnd)?.toUtc();
    if (start == null || end == null || !end.isAfter(start)) return false;
    final now = utcNow.toUtc();
    return !now.isBefore(start) && now.isBefore(end);
  }

  /// Out-of-cave town square (buildings). Off → fight-first rails instead.
  static bool townSquareActive(bool inDungeon) => _townEnabled && !inDungeon;

  /// A published WISP number differed from the shipped default.
  /// Debug builds keep the fast lantern until this is true.
  static bool get wispFromRemote => _wispFromRemote;

  static Map<String, dynamic> get defaults => <String, dynamic>{
    keyDailyCap: defaultDailyCap,
    keyFirstDelaySec: defaultFirstDelaySec,
    keyIntervalSec: defaultIntervalSec,
    keyVisibleSec: defaultVisibleSec,
    keyShopFeatured: '',
    keyFirstClimbAutoContinue: true,
    keyFirstClimbPlayNow: true,
    keyWelcomeBackFirstReturnShort: true,
    keyTownEnabled: defaultTownEnabled,
    keyGuaranteedFirstBoss: false,
    keyVipPassListed: false,
    keyLiveEventId: '',
    keyLiveEventMul: 1.0,
    keyLiveEventStart: '',
    keyLiveEventEnd: '',
  };

  /// [fromRemote] is true only after a fetch this process accepted.
  /// Out-of-range numbers and unknown shop ids fall back to shipped.
  static void apply({
    int? dailyCap,
    int? firstDelaySec,
    int? intervalSec,
    int? visibleSec,
    String? shopFeaturedId,
    bool? firstClimbAutoContinue,
    bool? firstClimbPlayNow,
    bool? welcomeBackFirstReturnShort,
    bool? townEnabled,
    bool? guaranteedFirstBoss,
    bool? vipPassListed,
    String? liveEventId,
    double? liveEventMul,
    String? liveEventStart,
    String? liveEventEnd,
    bool fromRemote = false,
  }) {
    final first = _inRange(firstDelaySec, 15, 3600, defaultFirstDelaySec);
    final visible = _inRange(visibleSec, 5, 30, defaultVisibleSec);
    final id = (shopFeaturedId ?? '').trim();
    // dailyCap and intervalSec stay in the signature so a later experiment
    // can read them. Shipped play ignores both.
    _dailyCap = defaultDailyCap;
    _firstDelaySec = first;
    _intervalSec = defaultIntervalSec;
    _visibleSec = visible;
    _shopFeaturedId = ShopCatalog.byId.containsKey(id) ? id : '';
    _firstClimbAutoContinue =
        firstClimbAutoContinue ?? _firstClimbAutoContinue;
    _firstClimbPlayNow = firstClimbPlayNow ?? _firstClimbPlayNow;
    _welcomeBackFirstReturnShort =
        welcomeBackFirstReturnShort ?? _welcomeBackFirstReturnShort;
    _townEnabled = townEnabled ?? _townEnabled;
    _guaranteedFirstBoss = guaranteedFirstBoss ?? _guaranteedFirstBoss;
    _vipPassListed = vipPassListed ?? _vipPassListed;
    _liveEventId = (liveEventId ?? _liveEventId).trim();
    final mul = liveEventMul;
    _liveEventMul = (mul == null || mul < 1 || mul > 5) ? 1 : mul;
    _liveEventStart = (liveEventStart ?? _liveEventStart).trim();
    _liveEventEnd = (liveEventEnd ?? _liveEventEnd).trim();
    _wispFromRemote =
        fromRemote &&
        (first != defaultFirstDelaySec || visible != defaultVisibleSec);
  }

  static void reset() => apply(
        firstClimbAutoContinue: true,
        firstClimbPlayNow: true,
        welcomeBackFirstReturnShort: true,
        townEnabled: defaultTownEnabled,
        guaranteedFirstBoss: false,
        vipPassListed: false,
        liveEventId: '',
        liveEventMul: 1,
        liveEventStart: '',
        liveEventEnd: '',
      );

  /// Bool feature flag from Remote Config. Web, tests, and a missing value
  /// keep [shippedDefault].
  static bool featureFlag(Object? raw, {required bool shippedDefault}) =>
      readBool(raw, shippedDefault);

  static bool readBool(Object? raw, bool fallback) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final lower = raw.trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on') {
        return true;
      }
      if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'off') {
        return false;
      }
    }
    return fallback;
  }

  /// Empty id lights the forever-scrolls bundle. That row stays off the
  /// SHOP shelf until Play returns the product, so nothing is lit until then.
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
