import 'package:flutter/material.dart';

import '../spatial/tile_map.dart';

/// Visual theme for dungeon combat maps (all six zones).
abstract final class DungeonEnvironment {
  /// Deep void behind carved space — not walkable brick fill.
  static Color ambient(String dungeonId) => switch (dungeonId) {
        'sandy' => const Color(0xFF14100A),
        'goblin' => const Color(0xFF100E0A),
        'king' => const Color(0xFF0A0C12),
        'underworld' => const Color(0xFF0C0812),
        'dead' => const Color(0xFF080A09),
        'hell' => const Color(0xFF160808),
        'crystal' => const Color(0xFF0A1420),
        _ => const Color(0xFF0C0B09),
      };

  /// Soft full-frame wash so each dungeon reads differently.
  static Color atmosphereWash(String dungeonId) => switch (dungeonId) {
        'sandy' => const Color(0x18C88840),
        'goblin' => const Color(0x1428A050),
        'king' => const Color(0x143060A0),
        'underworld' => const Color(0x1A7040B0),
        'dead' => const Color(0x16305040),
        'hell' => const Color(0x22A02018),
        'crystal' => const Color(0x1850A0F0),
        _ => const Color(0x10000000),
      };

  /// Dim corridors vs room floors.
  static Color corridorShade(String dungeonId) => switch (dungeonId) {
        'hell' => const Color(0x28000000),
        'underworld' => const Color(0x22000000),
        'dead' => const Color(0x20000000),
        'crystal' => const Color(0x22001018),
        _ => const Color(0x18000000),
      };

  /// Rare luminance jitter (not a checkerboard).
  static Color floorNoise(int x, int y, int seed) {
    final h = x * 73856093 ^ y * 19349663 ^ seed;
    final v = ((h % 7) + 7) % 7; // 0..6
    if (v == 0) return const Color(0x10000000);
    if (v == 1) return const Color(0x0CFFFFFF);
    return const Color(0x00000000);
  }

  static bool isCarved(TileKind kind) => kind != TileKind.wall;

  static bool wallTouchesCarved(TileMap map, int x, int y) {
    for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      if (isCarved(map.at(x + d.$1, y + d.$2))) return true;
    }
    return false;
  }

  static bool inChamber(TileMap map, int x, int y) {
    for (final c in map.chambers) {
      if (c.containsTile(x, y)) return true;
    }
    return false;
  }

  /// True when the gate sits in an east–west corridor (door should rotate).
  static bool gateRunsEastWest(TileMap map, int x, int y) {
    var lr = 0;
    var ud = 0;
    if (isCarved(map.at(x - 1, y))) lr++;
    if (isCarved(map.at(x + 1, y))) lr++;
    if (isCarved(map.at(x, y - 1))) ud++;
    if (isCarved(map.at(x, y + 1))) ud++;
    return lr >= ud;
  }
}
