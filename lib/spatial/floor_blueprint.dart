import 'dart:math';

import '../models/dungeon_room.dart';
import 'zone_layout_kit.dart';

/// One story beat on a floor (plan: docs/FLOOR_BLUEPRINT.md).
enum FloorBeatKind {
  approach,
  hub,
  choke,
  elite,
  treasure,
  decoy,
  boss,
  exitHold,
}

/// Main spine vs side alcove off hub or last main chamber.
enum FloorBeatAttach { main, sideHub, sideMain }

class FloorBeat {
  const FloorBeat(
    this.kind, {
    this.enemyBudget = 0,
    this.attach = FloorBeatAttach.main,
  });

  final FloorBeatKind kind;
  final int enemyBudget;
  final FloorBeatAttach attach;

  bool get isSide => attach != FloorBeatAttach.main;
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
        beats.add(FloorBeat(FloorBeatKind.approach, enemyBudget: 0));
        _addEliteCombatSpine(beats, budget, kit, rng);
        beats.add(const FloorBeat(FloorBeatKind.exitHold));
      case RoomType.normal:
        _buildNormalBeats(beats, budget, kit, rng);
        beats.add(const FloorBeat(FloorBeatKind.exitHold));
    }

    return FloorBlueprint(
      legacyType: room.type,
      beats: List<FloorBeat>.unmodifiable(beats),
      dungeonId: dungeonId,
    );
  }

  static void _buildNormalBeats(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng,
  ) {
    final useHub =
        budget >= 4 &&
        kit.hubChamberChance > 0 &&
        rng.nextDouble() < kit.hubChamberChance;

    if (useHub) {
      beats.add(const FloorBeat(FloorBeatKind.hub));
      _addHubSpineAndSides(beats, budget, kit, rng);
    } else {
      beats.add(const FloorBeat(FloorBeatKind.approach));
      _addClassicNormalSpine(beats, budget, kit, rng);
      _maybeAddSideMainAlcove(beats, budget, kit, rng);
    }

    if (kit.decoyAlcoveChance > 0 && rng.nextDouble() < kit.decoyAlcoveChance) {
      beats.add(
        FloorBeat(
          FloorBeatKind.decoy,
          attach: useHub
              ? FloorBeatAttach.sideHub
              : FloorBeatAttach.sideMain,
        ),
      );
    }
  }

  static void _addHubSpineAndSides(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng,
  ) {
    var remaining = budget;

    if (kit.eliteAlcoveChance > 0 && rng.nextDouble() < kit.eliteAlcoveChance) {
      final eliteBudget = max(1, min(3, budget ~/ 4));
      beats.add(
        FloorBeat(
          FloorBeatKind.elite,
          enemyBudget: eliteBudget,
          attach: FloorBeatAttach.sideHub,
        ),
      );
      remaining -= eliteBudget;
    }

    if (kit.preferTreasureAlcove &&
        rng.nextDouble() < kit.treasureAlcoveChance) {
      beats.add(
        const FloorBeat(
          FloorBeatKind.treasure,
          attach: FloorBeatAttach.sideHub,
        ),
      );
    }

    if (remaining <= 0) return;

    _addMainCombatSpine(beats, remaining, kit, rng);
  }

  static void _addClassicNormalSpine(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng,
  ) {
    _addMainCombatSpine(beats, budget, kit, rng);
    final preferTreasure =
        kit.preferTreasureAlcove && rng.nextDouble() < kit.treasureAlcoveChance;
    if (preferTreasure && budget >= 4) {
      beats.add(
        const FloorBeat(
          FloorBeatKind.treasure,
          attach: FloorBeatAttach.sideMain,
        ),
      );
    }
  }

  /// How many fight rooms the main spine should carve (staging is separate).
  static int _mainCombatRooms(int budget) {
    if (budget >= 6) return 3;
    if (budget >= 4) return 2;
    return budget > 0 ? 1 : 0;
  }

  static List<int> _shareBudget(int budget, int rooms) {
    if (rooms <= 0 || budget <= 0) return const [];
    if (rooms == 1) return [budget];
    final out = List<int>.filled(rooms, 0);
    var left = budget;
    for (var i = 0; i < rooms; i++) {
      if (i == rooms - 1) {
        out[i] = left;
      } else {
        final share = max(1, left ~/ (rooms - i));
        out[i] = min(share, left - (rooms - i - 1));
        left -= out[i];
      }
    }
    return out;
  }

  /// Approach → choke → elite/choke, split across [budget] so each room has a pack.
  static void _addMainCombatSpine(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng,
  ) {
    final rooms = _mainCombatRooms(budget);
    if (rooms == 0) return;
    final shares = _shareBudget(budget, rooms);
    final third = kit.preferChoke || rng.nextDouble() < 0.55
        ? FloorBeatKind.choke
        : FloorBeatKind.elite;
    final kinds = <FloorBeatKind>[
      FloorBeatKind.approach,
      FloorBeatKind.choke,
      if (rooms >= 3) third,
    ];
    for (var i = 0; i < rooms; i++) {
      beats.add(FloorBeat(kinds[i], enemyBudget: shares[i]));
    }
  }

  static void _addEliteCombatSpine(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng,
  ) {
    final rooms = _mainCombatRooms(budget);
    if (rooms == 0) return;
    final shares = _shareBudget(budget, rooms);
    beats.add(FloorBeat(FloorBeatKind.elite, enemyBudget: shares[0]));
    if (rooms >= 2) {
      beats.add(FloorBeat(FloorBeatKind.choke, enemyBudget: shares[1]));
    }
    if (rooms >= 3) {
      final last = kit.preferChoke || rng.nextDouble() < 0.5
          ? FloorBeatKind.choke
          : FloorBeatKind.approach;
      beats.add(FloorBeat(last, enemyBudget: shares[2]));
    }
  }

  static void _maybeAddSideMainAlcove(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng,
  ) {
    if (budget < 5) return;
    if (kit.eliteAlcoveChance <= 0 || rng.nextDouble() >= kit.eliteAlcoveChance) {
      return;
    }
    final eliteBudget = max(1, min(2, budget ~/ 5));
    beats.add(
      FloorBeat(
        FloorBeatKind.elite,
        enemyBudget: eliteBudget,
        attach: FloorBeatAttach.sideMain,
      ),
    );
    // Trim last main combat beat so total budget stays honest.
    for (var i = beats.length - 1; i >= 0; i--) {
      final b = beats[i];
      if (b.attach != FloorBeatAttach.main || b.enemyBudget <= eliteBudget) {
        continue;
      }
      beats[i] = FloorBeat(
        b.kind,
        enemyBudget: b.enemyBudget - eliteBudget,
        attach: b.attach,
      );
      break;
    }
  }
}
