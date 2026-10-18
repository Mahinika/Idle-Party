/// How many [SpatialCombat.step] calls fit in one screen refresh.
///
/// Live 2× pace drops to one step when the previous tick was already late.
/// Debug time scale stays uncapped so a 10× playtest still runs.
abstract final class FightFrameBudget {
  static int steps({
    required int pace,
    required double debugScale,
    required int catchUp,
    required int lastSimMs,
  }) {
    if (debugScale <= 1 && lastSimMs > 22) return 1;
    final raw = (debugScale * pace).round() + catchUp;
    if (raw < 1) return 1;
    if (raw > 20) return 20;
    return raw;
  }
}
