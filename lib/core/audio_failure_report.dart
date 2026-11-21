import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;

/// One non-fatal Crashlytics line per asset path per process.
///
/// A no-op under `flutter test` and when Firebase was not initialized, so a
/// missing google-services.json or a unit test never touches the plugin.
abstract final class AudioFailureReport {
  static final Set<String> _reported = <String>{};

  /// First call for [path] this session wins. Later calls are dropped.
  @visibleForTesting
  static bool claim(String path) => path.isNotEmpty && _reported.add(path);

  @visibleForTesting
  static void debugReset() => _reported.clear();

  static void loadFailed(String path, Object error, StackTrace stack) {
    _send(path, error, stack, 'audio load failed: $path');
  }

  static void playFailed(String path, Object error, StackTrace stack) {
    _send(path, error, stack, 'audio play failed: $path');
  }

  static void _send(
    String path,
    Object error,
    StackTrace stack,
    String reason,
  ) {
    if (!claim(path)) return;
    if (test_env.inFlutterTestProcess() || Firebase.apps.isEmpty) {
      // Do not burn the slot: Firebase may attach after the first miss,
      // and tests must not keep a path silent for a later case.
      _reported.remove(path);
      return;
    }
    try {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: false,
          reason: reason,
        ),
      );
    } catch (e, st) {
      _reported.remove(path);
      debugPrint('AudioFailureReport failed: $e\n$st');
    }
  }
}
