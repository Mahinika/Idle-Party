import 'dart:async';

import 'package:flutter/services.dart';

import '../models/roi2_persist.dart';
import 'flutter_test_env_stub.dart'
    if (dart.library.io) 'flutter_test_env_io.dart'
    as test_env;

/// What a resume may credit after comparing wall time to uptime.
enum ClockVerdict {
  /// Wall clock moved forward in step with uptime.
  ok,

  /// Device clock is behind the last time we saw. No offline credit.
  clockBack,

  /// The calendar jumped further than the device was actually on.
  /// Skip daily refills for that jump. Offline credit still follows wall
  /// time only when the clock did not move backwards.
  skipDailyRefill,
}

/// Highest wall time seen, plus an uptime check so a forward clock set
/// cannot mint a pile of daily refills.
abstract final class ClockGuard {
  /// Test seam for `SystemClock.elapsedRealtime`. Null asks the platform.
  static int? debugUptimeMs;

  static const MethodChannel _channel = MethodChannel('idle_party/screen');

  /// `SystemClock.elapsedRealtime`, including sleep. 0 when the platform
  /// has no answer (tests, web).
  static Future<int> readUptimeMs() async {
    final debug = debugUptimeMs;
    if (debug != null) return debug;
    if (test_env.inFlutterTestProcess()) return 0;
    try {
      // A test binding with no handler never answers. Cap the wait so boot
      // still finishes. A phone answers on this channel immediately.
      final raw = await _channel
          .invokeMethod<num>('elapsedRealtime')
          .timeout(const Duration(milliseconds: 50));
      return raw?.toInt() ?? 0;
    } on Object {
      return 0;
    }
  }

  static const int _dayMs = 24 * 60 * 60 * 1000;

  static ClockVerdict evaluate({
    required int nowMs,
    required int highestWallMs,
    required int uptimeMs,
    required int lastUptimeMs,
    required int lastWallMs,
    required int dayJump,
  }) {
    if (highestWallMs > 0 && nowMs < highestWallMs) {
      return ClockVerdict.clockBack;
    }
    if (dayJump > 0 && lastUptimeMs > 0 && lastWallMs > 0) {
      final elapsed = uptimeMs - lastUptimeMs;
      // A reboot resets elapsedRealtime. That is not a clock set.
      if (elapsed >= 0) {
        final elapsedDays = elapsed / _dayMs;
        if (dayJump > elapsedDays + 0.05) {
          return ClockVerdict.skipDailyRefill;
        }
      }
    }
    return ClockVerdict.ok;
  }

  /// Whole local days from [fromKey] to [toKey]. Negative if [toKey] is older.
  static int dayJump(String fromKey, String toKey) {
    final from = _parse(fromKey);
    final to = _parse(toKey);
    if (from == null || to == null) return 0;
    return to.difference(from).inDays;
  }

  static DateTime? _parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

  /// Updates the persisted clocks. A backward clock does not move the high
  /// water mark and does not replace the last honest session.
  static Roi2Persist noteSession(
    Roi2Persist roi, {
    required int nowMs,
    required int uptimeMs,
    required ClockVerdict verdict,
    required String todayKey,
    required String previousDayKey,
  }) {
    if (verdict == ClockVerdict.clockBack) return roi;
    var next = roi.copyWith(
      highestWallMs: nowMs > roi.highestWallMs ? nowMs : roi.highestWallMs,
      lastSessionWallMs: nowMs,
      lastSessionUptimeMs: uptimeMs,
    );
    if (verdict == ClockVerdict.skipDailyRefill) {
      next = next.copyWith(
        clockJumpSuppressDay: todayKey,
        tzPinnedDay: previousDayKey.isEmpty ? roi.tzPinnedDay : previousDayKey,
      );
    } else if (roi.clockJumpSuppressDay.isNotEmpty &&
        roi.clockJumpSuppressDay != todayKey) {
      next = next.copyWith(clockJumpSuppressDay: '');
    }
    return next;
  }
}
