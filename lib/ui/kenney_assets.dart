import 'package:flutter/material.dart';

import '../core/hero_identity.dart';
import '../core/relic_ids.dart';
import '../models/enemy.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/zone_art.dart';
import '../spatial/tile_map.dart';
import 'custom_assets.dart';

/// Central Kenney Tiny Dungeon + UI asset catalog.
///
/// Tiny Dungeon files are kept as original `tile_XXXX.png` IDs (Kenney sheet
/// is 12×11). Semantic getters below map roles → tile indices so art cannot
/// drift from misnamed copies again. Rebuild with:
/// `powershell -File tool/rebuild_tiny_dungeon_assets.ps1`
///
/// Identity art (pets, armor icons, dungeon portraits) prefers [CustomAssets].
abstract final class KenneyAssets {
  static const String _tiny = 'assets/kenney/tiny_dungeon';
  static const String _ui = 'assets/kenney/ui_adventure';
  static const String _bars = 'assets/kenney/ui_bars';

  /// Original Kenney tile path (`tile_0000` … `tile_0131`).
  static String tile(int id) {
    assert(id >= 0 && id < 132, 'Tiny Dungeon tile id out of range: $id');
    final n = id.toString().padLeft(4, '0');
    return '$_tiny/tile_$n.png';
  }

  // —— Floors (verified sheet cells) ——
  static String get floorDirt => tile(0);
  static String get floorDirtAlt1 => tile(1);
  static String get floorDirtAlt2 => tile(2);
  static String get floorDirtAlt3 => tile(3);

  /// Pebbled dirt — preferred when we want readable texture.
  static String get floorDirtDetail => tile(24);

  /// Clean sand (no baked wall-lip). Legacy edged sand is tile 30 — do not use as floor fill.
  static String get floorSand => tile(48);
  static String get floorSandWorn => tile(49);
  static String get floorSandAlt1 => tile(49);
  static String get floorSandAlt2 => tile(49);
  static String get floorStone => tile(42);
  static String get floorStoneAlt1 => tile(42);
  static String get floorStoneAlt2 => tile(42);

  // —— Walls / doors / stairs ——
  static String get wallStone => tile(40);
  static String get wallStoneAlt1 => tile(57);
  static String get wallBanner => tile(29);
  static String get wallBannerAlt => tile(28);
  static String get doorArch => tile(6);
  static String get doorClosed => tile(45);
  static String get doorVariant => tile(46);
  static String get doorOpen => tile(47);
  static String get stairsDown => tile(17);
  static String get stairs => tile(18);
  static String get stairsBoss => tile(18);
  static String get exitPad => tile(19);
  static String get trapSpikes => tile(41);

  // —— Hazards / markers ——
  static String get hazardWater => tile(32);

  /// Warm red floor stain (distinct from spike trap tile 41).
  static String get hazardLava => tile(12);
  static String get corridorActive => tile(60);
  static String get corridorInactive => tile(61);
  static String get target => tile(60);
  static String get slash => tile(61);
  static String get claw => tile(62);
  static String get gravestone => tile(64);
  static String get gravestoneAlt => tile(65);
  static String get hatch => tile(66);

  // —— Props (verified against Tiny Dungeon sheet) ——
  static String get crate => tile(63);
  static String get table => tile(72);
  static String get stool => tile(73);
  static String get anvil => tile(74);
  static String get barrel => tile(82);
  static String get propPot => tile(73);
  static String get propBones => tile(56);
  static String get fountainSlime => tile(20);
  static String get propShelf => tile(75);
  static String get propFence => tile(76);
  static String get propPillar => tile(77);
  static String get propRubble => tile(79);
  static String get chestClosed => tile(89);
  static String get chestOpen => tile(90);
  static String get chestMimic => tile(92);

  /// Wall fountain / glow — Tiny Dungeon has no free-standing torch sprite.
  static String get torch => tile(8);

  /// Warm wall accent (not the slime fountain twin).
  static String get torchAlt => tile(25);

  // —— Heroes (custom intro-matched pixel art) ——
  static String get heroWizard => CustomAssets.heroWizard;
  static String get heroVillager => tile(85);
  static String get heroBearded => tile(86);
  static String get heroSoldier => tile(87);
  static String get heroRogue => CustomAssets.heroRogue;
  static String get heroKnight => CustomAssets.heroKnight;
  static String get heroWoman => tile(98);
  static String get heroHealer => CustomAssets.heroHealer;
  static String get heroElder => tile(100);

  // —— Enemies (custom identity sprites; Tiny Dungeon tiles kept as fallback IDs) ——
  static String get enemySlime => CustomAssets.enemySlime;
  static String get enemyCyclops => CustomAssets.enemyCyclops;
  static String get enemyCrab => CustomAssets.enemyCrab;
  static String get enemyBoss => CustomAssets.enemyBossKing;
  static String get enemyHellBoss => CustomAssets.enemyBossHell;
  static String get enemyCultist => CustomAssets.enemyCultist;
  static String get enemyBat => CustomAssets.enemyBat;
  static String get enemyGhost => CustomAssets.enemyGhost;
  static String get enemySpider => CustomAssets.enemySpider;
  static String get enemyRat => CustomAssets.enemyRat;
  static String get enemySnake => CustomAssets.enemySpider;
  static String get enemyGolem => CustomAssets.enemyGolem;
  static String get enemyCrystalBoss => CustomAssets.enemyCrystalBoss;
  static String get enemyCrystalWraith => CustomAssets.enemyCrystalWraith;
  static String get enemyCrystalMite => CustomAssets.enemyCrystalMite;
  static String get enemyStormBoss => CustomAssets.enemyBossStorm;
  static String get enemyStormMite => CustomAssets.enemyStormMite;
  static String get enemyRimeBoss => CustomAssets.enemyBossRime;
  static String get enemyRimeMite => CustomAssets.enemyRimeMite;
  static String get enemyFenBoss => CustomAssets.enemyBossFen;
  static String get enemyFenMite => CustomAssets.enemyFenMite;
  static String get enemyBrassBoss => CustomAssets.enemyBossBrass;
  static String get enemyBrassMite => CustomAssets.enemyBrassMite;
  static String get enemyVeilBoss => CustomAssets.enemyBossVeil;
  static String get enemyVeilMite => CustomAssets.enemyVeilMite;
  static String get enemyBossSandy => CustomAssets.enemyBossSandy;
  static String get enemySandyMite => CustomAssets.enemySandyMite;
  static String get enemyBossGoblin => CustomAssets.enemyBossGoblin;
  static String get enemyGoblinMite => CustomAssets.enemyGoblinMite;
  static String get enemyKingMite => CustomAssets.enemyKingMite;
  static String get enemyBossUnderworld => CustomAssets.enemyBossUnderworld;
  static String get enemyUnderworldMite => CustomAssets.enemyUnderworldMite;
  static String get enemyBossDead => CustomAssets.enemyBossDead;
  static String get enemyDeadMite => CustomAssets.enemyDeadMite;
  static String get enemyHellMite => CustomAssets.enemyHellMite;
  static String get enemyBossTide => CustomAssets.enemyBossTide;
  static String get enemyTideMite => CustomAssets.enemyTideMite;
  static String get enemyBossEmber => CustomAssets.enemyBossEmber;
  static String get enemyEmberMite => CustomAssets.enemyEmberMite;
  static String get enemyBossGrove => CustomAssets.enemyBossGrove;
  static String get enemyGroveMite => CustomAssets.enemyGroveMite;

  // —— Gear / consumables (custom identity icons; Tiny Dungeon tiles kept as fallback) ——
  static String get shieldRound => CustomAssets.iconShieldRound;
  static String get shield => CustomAssets.iconShield;
  static String get dagger => CustomAssets.iconDagger;
  static String get sword => CustomAssets.iconSword;
  static String get swordAlt => CustomAssets.iconSwordAlt;
  static String get hammer => CustomAssets.iconMace;
  static String get axe => CustomAssets.iconAxe;
  static String get potionGrey => tile(113);
  static String get potionGreen => CustomAssets.iconFlaskGreen;
  static String get potionRed => CustomAssets.iconFlask;
  static String get potionBlue => CustomAssets.iconFlaskBlue;
  static String get vialGrey => tile(125);
  static String get vialGreen => CustomAssets.iconFlaskGreen;
  static String get vialRed => CustomAssets.iconFlask;
  static String get vialBlue => CustomAssets.iconFlaskPurple;
  static String get staff => CustomAssets.iconStaff;
  static String get staffBlue => CustomAssets.iconStaffBlue;
  static String get spear => CustomAssets.iconSpear;
  static String get bow => CustomAssets.iconBow;
  static String get crossbow => CustomAssets.iconCrossbow;
  static String get gun => CustomAssets.iconGun;
  static String get wand => CustomAssets.iconWand;
  static String get fist => CustomAssets.iconFist;
  static String get thrown => CustomAssets.iconThrown;
  static String get boots => CustomAssets.iconBoots;
  static String get cloak => CustomAssets.iconCloak;
  static String get helmet => CustomAssets.iconHelm;
  static String get chestArmor => CustomAssets.iconChest;
  static String get gloves => CustomAssets.iconGloves;
  static String get shoulders => CustomAssets.iconShoulders;
  static String get belt => CustomAssets.iconBelt;
  static String get propSkull => gravestoneAlt;

  // —— Identity icons (custom; not Kenney extras) ——
  static String get book => CustomAssets.iconBook;
  static String get coinGold => CustomAssets.iconCoinGold;
  static String get ring => CustomAssets.iconRing;

  // —— UI panels & buttons ——
  static const String panelBrown = '$_ui/panel_brown.png';
  static const String panelBeige = '$_ui/panel_beige.png';
  static const String panelInsetBrown = '$_ui/panelInset_brown.png';
  static const String panelBorder = '$_ui/panel-border-015.png';
  static const String buttonBrown = '$_ui/button_brown.png';
  static const String buttonGrey = '$_ui/button_grey.png';
  static const String buttonRed = '$_ui/button_red.png';
  static const String hexagonBrown = '$_ui/hexagon_brown.png';
  static const String hexagonBrownDark = '$_ui/hexagon_brown_dark.png';

  // —— Progress bars (rounded) ——
  static const String progressGreen = '$_ui/progress_green.png';
  static const String progressGreenBorder = '$_ui/progress_green_border.png';
  static const String progressRed = '$_ui/progress_red.png';
  static const String progressRedBorder = '$_ui/progress_red_border.png';
  static const String progressBlue = '$_ui/progress_blue.png';
  static const String progressBlueBorder = '$_ui/progress_blue_border.png';
  static const String progressWhite = '$_ui/progress_white.png';

  // —— HP bar segments ——
  static const String barBackLeft = '$_bars/barBack_horizontalLeft.png';
  static const String barBackMid = '$_bars/barBack_horizontalMid.png';
  static const String barBackRight = '$_bars/barBack_horizontalRight.png';
  static const String barGreenLeft = '$_bars/barGreen_horizontalLeft.png';
  static const String barGreenMid = '$_bars/barGreen_horizontalMid.png';
  static const String barGreenRight = '$_bars/barGreen_horizontalRight.png';
  static const String barRedLeft = '$_bars/barRed_horizontalLeft.png';
  static const String barRedMid = '$_bars/barRed_horizontalMid.png';
  static const String barRedRight = '$_bars/barRed_horizontalRight.png';
  static const String barYellowLeft = '$_bars/barYellow_horizontalLeft.png';
  static const String barYellowMid = '$_bars/barYellow_horizontalMid.png';
  static const String barYellowRight = '$_bars/barYellow_horizontalRight.png';

  // —— Icons ——
  static String get iconCoin => CustomAssets.iconCoinGold;
  static String get iconSword => CustomAssets.iconSword;
  static String get iconCrown => CustomAssets.iconCrown;
  static String get iconCampfire => CustomAssets.iconCampfire;
  static String get iconShield => CustomAssets.iconShield;
  static String get iconTrophy => CustomAssets.iconTrophy;
  static String get iconDoor => CustomAssets.iconDoor;
  static String get iconStar => CustomAssets.iconStar;
  static String get iconHeart => CustomAssets.iconHeart;
  static String get iconSkull => CustomAssets.iconSkull;
  static String get iconBow => CustomAssets.iconBow;

  // —— Relics ——
  static String get relicWarBanner => CustomAssets.iconRelicWarBanner;
  static String get relicIronWard => CustomAssets.iconRelicIronWard;
  static String get relicPhoenixEmber => CustomAssets.iconRelicPhoenixEmber;

  static String heroSpriteForClass(HeroClassId classId) => switch (classId) {
    HeroClassId.warrior => CustomAssets.heroKnight,
    HeroClassId.paladin => CustomAssets.heroPaladin,
    HeroClassId.hunter => CustomAssets.heroHunter,
    HeroClassId.rogue => CustomAssets.heroRogue,
    HeroClassId.priest => CustomAssets.heroHealer,
    HeroClassId.deathKnight => CustomAssets.heroDeathKnight,
    HeroClassId.shaman => CustomAssets.heroShaman,
    HeroClassId.mage => CustomAssets.heroWizard,
    HeroClassId.warlock => CustomAssets.heroWarlock,
    HeroClassId.druid => CustomAssets.heroDruid,
  };

  static String heroSpriteForSpec(HeroSpecId specId) =>
      CustomAssets.heroForClass(HeroIdentity.spriteClassFor(specId));

  static Color? heroTintForSpec(HeroSpecId specId) {
    final argb = HeroIdentity.tintArgb(specId);
    return argb == null ? null : Color(argb);
  }

  static String floorForDungeon(String dungeonId) =>
      ZoneArt.byId(dungeonId).floor;

  /// Single verified floor per dungeon — sand uses a clean + worn pair.
  static List<String> floorVariantsForDungeon(String dungeonId) =>
      ZoneArt.byId(dungeonId).floorVariants;

  static String wallForDungeon(String dungeonId) =>
      ZoneArt.byId(dungeonId).wall;

  /// Rim wall sprites only (deep walls paint as void).
  static List<String> wallVariantsForDungeon(String dungeonId) =>
      ZoneArt.byId(dungeonId).wallVariants;

  static String exitSpriteFor({required bool boss}) =>
      boss ? stairsBoss : stairs;

  static String gateSprite({required bool open}) =>
      open ? doorOpen : doorClosed;

  static String propAsset(MapPropKind kind) => switch (kind) {
    MapPropKind.barrel => barrel,
    MapPropKind.crate => crate,
    MapPropKind.table => table,
    MapPropKind.stool => stool,
    MapPropKind.torch => torch,
    MapPropKind.torchAlt => torchAlt,
    MapPropKind.gravestone => gravestone,
    MapPropKind.fountain => fountainSlime,
    MapPropKind.trap => trapSpikes,
    MapPropKind.pot => propPot,
    MapPropKind.bones => propBones,
    MapPropKind.skull => gravestoneAlt,
    MapPropKind.hatch => hatch,
    MapPropKind.water => hazardWater,
    MapPropKind.lava => hazardLava,
    MapPropKind.anvil => anvil,
    MapPropKind.shelf => propShelf,
    MapPropKind.fence => propFence,
    MapPropKind.pillar => propPillar,
    MapPropKind.rubble => propRubble,
    MapPropKind.chest => chestClosed,
  };

  /// Weighted clutter pool (duplicates = more common).
  static List<MapPropKind> propPoolForDungeon(String dungeonId) =>
      ZoneArt.byId(dungeonId).props;

  static String dungeonIconFor(String dungeonId) =>
      ZoneArt.byId(dungeonId).hubIcon;

  /// Hub detail portrait for the selected dungeon (boss / theme).
  static String dungeonPortraitFor(String dungeonId) =>
      CustomAssets.dungeonPortrait(dungeonId);

  static String enemySpriteForRole(EnemyRole role, {String? dungeonId}) =>
      ZoneArt.byId(dungeonId ?? '').enemies.forRole(role);

  static String enemySpriteFor(EnemyUnit enemy, {String? dungeonId}) {
    if (enemy.role == EnemyRole.boss) {
      return enemySpriteForRole(EnemyRole.boss, dungeonId: dungeonId);
    }
    return enemySpriteForArchetype(enemy.archetype, dungeonId: dungeonId);
  }

  static String enemySpriteForArchetype(
    EnemyArchetype archetype, {
    String? dungeonId,
  }) => ZoneArt.byId(dungeonId ?? '').enemies.forArchetype(archetype);

  static List<String> get enemySpriteCatalog => [
    enemySlime,
    enemyRat,
    enemyBat,
    enemySpider,
    enemyGhost,
    enemyCultist,
    enemyCyclops,
    enemyCrab,
    enemyGolem,
    enemyBoss,
    enemyHellBoss,
    enemyCrystalBoss,
    enemyCrystalWraith,
    enemyCrystalMite,
    enemyStormBoss,
    enemyStormMite,
    enemyRimeBoss,
    enemyRimeMite,
    enemyFenBoss,
    enemyFenMite,
    enemyBrassBoss,
    enemyBrassMite,
    enemyVeilBoss,
    enemyVeilMite,
    // Append only — the painter looks sprites up by catalog index.
    enemyBossSandy,
    enemySandyMite,
    enemyBossGoblin,
    enemyGoblinMite,
    enemyKingMite,
    enemyBossUnderworld,
    enemyUnderworldMite,
    enemyBossDead,
    enemyDeadMite,
    enemyHellMite,
    enemyBossTide,
    enemyTideMite,
    enemyBossEmber,
    enemyEmberMite,
    enemyBossGrove,
    enemyGroveMite,
  ];

  static int enemySpriteCatalogIndex(String asset) {
    final i = enemySpriteCatalog.indexOf(asset);
    return i < 0 ? 0 : i;
  }

  /// Every enemy sprite one zone can spawn. The stage decodes this set
  /// instead of all 24 sprites, and reloads it when the zone changes.
  static Set<String> enemySpritesForDungeon(String dungeonId) =>
      ZoneArt.byId(dungeonId).enemies.all;

  /// Stable cosmetic sprite for a codex enemy name (aligned with combat families).
  static String enemySpriteForCodexName(String name) {
    final key = name.trim().toLowerCase();
    final mapped = switch (key) {
      // Catalog bosses — must match enemySpriteForRole(boss, dungeonId:).
      'earth kraken' => enemyBossSandy,
      'hobgoblin lord' => enemyBossGoblin,
      'corrupt king' => enemyBoss,
      'beholder' => enemyBossUnderworld,
      'the no-one' => enemyBossDead,
      'cthulhu' || 'chtulu' => enemyHellBoss,
      'tide leviathan' => enemyBossTide,
      'cinder sovereign' => enemyBossEmber,
      'wyrd root' => enemyBossGrove,
      'storm tyrant' => enemyStormBoss,
      'rime colossus' => enemyRimeBoss,
      'fen hydra' => enemyFenBoss,
      'the mainspring' => enemyBrassBoss,
      'the pale monarch' => enemyVeilBoss,
      'crystal warden' ||
      'crystal golem' ||
      'frozen bulwark' ||
      'glacial brute' ||
      'shard brawler' ||
      'shell leviathan' ||
      'barnacle guard' ||
      'tide brute' ||
      'coral crusher' => enemyCrystalBoss,
      'crystal wraith' ||
      'ice caster' ||
      'frost slinger' ||
      'rime chanter' ||
      'frost adept' ||
      'splinter blade' ||
      'shatter fang' ||
      'spume spitter' ||
      'salt slinger' ||
      'depth chanter' ||
      'tide adept' ||
      'razor eel' ||
      'needle urchin' => enemyCrystalWraith,
      'crystal mite' || 'frost wisp' || 'rime bat' => enemyCrystalMite,
      // Zone trash with its own art (see lib/models/zone_art.dart).
      'brine mite' || 'reef tick' => enemyTideMite,
      'sand skitter' || 'glass skitter' => enemySandyMite,
      'goblin scrapper' || 'hideout runt' || 'pest' => enemyGoblinMite,
      'fort rat' || 'keep gnawer' => enemyKingMite,
      'imp swarm' || 'ash tick' => enemyUnderworldMite,
      'risen husk' || 'bone swarm' => enemyDeadMite,
      'hellspawn' || 'cinder rat' => enemyHellMite,
      'ash mite' || 'cinder tick' => enemyEmberMite,
      'moss slime' || 'root tick' || 'leaf mite' => enemyGroveMite,
      'king crab' || 'cave king' => enemyCrab,
      'hell lord' || 'hellgate tyrant' => enemyHellBoss,
      'vault brute' ||
      'slag brawler' ||
      'basalt golem' ||
      'ember bulwark' => enemyBoss,
      'spark caster' ||
      'cinder slinger' ||
      'ash chanter' ||
      'ember adept' => enemyCultist,
      'char blade' || 'soot fang' => enemyRat,
      'grove brute' ||
      'timber crusher' ||
      'hollow guard' ||
      'bark bulwark' => enemySpider,
      'spore bat' ||
      'canopy spitter' ||
      'wyrd chanter' ||
      'grove adept' => enemyBat,
      'thorn skitter' || 'bramble fang' => enemySlime,
      'gale mite' || 'storm tick' || 'spark bat' => enemyStormMite,
      'storm brute' ||
      'thunder crusher' ||
      'gale bulwark' ||
      'storm guard' => enemyGolem,
      'volt spitter' || 'gale slinger' => enemyBat,
      'lightning fang' || 'zephyr blade' => enemyRat,
      'storm chanter' || 'tempest adept' => enemyCultist,
      'rime mite' || 'frost tick' || 'glass flea' => enemyRimeMite,
      'rime brute' ||
      'frost crusher' ||
      'glass bulwark' ||
      'rime guard' => enemyGolem,
      'shard slinger' || 'rime spitter' => enemyGhost,
      'glass fang' || 'frost blade' => enemyRimeMite,
      'glacier chanter' || 'stillfrost adept' => enemyGhost,
      'bile slime' || 'fen tick' || 'spore flea' => enemyFenMite,
      'fen brute' ||
      'mire crusher' ||
      'bog bulwark' ||
      'fen guard' => enemySlime,
      'bile spitter' || 'fen slinger' => enemyBat,
      'rot fang' || 'mire blade' => enemyFenMite,
      'fen chanter' || 'mire adept' => enemyCultist,
      'cog mite' || 'rust tick' || 'brass flea' => enemyBrassMite,
      'vault bruiser' || 'cog crusher' => enemyCyclops,
      'brass bulwark' || 'cog guard' => enemyGolem,
      'spark spitter' || 'coil slinger' => enemyBat,
      'razor cog' || 'spring fang' => enemyBrassMite,
      'clock chanter' || 'brass adept' => enemyCultist,
      'dust moth' || 'veil mite' || 'silk flea' => enemyVeilMite,
      'silk bruiser' || 'veil crusher' => enemySpider,
      'cocoon guard' || 'veil bulwark' => enemyGhost,
      'dust spitter' || 'silk slinger' => enemyBat,
      'wing fang' || 'veil blade' => enemySpider,
      'moth chanter' || 'veil adept' => enemyCultist,
      'cave slime' || 'drip ooze' || 'sand mite' => enemySlime,
      'spit bat' || 'cavern spitter' => enemyBat,
      'needle rat' || 'sneak rat' => enemyRat,
      'rock crab' || 'shellback' || 'stone maw' => enemyCrab,
      'goblin thug' || 'clubber' || 'club champion' || 'lord thug' => enemyCrab,
      'cave brute' ||
      'fort sentry' ||
      'hall guard' ||
      'elite brute' ||
      'bone brute' ||
      'crypt brute' ||
      'infernal brute' ||
      'flame guard' => enemyCyclops,
      'stash bulwark' ||
      'bulwark golem' ||
      'obsidian golem' ||
      'molten golem' ||
      'ash colossus' ||
      'iron ward' ||
      'gate knight' ||
      'tomb shield' ||
      'ossuary guard' ||
      'pit guard' => enemyGolem,
      'hideout guard' ||
      'scrap shield' ||
      'lord guard' => enemyCyclops,
      'hex cultist' ||
      'glow cultist' ||
      'mire shaman' ||
      'court mage' ||
      'banner cleric' ||
      'cult chanter' ||
      'rift adept' ||
      'necro acolyte' ||
      'death chanter' ||
      'fire cultist' ||
      'hell chanter' ||
      'rift priest' => enemyCultist,
      'hex witch' ||
      'totem caller' ||
      'hex hag' ||
      'lord hexer' => enemyGhost,
      'hex spider' => enemySpider,
      'wailing ghost' ||
      'specter blade' ||
      'pale reaper' ||
      'grave knight' => enemyGhost,
      'blood stalker' ||
      'cutthroat' ||
      'knife kin' ||
      'coin cutter' ||
      'lord blade' ||
      'loot snatcher' ||
      'royal assassin' ||
      'blade page' ||
      'shade stalker' ||
      'wisp blade' ||
      'flame assassin' ||
      'cinder blade' => enemyRat,
      'stash guard' || 'raid pack' || 'lord pack' => enemyGoblinMite,
      'goblin slinger' ||
      'dart rascal' ||
      'raid slinger' ||
      'lord slinger' => enemyBat,
      'crossbowman' ||
      'tower archer' ||
      'ember archer' ||
      'bone archer' ||
      'warden archer' => enemyBat,
      'underworld imp' => enemyCultist,
      'warden shield' || 'warden guard' || 'warden adept' => enemyGolem,
      _ => null,
    };
    if (mapped != null) return mapped;

    if (key.contains('mothveil') ||
        key.contains('monarch') ||
        key.contains('moth ') ||
        key.contains('silk') ||
        (key.contains('veil') && !key.contains('brass'))) {
      if (key.contains('monarch')) return enemyVeilBoss;
      if (key.contains('chanter') || key.contains('adept')) {
        return enemyCultist;
      }
      if (key.contains('spitter') || key.contains('slinger')) {
        return enemyBat;
      }
      if (key.contains('bruiser') || key.contains('crusher')) {
        return enemySpider;
      }
      if (key.contains('bulwark') || key.contains('guard')) {
        return enemyGhost;
      }
      if (key.contains('fang') || key.contains('blade')) {
        return enemySpider;
      }
      return enemyVeilMite;
    }

    if (key.contains('crystal') ||
        key.contains('frost') ||
        key.contains('rime') ||
        key.contains('glacial') ||
        key.contains('shard') ||
        key.contains('splinter') ||
        key.contains('shatter') ||
        key.contains('tide') ||
        key.contains('brine') ||
        key.contains('reef') ||
        key.contains('coral') ||
        key.contains('barnacle') ||
        key.contains('spume')) {
      if (key.contains('wisp') ||
          key.contains('mite') ||
          key.contains('bat') ||
          key.contains('tick')) {
        return enemyCrystalMite;
      }
      if (key.contains('wraith') ||
          key.contains('caster') ||
          key.contains('adept') ||
          key.contains('chanter') ||
          key.contains('slinger') ||
          key.contains('spitter') ||
          key.contains('blade') ||
          key.contains('fang') ||
          key.contains('eel') ||
          key.contains('urchin')) {
        return enemyCrystalWraith;
      }
      return enemyCrystalBoss;
    }
    if (key.contains('slime') || key.contains('ooze') || key.contains('mite')) {
      return enemySlime;
    }
    if (key.contains('spider') || key.contains('tick') || key.contains('imp')) {
      return enemySpider;
    }
    if (key.contains('ghost') ||
        key.contains('specter') ||
        key.contains('wailing') ||
        key.contains('risen') ||
        key.contains('bone') ||
        key.contains('tomb') ||
        key.contains('grave') ||
        key.contains('necro') ||
        key.contains('pale')) {
      return enemyGhost;
    }
    if (key.contains('cult') ||
        key.contains('shaman') ||
        key.contains('witch') ||
        key.contains('mage') ||
        key.contains('chanter') ||
        key.contains('cleric') ||
        key.contains('priest') ||
        key.contains('adept')) {
      return enemyCultist;
    }
    if (key.contains('golem') ||
        key.contains('ward') ||
        key.contains('shield') ||
        key.contains('knight') ||
        key.contains('colossus') ||
        key.contains('guard')) {
      return enemyGolem;
    }
    if (key.contains('crab') || key.contains('shell') || key.contains('maw')) {
      return enemyCrab;
    }
    if (key.contains('bat') ||
        key.contains('spit') ||
        key.contains('archer') ||
        key.contains('slinger') ||
        key.contains('crossbow')) {
      return enemyBat;
    }
    if (key.contains('brute') ||
        key.contains('thug') ||
        key.contains('cyclops') ||
        key.contains('sentry')) {
      return enemyCyclops;
    }
    if (key.contains('mainspring') ||
        key.contains('brassvault') ||
        (key.contains('brass') && !key.contains('ember'))) {
      if (key.contains('mainspring')) return enemyBrassBoss;
      if (key.contains('chanter') || key.contains('adept')) {
        return enemyCultist;
      }
      if (key.contains('spitter') || key.contains('slinger')) {
        return enemyBat;
      }
      if (key.contains('bulwark') || key.contains('guard')) {
        return enemyGolem;
      }
      if (key.contains('bruiser') || key.contains('crusher')) {
        return enemyCyclops;
      }
      return enemyBrassMite;
    }
    if (key.contains('fen') ||
        key.contains('bile') ||
        key.contains('blight') ||
        key.contains('hydra')) {
      if (key.contains('hydra')) return enemyFenBoss;
      if (key.contains('chanter') || key.contains('adept')) {
        return enemyCultist;
      }
      if (key.contains('spitter') || key.contains('slinger')) {
        return enemyBat;
      }
      return enemyFenMite;
    }
    if (key.contains('rime') ||
        key.contains('frost') ||
        (key.contains('glass') && !key.contains('hour'))) {
      if (key.contains('colossus')) return enemyRimeBoss;
      if (key.contains('brute') ||
          key.contains('crusher') ||
          key.contains('bulwark') ||
          key.contains('guard')) {
        return enemyGolem;
      }
      if (key.contains('chanter') || key.contains('adept')) {
        return enemyGhost;
      }
      if (key.contains('slinger') || key.contains('spitter')) {
        return enemyGhost;
      }
      return enemyRimeMite;
    }
    if (key.contains('storm') ||
        key.contains('gale') ||
        key.contains('thunder') ||
        key.contains('tempest') ||
        key.contains('volt') ||
        key.contains('zephyr') ||
        key.contains('lightning')) {
      if (key.contains('tyrant')) return enemyGhost;
      if (key.contains('brute') ||
          key.contains('crusher') ||
          key.contains('bulwark') ||
          key.contains('guard')) {
        return enemyGolem;
      }
      if (key.contains('chanter') || key.contains('adept')) {
        return enemyCultist;
      }
      if (key.contains('fang') || key.contains('blade')) {
        return enemyRat;
      }
      return enemyBat;
    }
    if (key.contains('hell') ||
        key.contains('infernal') ||
        key.contains('flame') ||
        key.contains('cinder') ||
        key.contains('ember') ||
        key.contains('ash') ||
        key.contains('slag') ||
        key.contains('basalt') ||
        key.contains('soot') ||
        key.contains('char')) {
      if (key.contains('sovereign') || key.contains('lord')) {
        return enemyHellBoss;
      }
      if (key.contains('brute') ||
          key.contains('brawler') ||
          key.contains('golem') ||
          key.contains('bulwark')) {
        return enemyBoss;
      }
      if (key.contains('blade') || key.contains('fang')) {
        return enemyRat;
      }
      return enemyCultist;
    }
    if (key.contains('rat') ||
        key.contains('skitter') ||
        key.contains('stalker') ||
        key.contains('assassin') ||
        key.contains('blade') ||
        key.contains('scrapper') ||
        key.contains('pest')) {
      return enemyRat;
    }
    // Prefer dungeon-default slime over hash lottery for unknown names.
    return enemySlime;
  }

  static String lootIconFor(LootRarity rarity) => switch (rarity) {
    LootRarity.common => coinGold,
    LootRarity.uncommon => potionGreen,
    LootRarity.rare => vialBlue,
    LootRarity.epic => chestClosed,
    LootRarity.legendary => chestClosed,
  };

  static String equipmentIconFor(EquipmentItem item) {
    if (item.iconId != null) {
      switch (item.iconId) {
        case 'bow':
          return bow;
        case 'book':
          return CustomAssets.iconTome;
        case 'bandage':
          return potionGreen;
        case 'flask':
          return potionRed;
        default:
          break;
      }
    }

    if (item.slot == EquipmentSlot.offHand) {
      if (item.offHandKind == OffHandKind.frill) return CustomAssets.iconTome;
      if (item.offHandKind == OffHandKind.weapon) {
        return switch (item.weaponType) {
          WeaponType.dagger => dagger,
          WeaponType.axe => axe,
          WeaponType.mace => hammer,
          WeaponType.fist => fist,
          _ => sword,
        };
      }
      return item.rarity.index >= 1 ? shield : shieldRound;
    }

    if (item.slot == EquipmentSlot.weapon ||
        item.slot == EquipmentSlot.ranged) {
      return switch (item.weaponType) {
        WeaponType.axe => axe,
        WeaponType.sword => item.rarity.index >= 2 ? swordAlt : sword,
        WeaponType.mace => hammer,
        WeaponType.dagger => dagger,
        WeaponType.fist => fist,
        WeaponType.staff => item.rarity.index >= 2 ? staffBlue : staff,
        WeaponType.polearm => spear,
        WeaponType.bow => bow,
        WeaponType.crossbow => crossbow,
        WeaponType.gun => gun,
        WeaponType.thrown => thrown,
        WeaponType.wand => wand,
        null => switch (item.affinity) {
          'mage' => item.rarity.index >= 2 ? staffBlue : staff,
          'rogue' => dagger,
          'healer' => item.rarity.index >= 2 ? staffBlue : spear,
          'warrior' =>
            item.rarity.index >= 3
                ? axe
                : (item.rarity.index >= 2 ? swordAlt : sword),
          _ => sword,
        },
      };
    }

    return switch (item.slot) {
      EquipmentSlot.head => helmet,
      EquipmentSlot.shoulder => shoulders,
      EquipmentSlot.chest => chestArmor,
      EquipmentSlot.waist => belt,
      EquipmentSlot.legs => CustomAssets.iconLegs,
      EquipmentSlot.wrist => CustomAssets.iconWrist,
      EquipmentSlot.hands => gloves,
      EquipmentSlot.cloak => cloak,
      EquipmentSlot.boots => boots,
      EquipmentSlot.neck => CustomAssets.iconNeck,
      EquipmentSlot.ring || EquipmentSlot.ring2 => CustomAssets.iconRing,
      EquipmentSlot.trinket ||
      EquipmentSlot.trinket2 => CustomAssets.iconTrinket,
      EquipmentSlot.consumable => switch (item.rarity) {
        LootRarity.common => potionRed,
        LootRarity.uncommon => potionGreen,
        LootRarity.rare => potionBlue,
        LootRarity.epic => vialBlue,
        LootRarity.legendary => vialBlue,
      },
      _ => sword,
    };
  }

  static String lootDropIconFor(LootDrop drop) {
    final item = drop.equipment;
    if (item != null) return equipmentIconFor(item);
    final name = drop.name.toLowerCase();
    if (name.contains('gold')) return coinGold;
    if (name.contains('essence')) return vialBlue;
    if (name.contains('relic') || name.contains('shard')) return ring;
    if (name.contains('sigil')) return iconTrophy;
    if (name.contains('dust')) return potionGreen;
    return lootIconFor(drop.rarity);
  }

  static String relicIconFor(String relicId) => switch (relicId) {
    RelicIds.warBanner => relicWarBanner,
    RelicIds.ironWard => relicIronWard,
    RelicIds.phoenixEmber => relicPhoenixEmber,
    RelicIds.godHandFocus => fist,
    RelicIds.chamberLuck => iconStar,
    RelicIds.ironWill => iconTrophy,
    _ => relicWarBanner,
  };

  static String forgeIconFor(String title) {
    final upper = title.toUpperCase();
    if (upper.contains('ATTACK SPEED') || upper.contains('HASTE')) {
      return dagger;
    }
    if (upper.contains('MOVE') || upper.contains('SPEED')) return boots;
    if (upper.contains('CRIT')) return iconStar;
    if (upper.contains('ATTACK')) return sword;
    if (upper.contains('DEFENSE')) return shield;
    if (upper.contains('VITALITY')) return potionRed;
    if (upper.contains('TRAIN')) return book;
    if (upper.contains('FORGE') || upper.contains('ANVIL')) return anvil;
    return hammer;
  }

  /// Best-effort icon for a discovered Codex item name (cosmetic only).
  static String codexItemIconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('gold') || lower.contains('coin')) return coinGold;
    if (lower.contains('potion') || lower.contains('flask')) return potionRed;
    if (lower.contains('essence') || lower.contains('vial')) return vialBlue;
    if (lower.contains('helm') ||
        lower.contains('hood') ||
        lower.contains('crown')) {
      return helmet;
    }
    if (lower.contains('boot') || lower.contains('greave')) return boots;
    if (lower.contains('glove') || lower.contains('gaunt')) return gloves;
    if (lower.contains('cloak') || lower.contains('cape')) return cloak;
    if (lower.contains('shield') || lower.contains('buckler')) return shield;
    if (lower.contains('crossbow')) return crossbow;
    if (lower.contains('gun') ||
        lower.contains('pistol') ||
        lower.contains('rifle')) {
      return gun;
    }
    if (lower.contains('bow')) return bow;
    if (lower.contains('wand')) return wand;
    if (lower.contains('staff') || lower.contains('tome')) {
      return staff;
    }
    if (lower.contains('fist') || lower.contains('knuckle')) return fist;
    if (lower.contains('dagger') || lower.contains('knife')) return dagger;
    if (lower.contains('axe')) return axe;
    if (lower.contains('hammer') || lower.contains('mace')) return hammer;
    if (lower.contains('ring') || lower.contains('band')) {
      return CustomAssets.iconRing;
    }
    if (lower.contains('amulet') ||
        lower.contains('neck') ||
        lower.contains('pendant')) {
      return CustomAssets.iconNeck;
    }
    if (lower.contains('chest') ||
        lower.contains('mail') ||
        lower.contains('plate')) {
      return chestArmor;
    }
    final catalog = <String>[
      sword,
      shield,
      helmet,
      chestArmor,
      boots,
      gloves,
      staff,
      dagger,
      CustomAssets.iconRing,
      potionGreen,
    ];
    final hash = name.hashCode & 0x7fffffff;
    return catalog[hash % catalog.length];
  }
}
