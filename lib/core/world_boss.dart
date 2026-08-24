import 'game_logic.dart';
import 'game_state.dart';

/// Solo endgame world boss — tickets / UTC week; practice is free.
abstract final class WorldBoss {
  static const String id = 'world_boss';
  static const String name = 'Ashen Crown';
  static const String blurb =
      'Weekly solo boss. Ticket clears pay essence; practice is free.';
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
    return state.copyWith(
      essence: state.essence + essenceReward,
      metaDepth: state.metaDepth.copyWith(
        worldBossClearedWeek: true,
        titles: titles,
      ),
    );
  }
}
