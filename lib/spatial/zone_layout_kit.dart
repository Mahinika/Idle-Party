import '../models/zone_art.dart';
import '../ui/kenney_assets.dart';
import 'tile_map.dart';

/// Per-zone layout grammar knobs (docs/FLOOR_BLUEPRINT.md).
class ZoneLayoutKit {
  const ZoneLayoutKit({
    required this.dungeonId,
    required this.landmarks,
    this.preferChoke = false,
    this.preferTreasureAlcove = false,
    this.treasureAlcoveChance = 0.0,
    this.eliteRoomChest = true,
    this.normalRoomChestChance = 0.0,
    this.landmarkPerChamber = 1,
  });

  final String dungeonId;
  final List<MapPropKind> landmarks;
  final bool preferChoke;
  final bool preferTreasureAlcove;
  final double treasureAlcoveChance;
  final bool eliteRoomChest;
  final double normalRoomChestChance;
  final int landmarkPerChamber;

  /// Edge clutter falls back to the Kenney prop pool for this zone.
  List<MapPropKind> get edgeClutter =>
      KenneyAssets.propPoolForDungeon(dungeonId);

  /// Built from the zone manifest — see `lib/models/zone_art.dart`.
  static ZoneLayoutKit forId(String dungeonId) {
    final art = ZoneArt.byId(dungeonId);
    return ZoneLayoutKit(
      dungeonId: dungeonId,
      landmarks: art.landmarks,
      preferChoke: art.preferChoke,
      preferTreasureAlcove: art.preferTreasureAlcove,
      treasureAlcoveChance: art.treasureAlcoveChance,
      normalRoomChestChance: art.normalRoomChestChance,
      landmarkPerChamber: art.landmarkPerChamber,
    );
  }
}
