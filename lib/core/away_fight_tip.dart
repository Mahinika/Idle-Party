import 'funnel_analytics.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';

/// The appointment to open again tomorrow.
///
/// Before the first boss, the cave says the party keeps fighting, and the
/// hub says gold only gathers there. After the boss, the hub names
/// tomorrow's check-in prize for the rest of that UTC day. A tap does not
/// clear it. The next UTC day hides it.
abstract final class AwayFightTip {
  static const String line =
      'Close the app anytime. Your party keeps fighting.';

  /// Hub, after they have entered once and before the first boss.
  /// Fighting continues only in the cave.
  static const String hubLine =
      'Leave them in the cave and they keep fighting. On the hub, gold gathers.';

  /// [inCave] is the live dungeon, including floor 1. [bossStairs] is the
  /// walk to the stairs after the first boss, before the hub opens.
  static bool shouldShow(
    GameState state, {
    required bool bossStairs,
    bool inCave = false,
    DateTime? now,
  }) {
    if (state.metaDepth.awayFightTipSeen) return false;
    final armed = state.metaDepth.awayPromiseUtc;
    if (armed.isNotEmpty) {
      final clock = (now ?? DateTime.now()).toUtc();
      if (armed != MetaSystems.dailyDateKey(clock)) return false;
    }
    if (GameLogic.showDailyChase(state)) return true;
    if (!GameLogic.firstBossPending(state)) return false;
    if (inCave || bossStairs) return true;
    return FunnelAnalytics.has(state, FunnelAnalytics.firstEnter);
  }

  /// Prize first, so a one-line hub clip still names what waits.
  /// [onHub] picks the gold line before check-in exists.
  ///
  /// An unclaimed vault is wiped at the UTC day roll, so that prize is
  /// today or it is gone. Tomorrow is named only after the claim.
  static String lineFor(GameState state, {bool onHub = false}) {
    if (!GameLogic.checkInActive(state)) return onHub ? hubLine : line;
    final pay = GameLogic.checkInPayout(state);
    if (GameLogic.canClaimDailyVault(state)) {
      return 'Claim ${pay.hookPrize} before the day ends. '
          'Your party keeps fighting.';
    }
    if (state.metaDepth.dailyVaultClaimed) {
      return 'Tomorrow pays ${pay.hookPrize}. Your party keeps fighting.';
    }
    return 'One cave fills the vault. Your party keeps fighting.';
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
