import '../models/roi2_persist.dart';

/// Local-midnight day keys, with a one-time UTC migration and a time-zone
/// guard that honours a zone change at most once per day.
abstract final class DayClock {
  /// Test seam. Null uses the device zone. Does not change wall-clock time.
  static int? debugOffsetMinutes;

  static int offsetMinutes() =>
      debugOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;

  static String ymd(DateTime instant, int offsetMinutes) {
    final shifted = instant.toUtc().add(Duration(minutes: offsetMinutes));
    final y = shifted.year.toString().padLeft(4, '0');
    final m = shifted.month.toString().padLeft(2, '0');
    final d = shifted.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static int nextMidnightUtcMs(DateTime instant, int offsetMinutes) {
    final shifted = instant.toUtc().add(Duration(minutes: offsetMinutes));
    final next = DateTime.utc(shifted.year, shifted.month, shifted.day).add(
      const Duration(days: 1),
    );
    return next.millisecondsSinceEpoch - offsetMinutes * 60000;
  }

  /// Day key daily refills compare against.
  static String effective(Roi2Persist roi, DateTime now) {
    final utc = now.toUtc();
    final offset = offsetMinutes();
    final local = ymd(utc, offset);
    final nowMs = utc.millisecondsSinceEpoch;
    if (roi.dailyRefillHoldUntilMs > 0 &&
        nowMs < roi.dailyRefillHoldUntilMs &&
        roi.tzPinnedDay.isNotEmpty) {
      return roi.tzPinnedDay;
    }
    if (roi.clockJumpSuppressDay.isNotEmpty &&
        roi.clockJumpSuppressDay == local &&
        roi.tzPinnedDay.isNotEmpty) {
      return roi.tzPinnedDay;
    }
    if (roi.tzOffsetMinutes != Roi2Persist.unsetOffset &&
        roi.tzOffsetMinutes != offset) {
      final oldDay = ymd(utc, roi.tzOffsetMinutes);
      if (roi.tzHonoredDay.isNotEmpty &&
          (roi.tzHonoredDay == oldDay || roi.tzHonoredDay == local) &&
          roi.tzPinnedDay.isNotEmpty) {
        return roi.tzPinnedDay;
      }
    }
    return local;
  }

  /// Records a time-zone change. A second change on the same day keeps the
  /// day key from the first change.
  static Roi2Persist noteZone(Roi2Persist roi, DateTime now) {
    final offset = offsetMinutes();
    final utc = now.toUtc();
    final local = ymd(utc, offset);
    if (roi.tzOffsetMinutes == Roi2Persist.unsetOffset ||
        roi.tzOffsetMinutes == offset) {
      return roi.copyWith(tzOffsetMinutes: offset);
    }
    final oldDay = ymd(utc, roi.tzOffsetMinutes);
    if (roi.tzHonoredDay == oldDay || roi.tzHonoredDay == local) {
      return roi.copyWith(
        tzOffsetMinutes: offset,
        tzPinnedDay: roi.tzPinnedDay.isEmpty ? oldDay : roi.tzPinnedDay,
      );
    }
    return roi.copyWith(
      tzOffsetMinutes: offset,
      tzHonoredDay: local,
      tzPinnedDay: local,
    );
  }

  static int laterMs(int a, int b) => a > b ? a : b;
}
