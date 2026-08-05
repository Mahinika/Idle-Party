import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/ui/custom_assets.dart';
import 'package:idle_party/ui/kenney_assets.dart';

void main() {
  test('custom identity assets exist on disk', () {
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
      CustomAssets.iconDagger,
      CustomAssets.iconAxe,
      CustomAssets.iconMace,
      CustomAssets.iconStaff,
      CustomAssets.iconBow,
      CustomAssets.iconShield,
      CustomAssets.iconFlask,
      CustomAssets.iconThrown,
      CustomAssets.iconCoinGold,
      CustomAssets.iconBook,
      CustomAssets.iconRelicWarBanner,
      CustomAssets.portraitSandy,
      CustomAssets.portraitGoblin,
      CustomAssets.portraitKing,
      CustomAssets.portraitUnderworld,
      CustomAssets.portraitDead,
      CustomAssets.portraitHell,
      CustomAssets.introLogo,
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
    };

    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: 'missing $path');
    }
  });

  test('equipment and portraits resolve to custom assets', () {
    expect(KenneyAssets.helmet, CustomAssets.iconHelm);
    expect(KenneyAssets.boots, CustomAssets.iconBoots);
    expect(KenneyAssets.cloak, CustomAssets.iconCloak);
    expect(KenneyAssets.sword, CustomAssets.iconSword);
    expect(KenneyAssets.dagger, CustomAssets.iconDagger);
    expect(KenneyAssets.bow, CustomAssets.iconBow);
    expect(KenneyAssets.shield, CustomAssets.iconShield);
    expect(KenneyAssets.potionRed, CustomAssets.iconFlask);
    expect(KenneyAssets.thrown, CustomAssets.iconThrown);
    expect(KenneyAssets.coinGold, CustomAssets.iconCoinGold);
    expect(KenneyAssets.relicWarBanner, CustomAssets.iconRelicWarBanner);
    expect(
      KenneyAssets.dungeonPortraitFor('goblin'),
      CustomAssets.portraitGoblin,
    );
    expect(
      CustomAssets.petForInstanceId('ember_pup_42'),
      CustomAssets.petEmberPup,
    );
    expect(
      CustomAssets.petForInstanceId('ash_fox_9'),
      CustomAssets.enemySpider,
    );
    expect(
      CustomAssets.petForTemplateId('gold_grub'),
      CustomAssets.enemyRat,
    );
  });

  test('each pet species maps to a unique portrait path', () {
    final paths = {
      for (final species in PetCatalog.all)
        species.id: CustomAssets.petForTemplateId(species.id),
    };
    expect(paths.values.toSet().length, paths.length);
    expect(
      CustomAssets.petPortraitPaths.toSet().length,
      CustomAssets.petPortraitPaths.length,
    );
  });

  test('hell and king bosses use distinct combat sprites', () {
    expect(
      KenneyAssets.enemySpriteForRole(EnemyRole.boss, dungeonId: 'hell'),
      CustomAssets.enemyBossHell,
    );
    expect(
      KenneyAssets.enemySpriteForRole(EnemyRole.boss, dungeonId: 'king'),
      CustomAssets.enemyBossKing,
    );
    expect(KenneyAssets.enemyGolem, isNot(KenneyAssets.enemyCyclops));
  });

  test('combat enemies resolve to custom art', () {
    expect(KenneyAssets.enemySlime, startsWith('assets/custom/enemies/'));
    expect(
      KenneyAssets.enemySpriteCatalog,
      containsAll(<String>[
        CustomAssets.enemyBossKing,
        CustomAssets.enemyBossHell,
        CustomAssets.enemyGolem,
      ]),
    );
  });
}
