import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/visual/equipment_visual_resolver.dart';

void main() {
  test('factory stamps visualSetId', () {
    final sword = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    expect(sword.visualSetId, isNotNull);
    expect(
      EquipmentVisualResolver.catalog.containsKey(sword.visualSetId),
      isTrue,
    );
  });

  test('hunter bow and mage staff resolve weapon families', () {
    final bow = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.rogue,
    ).copyWith(weaponType: WeaponType.bow, clearVisualSetId: true);
    expect(EquipmentVisualResolver.resolveId(bow), startsWith('bow_'));
    expect(
      EquipmentVisualResolver.defForItem(bow)?.layer.name,
      'mainHand',
    );

    final staff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 4,
      bias: HeroRole.mage,
    ).copyWith(weaponType: WeaponType.staff, clearVisualSetId: true);
    expect(EquipmentVisualResolver.resolveId(staff), startsWith('staff_'));
  });

  test('explicit visualSetId wins over derive', () {
    final item = GameLogic.createEquipment(
      slot: EquipmentSlot.head,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.warrior,
    ).copyWith(visualSetId: 'helm_t3');
    expect(EquipmentVisualResolver.resolveId(item), 'helm_t3');
  });

  test('catalog covers sword/shield tiers', () {
    expect(EquipmentVisualResolver.catalog['sword_t0'], isNotNull);
    expect(EquipmentVisualResolver.catalog['shield_t2'], isNotNull);
    expect(EquipmentVisualResolver.catalog['bow_t1']!.useAnchor, isTrue);
  });
}
