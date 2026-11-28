import 'remote_tune.dart';

/// Remote Config live event. Shipped off: empty id, multiplier 1, no window.
abstract final class LiveEvent {
  /// Gold multiplier for the active window. 1 when no event is on.
  static double goldMul(DateTime now) {
    if (!RemoteTune.liveEventActive(now.toUtc())) return 1;
    return RemoteTune.liveEventMultiplier;
  }

  static int scaleGold(int gold, DateTime now) {
    if (gold <= 0) return gold;
    final mul = goldMul(now);
    if (mul == 1) return gold;
    final scaled = (gold * mul).round();
    return scaled < 0 ? 0 : scaled;
  }
}
