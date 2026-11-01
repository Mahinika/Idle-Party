import 'game_logic.dart';
import 'game_state.dart';
import 'hub_chase.dart';

/// Honest Play rating ask — no loot, no tickets, no forced stars.
///
/// Play forbids rewarding reviews. This only decides *when* to show Google's
/// in-app review sheet (or SETTINGS opening the listing). Play also quotas
/// the sheet. The card itself waits for a later sitting and a good moment.
abstract final class PlayReviewAsk {
  static const String title = 'Enjoying Idle Party?';
  static const String body =
      'If the party is treating you well, a Play rating helps other players '
      'find the cave. No reward — just a thank you.';

  /// Dismissals before the card stops for good.
  static const int maxAsks = 3;

  /// NOT NOW waits this long. A boss the same minute does not ask again.
  static const Duration snoozeFor = Duration(days: 7);

  /// Later sitting, hub only, after a boss this sitting or a big Welcome Back.
  /// Never on the first sitting. Never covers a READY claim.
  static bool shouldOffer(
    GameState state, {
    OfflineProgressResult? welcome,
    bool bossThisSession = false,
    DateTime? now,
  }) {
    if (state.inDungeon) return false;
    if (state.metaDepth.reviewPrompted) return false;
    if (state.metaDepth.sessionCount < 2) return false;
    if (state.metaDepth.reviewAskCount >= maxAsks) return false;
    if (!GameLogic.showDailyChase(state)) return false;
    if (HubChase.forState(state).urgency == HubChaseUrgency.ready) {
      return false;
    }
    final clock = (now ?? DateTime.now()).toUtc();
    if (state.metaDepth.reviewSnoozeUntilMs > clock.millisecondsSinceEpoch) {
      return false;
    }
    return bossThisSession || isBigWelcome(welcome);
  }

  /// A return worth asking after: a boss, a cave that kept fighting,
  /// or a hub chest that filled.
  static bool isBigWelcome(OfflineProgressResult? welcome) {
    if (welcome == null) return false;
    if (welcome.bossDelta > 0) return true;
    if (welcome.foughtWhileAway) return true;
    if (welcome.wasInDungeon &&
        (welcome.roomsCleared > 0 || welcome.secondsApplied >= 15 * 60)) {
      return true;
    }
    return welcome.hubChestStopped && welcome.goldGained > 0;
  }

  /// They opened the Play sheet, or the ask budget is used up.
  static GameState markPrompted(GameState state) {
    if (state.metaDepth.reviewPrompted) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(reviewPrompted: true),
    );
  }

  /// NOT NOW. A second call in the same minute does not burn another ask.
  static GameState snooze(GameState state, {DateTime? now}) {
    if (state.metaDepth.reviewPrompted) return state;
    final clock = (now ?? DateTime.now()).toUtc();
    final until = clock.millisecondsSinceEpoch + snoozeFor.inMilliseconds;
    final already =
        state.metaDepth.reviewSnoozeUntilMs >
        clock.millisecondsSinceEpoch + snoozeFor.inMilliseconds - 60000;
    if (already) return state;
    final count = state.metaDepth.reviewAskCount + 1;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        reviewAskCount: count,
        reviewSnoozeUntilMs: until,
        reviewPrompted: count >= maxAsks,
      ),
    );
  }
}
