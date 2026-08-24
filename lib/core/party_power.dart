import 'game_state.dart';
import 'game_logic.dart';

/// Single party power number for hub/META display (no Play board yet).
abstract final class PartyPower {
  /// Weighted sheet + meta score — display only.
  static int score(GameState state) {
    if (state.heroes.isEmpty) return 0;
    var gear = 0;
    var levels = 0;
    for (final h in state.heroes) {
      levels += h.level;
      for (final item in h.equipped.values) {
        gear += item.powerScore;
      }
    }
    final meanLv = levels ~/ state.heroes.length;
    final al = state.ascensionLevel;
    final bless = state.metaDepth.ascendBlessings;
    var apex = 0;
    for (final a in state.apexVault) {
      apex += a.apexRank * 40;
    }
    for (final h in state.heroes) {
      for (final item in h.equipped.values) {
        if (item.isApex) apex += item.apexRank * 25;
      }
    }
    final rosterBonus = state.metaDepth.rosterExhibition ? 80 : 0;
    return meanLv * 12 +
        gear ~/ 8 +
        al * 15 +
        bless * 10 +
        apex +
        rosterBonus +
        (GameLogic.endgameUnlocked(state) ? 100 : 0);
  }
}
