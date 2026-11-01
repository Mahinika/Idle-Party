import 'funnel_analytics.dart';

/// Firebase Analytics event ids and GA4-safe param helpers.
abstract final class AnalyticsEvents {
  static const appColdStart = 'app_cold_start';
  static const coachStep = 'coach_step';
  static const firstUpgrade = 'first_upgrade';

  static const welcomeBackAdTap = 'welcome_back_ad_tap';
  static const welcomeBackAdSkip = 'welcome_back_ad_skip';

  static const rewardedOffer = 'rewarded_offer';
  static const rewardedTap = 'rewarded_tap';
  static const rewardedComplete = 'rewarded_complete';
  static const rewardedSkip = 'rewarded_skip';
  static const rewardedLoadFail = 'rewarded_load_fail';

  static const storeProductView = 'store_product_view';
  static const storePurchaseStart = 'store_purchase_start';
  static const storePurchaseCancel = 'store_purchase_cancel';

  /// SCROLLS Ad-free line. Once per save. Not a buy sheet.
  static const adFreeNudgeView = 'ad_free_nudge_view';
  static const adFreeNudgeTap = 'ad_free_nudge_tap';

  static const scrollWellFree = 'scroll_well_free';
  static const scrollWellAd = 'scroll_well_ad';

  static const questReroll = 'quest_reroll';

  static const notifyOpen = 'notify_open';

  /// Matches [FirstSessionTips.tips] ids (coach only, not boot intro).
  static const Set<String> coachTipIds = {
    'first_run',
    'hub_enter',
    'godhand',
    'farm_push',
    'kit_abilities',
    'bag',
    'forge',
    'sanctuary',
  };

  static const placementWelcomeBack = 'welcome_back';
  static const placementWispGift = 'wisp_gift';
  static const placementPowerups = 'powerups';
  static const placementScrollWell = 'scroll_well';
  static const placementQuestReroll = 'quest_reroll';
  static const placementWipeRetry = 'wipe_retry';
  static const placementWipeRevive = 'wipe_revive';

  /// Offline away time on Welcome Back (seconds).
  static String offlineSecondsBucket(int seconds) {
    final s = seconds.clamp(0, 86400 * 14);
    if (s < 60) return 'lt_1m';
    if (s < 300) return '1_5m';
    if (s < 900) return '5_15m';
    if (s < 3600) return '15_60m';
    if (s < 14400) return '1_4h';
    if (s < 28800) return '4_8h';
    return '8h_cap';
  }

  /// Welcome Back gold credited this trip.
  static String offlineGoldBucket(int gold) {
    final g = gold.clamp(0, 999999999);
    if (g <= 0) return '0';
    if (g < 50) return '1_49';
    if (g < 200) return '50_199';
    if (g < 1000) return '200_999';
    if (g < 5000) return '1k_5k';
    return '5k_plus';
  }

  static int? daysSinceInstallMs(int installMs, DateTime now) {
    if (installMs <= 0) return null;
    final install = DateTime.fromMillisecondsSinceEpoch(installMs, isUtc: true);
    return FunnelAnalytics.utcCalendarDaysApart(install, now.toUtc());
  }
}
