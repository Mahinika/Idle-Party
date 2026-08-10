import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/dungeon_def.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/custom_assets.dart';
import 'package:idle_party/ui/kenney_assets.dart';

void main() {
  bool exists(String assetPath) => File(assetPath).existsSync();

  test('all Tiny Dungeon tiles 0000–0131 exist', () {
    for (var id = 0; id < 132; id++) {
      expect(exists(KenneyAssets.tile(id)), isTrue, reason: 'tile $id');
    }
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
      CustomAssets.portraitSandy,
      CustomAssets.portraitGoblin,
      CustomAssets.portraitKing,
      CustomAssets.portraitUnderworld,
      CustomAssets.portraitDead,
      CustomAssets.portraitHell,
      CustomAssets.portraitCrystal,
      CustomAssets.introLogo,
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

  test('enemySpriteCatalog files exist and Kenney extras/icons/runes exist', () {
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
