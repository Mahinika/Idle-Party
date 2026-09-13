import '../models/dungeon_def.dart';
import 'blessing_constellation.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// One ISO-week Crown venue — existing zone, not dungeon #16.
class AshenWeekKit {
  const AshenWeekKit({
    required this.dungeonId,
    required this.telegraph,
  });

  final String dungeonId;
  final String telegraph;

  String get venueName => DungeonCatalog.byId(dungeonId).name;

  String get title => '$venueName Crown';

  String get weekLine =>
      'This week: $title. Telegraph $telegraph, then SLAM / IGNITE.';
}

/// Weekly ticket solo boss **Ashen Crown**.
///
/// The hunt stays on KEY + hub ENDGAME. Each ISO week the Crown visits a
/// different shipped cave (same tickets / PRACTICE). Save/meta fields still
/// use `worldBoss*` JSON keys for older exports.
abstract final class AshenCrown {
  static const String id = 'ashen_crown';
  static const String name = 'Ashen Crown';
  static const String blurb =
      'Weekly solo boss. Each week a different cave. Clear pays essence; '
      'wipe/leave returns the ticket; practice is free.';
  static const int ticketsPerWeek = 3;

  /// ENDGAME map pin — hunt home. The fight uses [kitFor] that week.
  static const String dungeonId = 'ember';
  static const int essenceReward = 35;
  static const String titleReward = 'Crown Breaker';

  /// One kit per shipped zone — rotating Crown, not a 16th dungeon.
  static const List<AshenWeekKit> weekKits = <AshenWeekKit>[
    AshenWeekKit(dungeonId: 'ember', telegraph: 'CROWN'),
    AshenWeekKit(dungeonId: 'tide', telegraph: 'WAVE'),
    AshenWeekKit(dungeonId: 'brass', telegraph: 'WIND-UP'),
    AshenWeekKit(dungeonId: 'goblin', telegraph: 'RALLY'),
    AshenWeekKit(dungeonId: 'king', telegraph: 'DECREE'),
    AshenWeekKit(dungeonId: 'underworld', telegraph: 'BEAM'),
    AshenWeekKit(dungeonId: 'dead', telegraph: 'FADE'),
    AshenWeekKit(dungeonId: 'hell', telegraph: 'TENTACLE'),
    AshenWeekKit(dungeonId: 'crystal', telegraph: 'SHARD'),
    AshenWeekKit(dungeonId: 'grove', telegraph: 'ROOT'),
    AshenWeekKit(dungeonId: 'storm', telegraph: 'BOLT'),
    AshenWeekKit(dungeonId: 'rime', telegraph: 'FROST'),
    AshenWeekKit(dungeonId: 'fen', telegraph: 'SPIT'),
    AshenWeekKit(dungeonId: 'veil', telegraph: 'SILK'),
    AshenWeekKit(dungeonId: 'sandy', telegraph: 'BURY'),
  ];

  static AshenWeekKit kitFor({DateTime? now, String? weekKey}) {
    final key =
        weekKey ?? GameLogic.isoWeekKey((now ?? DateTime.now()).toUtc());
    return weekKits[_weekIndex(key)];
  }

  static AshenWeekKit kitByDungeonId(String dungeonId) {
    for (final kit in weekKits) {
      if (kit.dungeonId == dungeonId) return kit;
    }
    return weekKits.first;
  }

  static int _weekIndex(String weekKey) {
    var h = 0;
    for (final c in weekKey.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h % weekKits.length;
  }

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
    return GameLogic.applyMissionProgress(
      BlessingConstellation.grantPoints(
        rewarded,
        BlessingConstellation.ashenCrownPointReward,
      ),
      ashenClears: 1,
    );
  }

  /// Ticket runs only before the weekly essence clear.
  static bool ticketRunAllowed(GameState state) {
    final next = ensureWeek(state);
    return next.metaDepth.worldBossTickets > 0 &&
        !next.metaDepth.worldBossClearedWeek;
  }
}
