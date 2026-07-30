import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/ui/kenney_assets.dart';

void main() {
  test('Tiny Dungeon tile files exist for catalog getters', () {
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
      for (final role in HeroRole.values) KenneyAssets.heroSpriteForRole(role),
      // Enemies are custom PNGs (still must exist on disk).
      ...KenneyAssets.enemySpriteCatalog,
      for (final role in EnemyRole.values)
        KenneyAssets.enemySpriteForRole(role, dungeonId: 'sandy'),
      KenneyAssets.enemySpriteForCodexName('Goblin Scout'),
      KenneyAssets.enemySpriteForCodexName('Crystal Warden'),
    };

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
      KenneyAssets.enemyCrystalBoss,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Frost Wisp'),
      KenneyAssets.enemyCrystalMite,
    );
    expect(
      KenneyAssets.enemySpriteForCodexName('Ice Caster'),
      KenneyAssets.enemyCrystalWraith,
    );
  });
}
