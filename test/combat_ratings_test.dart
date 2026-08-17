import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/combat_ratings.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/stats.dart';

void main() {
  PartyHero hero(HeroSpecId id, {int level = 10, Stats? stats}) {
    final spec = HeroSpecs.def(id);
    return PartyHero(
      id: id.name,
      name: spec.shortLabel,
      level: level,
      currentHp: 100,
      stats: stats ?? spec.startingStats,
      specId: id,
      equipped: const {},
    );
  }

  test('plate melee is 2 AP per Strength', () {
    expect(
      CombatRatings.meleeAttackPower(
        role: HeroRole.warrior,
        strength: 10,
        agility: 50,
        level: 1,
      ),
      2 * 10 + 3,
    );
  });

  test('rogue-family is 1 AP per Strength and 2 AP per Agility', () {
    expect(
      CombatRatings.meleeAttackPower(
        role: HeroRole.rogue,
        strength: 10,
        agility: 20,
        level: 1,
      ),
      10 + 2 * 20 + 2,
    );
  });

  test('gear Int and Spell Power add the same sheet ATK', () {
    final mage = hero(HeroSpecId.fire, level: 20);
    final intGear = CombatRatings.fromHeroSheet(
      hero: mage,
      gearIntellect: 90,
    );
    final spGear = CombatRatings.fromHeroSheet(
      hero: mage,
      gearSpellPower: 90,
    );
    expect(intGear.physicalAttack, spGear.physicalAttack);
    expect(intGear.critChance, greaterThan(spGear.critChance));
  });

  test('level Intellect is full ATK; gear Int is ~/3', () {
    const base = Stats(
      strength: 1,
      agility: 1,
      stamina: 5,
      intellect: 10,
      spirit: 4,
    );
    final mage = hero(HeroSpecId.fire, level: 1, stats: base);
    final naked = CombatRatings.fromHeroSheet(hero: mage);
    final geared = CombatRatings.fromHeroSheet(hero: mage, gearIntellect: 9);
    expect(naked.physicalAttack, 10);
    expect(geared.physicalAttack, 10 + 9 ~/ 3);
  });

  test('soulbound item conversion matches worn gear ROI', () {
    expect(
      CombatRatings.itemAttackContribution(
        strength: 20,
        agility: 0,
        intellect: 0,
        spellPower: 0,
      ),
      (2 * 20 / CombatRatings.kAp).round(),
    );
    expect(
      CombatRatings.itemAttackContribution(
        strength: 0,
        agility: 20,
        intellect: 0,
        spellPower: 0,
      ),
      (2 * 20 / CombatRatings.kAp).round(),
    );
    expect(
      CombatRatings.itemAttackContribution(
        strength: 0,
        agility: 0,
        intellect: 12,
        spellPower: 12,
      ),
      (12 + 12) ~/ 3,
    );
  });

  test('percent armor always helps and never zeros a hit', () {
    const atk = 40;
    final none = CombatRatings.mitigateByArmor(
      rawDamage: atk,
      defense: 0,
      attackerAttack: atk,
    );
    final some = CombatRatings.mitigateByArmor(
      rawDamage: atk,
      defense: 20,
      attackerAttack: atk,
    );
    final lots = CombatRatings.mitigateByArmor(
      rawDamage: atk,
      defense: 400,
      attackerAttack: atk,
    );
    expect(none, atk);
    expect(some, lessThan(none));
    expect(lots, lessThan(some));
    expect(lots, greaterThanOrEqualTo((atk * 0.25).ceil()));
  });

  test('Agility chest raises Combat Rogue sheet ATK more than Strength', () {
    final rogue = hero(HeroSpecId.combat, level: 20);
    final str = CombatRatings.fromHeroSheet(hero: rogue, gearStrength: 12);
    final agi = CombatRatings.fromHeroSheet(hero: rogue, gearAgility: 12);
    expect(agi.physicalAttack, greaterThan(str.physicalAttack));
  });
}
