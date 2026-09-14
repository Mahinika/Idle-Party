import 'dart:math';

/// Shared Nephalem / Greater-style rift progress (Diablo 3–aligned).
///
/// Kills fill a 0..1 bar toward a Rift Guardian. Farm has no clear-timer fail;
/// Ranked GR races a par clock. SpatialCombat stays fight authority — this is
/// progress math + labels only.
abstract final class RiftProgress {
  /// Normal kill contribution toward 100% for [killTarget] expected kills.
  static double weightForKill({
    required bool elite,
    required bool farm,
  }) {
    if (elite) return farm ? 1.5 : 1.75;
    return 1.0;
  }

  /// Progress gained for one kill toward a bar calibrated to [killTarget].
  static double deltaForKill({
    required int killTarget,
    required bool elite,
    required bool farm,
  }) {
    final t = max(1, killTarget);
    return weightForKill(elite: elite, farm: farm) / t;
  }

  static double clamp01(double v) {
    if (v <= 0) return 0;
    // Float sum of 1/killTarget often lands just under 1.0.
    if (v >= 1.0 - 1e-9) return 1.0;
    return v;
  }

  static double add({
    required double current,
    required int killTarget,
    required int normalKills,
    int eliteKills = 0,
    required bool farm,
  }) {
    var p = current;
    for (var i = 0; i < normalKills; i++) {
      p += deltaForKill(killTarget: killTarget, elite: false, farm: farm);
    }
    for (var i = 0; i < eliteKills; i++) {
      p += deltaForKill(killTarget: killTarget, elite: true, farm: farm);
    }
    return clamp01(p);
  }

  /// Pace vs linear expected progress on a timed GR (AHEAD / BEHIND).
  static String paceLabel({
    required double progress01,
    required int timerMs,
    required int parMs,
  }) {
    if (parMs <= 0) return '';
    final expected = (timerMs / parMs).clamp(0.0, 1.5);
    if (progress01 + 0.05 >= expected) return 'AHEAD';
    return 'BEHIND';
  }

  /// How far the GR clock needle sits on the bar (0..1).
  static double timeSpent01({required int timerMs, required int parMs}) {
    if (parMs <= 0) return 0;
    return (timerMs / parMs).clamp(0.0, 1.0);
  }

  static String percentLabel(double progress01) =>
      '${(clamp01(progress01) * 100).round()}%';
}
