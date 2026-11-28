import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'analytics_guard.dart';
import 'crash_report.dart';
import 'firebase_boot.dart';
import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'measurement_consent.dart';
import 'remote_tune_boot.dart';
import 'ump_consent_gate.dart';

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
final Map<String, String> _userProps = <String, String>{};

/// Holds Dart errors until [init] attaches Crashlytics. No platform call.
void armEarlyErrorBuffer() {
  if (_handlersArmed) return;
  _handlersArmed = true;
  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_crashHandlersInstalled) {
      unawaited(_recordFlutter(details, alreadyPresented: false));
      return;
    }
    previousFlutter?.call(details);
    _flutterPending.add(details);
  };
  final previousPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (_crashHandlersInstalled) {
      _emitPlatform(error, stack);
    } else {
      _platformPending.add((error, stack));
    }
    return previousPlatform?.call(error, stack) ?? false;
  };
}

/// Test seam. When set, platform errors are reported here and not to Firebase.
void Function(Object error, StackTrace? stack, {required bool fatal})?
debugRecordPlatformError;

/// Records one uncaught async error the same way the live handlers do.
void debugEmitPlatformError(Object error, StackTrace stack) {
  _emitPlatform(error, stack);
}

void _emitPlatform(Object error, StackTrace? stack) {
  final fatal = platformAsyncErrorIsFatal(error, stack ?? StackTrace.empty);
  final hook = debugRecordPlatformError;
  if (hook != null) {
    hook(error, stack, fatal: fatal);
    return;
  }
  unawaited(
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal),
  );
}

int get debugBufferedErrorCount =>
    _flutterPending.length + _platformPending.length;

void debugResetEarlyErrorBuffer() {
  _handlersArmed = false;
  _crashHandlersInstalled = false;
  _flutterPending.clear();
  _platformPending.clear();
}

Future<void> init() async {
  if (!_androidLive || _ready) return;
  try {
    await FirebaseBoot.ensureInitialized();
    _analytics = FirebaseAnalytics.instance;
    // Manifest keeps both off until syncConsent returns. After UMP, Analytics
    // collection turns on (a decline still sends consent-mode pings).
    // Crashlytics turns on only when ads can be requested.
    await _analytics!.setAnalyticsCollectionEnabled(false);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    _installCrashHandlers();
    await syncConsent();
    _ready = true;
    await _flushUserProps();
    debugPrint('Firebase Analytics ready');
  } catch (e, st) {
    CrashReport.recordNonFatal(e, st, reason: 'app_analytics_io:init');
    // Missing google-services.json / Firebase project → stay quiet.
    if (kDebugMode) debugPrint('Firebase Analytics init skipped: $e\n$st');
    _analytics = null;
    _ready = false;
  }
}

Future<void> syncConsent() async {
  if (_analytics == null && !_androidLive) return;
  final analytics = _analytics;
  if (analytics == null) return;
  try {
    await runUmpConsentGate(
      requestUpdate: _requestConsentInfoUpdate,
      showForm: _showStartupConsentForm,
      resync: _resyncAfterConsentForm,
    );
    // Timeout, error, or a form that already resynced. Apply the answer
    // we can see now. A form that closed inside the gate already applied
    // it once; this covers the path where no form ran.
    await _applyMeasurementConsent();
  } catch (e, st) {
    CrashReport.recordNonFatal(e, st, reason: 'app_analytics_io:consent');
    if (kDebugMode) debugPrint('Firebase Analytics consent sync failed: $e\n$st');
  }
}

Future<void> _applyMeasurementConsent() async {
  final analytics = _analytics;
  if (analytics == null) return;
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
}

/// Form closed. Apply the real answer, then fetch Remote Config.
/// Remote Config still refuses the fetch when ads cannot be requested.
Future<void> _resyncAfterConsentForm() async {
  await _applyMeasurementConsent();
  await RemoteTuneBoot.refresh();
}

Future<void> adImpression({
  required String adFormat,
  required String adUnitName,
  double? value,
  String? currency,
  String? placement,
}) async {
  final code = currency?.trim().toUpperCase();
  final analytics = _analytics;
  if (analytics == null) return;
  try {
    await analytics.logAdImpression(
      adPlatform: 'admob',
      adFormat: adFormat,
      adUnitName: adUnitName,
      value: value,
      currency: code,
    );
  } catch (e, st) {
    CrashReport.recordNonFatal(e, st, reason: 'app_analytics_io:ad_impression');
    if (kDebugMode) {
      debugPrint('Firebase Analytics ad_impression failed: $e\n$st');
    }
  }
}

Future<void> logEvent(String name, [Map<String, Object>? params]) async {
  if (!AnalyticsGuard.shouldSend(name)) return;
  final analytics = _analytics;
  if (analytics == null) return;
  try {
    await analytics.logEvent(
      name: name,
      parameters: AnalyticsGuard.params(params),
    );
  } catch (e, st) {
    CrashReport.recordNonFatal(e, st, reason: 'app_analytics_io:log_event');
    if (kDebugMode) debugPrint('Firebase Analytics logEvent($name) failed: $e\n$st');
  }
}

Future<void> setUserProperty(String name, String value) async {
  final safe = AnalyticsGuard.userProperty(name, value);
  if (safe == null) return;
  _userProps[safe.name] = safe.value;
  final analytics = _analytics;
  if (analytics == null) return;
  try {
    await analytics.setUserProperty(name: safe.name, value: safe.value);
  } catch (e, st) {
    CrashReport.recordNonFatal(e, st, reason: 'app_analytics_io:user_prop');
    if (kDebugMode) {
      debugPrint('Firebase Analytics user property ${safe.name} failed: $e\n$st');
    }
  }
}

Future<void> _flushUserProps() async {
  final analytics = _analytics;
  if (analytics == null || _userProps.isEmpty) return;
  for (final entry in _userProps.entries) {
    try {
      await analytics.setUserProperty(name: entry.key, value: entry.value);
    } catch (e, st) {
      CrashReport.recordNonFatal(e, st, reason: 'app_analytics_io:flush_prop');
      if (kDebugMode) {
        debugPrint(
          'Firebase Analytics user property ${entry.key} failed: $e\n$st',
        );
      }
    }
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
    CrashReport.recordNonFatal(e, st, reason: 'app_analytics_io:crash_key');
    if (kDebugMode) debugPrint('Crashlytics setCustomKey failed: $e\n$st');
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
    // The early handler already presented these. recordFlutterError would
    // present them again, so record the same fatal/non-fatal choice quietly.
    unawaited(_recordFlutter(details, alreadyPresented: true));
  }
  for (final pending in platformCopy) {
    _emitPlatform(pending.$1, pending.$2);
  }
}

/// Rendering overflow stays non-fatal. Other framework errors stay fatal.
Future<void> _recordFlutter(
  FlutterErrorDetails details, {
  required bool alreadyPresented,
}) {
  final fatal = !flutterErrorIsNonFatal(details);
  if (!alreadyPresented) {
    return FirebaseCrashlytics.instance.recordFlutterError(
      details,
      fatal: fatal,
    );
  }
  return FirebaseCrashlytics.instance.recordError(
    details.exception,
    details.stack,
    fatal: fatal,
  );
}

void _requestConsentInfoUpdate(UmpUpdateCallbacks callbacks) {
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    callbacks.onSuccess,
    (FormError error) {
      debugPrint('UMP update (analytics): ${error.message}');
      callbacks.onError(error);
    },
  );
}

/// No timeout. The player can read the form for as long as they need.
Future<void> _showStartupConsentForm() async {
  final done = Completer<void>();
  ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
    if (error != null) {
      debugPrint('UMP form (analytics): ${error.message}');
    }
    if (!done.isCompleted) done.complete();
  });
  await done.future;
}
