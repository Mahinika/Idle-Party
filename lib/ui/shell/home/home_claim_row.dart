import '../../../core/first_climb_coach.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/return_week.dart';

/// The daily vault CLAIM on the home fight.
///
/// CLAIM sits in the top resource row, next to gold. When the vault is the
/// chase, that chip says it all, so the top bar drops its chase line and no
/// coach row ("Claim CAMP") is mounted under it.
abstract final class HomeClaimRow {
  /// CLAIM chip in the top row: in the cave with the vault ready.
  static bool showChip(GameState state) =>
      state.inDungeon && GameLogic.canClaimDailyVault(state);

  /// "Daily Vault · CAMP" for the chip's tooltip and semantics.
  static String chipHint(GameState state) {
    if (!ReturnWeek.active(state)) return 'Daily Vault';
    final shelf = ReturnWeek.shelf(GameLogic.checkInPayout(state));
    return 'Daily Vault · $shelf';
  }

  /// "Claim Daily Vault · CAMP" when the chip owns the vault chase, else
  /// null. The first climb keeps its own line under the bar.
  static String? vaultLine(GameState state) {
    if (!showChip(state)) return null;
    if (FirstClimbCoach.line(state, inDungeon: true) != null) return null;
    final chase = HubChase.forState(state);
    if (chase.kind != HubChaseKind.claimDailyVault) return null;
    if (!ReturnWeek.active(state)) return chase.title;
    final shelf = ReturnWeek.shelf(GameLogic.checkInPayout(state));
    return '${chase.title} · $shelf';
  }
}
