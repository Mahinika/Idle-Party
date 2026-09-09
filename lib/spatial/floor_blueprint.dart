import 'dart:math';

import '../models/dungeon_room.dart';
import 'zone_layout_kit.dart';

/// One story beat on a floor (plan: docs/FLOOR_BLUEPRINT.md).
enum FloorBeatKind { approach, choke, elite, treasure, boss, exitHold }

class FloorBeat {
  const FloorBeat(this.kind, {this.enemyBudget = 0});

  final FloorBeatKind kind;
  final int enemyBudget;
}

/// Deterministic floor story derived from room + seed (not serialized).
class FloorBlueprint {
  const FloorBlueprint({
    required this.legacyType,
    required this.beats,
    required this.dungeonId,
  });

  final RoomType legacyType;
  final List<FloorBeat> beats;
  final String dungeonId;

  bool get wantsRoomChest =>
      beats.any((b) => b.kind == FloorBeatKind.treasure) ||
      (legacyType == RoomType.elite &&
          beats.any((b) => b.kind == FloorBeatKind.elite)) ||
      legacyType == RoomType.treasure;

  /// Beats that become carved chambers (exit sits on the last one).
  List<FloorBeat> get storyChambers => [
        for (final b in beats)
          if (b.kind != FloorBeatKind.exitHold) b,
      ];

  /// Sum of per-beat enemy budgets (should match [DungeonRoom.enemyCount]).
  int get combatEnemyBudget =>
      beats.fold<int>(0, (sum, b) => sum + b.enemyBudget);

  /// Preferred chamber index for room-chest sockets (treasure → elite → last).
  int? get preferredChestChamberIndex {
    final story = storyChambers;
    if (story.isEmpty) return null;
    final treasure = story.indexWhere((b) => b.kind == FloorBeatKind.treasure);
    if (treasure >= 0) return treasure;
    final elite = story.indexWhere((b) => b.kind == FloorBeatKind.elite);
    if (elite >= 0) return elite;
    return story.length - 1;
  }

  /// Seeded blueprint for a combat floor.
  static FloorBlueprint forRoom(
    DungeonRoom room, {
    required String dungeonId,
    int layoutSeed = 0,
  }) {
    final kit = ZoneLayoutKit.forId(dungeonId);
    final rng = Random(
      room.floorNumber * 7919 +
          dungeonId.hashCode +
          layoutSeed +
          room.type.index * 131 +
          17,
    );
    final budget = max(0, room.enemyCount);
    final beats = <FloorBeat>[];

    switch (room.type) {
      case RoomType.boss:
        beats.addAll([
          FloorBeat(FloorBeatKind.approach, enemyBudget: 0),
          FloorBeat(FloorBeatKind.boss, enemyBudget: budget),
          const FloorBeat(FloorBeatKind.exitHold),
        ]);
      case RoomType.treasure:
        beats.addAll([
          FloorBeat(FloorBeatKind.approach, enemyBudget: 0),
          FloorBeat(FloorBeatKind.treasure, enemyBudget: 0),
          const FloorBeat(FloorBeatKind.exitHold),
        ]);
      case RoomType.elite:
        final mid = max(1, budget ~/ 2);
        beats.add(FloorBeat(FloorBeatKind.approach, enemyBudget: 0));
        beats.add(FloorBeat(FloorBeatKind.elite, enemyBudget: mid));
        if (kit.preferChoke || rng.nextDouble() < 0.55) {
          beats.add(FloorBeat(FloorBeatKind.choke, enemyBudget: budget - mid));
        } else {
          beats.add(
            FloorBeat(FloorBeatKind.approach, enemyBudget: budget - mid),
          );
        }
        beats.add(const FloorBeat(FloorBeatKind.exitHold));
      case RoomType.normal:
        beats.add(FloorBeat(FloorBeatKind.approach, enemyBudget: 0));
        final preferTreasure =
            kit.preferTreasureAlcove &&
            rng.nextDouble() < kit.treasureAlcoveChance;
        if (preferTreasure && budget >= 4) {
          // Full fight budget on the choke; treasure is a quiet alcove after.
          beats.add(FloorBeat(FloorBeatKind.choke, enemyBudget: budget));
          beats.add(const FloorBeat(FloorBeatKind.treasure));
        } else if (kit.preferChoke || rng.nextDouble() < 0.65) {
          final a = max(1, budget ~/ 2);
          beats.add(FloorBeat(FloorBeatKind.approach, enemyBudget: a));
          beats.add(FloorBeat(FloorBeatKind.choke, enemyBudget: budget - a));
        } else {
          beats.add(FloorBeat(FloorBeatKind.choke, enemyBudget: budget));
        }
        beats.add(const FloorBeat(FloorBeatKind.exitHold));
    }

    return FloorBlueprint(
      legacyType: room.type,
      beats: List<FloorBeat>.unmodifiable(beats),
      dungeonId: dungeonId,
    );
  }
}
