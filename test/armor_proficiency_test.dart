import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/starter_gear.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/proficiency.dart';

void main() {
  EquipmentItem chest(ArmorType armor) => EquipmentItem(
        id: 'c_${armor.name}',
        name: '${armor.name} Chest',
        slot: EquipmentSlot.chest,
        rarity: LootRarity.rare,
        armorType: armor,
        strengthBonus: 12,
        staminaBonus: 10,
        agilityBonus: 12,
        intellectBonus: 12,
        itemLevel: 40,
      );

  bool can(HeroSpecId id, ArmorType armor, {int level = 1}) {
    return ClassProficiency.canEquip(
      role: HeroSpecs.def(id).gearAffinity,
      level: level,
      item: chest(armor),
      specId: id,
    );
  }

  test('plate classes wear plate only, from level 1', () {
    for (final id in [
      HeroSpecId.protection,
      HeroSpecId.arms,
      HeroSpecId.holyPaladin,
      HeroSpecId.retribution,
      HeroSpecId.blood,
    ]) {
      expect(can(id, ArmorType.plate), isTrue, reason: '$id plate');
      expect(can(id, ArmorType.mail), isFalse, reason: '$id mail');
      expect(can(id, ArmorType.leather), isFalse, reason: '$id leather');
      expect(can(id, ArmorType.cloth), isFalse, reason: '$id cloth');
    }
  });

  test('rogue leather only; druid leather + cloth', () {
    expect(can(HeroSpecId.combat, ArmorType.leather), isTrue);
    expect(can(HeroSpecId.combat, ArmorType.cloth), isFalse);
    expect(can(HeroSpecId.balance, ArmorType.leather), isTrue);
    expect(can(HeroSpecId.balance, ArmorType.cloth), isTrue);
    expect(can(HeroSpecId.balance, ArmorType.mail), isFalse);
    expect(can(HeroSpecId.guardian, ArmorType.leather), isTrue);
    expect(can(HeroSpecId.guardian, ArmorType.plate), isFalse);
  });

  test('hunter leather until 40, then mail only', () {
    expect(can(HeroSpecId.beastMastery, ArmorType.leather, level: 1), isTrue);
    expect(can(HeroSpecId.beastMastery, ArmorType.mail, level: 1), isFalse);
    expect(can(HeroSpecId.beastMastery, ArmorType.leather, level: 40), isFalse);
    expect(can(HeroSpecId.beastMastery, ArmorType.mail, level: 40), isTrue);
  });

  test('shaman mail only; cloth casters cloth only', () {
    expect(can(HeroSpecId.enhancement, ArmorType.mail), isTrue);
    expect(can(HeroSpecId.enhancement, ArmorType.leather), isFalse);
    expect(can(HeroSpecId.restorationShaman, ArmorType.mail), isTrue);
    expect(can(HeroSpecId.fire, ArmorType.cloth), isTrue);
    expect(can(HeroSpecId.fire, ArmorType.leather), isFalse);
    expect(can(HeroSpecId.discipline, ArmorType.cloth), isTrue);
  });

  test('starters use the legal material', () {
    expect(
      StarterGear.forSpec(HeroSpecId.holyPaladin)[EquipmentSlot.chest]!
          .armorType,
      ArmorType.plate,
    );
    expect(
      StarterGear.forSpec(HeroSpecId.combat)[EquipmentSlot.chest]!.armorType,
      ArmorType.leather,
    );
    expect(
      StarterGear.forSpec(HeroSpecId.beastMastery)[EquipmentSlot.chest]!
          .armorType,
      ArmorType.leather,
    );
    expect(
      StarterGear.forSpec(HeroSpecId.restorationShaman)[EquipmentSlot.chest]!
          .armorType,
      ArmorType.mail,
    );
  });

  test('load strips illegal leather off a paladin into the bag', () {
    var state = GameLogic.createInitialState(
      now: DateTime(2026, 8, 17),
      partySpecs: [
        HeroSpecId.holyPaladin,
        HeroSpecId.discipline,
        HeroSpecId.fire,
      ],
    );
    final pal = state.heroes.firstWhere(
      (h) => h.specId == HeroSpecId.holyPaladin,
    );
    final leather = chest(ArmorType.leather);
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          if (h.id == pal.id)
            h.copyWith(
              equipped: {...h.equipped, EquipmentSlot.chest: leather},
            )
          else
            h,
      ],
    );
    final loaded = GameLogic.stateFromJson(state.toJson());
    final after = loaded.heroes.firstWhere(
      (h) => h.specId == HeroSpecId.holyPaladin,
    );
    expect(after.itemIn(EquipmentSlot.chest)?.armorType, ArmorType.plate);
    expect(
      loaded.gearStash.any((g) => g.id == leather.id),
      isTrue,
    );
  });
}
