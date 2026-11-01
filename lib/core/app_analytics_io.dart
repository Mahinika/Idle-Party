import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'measurement_consent.dart';

bool get _androidLive {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

bool _ready = false;
bool _handlersArmed = false;
bool _crashHandlersInstalled = false;
FirebaseAnalytics? _analytics;
final List<FlutterErrorDetails> _flutterPending = <FlutterErrorDetails>[];
final List<(Object, StackTrace?)> _platformPending = <(Object, StackTrace?)>[];

/// Holds Dart errors until [init] attaches Crashlytics. No platform call.
void armEarlyErrorBuffer() {
  if (_handlersArmed) return;
  _handlersArmed = true;
  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_crashHandlersInstalled) {
      unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
      return;
    }
    previousFlutter?.call(details);
    _flutterPending.add(details);
  };
  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (_crashHandlersInstalled) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
      );
    } else {
      _platformPending.add((error, stack));
    }
    return previousPlatform?.call(error, stack) ?? false;
  };
}

int get debugBufferedErrorCount =>
    _flutterPending.length + _platformPending.length;

void debugResetEarlyErrorBuffer() {
  _handlersArmed = false;
  _crashHandlersInstalled = false;
  _flutterPending.clear();
  _platformPending.clear();
}

/// Firebase auto-collects these; logging them manually is rejected.
const Set<String> _reservedEventNames = <String>{'first_open'};

Future<void> init() async {
  if (!_androidLive || _ready) return;
  try {
    await Firebase.initializeApp();
    _analytics = FirebaseAnalytics.instance;
    // Manifest keeps both off until syncConsent returns. After UMP, Analytics
    // collection turns on (a decline still sends consent-mode pings).
    // Crashlytics turns on only when ads can be requested.
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
    final canRequestAds = await ConsentInformation.instance.canRequestAds();
    final consent = MeasurementConsent(granted: canRequestAds);
    // One call sets all four, including ad_personalization. Google clears
    // that signal when storage consent is withdrawn.
    await analytics.setConsent(
      analyticsStorageConsentGranted: consent.analyticsStorage,
      adStorageConsentGranted: consent.adStorage,
      adUserDataConsentGranted: consent.adUserData,
      adPersonalizationSignalsConsentGranted: consent.adPersonalization,
    );
    await analytics.setAnalyticsCollectionEnabled(consent.analyticsCollection);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      consent.crashlytics,
    );
    debugPrint('Firebase Analytics consent granted: ${consent.granted}');
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

void syncCrashContext({required String zoneId, required String appVersion}) {
  if (!_androidLive || _analytics == null) return;
  try {
    unawaited(FirebaseCrashlytics.instance.setCustomKey('zone_id', zoneId));
    unawaited(
      FirebaseCrashlytics.instance.setCustomKey('app_version', appVersion),
    );
  } catch (e, st) {
    debugPrint('Crashlytics setCustomKey failed: $e\n$st');
  }
}

void _installCrashHandlers() {
  if (_crashHandlersInstalled) return;
  if (!_handlersArmed) {
    armEarlyErrorBuffer();
  }
  _crashHandlersInstalled = true;
  // Already presented while they waited. Record only, so the log is not doubled.
  final flutterCopy = List<FlutterErrorDetails>.of(_flutterPending);
  final platformCopy = List<(Object, StackTrace?)>.of(_platformPending);
  _flutterPending.clear();
  _platformPending.clear();
  for (final details in flutterCopy) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        details.exception,
        details.stack,
        fatal: true,
      ),
    );
  }
  for (final pending in platformCopy) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        pending.$1,
        pending.$2,
        fatal: true,
      ),
    );
  }
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
