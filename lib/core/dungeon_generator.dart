import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/dungeon_room.dart';

class DungeonGenerator {
  /// Boss floor: early floors then a boss every few floors; scales with ascension.
  static int bossFloorFor(int ascensionLevel) =>
      DungeonCatalog.bossFloor(ascensionLevel);

  /// Build the single combat encounter that represents [floorNumber].
  static DungeonRoom generateFloorRoom({
    required int floorNumber,
    required int ascensionLevel,
    required String dungeonId,
    int layoutSeed = 0,
  }) {
    final random = Random(
      floorNumber * 7919 + dungeonId.hashCode + layoutSeed,
    );
    final bossFloor = bossFloorFor(ascensionLevel);
    final isBoss = floorNumber == bossFloor;
    final isTreasure = !isBoss && floorNumber % 4 == 0;
    final type = isBoss
        ? RoomType.boss
        : (isTreasure
            ? RoomType.treasure
            : (random.nextDouble() < 0.22 ? RoomType.elite : RoomType.normal));

    final baseLevel = (floorNumber - 1) * 2 + 1;
    final enemyLevel = baseLevel + random.nextInt(3);
    final enemyCount = _enemyCountForType(type, random, floorNumber);

    return DungeonRoom(
      floorNumber: floorNumber,
      roomIndex: 0,
      type: type,
      enemyLevel: enemyLevel,
      enemyCount: enemyCount,
    );
  }

  /// Compatibility: returns a 1-element floor list (the current wave).
  static List<DungeonRoom> generateFloor(
    int floorNumber, {
    int ascensionLevel = 0,
    String dungeonId = 'sandy',
    int layoutSeed = 0,
  }) {
    return <DungeonRoom>[
      generateFloorRoom(
        floorNumber: floorNumber,
        ascensionLevel: ascensionLevel,
        dungeonId: dungeonId,
        layoutSeed: layoutSeed,
      ),
    ];
  }

  static int _enemyCountForType(RoomType type, Random random, int floor) {
    return switch (type) {
      RoomType.boss => 5 + random.nextInt(2),
      RoomType.elite => 5 + random.nextInt(3),
      RoomType.treasure => 0,
      RoomType.normal => 4 + (floor ~/ 2).clamp(0, 5) + random.nextInt(3),
    };
  }

  static String zoneNameForFloor(int floorNumber, {String dungeonId = 'sandy'}) {
    return DungeonCatalog.byId(dungeonId).name;
  }

  static String getRoomVisualType(RoomType type) {
    return switch (type) {
      RoomType.boss => 'B',
      RoomType.elite => 'E',
      RoomType.treasure => 'T',
      RoomType.normal => 'N',
    };
  }

  static double getDifficultyMultiplier(RoomType type) {
    return switch (type) {
      RoomType.boss => 1.8,
      RoomType.elite => 1.4,
      RoomType.treasure => 0.9,
      RoomType.normal => 1.0,
    };
  }
}
