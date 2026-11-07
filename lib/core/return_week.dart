import '../models/dungeon_def.dart';
import 'check_in.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// One named job for check-in days 1–7, before the first Ascend.
///
/// The day is [MetaDepthState.checkInDay]. It advances only when the Daily
/// Vault is claimed, so a missed UTC day does not reset it and this is not
/// a second calendar.
abstract final class ReturnWeek {
  static const String keepsFighting = 'Your party keeps fighting while closed.';

  /// After the first boss, until the first Ascend. Endgame keeps its ladder.
  static bool active(GameState state) =>
      state.ascensionLevel == 0 &&
      state.bossVictories > 0 &&
      !GameLogic.endgameUnlocked(state) &&
      GameLogic.checkInActive(state);

  static String caveName(GameState state) =>
      DungeonCatalog.byId(GameLogic.recommendedDungeonId(state)).name;

  /// Short shelf on the hunt title. One token per check-in day.
  static String shelf(CheckInPayout pay) => switch (pay.day) {
    1 => 'CAMP',
    2 => 'FORGE',
    3 => 'EMBERS',
    4 => 'CINDERS',
    5 => 'SCROLLS',
    6 => 'CAMP+FORGE',
    _ => 'JACKPOT',
  };

  static String spendSentence(CheckInPayout pay) => switch (pay.day) {
    1 => 'Spend the essence in CAMP.',
    2 => 'Spend the gold in FORGE.',
    3 => 'Spend the Embers on RELICS.',
    4 => 'Keep the Cinders for RELICS.',
    5 => 'Spend the tickets on SCROLLS.',
    6 => 'Spend the essence in CAMP and the gold in FORGE.',
    _ => 'Spend the jackpot in CAMP, FORGE, and SCROLLS.',
  };

  static String todayTitle(GameState state) {
    final pay = GameLogic.checkInPayout(state);
    return '${caveName(state)} · ${shelf(pay)}';
  }

  static String tomorrowTitle(GameState state) =>
      'Tomorrow: ${caveName(state)}';

  /// Wallet can already buy a click on a shelf that exists today.
  static String? readySpend(GameState state) {
    final forge = GameLogic.canForgeGoldSpendEven(state);
    final camp =
        state.essence > 0 &&
        state.essence >= GameLogic.cheapestSanctuaryNextCost(state);
    final scrolls = state.metaDepth.adTickets > 0;
    final bits = <String>[
      if (forge) 'FORGE',
      if (camp) 'CAMP',
      if (scrolls) 'SCROLLS',
    ];
    if (bits.isEmpty) return null;
    if (bits.length == 1) {
      return '${bits.single} is ready for what you earned.';
    }
    if (bits.length == 2) {
      return '${bits[0]} and ${bits[1]} are ready for what you earned.';
    }
    return 'FORGE, CAMP, and SCROLLS are ready for what you earned.';
  }

  static String todayDetail(GameState state) {
    final pay = GameLogic.checkInPayout(state);
    return _withReady(
      state,
      '${pay.name} · ${pay.prize}. '
      'One cave, ${caveName(state)}, fills the vault. '
      '${spendSentence(pay)} $keepsFighting',
    );
  }

  static String tomorrowDetail(GameState state) {
    final pay = GameLogic.checkInPayout(state);
    return _withReady(
      state,
      'Tomorrow · ${pay.name} pays ${pay.hookPrize}. '
      '${spendSentence(pay)} $keepsFighting',
    );
  }

  /// Home row under the hunt title. One job, including while the app was closed.
  static String coachLine(GameState state) {
    final pay = GameLogic.checkInPayout(state);
    final cave = caveName(state);
    if (state.metaDepth.dailyVaultClaimed) {
      return _withReady(
        state,
        'Tomorrow: $cave. ${spendSentence(pay)} $keepsFighting',
      );
    }
    if (GameLogic.canClaimDailyVault(state)) {
      return _withReady(
        state,
        'Claim ${pay.name}. ${spendSentence(pay)} $keepsFighting',
      );
    }
    return _withReady(
      state,
      '$cave today. ${spendSentence(pay)} $keepsFighting',
    );
  }

  /// Welcome Back and the check-in guide. Same prizes, plus the cave.
  static String welcomeLine(GameState state) {
    final pay = GameLogic.checkInPayout(state);
    final cave = caveName(state);
    if (state.metaDepth.dailyVaultClaimed) {
      return 'Tomorrow: $cave · ${pay.name} · ${pay.prize}. ${spendSentence(pay)}';
    }
    if (GameLogic.canClaimDailyVault(state)) {
      return '${pay.waitingLine} ${spendSentence(pay)}';
    }
    return 'One cave, $cave, fills the vault. Then ${pay.name}: ${pay.prize}. '
        '${spendSentence(pay)}';
  }

  static String _withReady(GameState state, String body) {
    final ready = readySpend(state);
    if (ready == null) return body;
    return '$body $ready';
  }
}
