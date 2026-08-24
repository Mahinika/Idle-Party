import 'dart:math';

/// Farm Rift — timed kill challenge with mid-run gold and gear (party max level).
///
/// Kill [killTarget] enemies before [parTimeMs] expires. Success unlocks the
/// next tier (+2 if finished with ≥25% time remaining). Not ranked on Play
/// Games (see [GreaterRift] for prestige boards). SpatialCombat stays the
/// fight authority — this module is rules + payout only.
abstract final class Rift {
  static const int maxTier = 20;
  static const int minTier = 1;

  /// Same endgame gate as KEY / Gauntlet.
  static const int minAscension = 20;

  /// Zone art for rift chambers.
  static const String dungeonId = 'crystal';

  static int clampTier(int tier) => tier.clamp(minTier, maxTier);

  /// Preferred hub dial: 1…best+1 (capped).
  static int maxSelectableTier(int bestCleared) =>
      clampTier(max(minTier, bestCleared + 1));

  static int killTarget(int tier) {
    final t = clampTier(tier);
    return 20 + t * 3; // R1=23 … R20=80
  }

  /// Par window — higher tiers get less time.
  static int parTimeMs(int tier) {
    final t = clampTier(tier);
    return max(45000, 120000 - t * 3000); // R1≈117s … R20=60s
  }

  static double threatMul(int tier) => 1.0 + clampTier(tier) * 0.12;

  static double densityMul(int tier) => 1.0 + clampTier(tier) * 0.08;

  static int successEssence(int tier) => 8 + clampTier(tier) * 2;

  static int failEssence(int tier) => max(1, clampTier(tier) ~/ 4);

  static int successGold(int tier) {
    final t = clampTier(tier);
    return 80 + t * 35;
  }

  /// Unlock next tier; +2 when remaining time ≥ 25% of par.
  static int unlockTierAfterSuccess({
    required int clearedTier,
    required int timerMs,
    required int parMs,
  }) {
    final remaining = (parMs - timerMs).clamp(0, parMs);
    final fast = parMs > 0 && remaining >= (parMs * 0.25).round();
    final bump = fast ? 2 : 1;
    return clampTier(clearedTier + bump);
  }

  static String formatTimer(int ms) {
    final totalSec = max(0, (ms / 1000).floor());
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String progressLabel({
    required int kills,
    required int target,
    required int timerMs,
    required int parMs,
    required int tier,
  }) =>
      'R$tier · $kills/$target · ${formatTimer(timerMs)}/${formatTimer(parMs)}';
}

/// One-time essence at Rift tier milestones.
abstract final class RiftMilestones {
  static const tiers = <int>[5, 10, 20];

  static int essenceForTier(int tier) => switch (tier) {
        5 => 18,
        10 => 36,
        20 => 72,
        _ => 10,
      };

  static String claimId(int tier) => 'r$tier';
}
