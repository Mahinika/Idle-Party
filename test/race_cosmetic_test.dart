import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';

void main() {
  test('race does not change starter combat stats', () {
    final human = PartyHero.starting(
      name: 'Test',
      specId: HeroSpecId.protection,
      race: HeroRace.human,
    );
    final orc = PartyHero.starting(
      name: 'Test',
      specId: HeroSpecId.protection,
      race: HeroRace.orc,
    );
  final nightElf = PartyHero.starting(
      name: 'Test',
      specId: HeroSpecId.fire,
      race: HeroRace.nightElf,
    );
    final humanFire = PartyHero.starting(
      name: 'Test',
      specId: HeroSpecId.fire,
      race: HeroRace.human,
    );

    expect(human.attack, orc.attack);
    expect(human.maxHp, orc.maxHp);
    expect(human.grownPrimaries, orc.grownPrimaries);
    expect(nightElf.attack, humanFire.attack);
    expect(nightElf.maxHp, humanFire.maxHp);
  });

  test('picker summary states cosmetic-only', () {
    expect(HeroRace.pickerSummary.toLowerCase(), contains('cosmetic'));
    expect(HeroRace.pickerSummary.toLowerCase(), contains('no stat bonus'));
  });
}