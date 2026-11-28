import 'analytics_events.dart';
import 'analytics_guard.dart';
import 'app_analytics_stub.dart'
    if (dart.library.io) 'app_analytics_io.dart'
    as impl;
import 'debug_play_log.dart';
import 'onboarding_funnel.dart';

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

  /// Test seam for uncaught async errors. Null sends them to Crashlytics.
  static set debugRecordPlatformError(
    void Function(Object error, StackTrace? stack, {required bool fatal})? hook,
  ) => impl.debugRecordPlatformError = hook;

  /// Records one platform error through the live fatal/non-fatal choice.
  static void debugEmitPlatformError(Object error, StackTrace stack) =>
      impl.debugEmitPlatformError(error, stack);

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
    final stepped = OnboardingFunnel.attachStep(name, params);
    final safeName = AnalyticsGuard.eventName(name);
    final safeParams = AnalyticsGuard.params(stepped);
    debugSink?.call(safeName ?? name, safeParams);
    DebugPlayLog.funnel(safeName ?? name, safeParams);
    if (safeName == null || AnalyticsGuard.isReserved(safeName)) return;
    await impl.logEvent(safeName, safeParams);
  }

  /// Once per install. No-op after the prefs flag is set.
  static Future<void> logOnboardingOnce(
    String name, [
    Map<String, Object>? params,
  ]) async {
    final step = OnboardingFunnel.claim(name);
    if (step == null) return;
    await logEvent(name, <String, Object>{...?params, 'step_index': step});
  }

  /// Cohort, days since install, ad-free, season pass, and build mode.
  /// Firebase collects `first_open` and `session_start` itself.
  static Future<void> syncMeasurementUser({
    String? installCohort,
    int? daysSinceInstall,
    required bool adFree,
    required bool seasonPass,
  }) async {
    if (installCohort != null) {
      await setUserProperty(AnalyticsEvents.propInstallCohort, installCohort);
    }
    if (daysSinceInstall != null && daysSinceInstall >= 0) {
      await setUserProperty(
        AnalyticsEvents.propDaysSinceInstall,
        '$daysSinceInstall',
      );
    }
    await setUserProperty(
      AnalyticsEvents.propAdFree,
      adFree ? 'true' : 'false',
    );
    await setUserProperty(
      AnalyticsEvents.propSeasonPass,
      seasonPass ? 'true' : 'false',
    );
    await setUserProperty(
      AnalyticsEvents.propBuildMode,
      AnalyticsGuard.buildMode(),
    );
  }

  static Future<void> setUserProperty(String name, String value) async {
    final safe = AnalyticsGuard.userProperty(name, value);
    if (safe == null) return;
    await impl.setUserProperty(safe.name, safe.value);
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

  static RewardedCompleteContext? _armedReward;

  /// Snapshot of the grant this watch will pay. Consumed by [rewardedComplete].
  static void armRewardedComplete(RewardedCompleteContext context) {
    _armedReward = context;
  }

  /// Drops a snapshot the platform did not log (skip, fail, or a test hook).
  static void discardArmedReward() {
    _armedReward = null;
  }

  static RewardedCompleteContext _takeArmedReward() {
    final context = _armedReward ?? const RewardedCompleteContext();
    _armedReward = null;
    return context;
  }

  static Future<void> rewardedComplete(
    String placement, {
    RewardedCompleteContext? context,
  }) {
    final reward = context ?? _takeArmedReward();
    return logEvent(AnalyticsEvents.rewardedComplete, {
      'placement': placement,
      ...reward.params,
    });
  }

  static Future<void> adDailyCapHit({
    required String placement,
    required int cap,
  }) => logEvent(AnalyticsEvents.adDailyCapHit, {
    'placement': placement,
    'cap': cap,
  });

  static Future<void> scrollSpent({
    required String buffId,
    required int tickets,
  }) => logEvent(AnalyticsEvents.scrollSpent, {
    'buff_id': buffId,
    'tickets': tickets,
  });

  static Future<void> rewardedSkip(String placement) =>
      logEvent(AnalyticsEvents.rewardedSkip, {'placement': placement});

  static Future<void> rewardedLoadFail(
    String placement, {
    String reason = 'load',
  }) => logEvent(AnalyticsEvents.rewardedLoadFail, {
    'placement': placement,
    'reason': reason,
  });

  /// SHOP tab opened. One event per visit.
  static Future<void> storeView() => logEvent('store_view');

  static Future<void> storeProductView(String productId) =>
      logEvent(AnalyticsEvents.storeProductView, {'product_id': productId});

  /// SCROLLS or CAMP showed the one-time Ad-free line.
  static Future<void> adFreeNudgeView() =>
      logEvent(AnalyticsEvents.adFreeNudgeView, {'product_id': 'ad_free'});

  /// Player tapped that line (opens SHOP).
  static Future<void> adFreeNudgeTap() =>
      logEvent(AnalyticsEvents.adFreeNudgeTap, {'product_id': 'ad_free'});

  static Future<void> storePurchaseStart(String productId) =>
      logEvent(AnalyticsEvents.storePurchaseStart, {'product_id': productId});

  static Future<void> storePurchaseCancel(String productId) =>
      logEvent(AnalyticsEvents.storePurchaseCancel, {'product_id': productId});

  /// The sheet never opened, Play returned an error, or the grant did not save.
  /// User cancel stays [storePurchaseCancel]. Prices are unchanged.
  static Future<void> storePurchaseFail(
    String productId, {
    required String reason,
  }) => logEvent(AnalyticsEvents.storePurchaseFail, {
    'product_id': productId,
    'reason': reason,
  });

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

/// Numbers attached to [AnalyticsEvents.rewardedComplete].
///
/// [incomeMinutes] is hub-income minutes; the event sends a bucket.
/// [ticketsToday] is extra ticket ads used today after this grant.
class RewardedCompleteContext {
  const RewardedCompleteContext({
    this.rewardGold = 0,
    this.ticketsGranted = 0,
    this.incomeMinutes = 0,
    this.ticketsToday = 0,
    this.wispClaimsToday = 0,
  });

  final int rewardGold;
  final int ticketsGranted;
  final int incomeMinutes;
  final int ticketsToday;
  final int wispClaimsToday;

  Map<String, Object> get params => {
    'reward_gold': rewardGold,
    'tickets_granted': ticketsGranted,
    'income_minutes': AnalyticsEvents.incomeMinutesBucket(incomeMinutes),
    'tickets_today': ticketsToday,
    'wisp_claims_today': wispClaimsToday,
  };
}
