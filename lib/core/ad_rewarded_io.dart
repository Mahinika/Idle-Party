import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_rewarded.dart';
import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart' as test_env;

bool get realAdsAvailable {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

bool _sdkReady = false;
bool _warming = false;
RewardedAd? _ready;

Future<void> warmup() async {
  if (!realAdsAvailable || _warming) return;
  _warming = true;
  try {
    await _ensureSdk();
    if (_sdkReady) {
      await _preload();
    }
  } finally {
    _warming = false;
  }
}

Future<void> showPrivacyOptions() async {
  if (!realAdsAvailable) return;
  await _requestConsent();
  final done = Completer<void>();
  ConsentForm.showPrivacyOptionsForm((FormError? error) {
    if (error != null) {
      debugPrint('UMP privacy options: ${error.message}');
    }
    if (!done.isCompleted) done.complete();
  });
  await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
}

/// Show a rewarded ad and wait until it is dismissed.
///
/// [RewardedAd.show] completes when the ad is *presented*, not when the user
/// finishes. Without waiting for [FullScreenContentCallback], we used to
/// dispose early and treat a full watch as [AdWatchResult.skipped] — so the
/// ad played but POWERUPS never granted.
Future<AdWatchResult> showRewarded() async {
  if (!realAdsAvailable) return AdWatchResult.unavailable;
  await warmup();
  if (!_sdkReady) return AdWatchResult.failed;
  var ad = _ready;
  _ready = null;
  ad ??= await _loadAd();
  if (ad == null) return AdWatchResult.failed;

  final finished = Completer<AdWatchResult>();
  var earned = false;

  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (RewardedAd closed) {
      closed.dispose();
      if (!finished.isCompleted) {
        finished.complete(
          earned ? AdWatchResult.rewarded : AdWatchResult.skipped,
        );
      }
    },
    onAdFailedToShowFullScreenContent: (RewardedAd closed, AdError error) {
      debugPrint('rewarded ad failed to show: $error');
      closed.dispose();
      if (!finished.isCompleted) {
        finished.complete(AdWatchResult.failed);
      }
    },
  );

  try {
    await ad.show(
      onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
        earned = true;
        debugPrint(
          'rewarded ad earned: ${reward.amount} ${reward.type}',
        );
      },
    );
  } catch (e, st) {
    debugPrint('rewarded ad show failed: $e\n$st');
    ad.dispose();
    unawaited(_preload());
    return AdWatchResult.failed;
  }

  try {
    return await finished.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        debugPrint('rewarded ad dismiss timed out');
        ad?.dispose();
        return earned ? AdWatchResult.rewarded : AdWatchResult.failed;
      },
    );
  } finally {
    unawaited(_preload());
  }
}

Future<void> _ensureSdk() async {
  if (_sdkReady) return;
  try {
    await _requestConsent();
    final canAsk = await ConsentInformation.instance.canRequestAds();
    if (!canAsk) {
      debugPrint('AdMob: cannot request ads (consent)');
      return;
    }
    await MobileAds.instance.initialize();
    _sdkReady = true;
    debugPrint(
      'AdMob ready (${AdConfig.isLiveUnit ? 'live unit' : 'sample test unit'})',
    );
  } catch (e, st) {
    debugPrint('AdMob init failed: $e\n$st');
  }
}

Future<void> _requestConsent() async {
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) {
          debugPrint('UMP form: ${error.message}');
        }
        if (!done.isCompleted) done.complete();
      });
    },
    (FormError error) {
      debugPrint('UMP update: ${error.message}');
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
}

Future<void> _preload() async {
  if (_ready != null || !_sdkReady) return;
  _ready = await _loadAd();
}

Future<RewardedAd?> _loadAd() async {
  final loaded = Completer<RewardedAd?>();
  await RewardedAd.load(
    adUnitId: AdConfig.rewardedUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        if (!loaded.isCompleted) loaded.complete(ad);
      },
      onAdFailedToLoad: (error) {
        debugPrint('rewarded ad load failed: $error');
        if (!loaded.isCompleted) loaded.complete(null);
      },
    ),
  );
  return loaded.future.timeout(const Duration(seconds: 20), onTimeout: () {
    debugPrint('rewarded ad load timed out');
    return null;
  });
}
