import '../models/town_building.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'menu_alerts.dart';
import 'return_week.dart';

/// Who may enter each town building, using existing unlocks only.
///
/// No new save fields. Locked taps never open a different sheet.
abstract final class TownAccess {
  static bool forgeOpen(GameState s) => MenuTabs.showCraft(s);

  static bool marketOpen(GameState s) => MenuTabs.showGold(s);

  /// INN on the square and the HEROES ROSTER tab share one gate.
  static bool innRosterOpen(GameState s) => s.ascensionLevel >= 1;

  static bool innOpen(GameState s) => innRosterOpen(s);

  static bool guildOpen(GameState s) => MenuTabs.showQuests(s);

  /// Vault is always on the square. Claim uses [GameLogic.canClaimDailyVault].
  static bool vaultInSeason(GameState s) => GameLogic.showDailyVault(s);

  static bool vaultClaimable(GameState s) =>
      vaultInSeason(s) && GameLogic.canClaimDailyVault(s);

  static bool vaultClaimedToday(GameState s) =>
      vaultInSeason(s) && s.metaDepth.dailyVaultClaimed;

  static bool isOpen(TownBuildingId id, GameState s) => switch (id) {
        TownBuildingId.forge => forgeOpen(s),
        TownBuildingId.market => marketOpen(s),
        TownBuildingId.inn => innOpen(s),
        TownBuildingId.guild => guildOpen(s),
        TownBuildingId.vault => vaultClaimable(s),
      };

  /// Dim the sign and art on the square before the player taps.
  static bool showLockedOnSign(TownBuildingId id, GameState s) => switch (id) {
        TownBuildingId.vault =>
          vaultInSeason(s) && !vaultClaimable(s) && !vaultClaimedToday(s),
        _ => !isOpen(id, s),
      };

  static String lockedCopy(TownBuildingId id, GameState s) => switch (id) {
        TownBuildingId.forge => 'CRAFT opens after your first boss.',
        TownBuildingId.inn => innLockedCopy(s),
        TownBuildingId.market => 'MARKET opens after the first boss.',
        TownBuildingId.guild => 'QUESTS open after the first floor.',
        TownBuildingId.vault => vaultCopy(s),
      };

  static String innLockedCopy(GameState s) {
    final n = s.heroes.length;
    final heroes = n == 1 ? '1 hero' : '$n heroes';
    return 'First Ascend unlocks party swaps and a fourth hero. '
        'Your $heroes keep the lineup until then.';
  }

  static String vaultCopy(GameState s) {
    if (vaultClaimedToday(s)) return vaultClaimedDetail(s);
    if (vaultInSeason(s)) {
      final clears = s.metaDepth.dailyVaultClears;
      final target = GameLogic.dailyVaultClearTarget;
      return 'Daily Vault $clears/$target · keep clearing.';
    }
    return 'Daily Vault after the first boss.';
  }

  /// After claim: reset countdown and tomorrow’s cave (audit vault tap).
  static String vaultClaimedDetail(GameState state) {
    final now = DateTime.now().toUtc();
    final next = DateTime.utc(now.year, now.month, now.day + 1);
    final hours = next.difference(now).inHours.clamp(0, 48);
    final reset = hours <= 1
        ? 'Resets at UTC midnight.'
        : 'Resets in ${hours}h (UTC).';
    final cave = ReturnWeek.tomorrowTitle(state);
    return 'Vault claimed today. $reset $cave';
  }
}
