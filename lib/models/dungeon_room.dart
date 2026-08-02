enum RoomType { normal, elite, boss, treasure }

/// One combat floor / wave. Not a list of 10 abstract rooms.
class DungeonRoom {
  final int floorNumber;
  final int roomIndex; // always 0 for floor-based model (kept for save compat)
  final RoomType type;
  final int enemyLevel;
  final bool isCleared;
  final int enemyCount;

  const DungeonRoom({
    required this.floorNumber,
    required this.roomIndex,
    required this.type,
    required this.enemyLevel,
    this.isCleared = false,
    this.enemyCount = 1,
  });

  String get displayName => type == RoomType.boss
      ? 'Floor $floorNumber — Boss'
      : 'Floor $floorNumber';

  /// Scaling index for loot/enemy budget (floor-based).
  int get globalBattleNumber => floorNumber;

  DungeonRoom copyWith({
    int? floorNumber,
    int? roomIndex,
    RoomType? type,
    int? enemyLevel,
    bool? isCleared,
    int? enemyCount,
  }) {
    return DungeonRoom(
      floorNumber: floorNumber ?? this.floorNumber,
      roomIndex: roomIndex ?? this.roomIndex,
      type: type ?? this.type,
      enemyLevel: enemyLevel ?? this.enemyLevel,
      isCleared: isCleared ?? this.isCleared,
      enemyCount: enemyCount ?? this.enemyCount,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'floorNumber': floorNumber,
        'roomIndex': roomIndex,
        'type': type.toString(),
        'enemyLevel': enemyLevel,
        'isCleared': isCleared,
        'enemyCount': enemyCount,
      };

  factory DungeonRoom.fromJson(Map<String, dynamic> json) {
    return DungeonRoom(
      floorNumber: json['floorNumber'] as int,
      roomIndex: (json['roomIndex'] as int?) ?? 0,
      type: RoomType.values.byName((json['type'] as String).split('.').last),
      enemyLevel: json['enemyLevel'] as int,
      isCleared: (json['isCleared'] as bool?) ?? false,
      enemyCount: (json['enemyCount'] as int?) ?? 1,
    );
  }
}
