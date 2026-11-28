import '../models/vfx_quality.dart';

/// A short freeze after a boss dies. Presentation only.
///
/// About 75 ms, inside the 60–90 ms window. Skipped when the fight is
/// already taking more than one step per frame (2× pace, or a 2× / 4×
/// debug scale), because a freeze there stutters. Minimal VFX is the
/// reduce-motion setting and skips it too.
abstract final class BossHitStop {
  static const double seconds = 0.075;

  static bool allow({
    required int pace,
    required double debugScale,
    required VfxQuality vfx,
    required int steps,
  }) {
    if (vfx == VfxQuality.minimal) return false;
    if (pace >= 2) return false;
    if (debugScale >= 2) return false;
    if (steps > 1) return false;
    return true;
  }
}
