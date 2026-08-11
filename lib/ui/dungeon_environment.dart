import 'package:flutter/material.dart';

import '../spatial/tile_map.dart';

/// Visual theme for dungeon combat maps (all catalog zones).
abstract final class DungeonEnvironment {
  /// Deep void behind carved space — not walkable brick fill.
  static Color ambient(String dungeonId) => switch (dungeonId) {
        'sandy' => const Color(0xFF0C0A08),
        'goblin' => const Color(0xFF0A0C09),
        'king' => const Color(0xFF080A10),
        'underworld' => const Color(0xFF0A0810),
        'dead' => const Color(0xFF070908),
        'hell' => const Color(0xFF120606),
        'crystal' => const Color(0xFF081018),
        'tide' => const Color(0xFF021018),
        'ember' => const Color(0xFF1C0C02),
        'grove' => const Color(0xFF06140A),
        // Violet void — not crystal blue, not underworld purple twin.
        'storm' => const Color(0xFF0A0614),
        _ => const Color(0xFF080706),
      };

  /// Soft full-frame wash so each dungeon reads differently.
  static Color atmosphereWash(String dungeonId) => switch (dungeonId) {
        'sandy' => const Color(0x44C88840),
        'goblin' => const Color(0x3A28A050),
        'king' => const Color(0x3A3060A0),
        'underworld' => const Color(0x447040B0),
        'dead' => const Color(0x3A305040),
        'hell' => const Color(0x4CA02018),
        'crystal' => const Color(0x4450A0F0),
        // Dedicated backdrops — keep washes light like crystal (~0x44–0x50).
        'tide' => const Color(0x4828C0B0),
        'ember' => const Color(0x4AF08028),
        'grove' => const Color(0x4858C040),
        // Violet haze + electric edge (distinct from crystal blue / underworld).
        'storm' => const Color(0x4A8040D0),
        _ => const Color(0x22000000),
      };

  /// Per-tile mute + zone tint so Kenney floors sit in the painted cave.
  static Color floorBlend(String dungeonId) => switch (dungeonId) {
        'sandy' => const Color(0x66A07038),
        'goblin' => const Color(0x5A284828),
        'king' => const Color(0x5A203048),
        'underworld' => const Color(0x66281840),
        'dead' => const Color(0x5A182028),
        'hell' => const Color(0x6A401010),
        'crystal' => const Color(0x5A183050),
        'tide' => const Color(0x5A186070),
        'ember' => const Color(0x5A482810),
        'grove' => const Color(0x5A283818),
        'storm' => const Color(0x5A281848),
        _ => const Color(0x55050403),
      };

  /// Opaque tint mixed into combat projectiles so bolts read with the zone.
  static Color projectileTint(String dungeonId) => switch (dungeonId) {
        'sandy' => const Color(0xFFE0A050),
        'goblin' => const Color(0xFF60C070),
        'king' => const Color(0xFF70A0E0),
        'underworld' => const Color(0xFFA070E0),
        'dead' => const Color(0xFF70A090),
        'hell' => const Color(0xFFE05040),
        'crystal' => const Color(0xFF80D0FF),
        'tide' => const Color(0xFF40C0B0),
        'ember' => const Color(0xFFE09040),
        'grove' => const Color(0xFF68B048),
        'storm' => const Color(0xFFE8E040),
        _ => const Color(0xFFE0C080),
      };

  /// Dim corridors vs room floors.
  static Color corridorShade(String dungeonId) => switch (dungeonId) {
        'hell' => const Color(0x40000000),
        'underworld' => const Color(0x38000000),
        'dead' => const Color(0x34000000),
        'crystal' => const Color(0x38001020),
        'tide' => const Color(0x38001820),
        'ember' => const Color(0x3C100800),
        'grove' => const Color(0x38081008),
        'storm' => const Color(0x3A100828),
        _ => const Color(0x2C000000),
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
