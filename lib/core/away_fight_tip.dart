import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';

/// The appointment to open again tomorrow.
///
/// Before the first boss is banked, the stairs only say the party keeps
/// fighting. After that, the hub names tomorrow's check-in prize for the
/// rest of that UTC day. A tap does not clear it. The next UTC day hides it.
abstract final class AwayFightTip {
  static const String line =
      'Close the app anytime. Your party keeps fighting.';

  /// [bossStairs] is the walk to the stairs after the first boss, before
  /// the victory is banked and the hub opens.
  static bool shouldShow(
    GameState state, {
    required bool bossStairs,
    DateTime? now,
  }) {
    if (state.metaDepth.awayFightTipSeen) return false;
    final armed = state.metaDepth.awayPromiseUtc;
    if (armed.isNotEmpty) {
      final clock = (now ?? DateTime.now()).toUtc();
      if (armed != MetaSystems.dailyDateKey(clock)) return false;
    }
    if (GameLogic.showDailyChase(state)) return true;
    return bossStairs && GameLogic.firstBossPending(state);
  }

  /// Prize first, so a one-line hub clip still names what waits.
  static String lineFor(GameState state) {
    if (!GameLogic.checkInActive(state)) return line;
    final pay = GameLogic.checkInPayout(state);
    final hook = state.metaDepth.dailyVaultClaimed
        ? 'Tomorrow pays ${pay.hookPrize}.'
        : 'Today\'s ${pay.hookPrize} still waits tomorrow.';
    return '$hook Your party keeps fighting.';
  }

  /// Stamp today the first time the appointment can show. Later days hide it.
  static GameState arm(GameState state, DateTime now) {
    if (state.metaDepth.awayFightTipSeen) return state;
    if (state.metaDepth.awayPromiseUtc.isNotEmpty) return state;
    if (!GameLogic.showDailyChase(state)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        awayPromiseUtc: MetaSystems.dailyDateKey(now.toUtc()),
      ),
    );
  }

  static GameState markSeen(GameState state) {
    if (state.metaDepth.awayFightTipSeen) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(awayFightTipSeen: true),
    );
  }
}
