import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  EquipmentItem piece({
    required ArmorType armor,
    required HeroRole affinity,
    int agi = 0,
    int intel = 0,
    int sp = 0,
    int str = 0,
    int sta = 8,
  }) {
    return EquipmentItem(
      id: 't_${armor.name}',
      name: 'Test ${armor.name}',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      armorType: armor,
      affinity: affinity.name,
      agilityBonus: agi,
      intellectBonus: intel,
      spellPowerBonus: sp,
      strengthBonus: str,
      staminaBonus: sta,
      armorBonus: armor == ArmorType.cloth
          ? 2
          : (armor == ArmorType.leather
              ? 6
              : (armor == ArmorType.mail ? 12 : 18)),
    );
  }

  PartyHero heroFor(HeroSpecId id, {String name = 'Hero', int level = 20}) {
    return PartyHero.starting(
      name: name,
      specId: id,
      stats: PartyHero.startingStatsForSpec(id),
    ).copyWith(level: level);
  }

  test('hunters prefer mail over leather at equal Agi budget', () {
    final hero = heroFor(HeroSpecId.beastMastery, name: 'Hunt');
    final mail = piece(
      armor: ArmorType.mail,
      affinity: HeroRole.rogue,
      agi: 10,
      sta: 8,
    );
    final leather = piece(
      armor: ArmorType.leather,
      affinity: HeroRole.rogue,
      agi: 12,
      sta: 6,
    );
    expect(
      GameLogic.specEquipScore(hero, mail),
      greaterThan(GameLogic.specEquipScore(hero, leather)),
    );
  });

  test('elemental prefers mail caster stats over cloth', () {
    final hero = heroFor(HeroSpecId.elemental, name: 'Storm');
    final mail = piece(
      armor: ArmorType.mail,
      affinity: HeroRole.mage,
      intel: 10,
      sp: 8,
      sta: 6,
    );
    final cloth = piece(
      armor: ArmorType.cloth,
      affinity: HeroRole.mage,
      intel: 12,
      sp: 10,
      sta: 4,
    );
    expect(
      GameLogic.specEquipScore(hero, mail),
      greaterThan(GameLogic.specEquipScore(hero, cloth)),
    );
  });

  test('holy paladin prefers plate healer stats over cloth', () {
    final hero = heroFor(HeroSpecId.holyPaladin, name: 'Light', level: 40);
    final plate = piece(
      armor: ArmorType.plate,
      affinity: HeroRole.healer,
      intel: 10,
      sp: 8,
      sta: 8,
    );
    final cloth = piece(
      armor: ArmorType.cloth,
      affinity: HeroRole.healer,
      intel: 12,
      sp: 10,
      sta: 4,
    );
    expect(
      GameLogic.specEquipScore(hero, plate),
      greaterThan(GameLogic.specEquipScore(hero, cloth)),
    );
  });

  test('mail+mage bias rolls intellect-heavy stats', () {
    EquipmentFactory.random = Random(7);
    var intSum = 0;
    var agiSum = 0;
    for (var i = 0; i < 20; i++) {
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.chest,
        rarity: LootRarity.rare,
        battleNumber: 12,
        bias: HeroRole.mage,
        preferredArmor: ArmorType.mail,
      );
      expect(item.armorType, ArmorType.mail);
      intSum += item.intellectBonus + item.spellPowerBonus;
      agiSum += item.agilityBonus;
    }
    expect(intSum, greaterThan(agiSum));
  });
}
