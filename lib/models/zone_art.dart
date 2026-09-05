import 'dart:ui' show Color;

import '../spatial/tile_map.dart' show MapPropKind;
import '../assets/custom_assets.dart';
import '../assets/kenney_assets.dart';
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
      // Buried dig sites: hatches + rubble, not generic barrel/crate dens.
      props: [
        MapPropKind.hatch,
        MapPropKind.hatch,
        MapPropKind.hatch,
        MapPropKind.rubble,
        MapPropKind.rubble,
        MapPropKind.shelf,
        MapPropKind.shelf,
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.crate,
        MapPropKind.barrel,
        MapPropKind.table,
      ],
      landmarks: [MapPropKind.hatch, MapPropKind.hatch, MapPropKind.rubble],
      ambient: Color(0xFF0C0A08),
      wash: Color(0x44C88840),
      floorBlend: Color(0x66A07038),
      projectileTint: Color(0xFFE0A050),
      normalRoomChestChance: 0.12,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossSandy,
        elite: CustomAssets.enemySlime,
        trash: CustomAssets.enemySlime,
        swarm: CustomAssets.enemySandyMite,
        brute: CustomAssets.enemyCrab,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemySandyMite,
        support: CustomAssets.enemyRat,
      ),
    ),
    'goblin': _customZone(
      id: 'goblin',
      // Worn dirt + raider junk; chests come from alcoves, not landmark spam.
      props: [
        MapPropKind.barrel,
        MapPropKind.barrel,
        MapPropKind.crate,
        MapPropKind.crate,
        MapPropKind.table,
        MapPropKind.stool,
        MapPropKind.bones,
        MapPropKind.pot,
        MapPropKind.skull,
        MapPropKind.shelf,
        MapPropKind.rubble,
        MapPropKind.torch,
      ],
      landmarks: [
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.barrel,
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
        // Distinct mid-pack from King's Fort (no shared cyclops/golem pair).
        brute: CustomAssets.enemySpider,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyGoblinMite,
        support: CustomAssets.enemyGoblinMite,
      ),
    ),
    'king': _customZone(
      id: 'king',
      wall: KenneyAssets.wallBanner,
      // Throne hall — pillars/tables, not forge anvils as the signature.
      props: [
        MapPropKind.torch,
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.table,
        MapPropKind.table,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.fence,
        MapPropKind.stool,
        MapPropKind.shelf,
        MapPropKind.crate,
        MapPropKind.barrel,
      ],
      landmarks: [
        MapPropKind.pillar,
        MapPropKind.table,
        MapPropKind.chest,
        MapPropKind.torch,
      ],
      ambient: Color(0xFF080A10),
      wash: Color(0x3A3060A0),
      floorBlend: Color(0x5A203048),
      projectileTint: Color(0xFF70A0E0),
      normalRoomChestChance: 0.1,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossKing,
        elite: CustomAssets.enemySpider,
        trash: CustomAssets.enemyKingMite,
        swarm: CustomAssets.enemyKingMite,
        brute: CustomAssets.enemyGolem,
        tank: CustomAssets.enemyCyclops,
        ranged: CustomAssets.enemyCultist,
        glass: CustomAssets.enemyKingMite,
        support: CustomAssets.enemyKingMite,
      ),
    ),
    'underworld': _customZone(
      id: 'underworld',
      // Eye shrines + pillars — less bone/grave overlap with City of Dead.
      props: [
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.fountain,
        MapPropKind.fountain,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.fence,
        MapPropKind.pot,
        MapPropKind.rubble,
        MapPropKind.crate,
        MapPropKind.skull,
      ],
      landmarks: [
        MapPropKind.fountain,
        MapPropKind.pillar,
        MapPropKind.torchAlt,
        MapPropKind.skull,
      ],
      ambient: Color(0xFF0A0810),
      wash: Color(0x447040B0),
      floorBlend: Color(0x66281840),
      projectileTint: Color(0xFFA070E0),
      // Darker corridors than Hell's gate fire-glow.
      corridorShade: Color(0x48081020),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.28,
      normalRoomChestChance: 0.12,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossUnderworld,
        elite: CustomAssets.enemyCyclops,
        trash: CustomAssets.enemyUnderworldMite,
        swarm: CustomAssets.enemyUnderworldMite,
        brute: CustomAssets.enemyUnderworldMite,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyUnderworldMite,
        glass: CustomAssets.enemyUnderworldMite,
        support: CustomAssets.enemyCultist,
      ),
    ),
    'dead': _customZone(
      id: 'dead',
      props: [
        MapPropKind.gravestone,
        MapPropKind.gravestone,
        MapPropKind.gravestone,
        MapPropKind.bones,
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.fence,
        MapPropKind.rubble,
        MapPropKind.pillar,
        MapPropKind.torch,
        MapPropKind.hatch,
      ],
      landmarks: [
        MapPropKind.gravestone,
        MapPropKind.gravestone,
        MapPropKind.bones,
        MapPropKind.skull,
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
        ranged: CustomAssets.enemyDeadMite,
        glass: CustomAssets.enemyGhost,
        support: CustomAssets.enemyGhost,
      ),
    ),
    'hell': _customZone(
      id: 'hell',
      props: [
        MapPropKind.torch,
        MapPropKind.torchAlt,
        MapPropKind.torchAlt,
        MapPropKind.lava,
        MapPropKind.lava,
        MapPropKind.trap,
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.rubble,
        MapPropKind.pillar,
        MapPropKind.barrel,
      ],
      landmarks: [
        MapPropKind.lava,
        MapPropKind.skull,
        MapPropKind.bones,
        MapPropKind.torchAlt,
      ],
      ambient: Color(0xFF120606),
      // Deep blood-crimson — distinct from Ashen Vault amber.
      wash: Color(0x54B01420),
      floorBlend: Color(0x6A401010),
      projectileTint: Color(0xFFE04038),
      corridorShade: Color(0x40000000),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.30,
      normalRoomChestChance: 0.14,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossHell,
        elite: CustomAssets.enemyHellMite,
        trash: CustomAssets.enemyHellMite,
        swarm: CustomAssets.enemyHellMite,
        brute: CustomAssets.enemyGolem,
        tank: CustomAssets.enemyGolem,
        ranged: CustomAssets.enemyHellMite,
        glass: CustomAssets.enemyHellMite,
        support: CustomAssets.enemyCultist,
      ),
    ),
    'crystal': _customZone(
      id: 'crystal',
      // Spire grammar: pillars + fountains (no forge anvil).
      props: [
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.fountain,
        MapPropKind.fountain,
        MapPropKind.chest,
        MapPropKind.fence,
        MapPropKind.torch,
        MapPropKind.hatch,
        MapPropKind.stool,
        MapPropKind.crate,
      ],
      landmarks: [
        MapPropKind.pillar,
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
      // Drowned fort: pillars + hatches with flood water, not pure pool rooms.
      props: [
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.hatch,
        MapPropKind.hatch,
        MapPropKind.fountain,
        MapPropKind.barrel,
        MapPropKind.pot,
        MapPropKind.fence,
      ],
      landmarks: [
        MapPropKind.pillar,
        MapPropKind.hatch,
        MapPropKind.water,
        MapPropKind.fountain,
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
        brute: CustomAssets.enemyTideBrute,
        tank: CustomAssets.enemyTideBrute,
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
        MapPropKind.torchAlt,
      ],
      ambient: Color(0xFF160A02),
      // Amber-gold forge wash — far from Hell's blood crimson.
      wash: Color(0x5CF0A010),
      floorBlend: Color(0x5A503010),
      projectileTint: Color(0xFFF0B028),
      corridorShade: Color(0x3C100800),
      preferChoke: true,
      preferTreasureAlcove: true,
      treasureAlcoveChance: 0.32,
      normalRoomChestChance: 0.18,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossEmber,
        elite: CustomAssets.enemyEmberElite,
        trash: CustomAssets.enemyEmberMite,
        swarm: CustomAssets.enemyEmberMite,
        brute: CustomAssets.enemyEmberBrute,
        tank: CustomAssets.enemyEmberBrute,
        ranged: CustomAssets.enemyEmberMite,
        glass: CustomAssets.enemyEmberMite,
        support: CustomAssets.enemySpider,
      ),
    ),
    'grove': _customZone(
      id: 'grove',
      // Canopy clutter: fences + pots + shelves stand in for root lattice.
      props: [
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.pot,
        MapPropKind.pot,
        MapPropKind.pot,
        MapPropKind.shelf,
        MapPropKind.shelf,
        MapPropKind.fountain,
        MapPropKind.bones,
        MapPropKind.rubble,
      ],
      landmarks: [
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.fountain,
        MapPropKind.shelf,
      ],
      ambient: Color(0xFF041208),
      wash: Color(0x5848A838),
      floorBlend: Color(0x5A1E3820),
      projectileTint: Color(0xFF58B050),
      corridorShade: Color(0x38081008),
      preferChoke: true,
      normalRoomChestChance: 0.12,
      landmarkPerChamber: 3,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossGrove,
        elite: CustomAssets.enemySpider,
        trash: CustomAssets.enemyGroveMite,
        swarm: CustomAssets.enemyGroveMite,
        brute: CustomAssets.enemySpider,
        tank: CustomAssets.enemyGroveMite,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyGroveMite,
        support: CustomAssets.enemyRat,
      ),
    ),
    'storm': _customZone(
      id: 'storm',
      // Lightning rods: traps + alt torches + pillars (not underworld purple).
      props: [
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.torchAlt,
        MapPropKind.torchAlt,
        MapPropKind.torchAlt,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.rubble,
        MapPropKind.fence,
        MapPropKind.bones,
        MapPropKind.torch,
      ],
      landmarks: [
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.torchAlt,
        MapPropKind.pillar,
      ],
      ambient: Color(0xFF060A18),
      wash: Color(0x504878E8),
      floorBlend: Color(0x5A182848),
      projectileTint: Color(0xFFD0E8FF),
      corridorShade: Color(0x3A081028),
      preferChoke: true,
      normalRoomChestChance: 0.08,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossStorm,
        elite: CustomAssets.enemyStormWraith,
        trash: CustomAssets.enemyStormMite,
        swarm: CustomAssets.enemyStormMite,
        brute: CustomAssets.enemyStormBrute,
        tank: CustomAssets.enemyStormBrute,
        ranged: CustomAssets.enemyStormWraith,
        glass: CustomAssets.enemyStormMite,
        support: CustomAssets.enemyStormMite,
      ),
    ),
    'rime': _customZone(
      id: 'rime',
      // Ice rift: pillars + frozen fountains — not tide water pools.
      props: [
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.fountain,
        MapPropKind.fountain,
        MapPropKind.fence,
        MapPropKind.rubble,
        MapPropKind.rubble,
        MapPropKind.bones,
        MapPropKind.chest,
        MapPropKind.pot,
        MapPropKind.shelf,
      ],
      landmarks: [
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.fountain,
        MapPropKind.fence,
      ],
      ambient: Color(0xFF041018),
      wash: Color(0x4860D8E0),
      floorBlend: Color(0x5A184860),
      projectileTint: Color(0xFF70E8F0),
      corridorShade: Color(0x38081828),
      preferTreasureAlcove: true,
      // Cold fantasy over loot-alcove spam.
      treasureAlcoveChance: 0.34,
      normalRoomChestChance: 0.20,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossRime,
        elite: CustomAssets.enemyRimeWraith,
        trash: CustomAssets.enemyRimeMite,
        swarm: CustomAssets.enemyRimeMite,
        brute: CustomAssets.enemyRimeBrute,
        tank: CustomAssets.enemyRimeBrute,
        ranged: CustomAssets.enemyRimeMite,
        glass: CustomAssets.enemyRimeMite,
        support: CustomAssets.enemyBat,
      ),
    ),
    'fen': _customZone(
      id: 'fen',
      // Poison bog: water + traps — blight, not spider-grove.
      props: [
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.water,
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.fountain,
        MapPropKind.bones,
        MapPropKind.skull,
        MapPropKind.rubble,
        MapPropKind.pot,
        MapPropKind.barrel,
      ],
      landmarks: [
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.water,
        MapPropKind.bones,
      ],
      ambient: Color(0xFF0C1404),
      wash: Color(0x50B8C820),
      floorBlend: Color(0x5A3A4810),
      projectileTint: Color(0xFFC8E040),
      corridorShade: Color(0x38101808),
      preferChoke: true,
      normalRoomChestChance: 0.12,
      landmarkPerChamber: 2,
      enemies: ZoneEnemyArt(
        boss: CustomAssets.enemyBossFen,
        elite: CustomAssets.enemyFenElite,
        trash: CustomAssets.enemyFenMite,
        swarm: CustomAssets.enemyFenMite,
        brute: CustomAssets.enemyFenBrute,
        tank: CustomAssets.enemyFenBrute,
        ranged: CustomAssets.enemyBat,
        glass: CustomAssets.enemyFenMite,
        support: CustomAssets.enemySlime,
      ),
    ),
    'brass': _customZone(
      id: 'brass',
      // Clockwork vault: anvils + pillars + stools — not sandy hatches.
      props: [
        MapPropKind.anvil,
        MapPropKind.anvil,
        MapPropKind.pillar,
        MapPropKind.pillar,
        MapPropKind.chest,
        MapPropKind.stool,
        MapPropKind.stool,
        MapPropKind.shelf,
        MapPropKind.rubble,
        MapPropKind.torch,
        MapPropKind.crate,
        MapPropKind.fence,
      ],
      landmarks: [
        MapPropKind.anvil,
        MapPropKind.pillar,
        MapPropKind.chest,
        MapPropKind.stool,
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
        elite: CustomAssets.enemyBrassElite,
        trash: CustomAssets.enemyBrassMite,
        swarm: CustomAssets.enemyBrassMite,
        brute: CustomAssets.enemyBrassBrute,
        tank: CustomAssets.enemyBrassBrute,
        ranged: CustomAssets.enemyBrassMite,
        glass: CustomAssets.enemyBrassMite,
        support: CustomAssets.enemyBrassMite,
      ),
    ),
    'veil': _customZone(
      id: 'veil',
      // Silk dens: fence webs + trap strands + pale torch glow.
      props: [
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.trap,
        MapPropKind.trap,
        MapPropKind.torchAlt,
        MapPropKind.torchAlt,
        MapPropKind.bones,
        MapPropKind.pot,
        MapPropKind.skull,
        MapPropKind.rubble,
        MapPropKind.torch,
      ],
      landmarks: [
        MapPropKind.fence,
        MapPropKind.fence,
        MapPropKind.trap,
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
        elite: CustomAssets.enemyVeilElite,
        trash: CustomAssets.enemyVeilMite,
        swarm: CustomAssets.enemyVeilMite,
        brute: CustomAssets.enemyVeilBrute,
        tank: CustomAssets.enemyVeilBrute,
        ranged: CustomAssets.enemyVeilMite,
        glass: CustomAssets.enemyVeilMite,
        support: CustomAssets.enemyBat,
      ),
    ),
  };
}
