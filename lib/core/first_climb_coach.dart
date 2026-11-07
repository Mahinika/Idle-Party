import 'game_logic.dart';
import 'game_state.dart';

/// One line for the first Sandy climb. No new save field: it reads the
/// floor, the vault, and whether the first boss is still ahead.
///
/// The home fight and the classic cave share this copy. After that boss
/// the existing coach lines take over.
abstract final class FirstClimbCoach {
  static bool active(GameState state) =>
      GameLogic.firstBossPending(state) &&
      !state.inGauntlet &&
      !state.inAnyRiftMode &&
      !state.inWorldBoss;

  static String get _bossBit => 'floor ${GameLogic.firstBossFloor}';

  /// Null on the porch before the first ENTER (that button already says
  /// so) and null once the first boss is dead.
  static String? line(GameState state, {required bool inDungeon}) {
    if (!active(state)) return null;
    final claim = GameLogic.canClaimDailyVault(state);
    if (!inDungeon) {
      if (claim) return 'Tap CLAIM VAULT. The boss is on $_bossBit.';
      if (state.highestFloorCleared >= 1) {
        return 'The boss is on $_bossBit. Tap ENTER.';
      }
      return null;
    }
    if (claim) return 'Tap CLAIM. The boss is on $_bossBit.';
    final floor = state.currentRoom.floorNumber;
    if (floor >= GameLogic.firstBossFloor) {
      return 'This is the boss. Your party fights on its own.';
    }
    if (state.highestFloorCleared < 1) {
      return 'Your party fights on its own. Boss on $_bossBit.';
    }
    return 'Floor ${state.highestFloorCleared} paid out. Boss on $_bossBit.';
  }

  /// Wipe card, while the first boss is still ahead.
  static String? wipeLine(GameState state) {
    if (!active(state)) return null;
    if (GameLogic.canClaimDailyVault(state)) {
      return 'The vault is ready to claim. The boss is still on $_bossBit.';
    }
    return 'The boss is still on $_bossBit.';
  }
}
