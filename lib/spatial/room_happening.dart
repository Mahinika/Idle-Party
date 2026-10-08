import '../core/game_state.dart';
import '../core/loot_pipeline.dart';
import '../models/dungeon_room.dart';

/// One thing in the first room. The party walks onto it. Same fight after.
enum RoomHappeningKind { chest, trap, altar }

/// Which moment this floor gets, and the save key so a resume does not pay twice.
abstract final class RoomHappening {
  /// How close a hero must stand (tiles) before it fires.
  static const double reach = 1.6;

  /// Boss floors stay a fight. Other floors cycle chest, trap, altar.
  static RoomHappeningKind? forRoom(DungeonRoom room) {
    if (room.type == RoomType.boss) return null;
    final n = room.floorNumber < 1 ? 1 : room.floorNumber;
    return RoomHappeningKind.values[(n - 1) % RoomHappeningKind.values.length];
  }

  /// Zone, mode, and battle. A new floor or a new cave can happen again.
  static String claimKey(GameState state) {
    final mode = state.inWorldBoss
        ? 'w'
        : state.inGauntlet
        ? 'g'
        : state.inGreaterRift
        ? 'gr'
        : state.inRift
        ? 'r'
        : 'p';
    return '${state.dungeonId}:$mode:${state.battleNumber}';
  }

  static bool alreadyClaimed(GameState state) {
    final key = claimKey(state);
    return key.isNotEmpty && state.roomHappeningClaim == key;
  }

  /// A snack, smaller than the room chest on the same floor.
  static int chestGold(GameState state) {
    final budget = LootPipeline.treasureGoldBudget(state);
    final snack = budget ~/ 15;
    return snack < 4 ? 4 : snack;
  }
}
