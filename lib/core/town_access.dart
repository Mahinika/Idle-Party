import '../models/town_building.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'menu_alerts.dart';

/// Who may enter each town building, using existing unlocks only.
///
/// No new save fields. Locked taps never open a different sheet.
abstract final class TownAccess {
  static bool forgeOpen(GameState s) => MenuTabs.showCraft(s);

  static bool marketOpen(GameState s) => MenuTabs.showGold(s);

  static bool innOpen(GameState s) => MenuTabs.showRoster(s);

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

  static String lockedCopy(TownBuildingId id, GameState s) => switch (id) {
        TownBuildingId.forge => 'CRAFT opens after the first boss.',
        TownBuildingId.market => 'MARKET opens after the first boss.',
        TownBuildingId.inn =>
          'Party swaps unlock at first Ascend. Until then the starter three rest here.',
        TownBuildingId.guild => 'QUESTS open after the first floor.',
        TownBuildingId.vault => vaultCopy(s),
      };

  static String vaultCopy(GameState s) {
    if (vaultClaimedToday(s)) return 'Vault claimed today.';
    if (vaultInSeason(s)) {
      final clears = s.metaDepth.dailyVaultClears;
      final target = GameLogic.dailyVaultClearTarget;
      return 'Daily Vault $clears/$target · keep clearing.';
    }
    return 'Daily Vault after the first boss.';
  }
}
