import 'dart:math';

/// Shared helpers for Farm Rift and Greater Rift timed kill ladders.
///
/// Keep the two player modes separate (loot vs ranked); only the common
/// timer formatting and fast-clear unlock bump live here.
abstract final class TimedLadder {
  static String formatTimer(int ms) {
    final totalSec = max(0, (ms / 1000).floor());
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    // Fixed width so dungeon HUD chips do not reflow as minutes tick.
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Unlock next tier; +2 when remaining time ≥ 25% of par.
  static int unlockTiersAfterSuccess({
    required int clearedTier,
    required int timerMs,
    required int parMs,
    required int Function(int) clampTier,
  }) {
    final remaining = (parMs - timerMs).clamp(0, parMs);
    final fast = parMs > 0 && remaining >= (parMs * 0.25).round();
    final bump = fast ? 2 : 1;
    return clampTier(clearedTier + bump);
  }
}
