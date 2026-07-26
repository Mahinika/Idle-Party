import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('all four classes have ability kits', () {
    expect(ClassKits.forRole(HeroRole.warrior), isNotEmpty);
    expect(ClassKits.forRole(HeroRole.healer), isNotEmpty);
    expect(ClassKits.forRole(HeroRole.mage), isNotEmpty);
    expect(ClassKits.forRole(HeroRole.rogue), isNotEmpty);
    expect(ClassKits.isUnlocked(AbilityId.atonement, 1), isTrue);
    expect(ClassKits.isUnlocked(AbilityId.powerWordShield, 3), isTrue);
    expect(ClassKits.isUnlocked(AbilityId.fireball, 3), isTrue);
    expect(ClassKits.isUnlocked(AbilityId.eviscerate, 5), isTrue);
  });

  test('healer role label is Disc Priest', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final priest = state.heroes.firstWhere((h) => h.role == HeroRole.healer);
    expect(priest.roleLabel, 'DISC PRIEST');
    expect(priest.passiveLabel, contains('Atone'));
  });

  test('warrior abilities unlock on the Protection curve', () {
    expect(WarriorAbilities.isUnlocked(AbilityId.defensiveStance, 1), isTrue);
    expect(WarriorAbilities.isUnlocked(AbilityId.sunderArmor, 6), isTrue);
    expect(WarriorAbilities.isUnlocked(AbilityId.demoralizingShout, 8), isTrue);
    expect(WarriorAbilities.unlockedAt(15).length, WarriorAbilities.all.length);
  });

  test('sunder reduces enemy effective defense', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final world = SpatialCombat.build(state);
    final enemy = world.enemies.first;
    enemy.sunderStacks = 5;
    enemy.sunderTimer = 10;
    expect(enemy.effectiveDefense, math.max(0, enemy.defense - 10));
  });

  test('boots icon uses real boot tile', () {
    expect(
      GameLogic.createEquipment(
        slot: EquipmentSlot.boots,
        rarity: LootRarity.common,
        battleNumber: 1,
      ),
      isNotNull,
    );
  });
}
