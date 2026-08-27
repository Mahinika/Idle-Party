import 'blessing_constellation.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// Weekly ticket solo boss **Ashen Crown** (ember zone art).
///
/// Save/meta fields still use `worldBoss*` JSON keys for older exports.
abstract final class AshenCrown {
  static const String id = 'ashen_crown';
  static const String name = 'Ashen Crown';
  static const String blurb =
      'Weekly solo boss. Clear pays essence; wipe/leave returns the ticket; practice is free.';
  static const int ticketsPerWeek = 3;
  static const String dungeonId = 'ember';
  static const int essenceReward = 35;
  static const String titleReward = 'Crown Breaker';

  static bool canEnter(GameState state) =>
      GameLogic.endgameUnlocked(state) && !state.inDungeon;

  static GameState ensureWeek(GameState state, {DateTime? now}) {
    final week = GameLogic.isoWeekKey((now ?? DateTime.now()).toUtc());
    final md = state.metaDepth;
    if (md.worldBossWeekKey == week) return state;
    return state.copyWith(
      metaDepth: md.copyWith(
        worldBossWeekKey: week,
        worldBossTickets: ticketsPerWeek,
        worldBossClearedWeek: false,
      ),
    );
  }

  static GameState onBossClear(GameState state) {
    if (!state.inWorldBoss || state.worldBossPractice) return state;
    if (state.metaDepth.worldBossClearedWeek) return state;
    final titles = List<String>.from(state.metaDepth.titles);
    if (!titles.contains(titleReward)) {
      titles.add(titleReward);
    }
    final rewarded = state.copyWith(
      essence: state.essence + essenceReward,
      metaDepth: state.metaDepth.copyWith(
        worldBossClearedWeek: true,
        titles: titles,
      ),
    );
    return BlessingConstellation.grantPoints(
      rewarded,
      BlessingConstellation.ashenCrownPointReward,
    );
  }

  /// Ticket runs only before the weekly essence clear.
  static bool ticketRunAllowed(GameState state) {
    final next = ensureWeek(state);
    return next.metaDepth.worldBossTickets > 0 &&
        !next.metaDepth.worldBossClearedWeek;
  }
}
