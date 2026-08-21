import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    } catch (_) {
      // Sideload / desktop / missing channel — ignore.
    }
  }
}
