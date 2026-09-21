import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/stats.dart';
import 'package:idle_party/models/zone_art.dart';
import 'package:idle_party/assets/custom_assets.dart';
import 'package:idle_party/assets/kenney_assets.dart';

void main() {
  bool exists(String assetPath) => File(assetPath).existsSync();

  test('owned fallback tiles exist for leftover Kenney roles', () {
    for (var id = 0; id < 132; id++) {
      expect(exists(KenneyAssets.tile(id)), isTrue, reason: 'tile $id');
    }
    expect(exists(CustomAssets.floorDirt), isTrue);
    expect(exists(CustomAssets.enemySnake), isTrue);
    expect(exists(CustomAssets.iconFlaskGrey), isTrue);
    expect(exists(CustomAssets.uiPanelBrown), isTrue);
  });

  test('CustomAssets hero/enemy/UI/pet/icon files exist', () {
    final paths = <String>{
      CustomAssets.petEgg,
      CustomAssets.petEmberPup,
      CustomAssets.petCaveBat,
      CustomAssets.petLootSprite,
      CustomAssets.petWardenCub,
      CustomAssets.iconHelm,
      CustomAssets.iconChest,
      CustomAssets.iconCloak,
      CustomAssets.iconBoots,
      CustomAssets.iconGloves,
      CustomAssets.iconRing,
      CustomAssets.iconShoulders,
      CustomAssets.iconBelt,
      CustomAssets.iconNeck,
      CustomAssets.iconWrist,
      CustomAssets.iconLegs,
      CustomAssets.iconTrinket,
      CustomAssets.iconTome,
      CustomAssets.iconSword,
      CustomAssets.iconSwordAlt,
      CustomAssets.iconDagger,
      CustomAssets.iconAxe,
      CustomAssets.iconMace,
      CustomAssets.iconStaff,
      CustomAssets.iconStaffBlue,
      CustomAssets.iconSpear,
      CustomAssets.iconBow,
      CustomAssets.iconCrossbow,
      CustomAssets.iconGun,
      CustomAssets.iconWand,
      CustomAssets.iconFist,
      CustomAssets.iconShield,
      CustomAssets.iconShieldRound,
      CustomAssets.iconFlask,
      CustomAssets.iconFlaskGreen,
      CustomAssets.iconFlaskBlue,
      CustomAssets.iconFlaskPurple,
      CustomAssets.iconThrown,
      CustomAssets.iconCoinGold,
      CustomAssets.iconBook,
      CustomAssets.iconRelicWarBanner,
      CustomAssets.iconRelicIronWard,
      CustomAssets.iconRelicPhoenixEmber,
      CustomAssets.iconCrown,
      CustomAssets.iconCampfire,
      CustomAssets.iconTrophy,
      CustomAssets.iconDoor,
      CustomAssets.iconStar,
      CustomAssets.iconHeart,
      CustomAssets.iconSkull,
      CustomAssets.iconSettings,
      CustomAssets.iconKey,
      CustomAssets.portraitSandy,
      CustomAssets.portraitGoblin,
      CustomAssets.portraitKing,
      CustomAssets.portraitUnderworld,
      CustomAssets.portraitDead,
      CustomAssets.portraitHell,
      CustomAssets.portraitCrystal,
      CustomAssets.introLogo,
      CustomAssets.studioLogo,
      CustomAssets.introScene,
      CustomAssets.hubScene,
      CustomAssets.worldPathMap,
      CustomAssets.dungeonBackdrop,
      CustomAssets.backdropSandy,
      CustomAssets.backdropGoblin,
      CustomAssets.backdropKing,
      CustomAssets.backdropUnderworld,
      CustomAssets.backdropDead,
      CustomAssets.backdropHell,
      CustomAssets.backdropCrystal,
      CustomAssets.heroKnight,
      CustomAssets.heroHealer,
      CustomAssets.heroWizard,
      CustomAssets.heroRogue,
      CustomAssets.heroPaladin,
      CustomAssets.heroHunter,
      CustomAssets.heroDeathKnight,
      CustomAssets.heroShaman,
      CustomAssets.heroWarlock,
      CustomAssets.heroDruid,
      CustomAssets.enemySlime,
      CustomAssets.enemyRat,
      CustomAssets.enemyBat,
      CustomAssets.enemySpider,
      CustomAssets.enemyGhost,
      CustomAssets.enemyCultist,
      CustomAssets.enemyCyclops,
      CustomAssets.enemyCrab,
      CustomAssets.enemyGolem,
      CustomAssets.enemyBossKing,
      CustomAssets.enemyBossHell,
      CustomAssets.enemyCrystalBoss,
      CustomAssets.enemyCrystalWraith,
      CustomAssets.enemyCrystalMite,
      CustomAssets.enemyBossStorm,
      CustomAssets.enemyStormMite,
      CustomAssets.enemyBossVeil,
      CustomAssets.enemyVeilMite,
    };
    for (final path in paths) {
      expect(exists(path), isTrue, reason: path);
    }
  });

  test('every HeroClassId has a custom sprite on disk', () {
    for (final classId in HeroClassId.values) {
      final path = CustomAssets.heroForClass(classId);
      expect(exists(path), isTrue, reason: '$classId → $path');
    }
  });

  test('unique late-zone elites are not shared golem/wraith', () {
    final late = ['tide', 'ember', 'storm', 'rime', 'fen', 'brass', 'veil'];
    for (final id in late) {
      final e = ZoneArt.byId(id).enemies;
      expect(e.elite, isNot(CustomAssets.enemyGolem), reason: '$id elite');
      expect(e.forArchetype(EnemyArchetype.brute), isNot(CustomAssets.enemyGolem),
          reason: '$id brute');
      expect(e.forArchetype(EnemyArchetype.tank), isNot(CustomAssets.enemyGolem),
          reason: '$id tank');
      if (id == 'storm' || id == 'rime') {
        expect(e.elite, isNot(CustomAssets.enemyCrystalWraith),
            reason: '$id elite not crystal wraith');
      }
      expect(exists(e.elite), isTrue);
      expect(exists(e.forArchetype(EnemyArchetype.brute)), isTrue);
    }
    expect(ZoneArt.byId('tide').enemies.elite, isNot(CustomAssets.enemySandyBrute));
    expect(ZoneArt.byId('tide').enemies.forArchetype(EnemyArchetype.brute),
        isNot(CustomAssets.enemyCrab));
    expect(ZoneArt.byId('grove').enemies.elite, isNot(CustomAssets.enemySpider));
    expect(ZoneArt.byId('grove').enemies.forArchetype(EnemyArchetype.brute),
        isNot(CustomAssets.enemySpider));
    final wraiths = [
      CustomAssets.enemyCrystalWraith,
      CustomAssets.enemyStormWraith,
      CustomAssets.enemyRimeWraith,
    ];
    expect(wraiths.toSet().length, 3);
    final blobs = [for (final path in wraiths) File(path).readAsBytesSync()];
    expect(blobs[0], isNot(blobs[1]));
    expect(blobs[1], isNot(blobs[2]));
    expect(blobs[0], isNot(blobs[2]));
  });

  test('an elite uses the elite sprite, and the codex matches combat', () {
    EnemyUnit unit(EnemyRole role, EnemyArchetype archetype) => EnemyUnit(
          name: 'x',
          level: 1,
          currentHp: 10,
          stats: Stats.enemy(attack: 1, defense: 1, maxHp: 10),
          rewardGold: 0,
          role: role,
          archetype: archetype,
        );
    expect(
      KenneyAssets.enemySpriteFor(
        unit(EnemyRole.elite, EnemyArchetype.brute),
        dungeonId: 'storm',
      ),
      CustomAssets.enemyStormWraith,
    );
    expect(
      KenneyAssets.enemySpriteFor(
        unit(EnemyRole.normal, EnemyArchetype.brute),
        dungeonId: 'storm',
      ),
      CustomAssets.enemyStormBrute,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Tide Brute'),
      ZoneArt.byId('tide').enemies.forArchetype(EnemyArchetype.brute),
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Timber Champion'),
      ZoneArt.byId('grove').enemies.elite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Thunder Champion'),
      ZoneArt.byId('storm').enemies.elite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Frost Champion'),
      ZoneArt.byId('rime').enemies.elite,
    );
  });

  test('Shadow Feral Guardian Balance Resto have unique hero sprites', () {
    expect(CustomAssets.heroForSpec(HeroSpecId.shadow), CustomAssets.heroShadow);
    expect(CustomAssets.heroForSpec(HeroSpecId.feral), CustomAssets.heroFeral);
    expect(
      CustomAssets.heroForSpec(HeroSpecId.guardian),
      CustomAssets.heroGuardian,
    );
    expect(
      CustomAssets.heroForSpec(HeroSpecId.balance),
      CustomAssets.heroMoonkin,
    );
    expect(
      CustomAssets.heroForSpec(HeroSpecId.restorationDruid),
      CustomAssets.heroTree,
    );
    expect(CustomAssets.hasUniqueHeroSprite(HeroSpecId.balance), isTrue);
    expect(
      CustomAssets.hasUniqueHeroSprite(HeroSpecId.restorationDruid),
      isTrue,
    );
    for (final path in CustomAssets.uniqueHeroSpecPaths) {
      expect(exists(path), isTrue, reason: path);
    }
  });

  test('every dungeon has portrait + backdrop', () {
    for (final d in DungeonCatalog.all) {
      expect(
        exists(CustomAssets.dungeonPortrait(d.id)),
        isTrue,
        reason: 'portrait ${d.id}',
      );
      expect(
        exists(CustomAssets.dungeonBackdropFor(d.id)),
        isTrue,
        reason: 'backdrop ${d.id}',
      );
    }
  });

  test('enemySpriteCatalog and identity icon files exist', () {
    for (final path in KenneyAssets.enemySpriteCatalog) {
      expect(exists(path), isTrue, reason: path);
    }
    for (final path in [
      KenneyAssets.book,
      KenneyAssets.coinGold,
      KenneyAssets.ring,
      KenneyAssets.iconCoin,
      KenneyAssets.iconSword,
      KenneyAssets.iconCrown,
      KenneyAssets.iconCampfire,
      KenneyAssets.iconShield,
      KenneyAssets.iconTrophy,
      KenneyAssets.iconDoor,
      KenneyAssets.iconStar,
      KenneyAssets.iconHeart,
      KenneyAssets.iconSkull,
      KenneyAssets.iconBow,
      KenneyAssets.sword,
      KenneyAssets.dagger,
      KenneyAssets.axe,
      KenneyAssets.hammer,
      KenneyAssets.staff,
      KenneyAssets.staffBlue,
      KenneyAssets.spear,
      KenneyAssets.bow,
      KenneyAssets.crossbow,
      KenneyAssets.gun,
      KenneyAssets.wand,
      KenneyAssets.fist,
      KenneyAssets.shield,
      KenneyAssets.shieldRound,
      KenneyAssets.potionRed,
      KenneyAssets.potionGreen,
      KenneyAssets.potionBlue,
      KenneyAssets.vialBlue,
      KenneyAssets.relicWarBanner,
      KenneyAssets.relicIronWard,
      KenneyAssets.relicPhoenixEmber,
      KenneyAssets.panelBrown,
      KenneyAssets.barBackMid,
      KenneyAssets.progressGreen,
    ]) {
      expect(exists(path), isTrue, reason: path);
    }
  });

  test('item_affixes.json is present for EquipmentFactory', () {
    expect(exists('assets/data/item_affixes.json'), isTrue);
  });

  test('codex boss sprites match combat boss sprites per dungeon', () {
    for (final d in DungeonCatalog.all) {
      final combat = KenneyAssets.enemySpriteForRole(
        EnemyRole.boss,
        dungeonId: d.id,
      );
      final codex = KenneyAssets.enemySpriteForCodexName(d.bossName);
      expect(
        codex,
        combat,
        reason: '${d.id} boss "${d.bossName}"',
      );
    }
  });
}
