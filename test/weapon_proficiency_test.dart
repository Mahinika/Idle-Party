import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/starter_gear.dart';
import 'package:idle_party/models/apex_craft.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/proficiency.dart';

void main() {
  EquipmentItem mh(WeaponType type, {WeaponHanded? handed}) {
    final hand = handed ?? ClassProficiency.defaultHanded(type);
    return EquipmentItem(
      id: 'mh_${type.name}',
      name: type.name,
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      weaponType: type,
      handed: hand,
      itemLevel: 20,
    );
  }

  EquipmentItem oh(OffHandKind kind, {WeaponType? weaponType}) {
    return EquipmentItem(
      id: 'oh_${kind.name}',
      name: kind.name,
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.rare,
      offHandKind: kind,
      weaponType: weaponType,
      handed: kind == OffHandKind.weapon ? WeaponHanded.oneHand : null,
      itemLevel: 20,
    );
  }

  EquipmentItem rng(WeaponType type) {
    return EquipmentItem(
      id: 'rng_${type.name}',
      name: type.name,
      slot: EquipmentSlot.ranged,
      rarity: LootRarity.rare,
      weaponType: type,
      handed: ClassProficiency.defaultHanded(type),
      itemLevel: 20,
    );
  }

  bool can(HeroSpecId id, EquipmentItem item) {
    return ClassProficiency.canEquip(
      role: HeroSpecs.def(id).gearAffinity,
      level: 40,
      item: item,
      specId: id,
    );
  }

  test('paladin cannot dagger; priest cannot sword; hunter cannot mace', () {
    expect(can(HeroSpecId.holyPaladin, mh(WeaponType.dagger)), isFalse);
    expect(can(HeroSpecId.retribution, mh(WeaponType.sword)), isTrue);
    expect(can(HeroSpecId.discipline, mh(WeaponType.sword)), isFalse);
    expect(can(HeroSpecId.shadow, mh(WeaponType.sword)), isFalse);
    expect(can(HeroSpecId.discipline, mh(WeaponType.mace)), isTrue);
    expect(can(HeroSpecId.beastMastery, mh(WeaponType.mace)), isFalse);
    expect(can(HeroSpecId.beastMastery, mh(WeaponType.polearm)), isTrue);
    expect(can(HeroSpecId.restorationShaman, mh(WeaponType.sword)), isFalse);
    expect(can(HeroSpecId.enhancement, mh(WeaponType.axe)), isTrue);
  });

  test('dual wield and shields follow the WotLK lists', () {
    expect(can(HeroSpecId.fury, oh(OffHandKind.weapon, weaponType: WeaponType.axe)), isTrue);
    expect(can(HeroSpecId.arms, oh(OffHandKind.weapon, weaponType: WeaponType.axe)), isFalse);
    expect(can(HeroSpecId.protection, oh(OffHandKind.shield)), isTrue);
    expect(can(HeroSpecId.retribution, oh(OffHandKind.weapon, weaponType: WeaponType.sword)), isFalse);
    expect(can(HeroSpecId.holyPaladin, oh(OffHandKind.shield)), isTrue);
    expect(can(HeroSpecId.frostDk, oh(OffHandKind.weapon, weaponType: WeaponType.axe)), isTrue);
    expect(can(HeroSpecId.frostDk, oh(OffHandKind.shield)), isFalse);
    expect(can(HeroSpecId.blood, oh(OffHandKind.shield)), isFalse);
    expect(can(HeroSpecId.enhancement, oh(OffHandKind.weapon, weaponType: WeaponType.axe)), isTrue);
    expect(can(HeroSpecId.restorationShaman, oh(OffHandKind.shield)), isTrue);
    expect(can(HeroSpecId.survival, oh(OffHandKind.weapon, weaponType: WeaponType.axe)), isTrue);
    expect(can(HeroSpecId.beastMastery, oh(OffHandKind.weapon, weaponType: WeaponType.axe)), isFalse);
    expect(can(HeroSpecId.guardian, oh(OffHandKind.shield)), isFalse);
    expect(can(HeroSpecId.combat, oh(OffHandKind.weapon, weaponType: WeaponType.dagger)), isTrue);
  });

  test('ranged slot is empty for paladin DK shaman druid', () {
    expect(can(HeroSpecId.holyPaladin, rng(WeaponType.wand)), isFalse);
    expect(can(HeroSpecId.holyPaladin, rng(WeaponType.thrown)), isFalse);
    expect(can(HeroSpecId.blood, rng(WeaponType.thrown)), isFalse);
    expect(can(HeroSpecId.restorationShaman, rng(WeaponType.wand)), isFalse);
    expect(can(HeroSpecId.balance, rng(WeaponType.wand)), isFalse);
    expect(can(HeroSpecId.protection, rng(WeaponType.thrown)), isTrue);
    expect(can(HeroSpecId.protection, rng(WeaponType.bow)), isFalse);
    expect(can(HeroSpecId.combat, rng(WeaponType.thrown)), isTrue);
    expect(can(HeroSpecId.beastMastery, rng(WeaponType.bow)), isTrue);
    expect(can(HeroSpecId.beastMastery, rng(WeaponType.thrown)), isFalse);
    expect(can(HeroSpecId.fire, rng(WeaponType.wand)), isTrue);
    expect(StarterGear.forSpec(HeroSpecId.holyPaladin).containsKey(EquipmentSlot.ranged), isFalse);
    expect(StarterGear.forSpec(HeroSpecId.blood).containsKey(EquipmentSlot.ranged), isFalse);
    expect(StarterGear.forSpec(HeroSpecId.restorationShaman).containsKey(EquipmentSlot.ranged), isFalse);
    expect(StarterGear.forSpec(HeroSpecId.balance).containsKey(EquipmentSlot.ranged), isFalse);
    expect(StarterGear.forSpec(HeroSpecId.protection)[EquipmentSlot.ranged]!.weaponType, WeaponType.thrown);
    expect(StarterGear.forSpec(HeroSpecId.combat)[EquipmentSlot.ranged]!.weaponType, WeaponType.thrown);
  });

  test('starters are legal weapons for every spec', () {
    for (final id in HeroSpecId.values) {
      final kit = StarterGear.forSpec(id);
      for (final item in kit.values) {
        if (item.slot != EquipmentSlot.weapon &&
            item.slot != EquipmentSlot.offHand &&
            item.slot != EquipmentSlot.ranged) {
          continue;
        }
        expect(
          ClassProficiency.canEquip(
            role: HeroSpecs.def(id).gearAffinity,
            level: 1,
            item: item,
            specId: id,
          ),
          isTrue,
          reason: '$id cannot wear ${item.name} (${item.slot} ${item.typeLabel})',
        );
      }
      expect(kit.containsKey(EquipmentSlot.weapon), isTrue, reason: '$id missing MH');
    }
  });

  test('load strips an illegal paladin dagger into the bag', () {
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
    final dagger = mh(WeaponType.dagger);
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          if (h.id == pal.id)
            h.copyWith(equipped: {...h.equipped, EquipmentSlot.weapon: dagger})
          else
            h,
      ],
    );
    final loaded = GameLogic.stateFromJson(state.toJson());
    final after = loaded.heroes.firstWhere(
      (h) => h.specId == HeroSpecId.holyPaladin,
    );
    expect(after.itemIn(EquipmentSlot.weapon)?.weaponType, isNot(WeaponType.dagger));
    expect(loaded.gearStash.any((g) => g.id == dagger.id), isTrue);
    expect(
      ClassProficiency.canEquip(
        role: after.gearAffinity,
        level: after.level,
        item: after.itemIn(EquipmentSlot.weapon)!,
        specId: after.specId,
      ),
      isTrue,
    );
  });

  test('loot for a paladin never rolls a ranged piece they cannot use', () {
    EquipmentFactory.random = Random(7);
    for (var i = 0; i < 12; i++) {
      final item = EquipmentFactory.create(
        slot: EquipmentSlot.ranged,
        rarity: LootRarity.rare,
        battleNumber: 10,
        bias: HeroRole.healer,
        lootSpecId: HeroSpecId.holyPaladin,
      );
      expect(item.slot, isNot(EquipmentSlot.ranged));
      expect(can(HeroSpecId.holyPaladin, item), isTrue);
    }
  });

  test('Apex weapons and off-hands are legal for the recipe spec', () {
    for (final classId in HeroClassId.values) {
      for (final role in ApexCraft.validRolesFor(classId)) {
        final spec = ApexCraft.representativeSpec(classId, role);
        expect(spec, isNotNull);
        for (final slot in ApexCraft.craftSlotsFor(classId, role)) {
          if (slot != EquipmentSlot.weapon && slot != EquipmentSlot.offHand) {
            continue;
          }
          final item = ApexCraft.buildItem(
            classId: classId,
            role: role,
            slot: slot,
            rank: 1,
            ascensionLevel: 0,
          );
          expect(
            ClassProficiency.canEquip(
              role: spec!.gearAffinity,
              level: 80,
              item: item,
              specId: spec.id,
            ),
            isTrue,
            reason: '$classId $role $slot -> ${item.typeLabel}',
          );
        }
      }
    }
  });
}
