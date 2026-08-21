import 'package:flutter/foundation.dart';

/// AdMob IDs for Idle Party (`com.idleparty.app`).
///
/// Debug `flutter run` keeps Google sample rewarded ads (do not click your
/// own live ads). Release/profile builds use the live POWERUPS unit.
/// Override with `--dart-define=ADMOB_REWARDED_UNIT_ID=…`.
abstract final class AdConfig {
  static const String testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static const String liveAppId =
      'ca-app-pub-4980376195917009~4491640230';

  static const String liveRewardedUnitId =
      'ca-app-pub-4980376195917009/5225353586';

  static const String _fromEnv = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID',
  );

  static String get rewardedUnitId {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kDebugMode) return testRewardedUnitId;
    return liveRewardedUnitId;
  }

  static bool get isLiveUnit => rewardedUnitId != testRewardedUnitId;
}
