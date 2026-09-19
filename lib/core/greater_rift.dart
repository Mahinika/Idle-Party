import 'dart:math';

import '../models/meta_depth.dart';
import 'rift_pacing.dart';
import 'rift_progress.dart';
import 'timed_ladder.dart';

/// Greater Rift — Diablo 3 Greater-style (party max level; Play Games ranked).
///
/// Runs in **Mothveil Hollow**. Fill progress by killing monsters, spawn the
/// **Rift Guardian** at 100%, defeat it before [parTimeMs]. No mid-run gear
/// (gold OK). Harder packs than farm [Rift]. Shares unlock helpers via
/// [TimedLadder]. SpatialCombat stays the fight authority.
abstract final class GreaterRift {
  /// TODAY campaign chase / kill-quota plateau — ranked push keeps going.
  static const int campaignCap = RiftPacing.campaignCap;

  /// Practical endless bound (save / Play encode / overflow).
  static const int maxTier = kEndlessLadderBound;
  static const int minTier = 1;
  static const int minAscension = 20;
  /// Zone art — Mothveil (prestige; not Crystal Spire Gauntlet / Stormwake farm).
  static const String dungeonId = 'veil';

  static int clampTier(int tier) => tier.clamp(minTier, maxTier);

  /// Open picker / enter: 1…[maxTier]. Best clear is not a gate.
  static int maxSelectableTier([int bestCleared = 0]) {
    assert(bestCleared >= 0);
    return maxTier;
  }

  /// Picker starts on last pick, else last clear (so GR20 opens on 20, not 1).
  static int pickerStart({required int preferred, required int bestCleared}) {
    final maxSel = maxSelectableTier(bestCleared);
    final p = clampTier(preferred.clamp(minTier, maxSel));
    if (p > minTier) return p;
    if (bestCleared <= 0) return minTier;
    return clampTier(bestCleared.clamp(minTier, maxSel));
  }

  /// Next uncleared rank — hub ENDGAME stamp; picker is any 1…[maxTier].
  static int nextOfferTier(int bestCleared) =>
      clampTier(max(minTier, bestCleared + 1));

  static String hubEnterLabel(int bestCleared) =>
      'RANKED GR${nextOfferTier(bestCleared)}';

  static String hubShortLabel(int bestCleared) =>
      'GR${nextOfferTier(bestCleared)}';

  static String hubTitle(int bestCleared) =>
      'Ranked GR${nextOfferTier(bestCleared)}';

  static bool isHubEnterLabel(String label) =>
      RegExp(r'^RANKED GR\d*$').hasMatch(label);

  /// Trash kills to fill the bar. Holds after [campaignCap].
  static int killTarget(int tier) => RiftPacing.killTarget(
        tier: clampTier(tier),
        base: 22,
        perTier: 2,
      );

  /// Fail clock from the same work equation, clamped 60s…90s.
  /// `par ≈ 12s guardian + kills × threat / 0.70 kps`.
  static int parTimeMs(int tier) {
    final t = clampTier(tier);
    return RiftPacing.parTimeMs(
      killTarget: killTarget(t),
      threatMul: threatMul(t),
      refKps: 0.70,
      guardianMs: 12000,
      minMs: 60000,
      maxMs: 90000,
    );
  }

  /// Pack HP/ATK. After GR20 the kill quota + 90s clock hold; threat must
  /// keep climbing or GR250 plays like GR25.
  static double threatMul(int tier) => RiftPacing.threatMul(
        tier: clampTier(tier),
        perTier: 0.16,
        afterCap: 0.20,
      );

  /// Extra bodies (soft-cap at 20). Ranked GR denser than farm.
  static double densityMul(int tier) => RiftPacing.densityMul(
        tier: clampTier(tier),
        perTier: 0.10,
      );

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

  static String hudChipLabel({
    required double progress01,
    required int tier,
    required bool guardianActive,
  }) {
    if (guardianActive) return 'RANK GR$tier · GUARDIAN';
    return 'RANK GR$tier · ${RiftProgress.percentLabel(progress01)}';
  }

  static String progressLabel({
    required double progress01,
    required int timerMs,
    required int parMs,
    required int tier,
    required bool guardianActive,
  }) {
    final pct = RiftProgress.percentLabel(progress01);
    final pace = RiftProgress.paceLabel(
      progress01: progress01,
      timerMs: timerMs,
      parMs: parMs,
    );
    final clock = '${formatTimer(timerMs)}/${formatTimer(parMs)}';
    if (guardianActive) {
      return 'RANK GR$tier · GUARDIAN · $clock';
    }
    final paceBit = pace.isEmpty ? '' : ' · $pace';
    return 'RANK GR$tier · $pct · $clock$paceBit';
  }
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
