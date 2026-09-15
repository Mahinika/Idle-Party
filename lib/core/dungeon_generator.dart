import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/dungeon_room.dart';

class DungeonGenerator {
  /// Boss floor: early floors then a boss every few floors; scales with ascension.
  static int bossFloorFor(int ascensionLevel) =>
      DungeonCatalog.bossFloor(ascensionLevel);

  /// Build the single combat encounter that represents [floorNumber].
  /// When [bossEvery] is set (e.g. 5 for Infinity Gauntlet), bosses land on
  /// every Nth floor instead of the single AL-scaled boss floor.
  static DungeonRoom generateFloorRoom({
    required int floorNumber,
    required int ascensionLevel,
    required String dungeonId,
    int layoutSeed = 0,
    int? bossEvery,
    int keyLevel = 0,
  }) {
    final random = Random(floorNumber * 7919 + dungeonId.hashCode + layoutSeed);
    final bossFloor = bossFloorFor(ascensionLevel);
    final isBoss = bossEvery != null && bossEvery > 0
        ? floorNumber > 0 && floorNumber % bossEvery == 0
        : floorNumber == bossFloor;
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
    final enemyCount = _enemyCountForType(
      type,
      random,
      floorNumber,
      ascensionLevel: ascensionLevel,
      keyLevel: keyLevel,
    );

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
    int? bossEvery,
    int keyLevel = 0,
  }) {
    return <DungeonRoom>[
      generateFloorRoom(
        floorNumber: floorNumber,
        ascensionLevel: ascensionLevel,
        dungeonId: dungeonId,
        layoutSeed: layoutSeed,
        bossEvery: bossEvery,
        keyLevel: keyLevel,
      ),
    ];
  }

  /// Extra pack / map size from AL and KEY (capped so endless keys stay sane).
  static int layoutPressure({int ascensionLevel = 0, int keyLevel = 0}) {
    final al = ascensionLevel.clamp(0, 20);
    final key = keyLevel.clamp(0, 20);
    return al ~/ 4 + key ~/ 4;
  }

  static int _enemyCountForType(
    RoomType type,
    Random random,
    int floor, {
    int ascensionLevel = 0,
    int keyLevel = 0,
  }) {
    final p = layoutPressure(
      ascensionLevel: ascensionLevel,
      keyLevel: keyLevel,
    );
    return switch (type) {
      RoomType.boss => (6 + random.nextInt(2) + p).clamp(6, 14),
      RoomType.elite => max(
        5,
        6 + random.nextInt(2) + (floor ~/ 4).clamp(0, 3) + p,
      ).clamp(5, 16),
      RoomType.treasure => 0,
      RoomType.normal => max(
        5,
        6 + (floor ~/ 3).clamp(0, 5) + random.nextInt(2) + p,
      ).clamp(5, 16),
    };
  }

  static String zoneNameForFloor(
    int floorNumber, {
    String dungeonId = 'sandy',
  }) {
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
