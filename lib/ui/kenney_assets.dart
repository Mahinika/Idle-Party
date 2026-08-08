import '../core/game_logic.dart';
import '../models/dungeon_def.dart';
import '../models/enemy.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
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
  static String get hazardLava => tile(41);
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
  static String get chestClosed => tile(89);
  static String get chestOpen => tile(90);
  static String get chestMimic => tile(92);
  /// Wall fountain / glow — Tiny Dungeon has no free-standing torch sprite.
  static String get torch => tile(8);
  static String get torchAlt => tile(20);

  // —— Heroes (custom intro-matched pixel art) ——
  static String get heroWizard => CustomAssets.heroWizard;
  static String get heroVillager => tile(85);
  static String get heroBearded => tile(86);
  static String get heroSoldier => tile(87);
  static String get heroRogue => CustomAssets.heroRogue;
  static String get heroKnight => CustomAssets.heroKnight;
  static String get heroKnightAlt => CustomAssets.heroKnight;
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
  static String get meat => potionGreen;
  static String get roomCleared => doorArch; // legacy alias; unused in painter
  static String get propSkull => gravestoneAlt;
  static String get wallStoneAlt2 => trapSpikes; // legacy — do not use as wall
  static String get stairsAlt => stairsDown;

  // —— Extras (custom identity; Kenney extras kept on disk as legacy) ——
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
      heroSpriteForClass(HeroSpecs.def(specId).classId);

  static String floorForDungeon(String dungeonId) {
    // Prefer textured floors so maps don't read as flat color slabs.
    return switch (dungeonId) {
      'sandy' => floorSand,
      'goblin' => floorDirtDetail,
      'king' => floorStone,
      'underworld' => floorDirtDetail,
      'dead' => floorStone,
      'hell' => floorSand,
      'crystal' => floorStone,
      'tide' => floorStone,
      'ember' => floorSand,
      _ => switch (DungeonCatalog.byId(dungeonId).layout) {
          DungeonLayoutKind.cave => floorSand,
          DungeonLayoutKind.hideout => floorDirtDetail,
          DungeonLayoutKind.fort || DungeonLayoutKind.arena => floorStone,
        },
    };
  }

  /// Single verified floor per dungeon — sand uses a clean + worn pair (no wall-lip tiles).
  static List<String> floorVariantsForDungeon(String dungeonId) {
    return switch (dungeonId) {
      'sandy' || 'hell' || 'ember' => <String>[
          floorSand,
          floorSand,
          floorSand,
          floorSandWorn,
        ],
      _ => <String>[floorForDungeon(dungeonId)],
    };
  }

  static String wallForDungeon(String dungeonId) {
    return switch (dungeonId) {
      'king' => wallBanner,
      _ => wallStone,
    };
  }

  /// Rim wall sprites only (deep walls paint as void).
  static List<String> wallVariantsForDungeon(String dungeonId) {
    return switch (dungeonId) {
      'king' => [wallStone, wallStone, wallStone, wallBanner],
      'hell' || 'ember' => [wallStone, wallStone, wallBanner],
      'dead' => [wallStone, wallStone, wallBannerAlt],
      'crystal' || 'tide' => [wallStone, wallStoneAlt1],
      _ => [wallStone],
    };
  }

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
      };

  static List<MapPropKind> propPoolForDungeon(String dungeonId) =>
      switch (dungeonId) {
        'sandy' => const [
            MapPropKind.barrel,
            MapPropKind.crate,
            MapPropKind.table,
            MapPropKind.stool,
          ],
        'goblin' => const [
            MapPropKind.barrel,
            MapPropKind.crate,
            MapPropKind.table,
            MapPropKind.bones,
          ],
        'king' => const [
            MapPropKind.torch,
            MapPropKind.crate,
            MapPropKind.anvil,
            MapPropKind.table,
            MapPropKind.barrel,
          ],
        'underworld' => const [
            MapPropKind.torch,
            MapPropKind.barrel,
            MapPropKind.fountain,
            MapPropKind.crate,
          ],
        'dead' => const [
            MapPropKind.gravestone,
            MapPropKind.bones,
            MapPropKind.crate,
            MapPropKind.torch,
          ],
        'hell' => const [
            MapPropKind.torch,
            MapPropKind.torchAlt,
            MapPropKind.barrel,
            MapPropKind.trap,
          ],
        'crystal' => const [
            MapPropKind.torch,
            MapPropKind.fountain,
            MapPropKind.crate,
          ],
        'tide' => const [
            MapPropKind.water,
            MapPropKind.barrel,
            MapPropKind.fountain,
            MapPropKind.crate,
          ],
        'ember' => const [
            MapPropKind.torch,
            MapPropKind.torchAlt,
            MapPropKind.lava,
            MapPropKind.anvil,
          ],
        _ => const [MapPropKind.barrel, MapPropKind.crate, MapPropKind.table],
      };

  static String dungeonIconFor(String dungeonId) => switch (dungeonId) {
        // Prefer entrance/prop icons — floor tiles look like clipboard blobs on the hub map.
        'sandy' => hatch,
        'goblin' => doorClosed,
        'king' => wallBanner,
        'underworld' => stairs,
        'dead' => gravestone,
        'hell' => doorOpen,
        'crystal' => doorVariant,
        'tide' => doorClosed,
        'ember' => hatch,
        _ => iconDoor,
      };

  /// Hub detail portrait for the selected dungeon (boss / theme).
  static String dungeonPortraitFor(String dungeonId) =>
      CustomAssets.dungeonPortrait(dungeonId);

  static String enemySpriteForRole(EnemyRole role, {String? dungeonId}) {
    if (role == EnemyRole.boss) {
      return switch (dungeonId) {
        'sandy' => enemyCrab,
        'goblin' => enemyCyclops,
        'king' => enemyBoss,
        'underworld' => enemyCultist,
        'dead' => enemyGhost,
        'hell' => enemyHellBoss,
        'crystal' => enemyCrystalBoss,
        'tide' => enemyCrab,
        'ember' => enemyCyclops,
        _ => enemyBoss,
      };
    }
    if (role == EnemyRole.elite) {
      return switch (dungeonId) {
        'dead' => enemyGhost,
        'underworld' => enemySpider,
        'hell' => enemyCultist,
        'ember' => enemyGolem,
        'crystal' => enemyCrystalWraith,
        'tide' => enemyCrab,
        _ => enemyCyclops,
      };
    }
    return switch (dungeonId) {
      'sandy' => enemySlime,
      'goblin' => enemyRat,
      'king' => enemyBat,
      'underworld' => enemySpider,
      'dead' => enemyGhost,
      'hell' => enemyCultist,
      'ember' => enemyRat,
      'crystal' => enemyCrystalMite,
      'tide' => enemySlime,
      _ => enemySlime,
    };
  }

  static String enemySpriteFor(
    EnemyUnit enemy, {
    String? dungeonId,
  }) {
    if (enemy.role == EnemyRole.boss) {
      return enemySpriteForRole(EnemyRole.boss, dungeonId: dungeonId);
    }
    return switch (enemy.archetype) {
      EnemyArchetype.swarm => switch (dungeonId) {
          'sandy' => enemySlime,
          'goblin' => enemyRat,
          'king' => enemyBat,
          'underworld' => enemySpider,
          'dead' => enemyGhost,
          'crystal' => enemyCrystalMite,
          'tide' => enemySlime,
          'ember' => enemyRat,
          _ => enemyRat,
        },
      EnemyArchetype.brute => switch (dungeonId) {
          'sandy' => enemyCrab,
          'goblin' => enemyCyclops,
          'king' => enemyCyclops,
          'hell' => enemyBoss,
          'ember' => enemyCyclops,
          'crystal' => enemyCrystalBoss,
          'tide' => enemyCrab,
          _ => enemyCyclops,
        },
      EnemyArchetype.tank => switch (dungeonId) {
          'sandy' => enemyCrab,
          'dead' => enemyGhost,
          'hell' => enemyBoss,
          'ember' => enemyGolem,
          'crystal' => enemyCrystalBoss,
          'tide' => enemyCrab,
          _ => enemyGolem,
        },
      EnemyArchetype.ranged => switch (dungeonId) {
          'dead' => enemyGhost,
          'underworld' => enemySpider,
          'hell' => enemyCultist,
          'ember' => enemyBat,
          'crystal' => enemyCrystalWraith,
          'tide' => enemyBat,
          _ => enemyBat,
        },
      EnemyArchetype.glass => switch (dungeonId) {
          'dead' => enemyGhost,
          'underworld' => enemySpider,
          'hell' => enemyCultist,
          'ember' => enemyRat,
          'crystal' => enemyCrystalWraith,
          'tide' => enemySlime,
          _ => enemyBat,
        },
      EnemyArchetype.support => switch (dungeonId) {
          'crystal' => enemyCrystalWraith,
          'tide' => enemyCrab,
          'ember' => enemyCultist,
          _ => enemyCultist,
        },
    };
  }

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
      ];

  static int enemySpriteCatalogIndex(String asset) {
    final i = enemySpriteCatalog.indexOf(asset);
    return i < 0 ? 0 : i;
  }

  /// Stable cosmetic sprite for a codex enemy name (aligned with combat families).
  static String enemySpriteForCodexName(String name) {
    final key = name.trim().toLowerCase();
    final mapped = switch (key) {
      // Catalog bosses — must match enemySpriteForRole(boss, dungeonId:).
      'earth kraken' => enemyCrab,
      'hobgoblin lord' => enemyCyclops,
      'corrupt king' => enemyBoss,
      'beholder' => enemyCultist,
      'the no-one' => enemyGhost,
      'cthulhu' || 'chtulu' => enemyHellBoss,
      'tide leviathan' => enemyCrab,
      'cinder sovereign' => enemyCyclops,
      'crystal warden' ||
      'crystal golem' ||
      'frozen bulwark' ||
      'glacial brute' ||
      'shard brawler' ||
      'shell leviathan' ||
      'barnacle guard' ||
      'tide brute' ||
      'coral crusher' =>
        enemyCrystalBoss,
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
      'needle urchin' =>
        enemyCrystalWraith,
      'crystal mite' ||
      'frost wisp' ||
      'rime bat' ||
      'brine mite' ||
      'reef tick' =>
        enemyCrystalMite,
      'king crab' || 'cave king' => enemyCrab,
      'hell lord' || 'hellgate tyrant' => enemyHellBoss,
      'vault brute' ||
      'slag brawler' ||
      'basalt golem' ||
      'ember bulwark' =>
        enemyBoss,
      'spark caster' ||
      'cinder slinger' ||
      'ash chanter' ||
      'ember adept' ||
      'ash mite' ||
      'cinder tick' =>
        enemyCultist,
      'char blade' || 'soot fang' => enemyRat,
      'cave slime' || 'drip ooze' || 'sand mite' => enemySlime,
      'spit bat' || 'cavern spitter' || 'drill bat' => enemyBat,
      'needle rat' || 'glass skitter' || 'fort rat' || 'sneak rat' || 'pest' ||
      'cinder rat' =>
        enemyRat,
      'rock crab' || 'shellback' || 'stone maw' => enemyCrab,
      'cave brute' || 'goblin thug' || 'clubber' || 'fort sentry' ||
      'hall guard' || 'elite brute' || 'bone brute' || 'crypt brute' ||
      'infernal brute' || 'flame guard' =>
        enemyCyclops,
      'bulwark golem' || 'obsidian golem' || 'molten golem' || 'ash colossus' ||
      'iron ward' || 'gate knight' || 'hideout guard' || 'scrap shield' ||
      'tomb shield' || 'ossuary guard' || 'pit guard' =>
        enemyGolem,
      'hex cultist' || 'glow cultist' || 'mire shaman' || 'hex witch' ||
      'totem caller' || 'court mage' || 'banner cleric' || 'cult chanter' ||
      'rift adept' || 'necro acolyte' || 'death chanter' || 'fire cultist' ||
      'hell chanter' || 'rift priest' =>
        enemyCultist,
      'hex spider' || 'imp swarm' || 'ash tick' => enemySpider,
      'wailing ghost' || 'risen husk' || 'bone swarm' || 'specter blade' ||
      'pale reaper' || 'grave knight' =>
        enemyGhost,
      'blood stalker' || 'cutthroat' || 'knife kin' || 'royal assassin' ||
      'blade page' || 'shade stalker' || 'wisp blade' || 'flame assassin' ||
      'cinder blade' =>
        enemyRat,
      'goblin scrapper' || 'goblin slinger' || 'dart rascal' => enemyRat,
      'crossbowman' || 'tower archer' || 'ember archer' || 'bone archer' ||
      'warden archer' =>
        enemyBat,
      'underworld imp' || 'hellspawn' => enemyCultist,
      'warden shield' || 'warden guard' || 'warden adept' => enemyGolem,
      _ => null,
    };
    if (mapped != null) return mapped;

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

    if (item.slot == EquipmentSlot.weapon || item.slot == EquipmentSlot.ranged) {
      return switch (item.weaponType) {
        WeaponType.axe => axe,
        WeaponType.sword =>
          item.rarity.index >= 2 ? swordAlt : sword,
        WeaponType.mace => hammer,
        WeaponType.dagger => dagger,
        WeaponType.fist => fist,
        WeaponType.staff =>
          item.rarity.index >= 2 ? staffBlue : staff,
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
            'warrior' => item.rarity.index >= 3
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
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => CustomAssets.iconTrinket,
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
        GameLogic.warBannerRelic => relicWarBanner,
        GameLogic.ironWardRelic => relicIronWard,
        GameLogic.phoenixEmberRelic => relicPhoenixEmber,
        GameLogic.godHandFocusRelic => fist,
        GameLogic.chamberLuckRelic => iconStar,
        GameLogic.ironWillRelic => iconTrophy,
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
    if (lower.contains('helm') || lower.contains('hood') || lower.contains('crown')) {
      return helmet;
    }
    if (lower.contains('boot') || lower.contains('greave')) return boots;
    if (lower.contains('glove') || lower.contains('gaunt')) return gloves;
    if (lower.contains('cloak') || lower.contains('cape')) return cloak;
    if (lower.contains('shield') || lower.contains('buckler')) return shield;
    if (lower.contains('crossbow')) return crossbow;
    if (lower.contains('gun') || lower.contains('pistol') || lower.contains('rifle')) {
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
    if (lower.contains('ring') || lower.contains('band')) return CustomAssets.iconRing;
    if (lower.contains('amulet') || lower.contains('neck') || lower.contains('pendant')) {
      return CustomAssets.iconNeck;
    }
    if (lower.contains('chest') || lower.contains('mail') || lower.contains('plate')) {
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
