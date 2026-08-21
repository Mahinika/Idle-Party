import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/loot_pipeline.dart';
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

  test('healer rares roll Mp5/Crit before Haste', () {
    var mp5Hits = 0;
    var critHits = 0;
    var hasteHits = 0;
    for (var i = 0; i < 40; i++) {
      EquipmentFactory.random = Random(4100 + i);
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.chest,
        rarity: LootRarity.rare,
        battleNumber: 18,
        bias: HeroRole.healer,
        preferredArmor: ArmorType.cloth,
        roleTag: SpecRoleTag.healer,
      );
      if (item.mp5Bonus > 0) mp5Hits++;
      if (item.critChanceBonus > 0) critHits++;
      if (item.attackSpeedBonus > 0) hasteHits++;
    }
    expect(mp5Hits, greaterThan(hasteHits));
    expect(mp5Hits + critHits, greaterThan(hasteHits * 2));
  });

  test('healer weapons do not haste-first', () {
    var mp5Hits = 0;
    var hasteHits = 0;
    for (var i = 0; i < 32; i++) {
      EquipmentFactory.random = Random(4200 + i);
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 18,
        bias: HeroRole.healer,
        roleTag: SpecRoleTag.healer,
        lootSpecId: HeroSpecId.discipline,
      );
      if (item.mp5Bonus > 0) mp5Hits++;
      if (item.attackSpeedBonus > 0) hasteHits++;
    }
    expect(mp5Hits, greaterThan(hasteHits));
  });

  test('healer Apex spends Mp5 not Haste', () {
    final disc = ApexCraft.buildItem(
      classId: HeroClassId.priest,
      role: SpecRoleTag.healer,
      slot: EquipmentSlot.weapon,
      rank: 1,
      ascensionLevel: 3,
    );
    expect(disc.mp5Bonus, greaterThan(0));
    expect(disc.attackSpeedBonus, 0);
    expect(disc.critChanceBonus, greaterThan(0));
  });

  test('starter party drops every wearable family including shields', () {
    final party = GameLogic.createInitialState().heroes;
    final seen = <EquipmentSlot>{};
    var shields = 0;
    var tomes = 0;
    var ring2 = 0;
    var trinket2 = 0;
    var chests = 0;
    var rings = 0;
    var gear = 0;
    for (var seed = 0; seed < 500; seed++) {
      GameLogic.random = Random(seed);
      for (final drop in GameLogic.rollKillLoot(
        8,
        party: party,
        dungeonId: 'sandy',
      )) {
        final item = drop.equipment;
        if (item == null) continue;
        gear++;
        seen.add(item.slot);
        if (item.slot == EquipmentSlot.chest) chests++;
        if (item.slot == EquipmentSlot.ring) rings++;
        if (item.slot == EquipmentSlot.ring2) ring2++;
        if (item.slot == EquipmentSlot.trinket2) trinket2++;
        if (item.offHandKind == OffHandKind.shield) shields++;
        if (item.offHandKind == OffHandKind.frill) tomes++;
      }
    }
    expect(gear, greaterThan(400));
    for (final slot in LootPipeline.dropFamilies) {
      expect(seen.contains(slot), isTrue, reason: '$slot never dropped');
    }
    expect(ring2, 0);
    expect(trinket2, 0);
    expect(shields, greaterThan(8), reason: 'Prot in party should see shields');
    expect(tomes, greaterThan(0));
    expect(rings, lessThan(chests * 3));
  });

  test('Prot-only off-hands are shields', () {
    final tank = PartyHero.starting(
      name: 'Aegis',
      specId: HeroSpecId.protection,
      level: 20,
    );
    var offHands = 0;
    var shields = 0;
    for (var seed = 0; seed < 250; seed++) {
      GameLogic.random = Random(9100 + seed);
      for (final drop in GameLogic.rollKillLoot(
        10,
        party: [tank],
        dungeonId: 'sandy',
      )) {
        final item = drop.equipment;
        if (item == null) continue;
        if (item.slot != EquipmentSlot.offHand) continue;
        offHands++;
        if (item.offHandKind == OffHandKind.shield) shields++;
      }
    }
    expect(offHands, greaterThan(8));
    expect(shields, offHands);
  });

  test('hunter-only party skips off-hand instead of turning it into weapons', () {
    final hunt = PartyHero.starting(
      name: 'Hunt',
      specId: HeroSpecId.beastMastery,
      level: 20,
    );
    var offHand = 0;
    var weapons = 0;
    var gear = 0;
    for (var seed = 0; seed < 300; seed++) {
      GameLogic.random = Random(8000 + seed);
      for (final drop in GameLogic.rollKillLoot(
        10,
        party: [hunt],
        dungeonId: 'sandy',
      )) {
        final item = drop.equipment;
        if (item == null) continue;
        gear++;
        if (item.slot == EquipmentSlot.offHand) offHand++;
        if (item.slot == EquipmentSlot.weapon) weapons++;
      }
    }
    expect(offHand, 0);
    expect(weapons, lessThan((gear * 0.14).round()));
    expect(weapons, greaterThan((gear * 0.03).round()));
  });

  test('charm drops always roll an on-item effect', () {
    for (var seed = 0; seed < 40; seed++) {
      GameLogic.random = Random(9000 + seed);
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.trinket,
        rarity: LootRarity.common,
        battleNumber: 8,
        bias: HeroRole.warrior,
        dungeonId: 'sandy',
      );
      expect(item.slot, EquipmentSlot.trinket);
      expect(item.effectId, isNot(GearEffectId.none));
      expect(item.name.toLowerCase(), contains('charm'));
    }
  });
}
