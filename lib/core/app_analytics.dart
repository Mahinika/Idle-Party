import 'analytics_events.dart';
import 'app_analytics_stub.dart'
    if (dart.library.io) 'app_analytics_io.dart'
    as impl;
import 'debug_play_log.dart';

/// Soft Firebase Analytics facade. No-op on web / tests / missing config.
abstract final class AppAnalytics {
  /// Test hook — records every [logEvent] (including reserved `first_open`).
  static void Function(String name, Map<String, Object>? params)? debugSink;

  static Future<void> init() => impl.init();

  /// Capture Dart errors before Crashlytics is attached. No platform call.
  static void armEarlyErrorBuffer() => impl.armEarlyErrorBuffer();

  /// Flutter errors waiting for Crashlytics. Test hook.
  static int get debugBufferedErrorCount => impl.debugBufferedErrorCount;

  /// Drops the early buffer so a test can restore the framework handlers.
  static void debugResetEarlyErrorBuffer() => impl.debugResetEarlyErrorBuffer();

  /// Re-read UMP after SETTINGS → AD PRIVACY.
  static Future<void> syncConsent() => impl.syncConsent();

  /// Crash reports: current cave and build label. Fire-and-forget.
  static void syncCrashContext({
    required String zoneId,
    required String appVersion,
  }) => impl.syncCrashContext(zoneId: zoneId, appVersion: appVersion);

  static Future<void> logEvent(
    String name, [
    Map<String, Object>? params,
  ]) async {
    debugSink?.call(name, params);
    DebugPlayLog.funnel(name, params);
    await impl.logEvent(name, params);
  }

  /// Process boot after a save is loaded (not each resume from background).
  static Future<void> appColdStart({int? daysSinceInstall}) => logEvent(
    AnalyticsEvents.appColdStart,
    {'days_since_install': ?daysSinceInstall},
  );

  static Future<void> coachStep(String tipId) =>
      logEvent(AnalyticsEvents.coachStep, {'tip_id': tipId});

  static Future<void> enterDungeon({
    required String dungeonId,
    required int keyLevel,
    required int floor,
  }) => logEvent('enter_dungeon', {
    'dungeon_id': dungeonId,
    'key_level': keyLevel,
    'floor': floor,
  });

  static Future<void> leaveDungeon({
    required String dungeonId,
    required int floor,
  }) => logEvent('leave_dungeon', {'dungeon_id': dungeonId, 'floor': floor});

  static Future<void> partyWipe({
    required String dungeonId,
    required int floor,
    required int streak,
  }) => logEvent('party_wipe', {
    'dungeon_id': dungeonId,
    'floor': floor,
    'streak': streak,
  });

  static Future<void> ascend({required int fromAl, required int toAl}) =>
      logEvent('ascend', {'from_al': fromAl, 'to_al': toAl});

  /// Welcome Back card. [where] is `hub` or `dungeon`.
  static Future<void> welcomeBack({
    required String where,
    required int seconds,
    required int gold,
  }) => logEvent('welcome_back', {
    'where': where,
    'seconds': seconds,
    'gold': gold,
    'seconds_bucket': AnalyticsEvents.offlineSecondsBucket(seconds),
    'gold_bucket': AnalyticsEvents.offlineGoldBucket(gold),
  });

  /// The watch button is on this Welcome Back card.
  static Future<void> welcomeBackAdOffer() => logEvent('welcome_back_ad_offer');

  static Future<void> welcomeBackAdTap() =>
      logEvent(AnalyticsEvents.welcomeBackAdTap);

  static Future<void> welcomeBackAdSkip() =>
      logEvent(AnalyticsEvents.welcomeBackAdSkip);

  static Future<void> rewardedOffer(String placement) =>
      logEvent(AnalyticsEvents.rewardedOffer, {'placement': placement});

  static Future<void> rewardedTap(String placement) =>
      logEvent(AnalyticsEvents.rewardedTap, {'placement': placement});

  static Future<void> rewardedComplete(String placement) =>
      logEvent(AnalyticsEvents.rewardedComplete, {'placement': placement});

  static Future<void> rewardedSkip(String placement) =>
      logEvent(AnalyticsEvents.rewardedSkip, {'placement': placement});

  static Future<void> rewardedLoadFail(String placement) =>
      logEvent(AnalyticsEvents.rewardedLoadFail, {'placement': placement});

  /// SHOP tab opened. One event per visit.
  static Future<void> storeView() => logEvent('store_view');

  static Future<void> storeProductView(String productId) =>
      logEvent(AnalyticsEvents.storeProductView, {'product_id': productId});

  /// SCROLLS showed the one-time Ad-free line.
  static Future<void> adFreeNudgeView() =>
      logEvent(AnalyticsEvents.adFreeNudgeView, {'product_id': 'ad_free'});

  /// Player tapped that line (opens SHOP).
  static Future<void> adFreeNudgeTap() =>
      logEvent(AnalyticsEvents.adFreeNudgeTap, {'product_id': 'ad_free'});

  static Future<void> storePurchaseStart(String productId) =>
      logEvent(AnalyticsEvents.storePurchaseStart, {'product_id': productId});

  static Future<void> storePurchaseCancel(String productId) =>
      logEvent(AnalyticsEvents.storePurchaseCancel, {'product_id': productId});

  /// A new Play purchase granted. Restores are not purchases.
  ///
  /// [value] and [currency] come from Play when that SKU is loaded. A missing
  /// price omits both, so the event is not a second `in_app_purchase`.
  static Future<void> storePurchase(
    String productId, {
    double? value,
    String? currency,
  }) {
    final params = <String, Object>{'product_id': productId};
    final code = currency?.trim().toUpperCase();
    if (value != null && code != null && code.length == 3) {
      params['value'] = value;
      params['currency'] = code;
    }
    return logEvent('store_purchase', params);
  }

  static Future<void> notifyOpen({required String channel}) =>
      logEvent(AnalyticsEvents.notifyOpen, {'channel': channel});

  /// Seconds this foreground stint lasted. Sent when the app backgrounds.
  static Future<void> sessionLength(int seconds) =>
      logEvent('session_length', {'seconds': seconds});
}
