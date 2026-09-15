import 'dart:math';

import '../models/meta_depth.dart';
import 'rift_progress.dart';
import 'timed_ladder.dart';

/// Farm Rift — Diablo 3 Nephalem-style (party max level).
///
/// Runs in **Stormwake Hollow**. Fill progress by killing monsters, then defeat
/// the **Rift Guardian**. No clear-timer fail (elapsed is display-only). Mid-run
/// gold + gear. Not ranked on Play Games (see [GreaterRift]).
/// SpatialCombat stays the fight authority — this module is rules + payout only.
abstract final class Rift {
  /// TODAY campaign chase / kill-quota plateau — farm push keeps going.
  static const int campaignCap = 20;

  /// Practical endless bound (save / overflow).
  static const int maxTier = kEndlessLadderBound;
  static const int minTier = 1;

  /// Same endgame gate as KEY / Gauntlet.
  static const int minAscension = 20;

  /// Zone art — Stormwake (not Crystal Spire; that is Infinity Gauntlet).
  static const String dungeonId = 'storm';

  static int clampTier(int tier) => tier.clamp(minTier, maxTier);

  /// Preferred hub dial: 1…best+1 (no campaign stop).
  static int maxSelectableTier(int bestCleared) =>
      clampTier(max(minTier, bestCleared + 1));

  /// Picker starts on last pick, else last clear (so GR20 opens on 20, not 1).
  static int pickerStart({required int preferred, required int bestCleared}) {
    final maxSel = maxSelectableTier(bestCleared);
    final p = clampTier(preferred.clamp(minTier, maxSel));
    if (p > minTier) return p;
    if (bestCleared <= 0) return minTier;
    return clampTier(bestCleared.clamp(minTier, maxSel));
  }

  /// Normal kills needed to fill the progress bar to 100%.
  static int killTarget(int tier) {
    final t = min(clampTier(tier), campaignCap);
    return 20 + t * 3; // R1=23 … R20+=80
  }

  /// Display-only elapsed reference (not a fail gate). Kept for HUD pacing.
  static int parTimeMs(int tier) {
    final t = min(clampTier(tier), campaignCap);
    return max(45000, 120000 - t * 3000);
  }

  /// Pack threat keeps climbing after 20.
  static double threatMul(int tier) => 1.0 + clampTier(tier) * 0.12;

  /// Pack count soft-caps at [campaignCap]; threat still climbs.
  static double densityMul(int tier) =>
      1.0 + min(clampTier(tier), campaignCap) * 0.08;

  static int successEssence(int tier) => 8 + clampTier(tier) * 2;

  static int failEssence(int tier) => max(1, clampTier(tier) ~/ 4);

  static int successGold(int tier) {
    final t = clampTier(tier);
    return 80 + t * 35;
  }

  /// Farm clears unlock +1 only (no timer-based +2).
  static int unlockTierAfterSuccess({required int clearedTier}) =>
      clampTier(clearedTier + 1);

  static String formatTimer(int ms) => TimedLadder.formatTimer(ms);

  static String hudChipLabel({
    required double progress01,
    required int tier,
    required bool guardianActive,
  }) {
    if (guardianActive) return 'FARM R$tier · GUARDIAN';
    return 'FARM R$tier · ${RiftProgress.percentLabel(progress01)}';
  }

  static String progressLabel({
    required double progress01,
    required int timerMs,
    required int tier,
    required bool guardianActive,
  }) {
    final pct = RiftProgress.percentLabel(progress01);
    if (guardianActive) {
      return 'FARM R$tier · GUARDIAN · ${formatTimer(timerMs)}';
    }
    return 'FARM R$tier · $pct · ${formatTimer(timerMs)}';
  }
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
