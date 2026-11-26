import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_rewarded.dart';
import 'app_analytics.dart';
import 'remote_tune_boot.dart';
import 'ump_consent_gate.dart';
import 'immersive_ui.dart';
import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;

bool get realAdsAvailable {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

bool _sdkReady = false;
RewardedAd? _ready;
DateTime? _readyAt;
Future<void>? _chain;

/// One ad load at a time. A tap during preload waits for that load.
Future<void> _serialized(Future<void> Function() body) {
  final run = (_chain ?? Future<void>.value()).then((_) => body());
  _chain = run.catchError((Object _) {});
  return run;
}

/// Load the rewarded unit only. Does not show the UMP form.
Future<void> prepareOffer({String? placement}) {
  if (!realAdsAvailable) return Future<void>.value();
  if (placement != null) {
    unawaited(AppAnalytics.rewardedOffer(placement));
  }
  return _serialized(() async {
    await _ensureSdk(askConsent: false);
    if (_sdkReady) await _preload(placement: placement);
  });
}

Future<void> warmup() => prepareOffer();

Future<void> showPrivacyOptions() async {
  if (!realAdsAvailable) return;
  await _requestConsent(askConsent: true);
  final done = Completer<void>();
  ConsentForm.showPrivacyOptionsForm((FormError? error) {
    if (error != null) {
      debugPrint('UMP privacy options: ${error.message}');
    }
    if (!done.isCompleted) done.complete();
  });
  await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
  unawaited(AppAnalytics.syncConsent());
  unawaited(RemoteTuneBoot.refresh());
  unawaited(lockImmersiveUi());
}

/// Show a rewarded ad and wait until it is dismissed.
///
/// [RewardedAd.show] completes when the ad is *presented*, not when the user
/// finishes. Without waiting for [FullScreenContentCallback], we used to
/// dispose early and treat a full watch as [AdWatchResult.skipped] — so the
/// ad played but POWERUPS never granted.
Future<AdWatchResult> showRewarded({required String placement}) async {
  if (!realAdsAvailable) return AdWatchResult.unavailable;
  unawaited(AppAnalytics.rewardedTap(placement));
  // Startup already shows UMP. If that form never finished, ask once here,
  // then show the ad this tap requested.
  await _serialized(() async {
    await _ensureSdk(askConsent: true);
    if (_sdkReady && _ready == null) await _preload(placement: placement);
  });
  if (!_sdkReady) {
    unawaited(AppAnalytics.rewardedLoadFail(placement, reason: 'not_ready'));
    return AdWatchResult.failed;
  }
  var ad = takeFreshRewardedPreload<RewardedAd>(
    ad: _ready,
    loadedAt: _readyAt,
    now: DateTime.now(),
    dispose: (stale) => stale.dispose(),
  );
  _ready = null;
  _readyAt = null;
  ad ??= await _loadAd(placement: placement);
  if (ad == null) {
    // _loadAd already reported this failure.
    return AdWatchResult.failed;
  }

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
        unawaited(AppAnalytics.rewardedLoadFail(placement, reason: 'show'));
        finished.complete(AdWatchResult.failed);
      }
    },
  );

  try {
    await ad.show(
      onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
        earned = true;
        debugPrint('rewarded ad earned: ${reward.amount} ${reward.type}');
      },
    );
  } catch (e, st) {
    debugPrint('rewarded ad show failed: $e\n$st');
    ad.dispose();
    unawaited(AppAnalytics.rewardedLoadFail(placement, reason: 'show'));
    unawaited(_preload(placement: placement));
    return AdWatchResult.failed;
  }

  try {
    final result = await finished.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        debugPrint('rewarded ad dismiss timed out');
        ad?.dispose();
        if (!earned) {
          unawaited(
            AppAnalytics.rewardedLoadFail(placement, reason: 'timeout'),
          );
        }
        return earned ? AdWatchResult.rewarded : AdWatchResult.failed;
      },
    );
    switch (result) {
      case AdWatchResult.rewarded:
        unawaited(AppAnalytics.rewardedComplete(placement));
      case AdWatchResult.skipped:
        unawaited(AppAnalytics.rewardedSkip(placement));
      case AdWatchResult.failed:
      case AdWatchResult.unavailable:
      case AdWatchResult.busy:
        break;
    }
    return result;
  } finally {
    unawaited(lockImmersiveUi());
    unawaited(_preload(placement: placement));
  }
}

Future<void> _ensureSdk({required bool askConsent}) async {
  if (_sdkReady) return;
  try {
    await _requestConsent(askConsent: askConsent);
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

Future<void> _requestConsent({required bool askConsent}) async {
  await runUmpConsentGate(
    showFormOnSuccess: askConsent,
    requestUpdate: (callbacks) {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        callbacks.onSuccess,
        (FormError error) {
          debugPrint('UMP update: ${error.message}');
          callbacks.onError(error);
        },
      );
    },
    showForm: () async {
      final done = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) {
          debugPrint('UMP form: ${error.message}');
        }
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    },
    resync: () async {
      await AppAnalytics.syncConsent();
      await RemoteTuneBoot.refresh();
    },
  );
  unawaited(lockImmersiveUi());
}

Future<void> _preload({String? placement}) async {
  if (_ready != null || !_sdkReady) return;
  final ad = await _loadAd(placement: placement, failReason: 'preload');
  if (ad == null) return;
  _ready = ad;
  _readyAt = DateTime.now();
}

Future<RewardedAd?> _loadAd({
  String? placement,
  String failReason = 'load',
}) async {
  final loaded = Completer<RewardedAd?>();
  var reported = false;
  void report(String reason) {
    if (reported || placement == null) return;
    reported = true;
    unawaited(AppAnalytics.rewardedLoadFail(placement, reason: reason));
  }

  await RewardedAd.load(
    adUnitId: AdConfig.rewardedUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        if (!loaded.isCompleted) loaded.complete(ad);
      },
      onAdFailedToLoad: (error) {
        debugPrint('rewarded ad load failed: $error');
        report(failReason);
        if (!loaded.isCompleted) loaded.complete(null);
      },
    ),
  );
  return loaded.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      debugPrint('rewarded ad load timed out');
      report('timeout');
      return null;
    },
  );
}
