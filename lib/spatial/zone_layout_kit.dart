import '../models/zone_art.dart';
import '../assets/kenney_assets.dart';
import 'floor_theme.dart';
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
    this.customDungeonArt = false,
    this.clutterDensity = 0.12,
    this.clutterPerChamberMin = 6,
    this.hubChamberChance = 0.0,
    this.eliteAlcoveChance = 0.0,
    this.shrineAlcoveChance = 0.0,
    this.corridorWindingChance = 0.5,
    this.verticalSpreadBoost = 2,
  });

  final String dungeonId;
  final List<MapPropKind> landmarks;
  final bool preferChoke;
  final bool preferTreasureAlcove;
  final double treasureAlcoveChance;
  final bool eliteRoomChest;
  final double normalRoomChestChance;
  final int landmarkPerChamber;
  final bool customDungeonArt;
  final double clutterDensity;
  final int clutterPerChamberMin;
  final double hubChamberChance;
  final double eliteAlcoveChance;
  final double shrineAlcoveChance;
  final double corridorWindingChance;
  final int verticalSpreadBoost;

  /// Edge clutter falls back to the Kenney prop pool for this zone.
  List<MapPropKind> get edgeClutter =>
      KenneyAssets.propPoolForDungeon(dungeonId);

  /// Silhouettes, floor themes, vignettes, particles for this zone.
  ZoneFloorStyle get style => ZoneFloorStyle.byId(dungeonId);

  /// Rare visual-only wonder room on normal / elite floors (about 1 in 12).
  static const double wonderChance = 1 / 12;

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
      customDungeonArt: art.customDungeonArt,
      clutterDensity: art.clutterDensity,
      clutterPerChamberMin: art.clutterPerChamberMin,
      hubChamberChance: art.hubChamberChance,
      eliteAlcoveChance: art.eliteAlcoveChance,
      shrineAlcoveChance: art.shrineAlcoveChance,
      corridorWindingChance: art.corridorWindingChance,
      verticalSpreadBoost: art.verticalSpreadBoost,
    );
  }
}
