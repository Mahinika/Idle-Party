import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/apex_craft.dart';
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

  test('budget score ignores armor type at equal weighted stats', () {
    // GEAR_BUDGET: no armor/affinity crumbs — same stats → same BiS score.
    // (piece() defaults armorBonus by material; pin equal Armor here.)
    final hero = heroFor(HeroSpecId.beastMastery, name: 'Hunt');
    final mail = piece(
      armor: ArmorType.mail,
      affinity: HeroRole.rogue,
      agi: 10,
      sta: 8,
    ).copyWith(armorBonus: 10);
    final leather = piece(
      armor: ArmorType.leather,
      affinity: HeroRole.rogue,
      agi: 10,
      sta: 8,
    ).copyWith(armorBonus: 10);
    expect(
      GameLogic.specEquipScore(hero, mail),
      GameLogic.specEquipScore(hero, leather),
    );
  });

  test('elemental ranks higher Int/SP budget over lower budget', () {
    final hero = heroFor(HeroSpecId.elemental, name: 'Storm');
    final strong = piece(
      armor: ArmorType.mail,
      affinity: HeroRole.mage,
      intel: 14,
      sp: 12,
      sta: 6,
    );
    final weak = piece(
      armor: ArmorType.cloth,
      affinity: HeroRole.mage,
      intel: 8,
      sp: 6,
      sta: 4,
    );
    expect(
      GameLogic.specEquipScore(hero, strong),
      greaterThan(GameLogic.specEquipScore(hero, weak)),
    );
  });

  test('holy paladin ranks higher healer budget over lower budget', () {
    final hero = heroFor(HeroSpecId.holyPaladin, name: 'Light', level: 40);
    final strong = piece(
      armor: ArmorType.plate,
      affinity: HeroRole.healer,
      intel: 14,
      sp: 12,
      sta: 10,
    );
    final weak = piece(
      armor: ArmorType.cloth,
      affinity: HeroRole.healer,
      intel: 8,
      sp: 6,
      sta: 4,
    );
    expect(
      GameLogic.specEquipScore(hero, strong),
      greaterThan(GameLogic.specEquipScore(hero, weak)),
    );
  });

  test('mail+mage bias rolls intellect-heavy stats', () {
    var intSum = 0;
    var agiSum = 0;
    for (var i = 0; i < 20; i++) {
      EquipmentFactory.random = Random(1000 + i);
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.chest,
        rarity: LootRarity.rare,
        battleNumber: 12,
        bias: HeroRole.mage,
        preferredArmor: ArmorType.mail,
      );
      // Prefer path is 82% — skip non-mail rolls for the stat check.
      if (item.armorType != ArmorType.mail) continue;
      intSum += item.intellectBonus + item.spellPowerBonus;
      agiSum += item.agilityBonus;
    }
    expect(intSum, greaterThan(agiSum));
  });

  test('Apex spends lootShares — no flat ATK dump, plate is Str not Agi', () {
    final arms = ApexCraft.buildItem(
      classId: HeroClassId.warrior,
      role: SpecRoleTag.meleeDps,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 3,
    );
    expect(arms.attackBonus, 0);
    expect(arms.agilityBonus, 0);
    expect(arms.strengthBonus, greaterThan(arms.staminaBonus));

    final combat = ApexCraft.buildItem(
      classId: HeroClassId.rogue,
      role: SpecRoleTag.meleeDps,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 3,
    );
    expect(combat.attackBonus, 0);
    expect(combat.agilityBonus, greaterThan(combat.strengthBonus));

    final hunt = ApexCraft.buildItem(
      classId: HeroClassId.hunter,
      role: SpecRoleTag.rangedDps,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 3,
    );
    expect(hunt.attackBonus, 0);
    expect(hunt.agilityBonus, greaterThan(hunt.strengthBonus));

    final fire = ApexCraft.buildItem(
      classId: HeroClassId.mage,
      role: SpecRoleTag.caster,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 3,
    );
    expect(fire.attackBonus, 0);
    expect(fire.intellectBonus, greaterThan(fire.spellPowerBonus));

    final disc = ApexCraft.buildItem(
      classId: HeroClassId.priest,
      role: SpecRoleTag.healer,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 3,
    );
    expect(
      disc.intellectBonus + disc.spellPowerBonus,
      greaterThan(disc.spiritBonus),
    );
  });

  test('warrior rare drops stay Str/Sta — not Agility', () {
    var strSum = 0;
    var agiSum = 0;
    for (var i = 0; i < 24; i++) {
      EquipmentFactory.random = Random(2000 + i);
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.chest,
        rarity: LootRarity.rare,
        battleNumber: 14,
        bias: HeroRole.warrior,
        preferredArmor: ArmorType.plate,
        roleTag: SpecRoleTag.meleeDps,
      );
      strSum += item.strengthBonus;
      agiSum += item.agilityBonus;
    }
    expect(strSum, greaterThan(agiSum * 4));
  });

  test('healer rare drops spend more on Int/SP than Spirit', () {
    var throughput = 0;
    var spi = 0;
    for (var i = 0; i < 24; i++) {
      EquipmentFactory.random = Random(3000 + i);
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.chest,
        rarity: LootRarity.rare,
        battleNumber: 14,
        bias: HeroRole.healer,
        preferredArmor: ArmorType.cloth,
        roleTag: SpecRoleTag.healer,
      );
      throughput += item.intellectBonus + item.spellPowerBonus;
      spi += item.spiritBonus;
    }
    expect(throughput, greaterThan(spi));
  });
}
