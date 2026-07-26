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
      KenneyAssets.enemySlime,
      KenneyAssets.enemyCyclops,
      KenneyAssets.enemyCrab,
      KenneyAssets.enemyBoss,
      KenneyAssets.enemyCultist,
      KenneyAssets.sword,
      KenneyAssets.staff,
      KenneyAssets.potionRed,
      KenneyAssets.chestClosed,
      KenneyAssets.barrel,
      KenneyAssets.book,
      KenneyAssets.coinGold,
      KenneyAssets.ring,
      for (final role in HeroRole.values) KenneyAssets.heroSpriteForRole(role),
      for (final role in EnemyRole.values)
        KenneyAssets.enemySpriteForRole(role, dungeonId: 'sandy'),
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
    expect(KenneyAssets.sword, isNot(KenneyAssets.torch));
  });
}
