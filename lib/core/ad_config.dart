import 'package:flutter/foundation.dart';

import 'build_stamp.dart';

/// AdMob IDs for Idle Party (`com.idleparty.app`).
///
/// Debug `flutter run` and sideload QA APKs (`GIT_SHA`) keep Google's sample
/// rewarded unit. Do not click the live unit. A Play release omits the SHA
/// and uses the live POWERUPS unit, unless `ADMOB_REWARDED_UNIT_ID` is set.
abstract final class AdConfig {
  static const String testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static const String liveAppId = 'ca-app-pub-4980376195917009~4491640230';

  static const String liveRewardedUnitId =
      'ca-app-pub-4980376195917009/5225353586';

  static const String _fromEnv = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID',
  );

  static String get rewardedUnitId {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kDebugMode || BuildStamp.gitSha.isNotEmpty) {
      return testRewardedUnitId;
    }
    return liveRewardedUnitId;
  }

  static bool get isLiveUnit => rewardedUnitId != testRewardedUnitId;
}
