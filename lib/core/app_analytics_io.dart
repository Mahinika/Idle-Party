import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;

bool get _androidLive {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

bool _ready = false;
bool _crashHandlersInstalled = false;
FirebaseAnalytics? _analytics;

/// Firebase auto-collects these; logging them manually is rejected.
const Set<String> _reservedEventNames = <String>{'first_open'};

Future<void> init() async {
  if (!_androidLive || _ready) return;
  try {
    await Firebase.initializeApp();
    _analytics = FirebaseAnalytics.instance;
    // Manifest keeps both off. Turn them on only after UMP.
    await _analytics!.setAnalyticsCollectionEnabled(false);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    _installCrashHandlers();
    await syncConsent();
    _ready = true;
    debugPrint('Firebase Analytics ready');
  } catch (e, st) {
    // Missing google-services.json / Firebase project → stay quiet.
    debugPrint('Firebase Analytics init skipped: $e\n$st');
    _analytics = null;
    _ready = false;
  }
}

Future<void> syncConsent() async {
  if (_analytics == null && !_androidLive) return;
  final analytics = _analytics;
  if (analytics == null) return;
  try {
    await _requestConsent();
    final canCollect = await ConsentInformation.instance.canRequestAds();
    await analytics.setAnalyticsCollectionEnabled(canCollect);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      canCollect,
    );
    debugPrint('Firebase Analytics collection: $canCollect');
  } catch (e, st) {
    debugPrint('Firebase Analytics consent sync failed: $e\n$st');
  }
}

Future<void> logEvent(String name, [Map<String, Object>? params]) async {
  if (_reservedEventNames.contains(name)) return;
  final analytics = _analytics;
  if (analytics == null) return;
  try {
    await analytics.logEvent(name: name, parameters: params);
  } catch (e, st) {
    debugPrint('Firebase Analytics logEvent($name) failed: $e\n$st');
  }
}

void _installCrashHandlers() {
  if (_crashHandlersInstalled) return;
  _crashHandlersInstalled = true;
  // recordFlutterFatalError already presents the Flutter error.
  FlutterError.onError = (details) {
    unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
  };
  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
    return previousPlatform?.call(error, stack) ?? false;
  };
}

Future<void> _requestConsent() async {
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) {
          debugPrint('UMP form (analytics): ${error.message}');
        }
        if (!done.isCompleted) done.complete();
      });
    },
    (FormError error) {
      debugPrint('UMP update (analytics): ${error.message}');
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
}
