import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'play_store_update_stub.dart'
    if (dart.library.io) 'play_store_update_io.dart'
    as play_core;

/// Soft-fail Google Play update probe + listing open.
///
/// Play-installed Android only. Sideload / web / tests stay quiet.
abstract final class PlayStoreUpdate {
  static const String packageId = 'com.idleparty.app';

  /// en-US listing (hl/gl so the store page is English, not the device locale).
  static final Uri listingUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$packageId&hl=en&gl=US',
  );

  static bool get isSupported {
    if (kIsWeb) return false;
    if (test_env.inFlutterTestProcess()) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Play versionCode waiting on the tester's track, or null if none / unknown.
  static Future<int?> availableVersionCode() async {
    if (!isSupported) return null;
    return play_core.probeAvailableVersionCode();
  }

  /// True when Play reports a newer build on the user's track.
  static Future<bool> isUpdateRequired() async {
    final code = await availableVersionCode();
    return code != null && code > 0;
  }

  static Future<bool> startImmediateUpdate() async {
    if (!isSupported) return false;
    return play_core.startImmediatePlayUpdate();
  }

  static Future<bool> startFlexibleUpdate() async {
    if (!isSupported) return false;
    return play_core.startFlexiblePlayUpdate();
  }

  /// Mandatory cold-start path: immediate → flexible → Play listing.
  static Future<bool> startMandatoryUpdate() async {
    if (!isSupported) return false;
    if (await startImmediateUpdate()) return true;
    if (await startFlexibleUpdate()) return true;
    return await openListing();
  }

  static Future<bool> openListing() async {
    try {
      if (!await canLaunchUrl(listingUri)) return false;
      return await launchUrl(
        listingUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e, st) {
      debugPrint('PlayStoreUpdate openListing failed: $e\n$st');
      return false;
    }
  }
}
