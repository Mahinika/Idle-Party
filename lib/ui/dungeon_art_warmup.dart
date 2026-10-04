import 'dart:async';

import '../assets/custom_assets.dart';
import '../assets/kenney_assets.dart';
import 'decoded_image_cache.dart';

/// Decodes the pictures a floor can paint before the party portraits.
///
/// The hub starts this while the player is still on the map, so ENTER is
/// not a blank "Loading floor…" while ten hero PNGs decode.
abstract final class DungeonArtWarmup {
  static const int _tile = 64;

  /// Stairs, doors, and the pickup icons the first paint requires.
  /// Hero portraits stay out of this list on purpose.
  static List<({String path, int width})> paintGate() => [
    (path: KenneyAssets.stairs, width: _tile),
    (path: KenneyAssets.stairsBoss, width: _tile),
    (path: KenneyAssets.doorClosed, width: _tile),
    (path: KenneyAssets.doorOpen, width: _tile),
    (path: KenneyAssets.chestClosed, width: _tile),
    (path: KenneyAssets.coinGold, width: 48),
    (path: KenneyAssets.sword, width: 48),
    (path: KenneyAssets.vialBlue, width: 48),
  ];

  static List<({String path, int width})> heroes() => [
    (path: KenneyAssets.heroKnight, width: 128),
    (path: KenneyAssets.heroHealer, width: 128),
    (path: KenneyAssets.heroWizard, width: 128),
    (path: KenneyAssets.heroRogue, width: 128),
    (path: CustomAssets.heroPaladin, width: 128),
    (path: CustomAssets.heroHunter, width: 128),
    (path: CustomAssets.heroDeathKnight, width: 128),
    (path: CustomAssets.heroShaman, width: 128),
    (path: CustomAssets.heroWarlock, width: 128),
    (path: CustomAssets.heroDruid, width: 128),
  ];

  static List<({String path, int width})> firstFloor(String dungeonId) {
    final floors = KenneyAssets.floorVariantsForDungeon(dungeonId);
    final walls = KenneyAssets.wallVariantsForDungeon(dungeonId);
    return [
      if (floors.isNotEmpty) (path: floors.first, width: _tile),
      if (walls.isNotEmpty) (path: walls.first, width: _tile),
    ];
  }

  /// Gate and the first floor pair. Portraits keep decoding after this returns.
  static Future<void> warm(String dungeonId) {
    unawaited(_load(heroes()));
    return _load([...paintGate(), ...firstFloor(dungeonId)]);
  }

  static Future<void> _load(List<({String path, int width})> items) {
    return Future.wait([
      for (final item in items)
        DecodedImageCache.load(item.path, targetWidth: item.width),
    ]);
  }
}
