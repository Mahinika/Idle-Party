import 'ad_rewarded_stub.dart'
    if (dart.library.io) 'ad_rewarded_io.dart'
    as impl;

import 'app_analytics.dart';
import 'game_audio.dart';

enum AdWatchResult { rewarded, skipped, failed, unavailable, busy }

/// A preloaded rewarded ad older than this is discarded and loaded again.
const Duration rewardedPreloadMaxAge = Duration(minutes: 55);

/// True when [loadedAt] is older than [rewardedPreloadMaxAge] at [now].
bool rewardedPreloadIsStale(DateTime loadedAt, DateTime now) =>
    now.difference(loadedAt) > rewardedPreloadMaxAge;

/// The ad to show, or null when it was missing or stale.
///
/// A stale or untimed preload is disposed. The caller loads a new one.
T? takeFreshRewardedPreload<T>({
  required T? ad,
  required DateTime? loadedAt,
  required DateTime now,
  required void Function(T ad) dispose,
}) {
  if (ad == null) return null;
  if (loadedAt == null || rewardedPreloadIsStale(loadedAt, now)) {
    dispose(ad);
    return null;
  }
  return ad;
}

/// Optional rewarded ads. No-op on web / tests / non-Android.
abstract final class AdRewarded {
  /// Test seam. Null uses the platform check.
  static bool? debugAdsAvailable;

  static bool get realAdsAvailable =>
      debugAdsAvailable ?? impl.realAdsAvailable;

  /// Test seam. When set, [showRewarded] awaits this instead of the SDK.
  static Future<AdWatchResult> Function({required String placement})?
  debugShowRewarded;

  static int _inFlight = 0;

  /// Drops the test seams. Does not finish an ad that is still open.
  static void debugReset() {
    debugAdsAvailable = null;
    debugShowRewarded = null;
    _inFlight = 0;
  }

  /// Times a visible offer asked for a load. Tests read this. The SDK no-ops
  /// off Android.
  static int prepareOfferCalls = 0;

  /// Preload the one rewarded unit when a button is about to show.
  /// Does not show a consent form.
  static Future<void> prepareOffer({String? placement}) {
    prepareOfferCalls++;
    return impl.prepareOffer(placement: placement);
  }

  static Future<void> warmup() => impl.warmup();

  /// One ad at a time. A second tap while the first is loading or showing
  /// returns [AdWatchResult.busy] and must not grant a reward.
  ///
  /// After a real show, bed music is restored. A busy tap does not, because
  /// the first ad is still on screen.
  static Future<AdWatchResult> showRewarded({required String placement}) {
    if (_inFlight > 0) return Future<AdWatchResult>.value(AdWatchResult.busy);
    _inFlight++;
    try {
      return _showRewarded(placement: placement).whenComplete(() {
        _inFlight--;
        GameAudio.resyncAfterInterrupt();
        // A skip, a fail, or a test hook never logs rewarded_complete.
        AppAnalytics.discardArmedReward();
      });
    } catch (error) {
      _inFlight--;
      GameAudio.resyncAfterInterrupt();
      return Future<AdWatchResult>.error(error);
    }
  }

  static Future<AdWatchResult> _showRewarded({required String placement}) {
    final hooked = debugShowRewarded;
    if (hooked != null) return hooked(placement: placement);
    return impl.showRewarded(placement: placement);
  }

  /// SETTINGS → AD PRIVACY. Lets EU players change or withdraw AdMob consent.
  static Future<void> showPrivacyOptions() => impl.showPrivacyOptions();
}
