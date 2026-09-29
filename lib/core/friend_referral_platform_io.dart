import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:share_plus/share_plus.dart';

import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;
import 'friend_referral.dart';

bool get _androidLive {
  if (test_env.inFlutterTestProcess()) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

Future<String?> readFriendDeviceId() async {
  if (!_androidLive) return null;
  try {
    final raw = await const AndroidId().getId();
    if (raw == null || raw.isEmpty) return null;
    return FriendReferral.deviceKey(raw);
  } catch (e, st) {
    debugPrint('Friend device id failed: $e\n$st');
    return null;
  }
}

Future<String?> readPlayInstallReferrer() async {
  if (!_androidLive) return null;
  try {
    final details = await PlayInstallReferrer.installReferrer;
    return details.installReferrer;
  } catch (e, st) {
    debugPrint('Play install referrer failed: $e\n$st');
    return null;
  }
}

Future<void> shareFriendMessage(String message) {
  return SharePlus.instance.share(
    ShareParams(text: message, subject: 'Play Idle Party with me'),
  );
}
