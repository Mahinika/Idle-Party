import 'dart:math';

/// Timed hub POWERUPS (optional rewarded ad). Duration stacks; effects do not.
abstract final class AdBoost {
  static const int hourMs = 60 * 60 * 1000;
  static const int maxStackMs = 24 * hourMs;

  /// Extra attack while a boost is running.
  static const int attackPercent = 25;

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static bool isActive(int untilMs, {int? nowMs}) {
    final now = nowMs ?? AdBoost.nowMs();
    return untilMs > now;
  }

  static int remainingMs(int untilMs, {int? nowMs}) {
    final now = nowMs ?? AdBoost.nowMs();
    return max(0, untilMs - now);
  }

  static bool atStackCap(int untilMs, {int? nowMs}) {
    return remainingMs(untilMs, nowMs: nowMs) >= maxStackMs;
  }

  /// One watched ad → +1 hour from remaining time (or from now). Caps at 24h.
  static int addHour(int untilMs, {int? nowMs}) {
    final now = nowMs ?? AdBoost.nowMs();
    final base = untilMs > now ? untilMs : now;
    final cap = now + maxStackMs;
    if (base >= cap) return untilMs;
    final next = base + hourMs;
    return next > cap ? cap : next;
  }

  static String formatRemaining(int untilMs, {int? nowMs}) {
    final ms = remainingMs(untilMs, nowMs: nowMs);
    if (ms <= 0) return '';
    final totalMin = max(1, (ms + 59999) ~/ 60000);
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h <= 0) return '${m}m';
    if (m <= 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
