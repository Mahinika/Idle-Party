import 'game_logic.dart';
import 'game_state.dart';
import 'hub_chase.dart';

/// Honest Play rating ask — no loot, no tickets, no forced stars.
///
/// Play forbids rewarding reviews. This only decides *when* to show Google's
/// in-app review sheet (or SETTINGS opening the listing). Quota is Play's.
abstract final class PlayReviewAsk {
  static const String title = 'Enjoying Idle Party?';
  static const String body =
      'If the party is treating you well, a Play rating helps other players '
      'find the cave. No reward — just a thank you.';

  /// After first boss or first Ascend, hub only, once.
  /// Never covers a READY claim (vault / bag / quests).
  static bool shouldOffer(GameState state) {
    if (state.inDungeon) return false;
    if (state.metaDepth.reviewPrompted) return false;
    if (!GameLogic.showDailyChase(state)) return false;
    if (HubChase.forState(state).urgency == HubChaseUrgency.ready) {
      return false;
    }
    return true;
  }

  static GameState markPrompted(GameState state) {
    if (state.metaDepth.reviewPrompted) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(reviewPrompted: true),
    );
  }
}
