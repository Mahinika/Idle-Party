import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/analytics_events.dart';
import 'package:idle_party/core/app_analytics.dart';

void main() {
  tearDown(() {
    AppAnalytics.debugSink = null;
  });

  test('offline buckets match documented ranges', () {
    expect(AnalyticsEvents.offlineSecondsBucket(0), 'lt_1m');
    expect(AnalyticsEvents.offlineSecondsBucket(59), 'lt_1m');
    expect(AnalyticsEvents.offlineSecondsBucket(60), '1_5m');
    expect(AnalyticsEvents.offlineSecondsBucket(28800), '8h_cap');
    expect(AnalyticsEvents.offlineGoldBucket(0), '0');
    expect(AnalyticsEvents.offlineGoldBucket(1), '1_49');
    expect(AnalyticsEvents.offlineGoldBucket(5000), '5k_plus');
    expect(AnalyticsEvents.incomeMinutesBucket(0), '0');
    expect(AnalyticsEvents.incomeMinutesBucket(29), 'lt_30m');
    expect(AnalyticsEvents.incomeMinutesBucket(30), '30_60m');
    expect(AnalyticsEvents.incomeMinutesBucket(120), '2_4h');
    expect(AnalyticsEvents.incomeMinutesBucket(240), '4h_plus');
  });

  test('measurement helpers use stable event names', () async {
    final hits = <String, Map<String, Object>?>{
      for (final e in <String>[
        AnalyticsEvents.appColdStart,
        AnalyticsEvents.coachStep,
        AnalyticsEvents.welcomeBackAdTap,
        AnalyticsEvents.rewardedOffer,
        AnalyticsEvents.rewardedTap,
        AnalyticsEvents.rewardedComplete,
        AnalyticsEvents.storeProductView,
        AnalyticsEvents.storePurchaseStart,
        AnalyticsEvents.notifyOpen,
      ])
        e: null,
    };
    final logged = <String>[];
    AppAnalytics.debugSink = (name, params) {
      logged.add(name);
      hits.remove(name);
      if (name == AnalyticsEvents.coachStep) {
        expect(params?['tip_id'], 'forge');
      }
      if (name == AnalyticsEvents.rewardedOffer) {
        expect(params?['placement'], AnalyticsEvents.placementPowerups);
      }
    };

    await AppAnalytics.appColdStart(daysSinceInstall: 2);
    await AppAnalytics.coachStep('forge');
    await AppAnalytics.welcomeBackAdTap();
    await AppAnalytics.rewardedOffer(AnalyticsEvents.placementPowerups);
    await AppAnalytics.rewardedTap(AnalyticsEvents.placementWelcomeBack);
    await AppAnalytics.rewardedComplete(AnalyticsEvents.placementWispGift);
    await AppAnalytics.storeProductView('ad_free');
    await AppAnalytics.storePurchaseStart('long_away');
    await AppAnalytics.notifyOpen(channel: 'away_ping');

    expect(logged.length, 9);
    expect(hits, isEmpty);
  });

  test('rewarded_complete carries the reward snapshot', () async {
    final seen = <String, Map<String, Object>?>{};
    AppAnalytics.debugSink = (name, params) {
      seen[name] = params;
    };
    AppAnalytics.armRewardedComplete(
      const RewardedCompleteContext(
        rewardGold: 1200,
        ticketsGranted: 1,
        incomeMinutes: 120,
        ticketsToday: 3,
        wispClaimsToday: 2,
      ),
    );
    await AppAnalytics.rewardedComplete(AnalyticsEvents.placementWispGift);
    final complete = seen[AnalyticsEvents.rewardedComplete];
    expect(complete?['placement'], AnalyticsEvents.placementWispGift);
    expect(complete?['reward_gold'], 1200);
    expect(complete?['tickets_granted'], 1);
    expect(complete?['income_minutes'], '2_4h');
    expect(complete?['tickets_today'], 3);
    expect(complete?['wisp_claims_today'], 2);

    await AppAnalytics.adDailyCapHit(
      placement: AnalyticsEvents.placementPowerups,
      cap: 8,
    );
    await AppAnalytics.scrollSpent(buffId: 'gold', tickets: 1);
    expect(seen[AnalyticsEvents.adDailyCapHit]?['placement'], 'powerups');
    expect(seen[AnalyticsEvents.adDailyCapHit]?['cap'], 8);
    expect(seen[AnalyticsEvents.scrollSpent]?['buff_id'], 'gold');
    expect(seen[AnalyticsEvents.scrollSpent]?['tickets'], 1);
  });
}
