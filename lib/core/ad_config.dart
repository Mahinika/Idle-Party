/// AdMob IDs. Google sample values until a real AdMob app is wired.
///
/// Replace both the Android manifest `admobAppId` and [rewardedUnitId]
/// with production IDs before a Play build that shows live ads.
/// Override the unit at build time: `--dart-define=ADMOB_REWARDED_UNIT_ID=…`
abstract final class AdConfig {
  /// Google sample rewarded unit (safe for debug / closed test until live IDs).
  static const String rewardedUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
}
