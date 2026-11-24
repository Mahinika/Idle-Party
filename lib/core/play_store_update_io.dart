import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import 'flutter_test_env_io.dart' as test_env;
import 'play_update_timeout.dart';

/// Android Play Core probe. Tests / missing Play → null, never throws.
/// A hung [InAppUpdate.checkForUpdate] gives up after [playUpdateCheckTimeout].
Future<int?> probeAvailableVersionCode() async {
  if (test_env.inFlutterTestProcess()) return null;
  try {
    final info = await boundPlayUpdateCall(InAppUpdate.checkForUpdate());
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      return info.availableVersionCode;
    }
  } catch (e, st) {
    debugPrint('PlayStoreUpdate check failed: $e\n$st');
  }
  return null;
}

/// Full-screen Play update when allowed. False → try flexible or listing.
Future<bool> startImmediatePlayUpdate() async {
  if (test_env.inFlutterTestProcess()) return false;
  try {
    final info = await boundPlayUpdateCall(InAppUpdate.checkForUpdate());
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }
    if (!info.immediateUpdateAllowed) return false;
    final result = await InAppUpdate.performImmediateUpdate();
    return result == AppUpdateResult.success;
  } catch (e, st) {
    debugPrint('PlayStoreUpdate immediate failed: $e\n$st');
    return false;
  }
}

/// What the Play probe said, without the plugin type, so tests can drive it.
class PlayUpdateOffer {
  const PlayUpdateOffer({
    required this.updateAvailable,
    required this.flexibleAllowed,
  });

  final bool updateAvailable;
  final bool flexibleAllowed;
}

/// Flexible flow. True only after the download resolves and the installer
/// runs. [startFlexibleUpdate] in in_app_update 5.0.0 completes on DOWNLOADED,
/// so [complete] runs after that future, not before it. Cancel or failure
/// returns false so the caller can open the Play listing.
Future<bool> runFlexiblePlayUpdate({
  required PlayUpdateOffer offer,
  required Future<AppUpdateResult> Function() start,
  required Future<void> Function() complete,
}) async {
  if (!offer.updateAvailable || !offer.flexibleAllowed) return false;
  try {
    final result = await start();
    if (result != AppUpdateResult.success) return false;
    await complete();
    return true;
  } catch (e, st) {
    debugPrint('PlayStoreUpdate flexible failed: $e\n$st');
    return false;
  }
}

/// Starts a flexible Play download when allowed. False → caller opens listing.
Future<bool> startFlexiblePlayUpdate() async {
  if (test_env.inFlutterTestProcess()) return false;
  try {
    final info = await boundPlayUpdateCall(InAppUpdate.checkForUpdate());
    return await runFlexiblePlayUpdate(
      offer: PlayUpdateOffer(
        updateAvailable:
            info.updateAvailability == UpdateAvailability.updateAvailable,
        flexibleAllowed: info.flexibleUpdateAllowed,
      ),
      start: InAppUpdate.startFlexibleUpdate,
      complete: InAppUpdate.completeFlexibleUpdate,
    );
  } catch (e, st) {
    debugPrint('PlayStoreUpdate start failed: $e\n$st');
    return false;
  }
}
