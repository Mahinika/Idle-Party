/// AdMob IDs. Empty / sample values = Google test ads (no payout).
///
/// Live unit: `--dart-define=ADMOB_REWARDED_UNIT_ID=ca-app-pub-…/…`
/// or GitHub secret `ADMOB_REWARDED_UNIT_ID` on tag builds.
/// App ID lives in AndroidManifest via `android/admob.properties`.
abstract final class AdConfig {
  static const String testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static const String rewardedUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID',
    defaultValue: testRewardedUnitId,
  );

  static bool get isLiveUnit =>
      rewardedUnitId.isNotEmpty && rewardedUnitId != testRewardedUnitId;
}
