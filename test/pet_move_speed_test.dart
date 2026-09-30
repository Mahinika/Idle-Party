import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('pets use the owner move speed, including forge MOVE', () {
    const grub = Pet(id: 'grub', name: 'Grub', attackBonus: 2);
    final state = GameLogic.createInitialState(
      now: DateTime(2026, 9, 30),
      partySpecs: [
        HeroSpecId.beastMastery,
        HeroSpecId.unholy,
        HeroSpecId.demonology,
      ],
    ).copyWith(moveSpeedBonus: 40, activePet: grub, ownedPets: [grub]);

    final world = SpatialCombat.build(state);
    expect(world.pets, hasLength(4));

    for (final spec in [
      HeroSpecId.beastMastery,
      HeroSpecId.unholy,
      HeroSpecId.demonology,
    ]) {
      final owner = world.heroes.firstWhere((h) => h.heroSpecId == spec);
      final pet = world.pets.firstWhere((p) => p.petOwnerId == owner.id);
      final sheet = state.effectiveHeroMoveSpeed(
        state.heroes.firstWhere((h) => h.specId == spec),
      );
      expect(owner.moveSpeed, closeTo(sheet, 0.01));
      expect(
        pet.moveSpeed,
        greaterThanOrEqualTo(sheet),
        reason: '$spec pet ${pet.moveSpeed} lagged owner $sheet',
      );
    }

    final leader = world.heroes.first;
    final pocket = world.pets.firstWhere((p) => p.id.startsWith('pet_'));
    expect(pocket.moveSpeed, greaterThanOrEqualTo(leader.moveSpeed));
  });

  test('a pet left behind speeds up to the owner', () {
    final state = GameLogic.createInitialState(
      now: DateTime(2026, 9, 30),
      partySpecs: [HeroSpecId.beastMastery],
    ).copyWith(moveSpeedBonus: 40);
    final world = SpatialCombat.build(state);
    final hunter = world.heroes.first;
    final pet = world.pets.first;
    pet
      ..x = hunter.x - 4
      ..y = hunter.y;
    for (final e in world.enemies) {
      e.hp = 0;
    }

    final stepped = SpatialCombat.step(world, state, dt: 0.16).world;
    final after = stepped.pets.first;
    final owner = stepped.heroes.first;
    expect(after.moveSpeed, greaterThan(owner.moveSpeed));
  });
}
