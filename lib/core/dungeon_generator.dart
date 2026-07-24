import 'dart:math';

import '../models/dungeon_room.dart';

class DungeonGenerator {
  static const _roomsPerFloor = 10;
  static const _eliteRoomChance = 0.2; // 20% elite rooms

  /// Generate a full floor (10 rooms) - deterministic based on floor number
  static List<DungeonRoom> generateFloor(int floorNumber) {
    final rooms = <DungeonRoom>[];
    final baseLevelForFloor = (floorNumber - 1) * 3 + 1;
    // Seed random with floor number for consistency
    final random = Random(
      floorNumber * 7919,
    ); // Use prime for seed distribution

    for (int i = 0; i < _roomsPerFloor; i++) {
      final type = _determineRoomType(i, random);
      final enemyLevel = baseLevelForFloor + random.nextInt(4);
      final enemyCount = _enemyCountForType(type, random);

      rooms.add(
        DungeonRoom(
          floorNumber: floorNumber,
          roomIndex: i,
          type: type,
          enemyLevel: enemyLevel,
          isCleared: false,
          enemyCount: enemyCount,
        ),
      );
    }

    return rooms;
  }

  /// Group size per room type (deterministic via the floor-seeded random).
  static int _enemyCountForType(RoomType type, Random random) {
    return switch (type) {
      RoomType.boss => 3, // 1 boss + 2 guards
      RoomType.elite => 2 + random.nextInt(2), // 2-3
      RoomType.treasure => 0, // combat-free chest room
      RoomType.normal => 1 + (random.nextDouble() < 0.45 ? 1 : 0), // 1-2
    };
  }

  /// Thematic zone name per floor range (Idle Sword 2 homage).
  static String zoneNameForFloor(int floorNumber) {
    if (floorNumber <= 3) return 'Sandy Caverns';
    if (floorNumber <= 6) return "Goblin's Hideout";
    if (floorNumber <= 9) return "King's Fort";
    if (floorNumber <= 12) return 'Underworld';
    if (floorNumber <= 15) return 'City of Dead';
    return "Hell's Door";
  }

  /// Determine room type based on position in floor
  static RoomType _determineRoomType(int roomIndex, Random random) {
    // Boss room is always last (room 10)
    if (roomIndex == _roomsPerFloor - 1) return RoomType.boss;

    // Treasure rooms at indices 4, 9 (every 5 rooms)
    if (roomIndex % 5 == 4) return RoomType.treasure;

    // Random elite rooms (deterministic based on seeded random)
    if (random.nextDouble() < _eliteRoomChance) return RoomType.elite;

    return RoomType.normal;
  }

  /// Get visual representation of room layout for mini-map
  static String getRoomVisualType(RoomType type) {
    return switch (type) {
      RoomType.boss => '👑',
      RoomType.elite => '⚔️',
      RoomType.treasure => '💎',
      RoomType.normal => '🗡️',
    };
  }

  /// Difficulty multiplier for room type
  static double getDifficultyMultiplier(RoomType type) {
    return switch (type) {
      RoomType.boss => 1.8,
      RoomType.elite => 1.4,
      RoomType.treasure => 0.9,
      RoomType.normal => 1.0,
    };
  }
}
