import 'dart:io';

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

  test('all families expose walk and attack clips', () {
    final mage = PartyHero.starting(
      name: 'M',
      specId: HeroSpecId.arcane,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.arcane),
    );
    expect(BodyFamilyCatalog.familyFor(mage), BodyFamily.mage);
    expect(
      BodyFamilyCatalog.assetFor(mage, HeroAnimKind.walk),
      'assets/custom/char/mage/body_walk.png',
    );
    expect(
      BodyFamilyCatalog.assetFor(mage, HeroAnimKind.attack),
      'assets/custom/char/mage/body_attack.png',
    );
    expect(
      BodyFamilyCatalog.assetFor(mage, HeroAnimKind.cast),
      'assets/custom/char/mage/body_attack.png',
    );
    // No hit clip: idle + painter recoil. The walk stride read as a phantom
    // step every time a hero took damage.
    expect(
      BodyFamilyCatalog.assetFor(mage, HeroAnimKind.hit),
      'assets/custom/char/mage/body_idle.png',
    );
  });

  test('catalog lists unique asset paths that exist on disk', () {
    final paths = BodyFamilyCatalog.allAssetPaths;
    expect(paths, contains('assets/custom/char/warrior/body_idle.png'));
    expect(paths, contains('assets/custom/char/rogue/body_idle.png'));
    expect(paths, contains('assets/custom/char/healer/body_walk.png'));
    expect(paths, contains('assets/custom/char/mage/body_attack.png'));
    expect(paths, contains('assets/custom/char/warrior/body_tint_idle.png'));
    expect(paths, contains('assets/custom/char/rogue/body_tint_attack.png'));
    expect(
      paths,
      contains('assets/custom/char/warrior/nightelf_m_body_idle.png'),
    );
    expect(
      paths,
      contains('assets/custom/char/healer/nightelf_f_body_walk.png'),
    );
    expect(
      paths,
      contains('assets/custom/char/healer/nightelf_f_body_tint_attack.png'),
    );
    expect(paths.toSet().length, paths.length);
    // 4 families × 3 anims × (body+tint) = 24; + 11 races × 4 × 3 × 2 = 264.
    expect(paths.length, 24 + 264);
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test(
    'Night Elf uses a family body clip for every kit',
    () {
      final warrior = PartyHero.starting(
        name: 'Aegis',
        specId: HeroSpecId.protection,
        race: HeroRace.nightElf,
      );
      expect(warrior.sex, HeroSex.male);
      expect(BodyFamilyCatalog.hasAuthoredRaceBody(warrior), isTrue);
      expect(
        BodyFamilyCatalog.assetFor(warrior, HeroAnimKind.idle),
        'assets/custom/char/warrior/nightelf_m_body_idle.png',
      );
      expect(
        BodyFamilyCatalog.tintMaskAssetFor(warrior, HeroAnimKind.walk),
        'assets/custom/char/warrior/nightelf_m_body_tint_walk.png',
      );

      final healer = PartyHero.starting(
        name: 'Vale',
        specId: HeroSpecId.discipline,
        race: HeroRace.nightElf,
      );
      expect(healer.sex, HeroSex.female);
      expect(
        BodyFamilyCatalog.assetFor(healer, HeroAnimKind.attack),
        'assets/custom/char/healer/nightelf_f_body_attack.png',
      );

      final mage = PartyHero.starting(
        name: 'Ember',
        specId: HeroSpecId.fire,
        race: HeroRace.nightElf,
      );
      expect(mage.sex, HeroSex.male);
      expect(BodyFamilyCatalog.hasAuthoredRaceBody(mage), isTrue);
      expect(
        BodyFamilyCatalog.assetFor(mage, HeroAnimKind.idle),
        'assets/custom/char/mage/nightelf_m_body_idle.png',
      );

      final rogue = PartyHero.starting(
        name: 'Shade',
        specId: HeroSpecId.combat,
        race: HeroRace.nightElf,
      );
      expect(
        BodyFamilyCatalog.assetFor(rogue, HeroAnimKind.walk),
        'assets/custom/char/rogue/nightelf_m_body_walk.png',
      );
    },
  );
}
