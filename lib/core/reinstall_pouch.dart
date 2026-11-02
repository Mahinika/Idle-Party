import 'game_state.dart';

/// One rewarded gold pile after a fresh install with no local save.
abstract final class ReinstallPouch {
  static bool showOffer(GameState state) {
    final md = state.metaDepth;
    return md.reinstallPouchDue && !md.reinstallPouchClaimed;
  }

  static int goldAmount(GameState state) {
    final zone = (state.highestDungeonCleared + 1).clamp(1, 99);
    return 2500 * zone;
  }

  static GameState markDue(GameState state) {
    if (state.metaDepth.reinstallPouchClaimed) return state;
    if (state.metaDepth.reinstallPouchDue) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(reinstallPouchDue: true),
    );
  }

  static GameState grant(GameState state) {
    if (!showOffer(state)) return state;
    final gold = goldAmount(state);
    return state.copyWith(
      gold: state.gold + gold,
      lifetimeGoldEarned: state.lifetimeGoldEarned + gold,
      metaDepth: state.metaDepth.copyWith(
        reinstallPouchDue: false,
        reinstallPouchClaimed: true,
      ),
    );
  }
}
