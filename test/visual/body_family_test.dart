import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/hero_anim_state.dart';

void main() {
  test('gear affinity maps to body family', () {
    final warrior = PartyHero.starting(
      name: 'A',
      specId: HeroSpecId.protection,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.protection),
    );
    expect(BodyFamilyCatalog.familyFor(warrior), BodyFamily.warrior);
    expect(
      BodyFamilyCatalog.assetFor(warrior, HeroAnimKind.idle),
      'assets/custom/char/warrior/body_idle.png',
    );
    expect(
      BodyFamilyCatalog.assetFor(warrior, HeroAnimKind.attack),
      'assets/custom/char/warrior/body_attack.png',
    );
  });

  test('missing clips fall back to idle', () {
    final mage = PartyHero.starting(
      name: 'M',
      specId: HeroSpecId.arcane,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.arcane),
    );
    expect(BodyFamilyCatalog.familyFor(mage), BodyFamily.mage);
    expect(
      BodyFamilyCatalog.assetFor(mage, HeroAnimKind.walk),
      'assets/custom/char/mage/body_idle.png',
    );
  });

  test('catalog lists unique asset paths', () {
    final paths = BodyFamilyCatalog.allAssetPaths;
    expect(paths, contains('assets/custom/char/warrior/body_idle.png'));
    expect(paths, contains('assets/custom/char/rogue/body_idle.png'));
    expect(paths.toSet().length, paths.length);
  });
}
