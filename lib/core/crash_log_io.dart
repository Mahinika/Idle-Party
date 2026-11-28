import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;

/// Firebase Crashlytics non-fatal line, once per [reason] key per process.
void recordNonFatal(
  Object error,
  StackTrace stack, {
  String? reason,
}) {
  final tag = reason?.trim() ?? error.runtimeType.toString();
  if (tag.isEmpty) return;
  if (!_CrashDedup.claim(tag)) return;
  if (test_env.inFlutterTestProcess() || Firebase.apps.isEmpty) {
    _CrashDedup.release(tag);
    return;
  }
  try {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: false,
        reason: tag,
      ),
    );
  } catch (e, st) {
    _CrashDedup.release(tag);
    if (kDebugMode) debugPrint('CrashReport.recordNonFatal failed: $e\n$st');
  }
}

final class _CrashDedup {
  static final Set<String> _seen = <String>{};

  static bool claim(String key) => key.isNotEmpty && _seen.add(key);

  static void release(String key) => _seen.remove(key);

}