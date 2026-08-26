import 'dart:ui' show Color;

import '../spatial/tile_map.dart' show MapPropKind;
import '../ui/custom_assets.dart';
import '../ui/kenney_assets.dart';
import 'dungeon_def.dart';
import 'enemy.dart';

/// Which sprite a zone spawns for each slot on the enemy roster.
///
/// Every zone owns at least a boss and a trash sprite nobody else uses — that
/// is what stops Sunken Tidehold from reading as "Sandy Caverns, but blue".
class ZoneEnemyArt {
  const ZoneEnemyArt({
    required this.boss,
    required this.elite,
    required this.trash,
    String? swarm,
    String? brute,
    String? tank,
    String? ranged,
    String? glass,
    String? support,
  }) : _swarm = swarm,
       _brute = brute,
       _tank = tank,
       _ranged = ranged,
       _glass = glass,
       _support = support;

  final String boss;
  final String elite;

  /// Fallback for any archetype the zone does not name explicitly.
  final String trash;

  final String? _swarm;
  final String? _brute;
  final String? _tank;
  final String? _ranged;
  final String? _glass;
  final String? _support;

  String forArchetype(EnemyArchetype archetype) => switch (archetype) {
    EnemyArchetype.swarm => _swarm ?? trash,
    EnemyArchetype.brute => _brute ?? elite,
    EnemyArchetype.tank => _tank ?? elite,
    EnemyArchetype.ranged => _ranged ?? trash,
    EnemyArchetype.glass => _glass ?? trash,
    EnemyArchetype.support => _support ?? trash,
  };

  String forRole(EnemyRole role) => switch (role) {
    EnemyRole.boss => boss,
    EnemyRole.elite => elite,
    _ => trash,
  };

  /// Everything this zone can paint — the stage decodes exactly this set.
  Set<String> get all => <String>{
    boss,
    elite,
    trash,
    for (final a in EnemyArchetype.values) forArchetype(a),
  };
}

/// One zone, one place.
///
/// Art, colour, clutter, layout grammar and enemy roster used to live in six
/// separate switch statements across `kenney_assets`, `dungeon_environment`,
/// `zone_layout_kit`, `custom_assets` and the hub — adding a zone meant editing
/// a dozen files and hoping you found them all. Those functions now read from
/// here, so a zone is a single entry in [ZoneArt.byId].
class ZoneArtDef {
  const ZoneArtDef({
    required this.id,
    required this.floor,
    required this.wallVariants,
    required this.props,
    required this.landmarks,
    required this.hubIcon,
    required this.ambient,
    required this.wash,
    required this.floorBlend,
    required this.projectileTint,
    required this.enemies,
    List<String>? floorVariants,
    String? wall,
    Color? corridorShade,
    this.preferChoke = false,
    this.preferTreasureAlcove = false,
    this.treasureAlcoveChance = 0.0,
    this.normalRoomChestChance = 0.0,
    this.landmarkPerChamber = 1,
    this.customDungeonArt = false,
    this.clutterDensity = 0.12,
    this.clutterPerChamberMin = 6,
  }) : _floorVariants = floorVariants,
       _wall = wall,
       _corridorShade = corridorShade;

  final String id;

  // —— Tiles ——
  final String floor;
  final List<String>? _floorVariants;
  final String? _wall;

  /// Rim wall sprites only (deep walls paint as void).
  final List<String> wallVariants;

  /// Weighted clutter pool (duplicates = more common).
  final List<MapPropKind> props;

  /// Signature props the blueprint places on purpose, not as clutter.
  final List<MapPropKind> landmarks;

  /// Entrance icon on the hub world path.
  final String hubIcon;

  // —— Colour ——
  /// Deep void behind carved space — not walkable brick fill.
  final Color ambient;

  /// Soft full-frame wash so each dungeon reads differently.
  final Color wash;

  /// Per-tile mute + zone tint so Kenney floors sit in the painted cave.
  final Color floorBlend;

  /// Opaque tint mixed into combat projectiles so bolts read with the zone.
  final Color projectileTint;

  final Color? _corridorShade;

  // —— Layout grammar (docs/FLOOR_BLUEPRINT.md) ——
  final bool preferChoke;
  final bool preferTreasureAlcove;
  final double treasureAlcoveChance;
  final double normalRoomChestChance;
  final int landmarkPerChamber;

  /// Owned tiles/props (`assets/custom/dungeon/`) — less random clutter.
  final bool customDungeonArt;
  final double clutterDensity;
  final int clutterPerChamberMin;

  final ZoneEnemyArt enemies;

  String get portrait => CustomAssets.dungeonPortrait(id);

  String get backdrop => CustomAssets.dungeonBackdropFor(id);

  List<String> get floorVariants => _floorVariants ?? <String>[floor];

  String get wall => _wall ?? KenneyAssets.wallStone;

  Color get corridorShade => _corridorShade ?? const Color(0x2C000000);
}

abstract final class ZoneArt {
  /// Manifest for [dungeonId]; unknown ids fall back to a plain cave so a
  /// half-built zone still paints instead of throwing.
  static ZoneArtDef byId(String dungeonId) =>
      _byId[dungeonId] ?? _fallbackFor(dungeonId);

  static Iterable<ZoneArtDef> get all => _byId.values;

  static ZoneArtDef _fallbackFor(String dungeonId) {
    final layout = DungeonCatalog.byId(dungeonId).layout;
    return ZoneArtDef(
      id: dungeonId,
      floor: switch (layout) {
        DungeonLayoutKind.cave => KenneyAssets.floorSand,
        DungeonLayoutKind.hideout => KenneyAssets.floorDirtDetail,
        DungeonLayoutKind.fort || DungeonLayoutKind.arena =>
          KenneyAssets.floorStone,
      },
      wallVariants: [KenneyAssets.wallStone],
      props: _genericProps,
      landmarks: _genericProps.take(4).toList(),
      hubIcon: KenneyAssets.iconDoor,
      ambient: const Color(0xFF080706),
      wash: const Color(0x22000000),
      floorBlend: const Color(0x55050403),
      projectileTint: const Color(0xFFE0C080),
      enemies: const ZoneEnemyArt(
        boss: CustomAssets.enemyBossKing,
        elite: CustomAssets.enemyCyclops,
        trash: CustomAssets.enemySlime,
        swarm: CustomAssets.enemyRat,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyBat,
        support: CustomAssets.enemyCultist,
      ),
    );
  }

  static const List<MapPropKind> _genericProps = [
    MapPropKind.barrel,
    MapPropKind.crate,
    MapPropKind.table,
    MapPropKind.stool,
    MapPropKind.shelf,
    MapPropKind.rubble,
    MapPropKind.chest,
  ];

  /// Owned dungeon tiles/props/hub icon (`assets/custom/dungeon/<id>/`).
  static ZoneArtDef _customZone({
    required String id,
    required List<MapPropKind> props,
    required List<MapPropKind> landmarks,
    required Color ambient,
    required Color wash,
    required Color floorBlend,
    required Color projectileTint,
    required ZoneEnemyArt enemies,
    String? wall,
    Color? corridorShade,
    bool preferChoke = false,
    bool preferTreasureAlcove = false,
    double treasureAlcoveChance = 0.0,
    double normalRoomChestChance = 0.0,
    int landmarkPerChamber = 1,
  }) =>
      ZoneArtDef(
        id: id,
        customDungeonArt: true,
        clutterDensity: 0.08,
        clutterPerChamberMin: 4,
        floor: CustomAssets.dungeonTile(id, 'floor_a'),
        floorVariants: CustomAssets.dungeonFloorVariants(id),
        wallVariants: CustomAssets.dungeonWallVariants(id),
        hubIcon: CustomAssets.dungeonHubIcon(id),
        props: props,
        landmarks: landmarks,
        ambient: ambient,
        wash: wash,
        floorBlend: floorBlend,
        projectileTint: projectileTint,
        enemies: enemies,
        wall: wall,
        corridorShade: corridorShade,
        preferChoke: preferChoke,
        preferTreasureAlcove: preferTreasureAlcove,
        treasureAlcoveChance: treasureAlcoveChance,
        normalRoomChestChance: normalRoomChestChance,
        landmarkPerChamber: landmarkPerChamber,
      );

  // Not const: some Kenney tile paths resolve through getters.
  static final Map<String, ZoneArtDef> _byId = {
    'sandy': _customZone(
      id: 'sandy',
      props: [
        MapPropKind.barrel,
        MapPropKind.barrel,
        MapPropKind.crate,
        MapPropKind.crate,
        MapPropKind.crate,
        MapPropKind.table,
        MapPropKind.hatch,
        MapPropKind.hatch,
        MapPropKind.shelf,
        MapPropKind.shelf,
        MapPropKind.rubble,
        MapPropKind.torch,
        MapPropKind.torchAlt,
      ],
      landmarks: [MapPropKind.hatch, MapPropKind.crate, MapPropKind.barrel],
      ambient: Color(0xFF0C0A08),
      wash: Color(0x44C88840),
      floorBlend: Color(0x66A07038),
      projectileTint: Color(0xFFE0A050),
      normalRoomChestChance: 0.10,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossSandy,
        elite: CustomAssets.enemySlime,
        trash: CustomAssets.enemySlime,
        swarm: CustomAssets.enemySandyMite,
        brute: CustomAssets.enemyCrab,
        tank: CustomAssets.enemyCrab,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemySandyMite,
        support: CustomAssets.enemyRat,
      ),
    ),
    'goblin': _customZone(
      id: 'goblin',
      // Worn dirt (not Underworld's detail tile) + boarded door rims.
      props: [
        MapPropKind.barrel,
        MapPropKind.barrel,
        MapPropKind.crate,
        MapPropKind.crate,
        MapPropKind.crate,
        MapPropKind.table,
        MapPropKind.stool,
        MapPropKind.bones,
        MapPropKind.pot,
        MapPropKind.skull,
        MapPropKind.shelf,
        MapPropKind.rubble,
        MapPropKind.chest,
      ],
      landmarks: [
        MapPropKind.chest,
        MapPropKind.barrel,
        MapPropKind.crate,
        MapPropKind.skull,
        MapPropKind.torch,
      ],
      ambient: Color(0xFF0A0C09),
      wash: Color(0x3A28A050),
      floorBlend: Color(0x5A284828),
      projectileTint: Color(0xFF60C070),
      // Raider dens: choke approaches + frequent stolen-stash alcoves.
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.34,
      normalRoomChestChance: 0.22,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossGoblin,
        elite: CustomAssets.enemyRat,
        trash: CustomAssets.enemyGoblinMite,
        swarm: CustomAssets.enemyGoblinMite,
        brute: CustomAssets.enemyCrab,
        tank: CustomAssets.enemyCyclops,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyGoblinMite,
        support: CustomAssets.enemyGoblinMite,
      ),
    ),
    'king': _customZone(
      id: 'king',
      wall: KenneyAssets.wallBanner,
      props: [
        MapPropKind.torch,
        MapPropKind.torch,
        MapPropKind.crate,
        MapPropKind.anvil,
        MapPropKind.table,
        MapPropKind.table,
        MapPropKind.barrel,
        MapPropKind.stool,
        MapPropKind.fence,
        MapPropKind.pillar,
        MapPropKind.shelf,
        MapPropKind.hatch,
      ],
      landmarks: [
        MapPropKind.anvil,
        MapPropKind.pillar,
        MapPropKind.table,
        MapPropKind.chest,
      ],
      ambient: Color(0xFF080A10),
      wash: Color(0x3A3060A0),
      floorBlend: Color(0x5A203048),
      projectileTint: Color(0xFF70A0E0),
      normalRoomChestChance: 0.1,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossKing,
        elite: CustomAssets.enemyCyclops,
        trash: CustomAssets.enemyKingMite,
        swarm: CustomAssets.enemyKingMite,
        brute: CustomAssets.enemyCyclops,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyKingMite,
        support: CustomAssets.enemyCultist,
      ),
    ),
    'underworld': _customZone(
      id: 'underworld',
      props: [
        MapPropKind.torch,
        MapPropKind.torch,
        MapPropKind.barrel,
        MapPropKind.fountain,
        MapPropKind.crate,
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.pillar,
        MapPropKind.fence,
        MapPropKind.rubble,
        MapPropKind.pot,
      ],
      landmarks: [
        MapPropKind.skull,
        MapPropKind.bones,
        MapPropKind.torchAlt,
        MapPropKind.pillar,
      ],
      ambient: Color(0xFF0A0810),
      wash: Color(0x447040B0),
      floorBlend: Color(0x66281840),
      projectileTint: Color(0xFFA070E0),
      corridorShade: Color(0x38000000),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.28,
      normalRoomChestChance: 0.12,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossUnderworld,
        elite: CustomAssets.enemyGhost,
        trash: CustomAssets.enemyUnderworldMite,
        swarm: CustomAssets.enemyUnderworldMite,
        brute: CustomAssets.enemyCyclops,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemySpider,
        glass: CustomAssets.enemyUnderworldMite,
        support: CustomAssets.enemyCultist,
      ),
    ),
    'dead': _customZone(
      id: 'dead',
      props: [
        MapPropKind.gravestone,
        MapPropKind.gravestone,
        MapPropKind.bones,
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.crate,
        MapPropKind.torch,
        MapPropKind.hatch,
        MapPropKind.fence,
        MapPropKind.rubble,
        MapPropKind.pillar,
      ],
      landmarks: [
        MapPropKind.gravestone,
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.fence,
      ],
      ambient: Color(0xFF070908),
      wash: Color(0x3A305040),
      floorBlend: Color(0x5A182028),
      projectileTint: Color(0xFF70A090),
      corridorShade: Color(0x34000000),
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.30,
      normalRoomChestChance: 0.18,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossDead,
        elite: CustomAssets.enemyGhost,
        trash: CustomAssets.enemyDeadMite,
        swarm: CustomAssets.enemyDeadMite,
        brute: CustomAssets.enemyCyclops,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyDeadMite,
        support: CustomAssets.enemyGhost,
      ),
    ),
    'hell': _customZone(
      id: 'hell',
      props: [
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.torchAlt,
        MapPropKind.barrel,
        MapPropKind.trap,
        MapPropKind.lava,
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.rubble,
        MapPropKind.pillar,
        MapPropKind.crate,
      ],
      landmarks: [
        MapPropKind.lava,
        MapPropKind.skull,
        MapPropKind.bones,
        MapPropKind.torch,
      ],
      ambient: Color(0xFF120606),
      wash: Color(0x4CA02018),
      floorBlend: Color(0x6A401010),
      projectileTint: Color(0xFFE05040),
      corridorShade: Color(0x40000000),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.30,
      normalRoomChestChance: 0.14,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossHell,
        elite: CustomAssets.enemyCyclops,
        trash: CustomAssets.enemyHellMite,
        swarm: CustomAssets.enemyHellMite,
        brute: CustomAssets.enemyCultist,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyRat,
        support: CustomAssets.enemySpider,
      ),
    ),
    'crystal': _customZone(
      id: 'crystal',
      props: [
        MapPropKind.torch,
        MapPropKind.fountain,
        MapPropKind.fountain,
        MapPropKind.crate,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.chest,
        MapPropKind.fence,
        MapPropKind.hatch,
        MapPropKind.anvil,
        MapPropKind.stool,
      ],
      landmarks: [
        MapPropKind.pillar,
        MapPropKind.fountain,
        MapPropKind.chest,
      ],
      ambient: Color(0xFF081018),
      wash: Color(0x4450A0F0),
      floorBlend: Color(0x5A183050),
      projectileTint: Color(0xFF80D0FF),
      corridorShade: Color(0x38001020),
      normalRoomChestChance: 0.12,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyCrystalBoss,
        elite: CustomAssets.enemyCrystalWraith,
        trash: CustomAssets.enemyCrystalMite,
        swarm: CustomAssets.enemyCrystalMite,
        brute: CustomAssets.enemyGolem,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyCrystalWraith,
        glass: CustomAssets.enemyCrystalMite,
        support: CustomAssets.enemyCrystalMite,
      ),
    ),
    'tide': _customZone(
      id: 'tide',
      props: [
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.fountain,
        MapPropKind.fountain,
        MapPropKind.barrel,
        MapPropKind.hatch,
        MapPropKind.pot,
        MapPropKind.pillar,
      ],
      landmarks: [
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.fountain,
        MapPropKind.pillar,
      ],
      ambient: Color(0xFF02141A),
      wash: Color(0x5020B8A0),
      floorBlend: Color(0x5A146878),
      projectileTint: Color(0xFF38D0B8),
      corridorShade: Color(0x38001820),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.36,
      normalRoomChestChance: 0.16,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossTide,
        elite: CustomAssets.enemyCrab,
        trash: CustomAssets.enemyTideMite,
        swarm: CustomAssets.enemyTideMite,
        brute: CustomAssets.enemyCrab,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyTideMite,
        glass: CustomAssets.enemySlime,
        support: CustomAssets.enemySlime,
      ),
    ),
    'ember': _customZone(
      id: 'ember',
      props: [
        MapPropKind.lava,
        MapPropKind.lava,
        MapPropKind.lava,
        MapPropKind.lava,
        MapPropKind.anvil,
        MapPropKind.anvil,
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.torchAlt,
        MapPropKind.pillar,
        MapPropKind.skull,
        MapPropKind.rubble,
      ],
      landmarks: [
        MapPropKind.lava,
        MapPropKind.lava,
        MapPropKind.anvil,
        MapPropKind.skull,
      ],
      ambient: Color(0xFF160A02),
      wash: Color(0x58E08820),
      floorBlend: Color(0x5A503010),
      projectileTint: Color(0xFFE89830),
      corridorShade: Color(0x3C100800),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.32,
      normalRoomChestChance: 0.18,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossEmber,
        elite: CustomAssets.enemyGolem,
        trash: CustomAssets.enemyEmberMite,
        swarm: CustomAssets.enemyEmberMite,
        brute: CustomAssets.enemySpider,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyEmberMite,
        glass: CustomAssets.enemyEmberMite,
        support: CustomAssets.enemySpider,
      ),
    ),
    'grove': _customZone(
      id: 'grove',
      props: [
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.pot,
        MapPropKind.pot,
        MapPropKind.fountain,
        MapPropKind.bones,
        MapPropKind.rubble,
        MapPropKind.shelf,
        MapPropKind.torch,
        MapPropKind.crate,
        MapPropKind.barrel,
      ],
      landmarks: [
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.pot,
        MapPropKind.fountain,
      ],
      ambient: Color(0xFF041208),
      wash: Color(0x5848A838),
      floorBlend: Color(0x5A1E3820),
      projectileTint: Color(0xFF58B050),
      corridorShade: Color(0x38081008),
      preferChoke: true,
      normalRoomChestChance: 0.12,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossGrove,
        elite: CustomAssets.enemySlime,
        trash: CustomAssets.enemyGroveMite,
        swarm: CustomAssets.enemyGroveMite,
        brute: CustomAssets.enemyCyclops,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyRat,
        glass: CustomAssets.enemyGroveMite,
        support: CustomAssets.enemyBat,
      ),
    ),
    'storm': _customZone(
      id: 'storm',
      props: [
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.torch,
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.torchAlt,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.rubble,
        MapPropKind.fence,
        MapPropKind.crate,
        MapPropKind.bones,
      ],
      landmarks: [
        MapPropKind.trap,
        MapPropKind.torchAlt,
        MapPropKind.pillar,
        MapPropKind.torch,
      ],
      ambient: Color(0xFF0A0614),
      wash: Color(0x528040D0),
      floorBlend: Color(0x5A281848),
      projectileTint: Color(0xFFE8E040),
      corridorShade: Color(0x3A100828),
      preferChoke: true,
      normalRoomChestChance: 0.08,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossStorm,
        elite: CustomAssets.enemyCrystalWraith,
        trash: CustomAssets.enemyStormMite,
        swarm: CustomAssets.enemyStormMite,
        brute: CustomAssets.enemyGolem,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyCrystalWraith,
        glass: CustomAssets.enemyStormMite,
        support: CustomAssets.enemyStormMite,
      ),
    ),
    'rime': _customZone(
      id: 'rime',
      props: [
        MapPropKind.fountain,
        MapPropKind.fountain,
        MapPropKind.water,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.chest,
        MapPropKind.rubble,
        MapPropKind.crate,
        MapPropKind.barrel,
        MapPropKind.pot,
        MapPropKind.shelf,
        MapPropKind.bones,
        MapPropKind.fence,
      ],
      landmarks: [
        MapPropKind.pillar,
        MapPropKind.fountain,
        MapPropKind.chest,
        MapPropKind.water,
      ],
      ambient: Color(0xFF041018),
      wash: Color(0x4860D8E0),
      floorBlend: Color(0x5A184860),
      projectileTint: Color(0xFF70E8F0),
      corridorShade: Color(0x38081828),
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.45,
      normalRoomChestChance: 0.28,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossRime,
        elite: CustomAssets.enemyCrystalWraith,
        trash: CustomAssets.enemyRimeMite,
        swarm: CustomAssets.enemyRimeMite,
        brute: CustomAssets.enemyGolem,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyRimeMite,
        glass: CustomAssets.enemyRimeMite,
        support: CustomAssets.enemyBat,
      ),
    ),
    'fen': _customZone(
      id: 'fen',
      props: [
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.fountain,
        MapPropKind.fountain,
        MapPropKind.bones,
        MapPropKind.trap,
        MapPropKind.rubble,
        MapPropKind.crate,
        MapPropKind.barrel,
        MapPropKind.skull,
        MapPropKind.pot,
      ],
      landmarks: [
        MapPropKind.water,
        MapPropKind.fountain,
        MapPropKind.bones,
        MapPropKind.trap,
      ],
      ambient: Color(0xFF0C1404),
      wash: Color(0x48B0C028),
      floorBlend: Color(0x5A3A4810),
      projectileTint: Color(0xFFC8E040),
      corridorShade: Color(0x38101808),
      preferChoke: true,
      normalRoomChestChance: 0.12,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossFen,
        elite: CustomAssets.enemyCrab,
        trash: CustomAssets.enemyFenMite,
        swarm: CustomAssets.enemyFenMite,
        brute: CustomAssets.enemyCrab,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyFenMite,
        support: CustomAssets.enemySlime,
      ),
    ),
    'brass': _customZone(
      id: 'brass',
      props: [
        MapPropKind.anvil,
        MapPropKind.anvil,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.chest,
        MapPropKind.hatch,
        MapPropKind.crate,
        MapPropKind.barrel,
        MapPropKind.rubble,
        MapPropKind.torch,
        MapPropKind.stool,
        MapPropKind.shelf,
      ],
      landmarks: [
        MapPropKind.anvil,
        MapPropKind.pillar,
        MapPropKind.chest,
        MapPropKind.hatch,
      ],
      ambient: Color(0xFF120A04),
      wash: Color(0x48C89820),
      floorBlend: Color(0x5A483010),
      projectileTint: Color(0xFFE0C040),
      corridorShade: Color(0x38100800),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.44,
      normalRoomChestChance: 0.22,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossBrass,
        elite: CustomAssets.enemyGolem,
        trash: CustomAssets.enemyBrassMite,
        swarm: CustomAssets.enemyBrassMite,
        brute: CustomAssets.enemyGolem,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBrassMite,
        glass: CustomAssets.enemyBrassMite,
        support: CustomAssets.enemyBrassMite,
      ),
    ),
    'veil': _customZone(
      id: 'veil',
      props: [
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.bones,
        MapPropKind.crate,
        MapPropKind.barrel,
        MapPropKind.rubble,
        MapPropKind.skull,
        MapPropKind.pot,
      ],
      landmarks: [
        MapPropKind.trap,
        MapPropKind.fence,
        MapPropKind.bones,
        MapPropKind.torchAlt,
      ],
      ambient: Color(0xFF140812),
      wash: Color(0x52E8C8F8),
      floorBlend: Color(0x5A382438),
      projectileTint: Color(0xFFE8C0F0),
      corridorShade: Color(0x38100818),
      preferChoke: true,
      normalRoomChestChance: 0.10,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossVeil,
        elite: CustomAssets.enemyBat,
        trash: CustomAssets.enemyVeilMite,
        swarm: CustomAssets.enemyVeilMite,
        brute: CustomAssets.enemySpider,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyVeilMite,
        glass: CustomAssets.enemyVeilMite,
        support: CustomAssets.enemyCultist,
      ),
    ),
  };
}
