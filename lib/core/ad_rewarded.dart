import 'ad_rewarded_stub.dart'
    if (dart.library.io) 'ad_rewarded_io.dart' as impl;

enum AdWatchResult { rewarded, skipped, failed, unavailable }

/// Optional rewarded ads. No-op on web / tests / non-Android.
abstract final class AdRewarded {
  static bool get realAdsAvailable => impl.realAdsAvailable;

  static Future<void> warmup() => impl.warmup();

  static Future<AdWatchResult> showRewarded() => impl.showRewarded();
}
