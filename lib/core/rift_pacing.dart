import 'dart:math';

/// Shared Farm Rift / Ranked GR pacing.
///
/// One equation so time, kill quota, and toughness stay honest:
///
/// `parMs ≈ guardianMs + killTarget × threatMul / refKps × 1000`
///
/// then clamp to a phone-length window. Difficulty is **threat** (HP/ATK).
/// **Density** is extra bodies (like KEY), not a second HP tax.
/// Kill quota grows through [campaignCap] then holds; threat keeps climbing.
abstract final class RiftPacing {
  static const int campaignCap = 20;

  static int killTarget({
    required int tier,
    required int base,
    required int perTier,
  }) {
    final t = min(max(1, tier), campaignCap);
    return base + t * perTier;
  }

  static double threatMul({
    required int tier,
    required double perTier,
    required double afterCap,
  }) {
    final t = max(1, tier);
    if (t <= campaignCap) return 1.0 + t * perTier;
    return 1.0 + campaignCap * perTier + (t - campaignCap) * afterCap;
  }

  static double densityMul({
    required int tier,
    required double perTier,
  }) {
    final t = min(max(1, tier), campaignCap);
    return 1.0 + t * perTier;
  }

  /// Expected duration from work = kills × toughness at [refKps] of 1.0-threat trash.
  static int parTimeMs({
    required int killTarget,
    required double threatMul,
    required double refKps,
    required int guardianMs,
    required int minMs,
    required int maxMs,
  }) {
    final kps = max(0.05, refKps);
    final workMs = (killTarget * threatMul / kps * 1000).round();
    return (guardianMs + workMs).clamp(minMs, maxMs);
  }

  /// Required trash DPS-vs-R1 proxy: kills × threat / seconds.
  static double workPerSecond({
    required int killTarget,
    required double threatMul,
    required int parMs,
  }) {
    final sec = max(0.001, parMs / 1000.0);
    return killTarget * threatMul / sec;
  }
}
