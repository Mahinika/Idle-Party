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
  List<MapPropKind> get edgeClutter => KenneyAssets.propPoolForDungeon(dungeonId);

  static ZoneLayoutKit forId(String dungeonId) => switch (dungeonId) {
        'rime' => const ZoneLayoutKit(
          dungeonId: 'rime',
          landmarks: <MapPropKind>[
            MapPropKind.pillar,
            MapPropKind.fountain,
            MapPropKind.chest,
            MapPropKind.water,
          ],
          preferTreasureAlcove: true,
          treasureAlcoveChance: 0.45,
          eliteRoomChest: true,
          normalRoomChestChance: 0.28,
          landmarkPerChamber: 2,
        ),
        'fen' => const ZoneLayoutKit(
          dungeonId: 'fen',
          landmarks: <MapPropKind>[
            MapPropKind.water,
            MapPropKind.fountain,
            MapPropKind.bones,
            MapPropKind.trap,
          ],
          preferChoke: true,
          eliteRoomChest: true,
          normalRoomChestChance: 0.12,
          landmarkPerChamber: 1,
        ),
        'brass' => const ZoneLayoutKit(
          dungeonId: 'brass',
          landmarks: <MapPropKind>[
            MapPropKind.anvil,
            MapPropKind.pillar,
            MapPropKind.chest,
            MapPropKind.hatch,
          ],
          preferTreasureAlcove: true,
          treasureAlcoveChance: 0.40,
          eliteRoomChest: true,
          normalRoomChestChance: 0.22,
          landmarkPerChamber: 2,
        ),
        'veil' => const ZoneLayoutKit(
          dungeonId: 'veil',
          landmarks: <MapPropKind>[
            MapPropKind.bones,
            MapPropKind.trap,
            MapPropKind.torch,
            MapPropKind.torchAlt,
          ],
          preferChoke: true,
          eliteRoomChest: true,
          normalRoomChestChance: 0.10,
          landmarkPerChamber: 1,
        ),
        'storm' => const ZoneLayoutKit(
          dungeonId: 'storm',
          landmarks: <MapPropKind>[
            MapPropKind.torch,
            MapPropKind.torchAlt,
            MapPropKind.pillar,
            MapPropKind.trap,
          ],
          preferChoke: true,
          eliteRoomChest: true,
          normalRoomChestChance: 0.08,
          landmarkPerChamber: 1,
        ),
        'tide' => const ZoneLayoutKit(
          dungeonId: 'tide',
          landmarks: <MapPropKind>[
            MapPropKind.water,
            MapPropKind.fountain,
            MapPropKind.barrel,
            MapPropKind.pillar,
          ],
          preferTreasureAlcove: true,
          treasureAlcoveChance: 0.28,
          eliteRoomChest: true,
          normalRoomChestChance: 0.14,
          landmarkPerChamber: 2,
        ),
        'ember' => const ZoneLayoutKit(
          dungeonId: 'ember',
          landmarks: <MapPropKind>[
            MapPropKind.lava,
            MapPropKind.anvil,
            MapPropKind.torch,
            MapPropKind.pillar,
          ],
          preferChoke: true,
          eliteRoomChest: true,
          normalRoomChestChance: 0.10,
          landmarkPerChamber: 2,
        ),
        'grove' => const ZoneLayoutKit(
          dungeonId: 'grove',
          landmarks: <MapPropKind>[
            MapPropKind.fountain,
            MapPropKind.pot,
            MapPropKind.bones,
            MapPropKind.rubble,
          ],
          preferChoke: true,
          preferTreasureAlcove: false,
          eliteRoomChest: true,
          normalRoomChestChance: 0.12,
          landmarkPerChamber: 2,
        ),
        'crystal' => const ZoneLayoutKit(
          dungeonId: 'crystal',
          landmarks: <MapPropKind>[
            MapPropKind.pillar,
            MapPropKind.fountain,
            MapPropKind.chest,
          ],
          eliteRoomChest: true,
          normalRoomChestChance: 0.12,
          landmarkPerChamber: 2,
        ),
        'hell' => const ZoneLayoutKit(
          dungeonId: 'hell',
          landmarks: <MapPropKind>[
            MapPropKind.lava,
            MapPropKind.skull,
            MapPropKind.bones,
            MapPropKind.torch,
          ],
          preferChoke: true,
          eliteRoomChest: true,
        ),
        'dead' => const ZoneLayoutKit(
          dungeonId: 'dead',
          landmarks: <MapPropKind>[
            MapPropKind.gravestone,
            MapPropKind.bones,
            MapPropKind.skull,
            MapPropKind.fence,
          ],
          eliteRoomChest: true,
          normalRoomChestChance: 0.1,
        ),
        'sandy' => const ZoneLayoutKit(
          dungeonId: 'sandy',
          landmarks: <MapPropKind>[
            MapPropKind.hatch,
            MapPropKind.crate,
            MapPropKind.barrel,
          ],
          eliteRoomChest: true,
          normalRoomChestChance: 0.05,
        ),
        'goblin' => const ZoneLayoutKit(
          dungeonId: 'goblin',
          landmarks: <MapPropKind>[
            MapPropKind.barrel,
            MapPropKind.crate,
            MapPropKind.table,
            MapPropKind.torch,
          ],
          eliteRoomChest: true,
          normalRoomChestChance: 0.08,
        ),
        'king' => const ZoneLayoutKit(
          dungeonId: 'king',
          landmarks: <MapPropKind>[
            MapPropKind.anvil,
            MapPropKind.pillar,
            MapPropKind.table,
            MapPropKind.chest,
          ],
          eliteRoomChest: true,
          normalRoomChestChance: 0.1,
        ),
        'underworld' => const ZoneLayoutKit(
          dungeonId: 'underworld',
          landmarks: <MapPropKind>[
            MapPropKind.skull,
            MapPropKind.bones,
            MapPropKind.torchAlt,
            MapPropKind.pillar,
          ],
          preferChoke: true,
          eliteRoomChest: true,
        ),
        _ => ZoneLayoutKit(
          dungeonId: dungeonId,
          landmarks: KenneyAssets.propPoolForDungeon(dungeonId).take(4).toList(),
          eliteRoomChest: true,
        ),
      };
}
