import '../models/dungeon_mode.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// FARM-only pack strength and loot multiplier (1× / 2× / 4× on cleared floors).
abstract final class FarmIntensity {
  static const List<int> allowed = [1, 2, 4];

  static bool applies(GameState state) {
    if (!state.inDungeon || state.dungeonMode != DungeonMode.farm) return false;
    if (state.inGauntlet ||
        state.inRift ||
        state.inGreaterRift ||
        state.keystoneRunActive ||
        state.inWorldBoss) {
      return false;
    }
    final floor = state.currentRoom.floorNumber;
    return floor > 0 && floor <= state.highestFloorCleared;
  }

  static int maxUnlocked(GameState state) {
    if (state.ascensionLevel >= 1 || state.metaDepth.lifetimeFloorClears >= 20) {
      return 4;
    }
    if (GameLogic.showDailyChase(state)) return 2;
    return 1;
  }

  static int effectiveMult(GameState state) {
    if (state.farmTryMult > 0 && allowed.contains(state.farmTryMult)) {
      return state.farmTryMult;
    }
    final picked = state.metaDepth.farmIntensity;
    final clamped = allowed.contains(picked) ? picked : 1;
    return clamped.clamp(1, maxUnlocked(state));
  }

  static double threatMult(GameState state) =>
      applies(state) ? effectiveMult(state).toDouble() : 1.0;

  static double rewardMult(GameState state) => threatMult(state);

  static bool canPick(GameState state, int mult) =>
      allowed.contains(mult) && mult <= maxUnlocked(state);

  static bool canTry(GameState state, int mult) =>
      applies(state) &&
      mult > maxUnlocked(state) &&
      allowed.contains(mult) &&
      state.metaDepth.farmTryUsesLeft > 0;

  static String hudLabel(GameState state) {
    if (!applies(state)) return '';
    final m = effectiveMult(state);
    return 'FARM ${m}× packs · ${m}× loot';
  }
}
