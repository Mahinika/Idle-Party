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

Future<AdWatchResult> showRewarded() async {
  if (!realAdsAvailable) return AdWatchResult.unavailable;
  await warmup();
  if (!_sdkReady) return AdWatchResult.failed;
  var ad = _ready;
  _ready = null;
  ad ??= await _loadAd();
  if (ad == null) return AdWatchResult.failed;
  var earned = false;
  try {
    await ad.show(
      onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
        earned = true;
      },
    );
    return earned ? AdWatchResult.rewarded : AdWatchResult.skipped;
  } catch (e, st) {
    debugPrint('rewarded ad show failed: $e\n$st');
    return AdWatchResult.failed;
  } finally {
    ad.dispose();
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
