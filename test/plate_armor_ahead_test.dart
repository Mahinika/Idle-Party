import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/combat_ratings.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  test('Agi to DEF is a crumb, not Classic 2 armor per Agi', () {
    expect(CombatRatings.agilityToDefense(0), 0);
    expect(CombatRatings.agilityToDefense(7), 0);
    expect(CombatRatings.agilityToDefense(8), 1);
    expect(CombatRatings.agilityToDefense(800), 100);
    expect(CombatRatings.agilityToDefense(800), lessThan(800 * 2));
  });

  test('plate Prot ARMOR beats leather Combat Rogue at high level', () {
    final meta = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 13));
    final prot = _geared(
      spec: HeroSpecId.protection,
      armor: ArmorType.plate,
      roleTag: SpecRoleTag.tank,
      bias: HeroRole.warrior,
      level: 250,
      seed: 7,
    );
    final rogue = _geared(
      spec: HeroSpecId.combat,
      armor: ArmorType.leather,
      roleTag: SpecRoleTag.meleeDps,
      bias: HeroRole.rogue,
      level: 250,
      seed: 11,
    );

    expect(prot.gearArmorBonus, greaterThan(rogue.gearArmorBonus));
    expect(
      meta.effectiveHeroDefense(prot),
      greaterThan(meta.effectiveHeroDefense(rogue)),
      reason:
          'PPROT ${meta.effectiveHeroDefense(prot)} vs COMBAT '
          '${meta.effectiveHeroDefense(rogue)} — plate must win ARMOR',
    );
  });

  test('naked high-level rogue Agi crumb cannot beat tank guard', () {
    final meta = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 13));
    final prot = PartyHero.starting(
      name: 'PPROT',
      specId: HeroSpecId.protection,
      level: 250,
    );
    final rogue = PartyHero.starting(
      name: 'COMBAT',
      specId: HeroSpecId.combat,
      level: 250,
    );
    expect(
      meta.effectiveHeroDefense(prot),
      greaterThan(meta.effectiveHeroDefense(rogue)),
    );
  });
}

const _slots = <EquipmentSlot>[
  EquipmentSlot.head,
  EquipmentSlot.shoulder,
  EquipmentSlot.chest,
  EquipmentSlot.waist,
  EquipmentSlot.legs,
  EquipmentSlot.boots,
  EquipmentSlot.wrist,
  EquipmentSlot.hands,
  EquipmentSlot.cloak,
  EquipmentSlot.neck,
  EquipmentSlot.ring,
  EquipmentSlot.ring2,
  EquipmentSlot.weapon,
  EquipmentSlot.offHand,
  EquipmentSlot.ranged,
];

PartyHero _geared({
  required HeroSpecId spec,
  required ArmorType armor,
  required SpecRoleTag roleTag,
  required HeroRole bias,
  required int level,
  required int seed,
}) {
  EquipmentFactory.random = Random(seed);
  final gear = <EquipmentSlot, EquipmentItem>{
    for (final slot in _slots)
      slot: EquipmentFactory.create(
        slot: slot,
        rarity: LootRarity.rare,
        battleNumber: 10,
        bias: bias,
        preferredArmor: armor,
        roleTag: roleTag,
        dungeonId: 'sandy',
      ),
  };
  return PartyHero.starting(
    name: spec.name,
    specId: spec,
    level: level,
  ).copyWith(equipped: gear);
}
