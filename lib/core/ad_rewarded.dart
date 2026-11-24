import 'ad_rewarded_stub.dart'
    if (dart.library.io) 'ad_rewarded_io.dart' as impl;

import 'game_audio.dart';

enum AdWatchResult { rewarded, skipped, failed, unavailable }

/// Optional rewarded ads. No-op on web / tests / non-Android.
abstract final class AdRewarded {
  static bool get realAdsAvailable => impl.realAdsAvailable;

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

  static Future<AdWatchResult> showRewarded({required String placement}) async {
    try {
      return await impl.showRewarded(placement: placement);
    } finally {
      GameAudio.resyncAfterInterrupt();
    }
  }

  /// SETTINGS → AD PRIVACY. Lets EU players change or withdraw AdMob consent.
  static Future<void> showPrivacyOptions() => impl.showPrivacyOptions();
}
