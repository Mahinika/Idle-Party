import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/models/proficiency.dart';

void main() {
  test('every class starter fills all equipment slots', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    for (final hero in state.heroes) {
      expect(
        hero.equipped.keys.toSet(),
        EquipmentSlot.values.toSet(),
        reason: '${hero.role} missing slots',
      );
      for (final item in hero.equipped.values) {
        expect(
          ClassProficiency.canEquip(
            role: hero.role,
            level: hero.level,
            item: item,
          ),
          isTrue,
          reason: '${hero.role} cannot wear ${item.name} (${item.slot})',
        );
      }
    }
  });

  test('fillMissingStarterGear completes partial kits', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final warrior = state.heroes.first;
    state = state.copyWith(
      heroes: [
        warrior.copyWith(
          equipped: {
            EquipmentSlot.weapon: warrior.itemIn(EquipmentSlot.weapon)!,
          },
        ),
        ...state.heroes.skip(1),
      ],
    );
    expect(state.heroes.first.equipped.length, 1);
    final keptId = state.heroes.first.itemIn(EquipmentSlot.weapon)!.id;
    state = GameLogic.fillMissingStarterGear(state);
    expect(
      state.heroes.first.equipped.keys.toSet(),
      EquipmentSlot.values.toSet(),
    );
    expect(state.heroes.first.itemIn(EquipmentSlot.weapon)?.id, keptId);
  });

  test('factory rolls equippable gear for every slot and class', () {
    EquipmentFactory.random = GameLogic.random;
    for (final role in HeroRole.values) {
      for (final slot in EquipmentSlot.values) {
        if (slot == EquipmentSlot.consumable) continue;
        final item = EquipmentFactory.create(
          slot: slot,
          rarity: LootRarity.uncommon,
          battleNumber: 8,
          bias: role,
        );
        expect(item.slot, slot);
        expect(
          ClassProficiency.canEquip(role: role, level: 40, item: item),
          isTrue,
          reason: '$role $slot -> ${item.name} ${item.typeLabel}',
        );
      }
    }
  });

  test('rogue can dual-wield off-hand weapons', () {
    final oh = EquipmentFactory.create(
      slot: EquipmentSlot.offHand,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.rogue,
    );
    expect(oh.offHandKind, OffHandKind.weapon);
    expect(oh.weaponType, isNotNull);
    expect(
      ClassProficiency.canEquip(
        role: HeroRole.rogue,
        level: 1,
        item: oh,
      ),
      isTrue,
    );
  });
}
