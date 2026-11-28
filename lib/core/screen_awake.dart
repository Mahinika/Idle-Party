import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'crash_report.dart';

/// Android FLAG_KEEP_SCREEN_ON while fighting (soft-fail on web / desktop).
abstract final class ScreenAwake {
  static const MethodChannel _channel = MethodChannel('idle_party/screen');

  static bool _last = false;

  static Future<void> setEnabled(bool enabled) async {
    if (_last == enabled) {
      return;
    }
    _last = enabled;
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', <String, bool>{
        'on': enabled,
      });
    } catch (e, st) {
      CrashReport.recordNonFatal(e, st, reason: 'screen_awake:set_enabled');
      // Sideload / desktop / missing channel — ignore.
    }
  }
}
