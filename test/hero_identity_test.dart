import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/hero_identity.dart';
import 'package:idle_party/models/hero_spec.dart';

void main() {
  test('Shadow remaps to warlock silhouette', () {
    expect(
      HeroIdentity.spriteClassFor(HeroSpecId.shadow),
      HeroClassId.warlock,
    );
    expect(
      HeroIdentity.spriteClassFor(HeroSpecId.discipline),
      HeroClassId.priest,
    );
  });

  test('same-class specs get distinct tints', () {
    final arms = HeroIdentity.tintArgb(HeroSpecId.arms);
    final fury = HeroIdentity.tintArgb(HeroSpecId.fury);
    final prot = HeroIdentity.tintArgb(HeroSpecId.protection);
    expect(arms, isNotNull);
    expect(fury, isNotNull);
    expect(prot, isNotNull);
    expect(arms, isNot(fury));
    expect(fury, isNot(prot));
  });

  test('fantasy lines are non-empty for unlock ladder kits', () {
    for (final id in [
      HeroSpecId.combat,
      HeroSpecId.arms,
      HeroSpecId.beastMastery,
      HeroSpecId.shadow,
    ]) {
      expect(HeroIdentity.fantasyLine(id), isNotEmpty);
    }
  });
}
