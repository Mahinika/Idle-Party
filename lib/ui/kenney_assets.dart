import '../core/game_logic.dart';
import '../models/dungeon_def.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
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
  static const String _extras = 'assets/kenney/extras';
  static const String _ui = 'assets/kenney/ui_adventure';
  static const String _bars = 'assets/kenney/ui_bars';
  static const String _icons = 'assets/kenney/icons';
  static const String _runes = 'assets/kenney/runes';

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

  // —— Heroes (sample map / sheet character band) ——
  static String get heroWizard => tile(84);
  static String get heroVillager => tile(85);
  static String get heroBearded => tile(86);
  static String get heroSoldier => tile(87);
  static String get heroRogue => tile(88);
  static String get heroKnight => tile(96);
  static String get heroKnightAlt => tile(97);
  static String get heroWoman => tile(98);
  static String get heroHealer => tile(99);
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

  // —— Gear / consumables ——
  static String get shieldRound => tile(101);
  static String get shield => tile(102);
  static String get dagger => tile(103);
  static String get sword => tile(104);
  static String get swordAlt => tile(106);
  static String get hammer => tile(117);
  static String get axe => tile(118);
  static String get potionGrey => tile(113);
  static String get potionGreen => tile(114);
  static String get potionRed => tile(115);
  static String get potionBlue => tile(116);
  static String get vialGrey => tile(125);
  static String get vialGreen => tile(126);
  static String get vialRed => tile(127);
  static String get vialBlue => tile(128);
  static String get staff => tile(129);
  static String get staffBlue => tile(130);
  static String get spear => tile(131);
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

  // —— Extras (not from Tiny Dungeon sheet) ——
  static const String book = '$_extras/book.png';
  static const String coinGold = '$_extras/coin_gold.png';
  static const String ring = '$_extras/ring.png';

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
  static const String iconCoin = '$_icons/coin.png';
  static const String iconSword = '$_icons/sword.png';
  static const String iconCrown = '$_icons/crown.png';
  static const String iconCampfire = '$_icons/campfire.png';
  static const String iconShield = '$_icons/shield_icon.png';
  static const String iconTrophy = '$_icons/trophy.png';
  static const String iconDoor = '$_icons/door.png';
  static const String iconStar = '$_icons/star.png';
  static const String iconHeart = '$_icons/heart.png';
  static const String iconSkull = '$_icons/skull.png';
  static const String iconBow = '$_icons/bow.png';

  // —— Relics ——
  static const String relicWarBanner = '$_runes/war_banner.png';
  static const String relicIronWard = '$_runes/iron_ward.png';
  static const String relicPhoenixEmber = '$_runes/phoenix_ember.png';

  static String heroSpriteForRole(HeroRole role) => switch (role) {
        HeroRole.warrior => heroKnight,
        HeroRole.healer => heroHealer,
        HeroRole.mage => heroWizard,
        HeroRole.rogue => heroRogue,
      };

  static String heroSpriteFor(int index) => switch (index) {
        0 => heroKnight,
        1 => heroHealer,
        2 => heroWizard,
        _ => heroRogue,
      };

  static String heroPortraitFor(int index) => heroSpriteFor(index);

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
      'sandy' || 'hell' => <String>[
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
      'hell' => [wallStone, wallStone, wallBanner],
      'dead' => [wallStone, wallStone, wallBannerAlt],
      'crystal' => [wallStone, wallStoneAlt1],
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
        'crystal' => enemyBoss,
        _ => enemyBoss,
      };
    }
    if (role == EnemyRole.elite) {
      return switch (dungeonId) {
        'dead' => enemyGhost,
        'underworld' => enemySpider,
        'hell' => enemyCultist,
        'crystal' => enemyCyclops,
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
      'crystal' => enemySlime,
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
          _ => enemyRat,
        },
      EnemyArchetype.brute => switch (dungeonId) {
          'sandy' => enemyCrab,
          'goblin' => enemyCyclops,
          'king' => enemyCyclops,
          'hell' => enemyBoss,
          _ => enemyCyclops,
        },
      EnemyArchetype.tank => switch (dungeonId) {
          'sandy' => enemyCrab,
          'dead' => enemyGhost,
          'hell' => enemyBoss,
          _ => enemyGolem,
        },
      EnemyArchetype.ranged => switch (dungeonId) {
          'dead' => enemyGhost,
          'underworld' => enemySpider,
          'hell' => enemyCultist,
          _ => enemyBat,
        },
      EnemyArchetype.glass => switch (dungeonId) {
          'dead' => enemyGhost,
          'underworld' => enemySpider,
          _ => enemyRat,
        },
      EnemyArchetype.support => enemyCultist,
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
      ];

  static int enemySpriteCatalogIndex(String asset) {
    final i = enemySpriteCatalog.indexOf(asset);
    return i < 0 ? 0 : i;
  }

  /// Stable cosmetic sprite for a codex enemy name (no combat coupling).
  static String enemySpriteForCodexName(String name) {
    final catalog = enemySpriteCatalog;
    if (catalog.isEmpty) return enemyRat;
    final hash = name.hashCode & 0x7fffffff;
    return catalog[hash % catalog.length];
  }

  static String lootIconFor(LootRarity rarity) => switch (rarity) {
        LootRarity.common => coinGold,
        LootRarity.uncommon => potionGreen,
        LootRarity.rare => vialBlue,
        LootRarity.epic => chestClosed,
      };

  static String equipmentIconFor(EquipmentItem item) {
    if (item.iconId != null) {
      switch (item.iconId) {
        case 'bow':
          return iconBow;
        case 'book':
          return CustomAssets.iconTome;
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
          WeaponType.mace || WeaponType.fist => hammer,
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
        WeaponType.dagger || WeaponType.fist => dagger,
        WeaponType.staff =>
          item.rarity.index >= 2 ? staffBlue : staff,
        WeaponType.polearm => spear,
        WeaponType.bow ||
        WeaponType.crossbow ||
        WeaponType.gun ||
        WeaponType.thrown =>
          iconBow,
        WeaponType.wand => staffBlue,
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
        _ => relicWarBanner,
      };

  static String forgeIconFor(String title) {
    final upper = title.toUpperCase();
    if (upper.contains('ATTACK')) return sword;
    if (upper.contains('DEFENSE')) return shield;
    if (upper.contains('VITALITY')) return potionRed;
    if (upper.contains('TRAIN')) return book;
    if (upper.contains('FORGE') || upper.contains('ANVIL')) return anvil;
    return hammer;
  }
}
