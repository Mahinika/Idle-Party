import 'game_logic.dart';
import 'game_state.dart';

/// One line after the first boss: the party keeps fighting if you leave.
abstract final class AwayFightTip {
  static const String line =
      'Close the app anytime. Your party keeps fighting.';

  /// [bossStairs] is the walk to the stairs after the first boss, before
  /// the victory is banked and the hub opens.
  static bool shouldShow(GameState state, {required bool bossStairs}) {
    if (state.metaDepth.awayFightTipSeen) return false;
    if (GameLogic.showDailyChase(state)) return true;
    return bossStairs && GameLogic.firstBossPending(state);
  }

  static GameState markSeen(GameState state) {
    if (state.metaDepth.awayFightTipSeen) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(awayFightTipSeen: true),
    );
  }
}
