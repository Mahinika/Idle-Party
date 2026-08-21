import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import 'flutter_test_env_io.dart' as test_env;

/// Android Play Core probe. Tests / missing Play → null, never throws.
Future<int?> probeAvailableVersionCode() async {
  if (test_env.inFlutterTestProcess()) return null;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      return info.availableVersionCode;
    }
  } catch (e, st) {
    debugPrint('PlayStoreUpdate check failed: $e\n$st');
  }
  return null;
}

/// Starts a flexible Play download when allowed. False → caller opens listing.
Future<bool> startFlexiblePlayUpdate() async {
  if (test_env.inFlutterTestProcess()) return false;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }
    if (!info.flexibleUpdateAllowed) return false;
    unawaited(() async {
      try {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      } catch (e, st) {
        debugPrint('PlayStoreUpdate flexible failed: $e\n$st');
      }
    }());
    return true;
  } catch (e, st) {
    debugPrint('PlayStoreUpdate start failed: $e\n$st');
    return false;
  }
}
