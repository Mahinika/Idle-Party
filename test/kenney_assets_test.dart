import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/assets/kenney_assets.dart';

void main() {
  test('catalog getters resolve to owned files on disk', () {
    final paths = <String>{
      KenneyAssets.floorDirt,
      KenneyAssets.floorSand,
      KenneyAssets.floorStone,
      KenneyAssets.wallStone,
      KenneyAssets.doorClosed,
      KenneyAssets.doorOpen,
      KenneyAssets.stairs,
      KenneyAssets.heroKnight,
      KenneyAssets.heroWizard,
      KenneyAssets.heroHealer,
      KenneyAssets.heroRogue,
      KenneyAssets.sword,
      KenneyAssets.staff,
      KenneyAssets.potionRed,
      KenneyAssets.chestClosed,
      KenneyAssets.barrel,
      KenneyAssets.book,
      KenneyAssets.coinGold,
      KenneyAssets.ring,
      // Enemies are custom PNGs (still must exist on disk).
      ...KenneyAssets.enemySpriteCatalog,
      for (final role in EnemyRole.values)
        KenneyAssets.enemySpriteForRole(role, dungeonId: 'sandy'),
      KenneyAssets.enemySpriteForCodexName('Goblin Scrapper'),
      KenneyAssets.enemySpriteForCodexName('Goblin Slinger'),
      KenneyAssets.enemySpriteForCodexName('Stash Guard'),
      KenneyAssets.enemySpriteForCodexName('Crystal Warden'),
    };

    expect(
      KenneyAssets.enemySpriteForCodexName('Goblin Slinger'),
      KenneyAssets.enemyGoblinRanged,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Stash Guard'),
      KenneyAssets.enemyGoblinMite,
    );

    for (final path in paths) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing $path');
    }
  });

  test('enemy and hero sprites are distinct where required', () {
    expect(KenneyAssets.enemyCultist, isNot(KenneyAssets.enemyBoss));
    expect(KenneyAssets.heroWizard, isNot(KenneyAssets.propSkull));
    expect(KenneyAssets.boots, isNot(KenneyAssets.stairs));
    expect(KenneyAssets.boots, startsWith('assets/custom/'));
    expect(KenneyAssets.sword, isNot(KenneyAssets.torch));
  });

  test('dungeon portraits use custom art', () {
    expect(
      KenneyAssets.dungeonPortraitFor('sandy'),
      startsWith('assets/custom/portraits/'),
    );
  });

  test('Crystal Spire codex names map to crystal sprites', () {
    expect(
      KenneyAssets.enemySpriteForCodexName('Crystal Warden'),
      KenneyAssets.enemyCrystalBoss,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Crystal Golem'),
      KenneyAssets.enemyCrystalBrute,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Frost Wisp'),
      KenneyAssets.enemyCrystalMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Prism Bat'),
      KenneyAssets.enemyCrystalMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Shard Slinger'),
      KenneyAssets.enemyRimeMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Glacier Chanter'),
      KenneyAssets.enemyRimeWraith,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Brass Bulwark'),
      KenneyAssets.enemyBrassBrute,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Ice Caster'),
      KenneyAssets.enemyCrystalWraith,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Storm Tyrant'),
      KenneyAssets.enemyStormBoss,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Gale Mite'),
      KenneyAssets.enemyStormMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('The Pale Monarch'),
      KenneyAssets.enemyVeilBoss,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Dust Moth'),
      KenneyAssets.enemyVeilMite,
    );
  });

  test('sandy swarm codex names map to sandy mite fight art', () {
    expect(
      KenneyAssets.enemySpriteForCodexName('Cave Slime'),
      KenneyAssets.enemySandyMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Drip Ooze'),
      KenneyAssets.enemySandyMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Spit Bat'),
      KenneyAssets.enemySandyRanged,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Blood Stalker'),
      KenneyAssets.enemyRat,
    );
  });

  test('named trash maps to zone fight art', () {
    expect(
      KenneyAssets.enemySpriteForCodexName('Goblin Thug'),
      KenneyAssets.enemySpider,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Hex Spider'),
      KenneyAssets.enemyUnderworldMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Soul Spitter'),
      KenneyAssets.enemyUnderworldMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Crossbowman'),
      KenneyAssets.enemyCultist,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Court Mage'),
      KenneyAssets.enemyKingMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Hex Witch'),
      KenneyAssets.enemyCultist,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Ash Chanter'),
      KenneyAssets.enemySpider,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Razor Eel'),
      KenneyAssets.enemySlime,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Ash Behemoth'),
      KenneyAssets.enemyHellBrute,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Ash Colossus'),
      KenneyAssets.enemyHellBrute,
    );
  });
}
