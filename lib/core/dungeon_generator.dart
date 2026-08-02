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
    final isTreasure = !isBoss && floorNumber % 6 == 0;
    // Elites often after the early ramp; rare before F4.
    final eliteChance = floorNumber <= 3 ? 0.14 : 0.38;
    final eliteRoll = random.nextDouble() < eliteChance;
    final guaranteedElite =
        !isBoss && !isTreasure && floorNumber >= 6 && floorNumber % 3 == 0;
    final type = isBoss
        ? RoomType.boss
        : (isTreasure
            ? RoomType.treasure
            : ((eliteRoll || guaranteedElite)
                ? RoomType.elite
                : RoomType.normal));

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
    final earlyCut = floor <= 3 ? 1 : 0;
    return switch (type) {
      RoomType.boss => 6 + random.nextInt(2),
      RoomType.elite =>
        max(4, 6 + random.nextInt(2) + (floor ~/ 4).clamp(0, 2) - earlyCut),
      RoomType.treasure => 0,
      RoomType.normal =>
        max(3, 5 + (floor ~/ 3).clamp(0, 4) + random.nextInt(2) - earlyCut),
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
      RoomType.boss => 2.1,
      RoomType.elite => 1.55,
      RoomType.treasure => 0.9,
      RoomType.normal => 1.15,
    };
  }
}
