import 'dart:math';

import '../models/dungeon_room.dart';
import 'floor_theme.dart';
import 'zone_layout_kit.dart';

/// One story beat on a floor (plan: docs/FLOOR_BLUEPRINT.md).
enum FloorBeatKind {
  approach,
  hub,
  choke,
  elite,
  treasure,

  /// Quiet side room with a glowing centrepiece. No enemies, no power.
  shrine,

  /// Rare visual-only surprise room (about 1 floor in 12).
  wonder,

  /// The zone's signature room — the last fight before the stairs.
  setpiece,
  boss,
  exitHold,
}

extension FloorBeatKindLook on FloorBeatKind {
  /// Rooms that never hold a pack unless a budget was assigned.
  bool get isQuiet =>
      this == FloorBeatKind.treasure ||
      this == FloorBeatKind.shrine ||
      this == FloorBeatKind.wonder;
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
    this.theme = FloorTheme.torchlit,
    this.wonder,
  });

  final RoomType legacyType;
  final List<FloorBeat> beats;
  final String dungeonId;

  /// One mood for the whole floor (decals, tint, HUD name).
  final FloorTheme theme;

  /// Set when this floor rolled a wonder room.
  final WonderKind? wonder;

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
    int extraCombatRooms = 0,
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
    // Separate stream so look rolls never shift the beat rolls above.
    final lookRng = Random(
      room.floorNumber * 4513 + dungeonId.hashCode * 3 + layoutSeed + 0x7E3E,
    );
    final style = kit.style;
    final theme = style.themes[lookRng.nextInt(style.themes.length)];
    final rollWonder = lookRng.nextDouble() < ZoneLayoutKit.wonderChance;
    final rollSetpiece = lookRng.nextDouble() < 0.78;
    WonderKind? wonder;

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
        _addEliteCombatSpine(
          beats,
          budget,
          kit,
          rng,
          extraCombatRooms: extraCombatRooms,
        );
        if (rollWonder && budget >= 4) {
          wonder = style.wonders[lookRng.nextInt(style.wonders.length)];
          beats.add(
            const FloorBeat(
              FloorBeatKind.wonder,
              attach: FloorBeatAttach.sideMain,
            ),
          );
        } else if (budget >= 5 &&
            kit.shrineAlcoveChance > 0 &&
            lookRng.nextDouble() < kit.shrineAlcoveChance) {
          beats.add(
            const FloorBeat(
              FloorBeatKind.shrine,
              attach: FloorBeatAttach.sideMain,
            ),
          );
        }
        if (rollSetpiece) _promoteSetpiece(beats);
        beats.add(const FloorBeat(FloorBeatKind.exitHold));
      case RoomType.normal:
        final gotWonder = _buildNormalBeats(
          beats,
          budget,
          kit,
          rng,
          extraCombatRooms: extraCombatRooms,
          rollWonder: rollWonder,
        );
        if (gotWonder) {
          wonder = style.wonders[lookRng.nextInt(style.wonders.length)];
        }
        if (rollSetpiece) _promoteSetpiece(beats);
        beats.add(const FloorBeat(FloorBeatKind.exitHold));
    }

    return FloorBlueprint(
      legacyType: room.type,
      beats: List<FloorBeat>.unmodifiable(beats),
      dungeonId: dungeonId,
      theme: theme,
      wonder: wonder,
    );
  }

  /// Peak-end: the last main fight room becomes the zone's signature room so
  /// the floor's high point sits right before the stairs. Budget is kept.
  static void _promoteSetpiece(List<FloorBeat> beats) {
    final mainFights = <int>[
      for (var i = 0; i < beats.length; i++)
        if (!beats[i].isSide && beats[i].enemyBudget > 0) i,
    ];
    if (mainFights.length < 3) return;
    final last = mainFights.last;
    final b = beats[last];
    if (b.kind == FloorBeatKind.hub) return;
    beats[last] = FloorBeat(
      FloorBeatKind.setpiece,
      enemyBudget: b.enemyBudget,
      attach: b.attach,
    );
  }

  /// Returns true when a wonder room was added.
  static bool _buildNormalBeats(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng, {
    int extraCombatRooms = 0,
    bool rollWonder = false,
  }) {
    final useHub =
        budget >= 4 &&
        kit.hubChamberChance > 0 &&
        rng.nextDouble() < kit.hubChamberChance;

    if (useHub) {
      beats.add(const FloorBeat(FloorBeatKind.hub));
      _addHubSpineAndSides(
        beats,
        budget,
        kit,
        rng,
        extraCombatRooms: extraCombatRooms,
      );
    } else {
      beats.add(const FloorBeat(FloorBeatKind.approach));
      _addClassicNormalSpine(
        beats,
        budget,
        kit,
        rng,
        extraCombatRooms: extraCombatRooms,
      );
      _maybeAddSideMainAlcove(beats, budget, kit, rng);
    }

    final sideAttach = useHub
        ? FloorBeatAttach.sideHub
        : FloorBeatAttach.sideMain;
    final rollShrine =
        kit.shrineAlcoveChance > 0 && rng.nextDouble() < kit.shrineAlcoveChance;
    if (rollWonder && budget >= 4) {
      beats.add(FloorBeat(FloorBeatKind.wonder, attach: sideAttach));
      return true;
    }
    if (rollShrine) {
      beats.add(FloorBeat(FloorBeatKind.shrine, attach: sideAttach));
    }
    return false;
  }

  static void _addHubSpineAndSides(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng, {
    int extraCombatRooms = 0,
  }) {
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

    _addMainCombatSpine(
      beats,
      remaining,
      kit,
      rng,
      extraCombatRooms: extraCombatRooms,
    );
  }

  static void _addClassicNormalSpine(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng, {
    int extraCombatRooms = 0,
  }) {
    _addMainCombatSpine(
      beats,
      budget,
      kit,
      rng,
      extraCombatRooms: extraCombatRooms,
    );
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
  static int _mainCombatRooms(int budget, {int extra = 0}) {
    var n = 0;
    if (budget >= 16) {
      n = 5;
    } else if (budget >= 12) {
      n = 4;
    } else if (budget >= 6) {
      n = 3;
    } else if (budget >= 4) {
      n = 2;
    } else {
      n = budget > 0 ? 1 : 0;
    }
    if (n <= 0) return 0;
    return min(6, n + extra.clamp(0, 3));
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
    Random rng, {
    int extraCombatRooms = 0,
  }) {
    final rooms = _mainCombatRooms(budget, extra: extraCombatRooms);
    if (rooms == 0) return;
    final shares = _shareBudget(budget, rooms);
    final third = kit.preferChoke || rng.nextDouble() < 0.55
        ? FloorBeatKind.choke
        : FloorBeatKind.elite;
    final kinds = <FloorBeatKind>[
      FloorBeatKind.approach,
      FloorBeatKind.choke,
      if (rooms >= 3) third,
      if (rooms >= 4) FloorBeatKind.elite,
      if (rooms >= 5) FloorBeatKind.choke,
      // Open after tight: never two chokes back to back at the end.
      if (rooms >= 6) FloorBeatKind.approach,
    ];
    for (var i = 0; i < rooms; i++) {
      beats.add(FloorBeat(kinds[i], enemyBudget: shares[i]));
    }
  }

  static void _addEliteCombatSpine(
    List<FloorBeat> beats,
    int budget,
    ZoneLayoutKit kit,
    Random rng, {
    int extraCombatRooms = 0,
  }) {
    final rooms = _mainCombatRooms(budget, extra: extraCombatRooms);
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
    if (rooms >= 4) {
      beats.add(FloorBeat(FloorBeatKind.elite, enemyBudget: shares[3]));
    }
    if (rooms >= 5) {
      beats.add(FloorBeat(FloorBeatKind.choke, enemyBudget: shares[4]));
    }
    if (rooms >= 6) {
      beats.add(FloorBeat(FloorBeatKind.choke, enemyBudget: shares[5]));
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
