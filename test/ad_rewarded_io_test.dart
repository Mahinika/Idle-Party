import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_rewarded.dart' show AdRewarded, AdWatchResult;
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/crash_report.dart';

void main() {
  test('rewarded facade is unavailable under flutter test', () async {
    expect(AdRewarded.realAdsAvailable, isFalse);
    final result = await AdRewarded.showRewarded(placement: 'welcome_back');
    expect(result, AdWatchResult.unavailable);
  });

  test('rewarded load-fail analytics are safe under flutter test', () async {
    AppAnalytics.debugSink = (name, params) {};
    addTearDown(() => AppAnalytics.debugSink = null);
    await AppAnalytics.rewardedLoadFail('wisp_gift', reason: 'preload');
  });

  test('CrashReport.recordNonFatal is a no-op under flutter test', () {
    expect(
      () => CrashReport.recordNonFatal(
        StateError('ad'),
        StackTrace.empty,
        reason: 'ad_rewarded_io:test',
      ),
      returnsNormally,
    );
  });
}