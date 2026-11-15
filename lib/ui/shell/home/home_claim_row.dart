import '../../../core/first_climb_coach.dart';
import '../../../core/game_logic.dart';
import '../../../core/game_state.dart';
import '../../../core/hub_chase.dart';
import '../../../core/menu_router.dart';
import '../../../core/return_week.dart';

/// The one home row that owns a ready daily vault in the cave.
///
/// The top bar and the coach row used to say the same thing twice
/// ("Claim Daily Vault" and "Claim CAMP"). When this returns text, the
/// coach row paints it next to CLAIM and the top bar drops its chase line.
abstract final class HomeClaimRow {
  /// Same rule as the home shell: a sheet over the fight hides the row.
  static bool sheetOpen(GameState state, MenuRoute route) {
    final interceptGold = state.inDungeon && route == MenuRoute.gold;
    return route != MenuRoute.none && !interceptGold;
  }

  /// "Claim Daily Vault · CAMP", or null when the vault row is not up.
  /// The first climb keeps its own line.
  static String? vaultLine(GameState state, {required bool sheet}) {
    if (sheet || !state.inDungeon) return null;
    if (!GameLogic.canClaimDailyVault(state)) return null;
    if (FirstClimbCoach.line(state, inDungeon: true) != null) return null;
    final chase = HubChase.forState(state);
    if (chase.kind != HubChaseKind.claimDailyVault) return null;
    if (!ReturnWeek.active(state)) return chase.title;
    final shelf = ReturnWeek.shelf(GameLogic.checkInPayout(state));
    return '${chase.title} · $shelf';
  }
}
