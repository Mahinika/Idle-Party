import 'dart:math';

import 'timed_ladder.dart';

/// Greater Rift — prestige timed kill ladder (party max level; Play Games ranked).
///
/// Runs in **Mothveil Hollow** (not Crystal Spire / not Stormwake farm). Harder
/// packs than farm [Rift], thinner mid-run loot (gold OK, no gear), bigger clear
/// payout. Higher GR tier always ranks above lower; same tier prefers faster clear.
/// Shares timer/unlock helpers with [Rift] via [TimedLadder] — modes stay separate.
abstract final class GreaterRift {
  static const int maxTier = 20;
  static const int minTier = 1;
  static const int minAscension = 20;
  /// Zone art — Mothveil (prestige; not Crystal Spire Gauntlet / Stormwake farm).
  static const String dungeonId = 'veil';

  static int clampTier(int tier) => tier.clamp(minTier, maxTier);

  static int maxSelectableTier(int bestCleared) =>
      clampTier(max(minTier, bestCleared + 1));

  static int killTarget(int tier) {
    final t = clampTier(tier);
    return 22 + t * 4; // GR1=26 … GR20=102
  }

  static int parTimeMs(int tier) {
    final t = clampTier(tier);
    // Tighter than farm through mid tiers. GR20 keeps ~62s — ranked is extra
    // kills + threat, not a 46s blender.
    return max(58000, 112000 - t * 2500);
  }

  /// ~1.5× farm Rift threat at the same tier band.
  static double threatMul(int tier) => 1.0 + clampTier(tier) * 0.20;

  static double densityMul(int tier) => 1.0 + clampTier(tier) * 0.12;

  static int successEssence(int tier) => 14 + clampTier(tier) * 3;

  static int failEssence(int tier) => max(1, clampTier(tier) ~/ 3);

  static int successGold(int tier) {
    final t = clampTier(tier);
    return 120 + t * 50;
  }

  static int unlockTierAfterSuccess({
    required int clearedTier,
    required int timerMs,
    required int parMs,
  }) =>
      TimedLadder.unlockTiersAfterSuccess(
        clearedTier: clearedTier,
        timerMs: timerMs,
        parMs: parMs,
        clampTier: clampTier,
      );

  static String formatTimer(int ms) => TimedLadder.formatTimer(ms);

  /// Short in-dungeon chip (no timer — timer lives on the place line).
  static String hudChipLabel({
    required int kills,
    required int target,
    required int tier,
  }) =>
      'RANK GR$tier · $kills/$target';

  static String progressLabel({
    required int kills,
    required int target,
    required int timerMs,
    required int parMs,
    required int tier,
  }) =>
      'RANK GR$tier · $kills/$target · ${formatTimer(timerMs)}/${formatTimer(parMs)}';
}

/// One-time essence at Greater Rift tier milestones.
abstract final class GreaterRiftMilestones {
  static const tiers = <int>[5, 10, 20];

  static int essenceForTier(int tier) => switch (tier) {
        5 => 24,
        10 => 48,
        20 => 96,
        _ => 12,
      };

  static String claimId(int tier) => 'gr$tier';
}
