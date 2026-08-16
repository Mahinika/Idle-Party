import 'package:flutter/material.dart';

import '../models/zone_art.dart';
import '../spatial/tile_map.dart';

/// Visual theme for dungeon combat maps (all catalog zones).
abstract final class DungeonEnvironment {
  /// Deep void behind carved space — not walkable brick fill.
  static Color ambient(String dungeonId) => ZoneArt.byId(dungeonId).ambient;

  /// Soft full-frame wash so each dungeon reads differently.
  static Color atmosphereWash(String dungeonId) => ZoneArt.byId(dungeonId).wash;

  /// Per-tile mute + zone tint so Kenney floors sit in the painted cave.
  static Color floorBlend(String dungeonId) =>
      ZoneArt.byId(dungeonId).floorBlend;

  /// Opaque tint mixed into combat projectiles so bolts read with the zone.
  static Color projectileTint(String dungeonId) =>
      ZoneArt.byId(dungeonId).projectileTint;

  /// Dim corridors vs room floors.
  static Color corridorShade(String dungeonId) =>
      ZoneArt.byId(dungeonId).corridorShade;

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
