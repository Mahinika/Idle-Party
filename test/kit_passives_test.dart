import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('every non-legacy kit passive sets a real combat mul', () {
    final legacy = {
      HeroSpecId.protection,
      HeroSpecId.discipline,
      HeroSpecId.fire,
      HeroSpecId.combat,
    };
    for (final specId in HeroSpecId.values) {
      if (legacy.contains(specId)) continue;
      final passive = ClassKits.forSpec(specId).firstWhere(
        (d) => d.effect == AbilityEffectKind.passive,
      );
      final state = _soloSpecParty(specId, level: 15);
      var world = SpatialCombat.build(state);
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      final hero = world.heroes.firstWhere((h) => !h.isPet);
      final changed = hero.kitOutMul != 1.0 ||
          hero.kitInMul != 1.0 ||
          hero.kitHealMul != 1.0 ||
          hero.kitHasteMul != 1.0 ||
          hero.kitRootBonus != 0.0;
      expect(
        changed,
        isTrue,
        reason: '${passive.name} ($specId) left all kit muls at defaults '
            '(out=${hero.kitOutMul} in=${hero.kitInMul} heal=${hero.kitHealMul} '
            'haste=${hero.kitHasteMul} root=${hero.kitRootBonus})',
      );
    }
  });

  test('legacy Fire keeps kitOutMul honest; tax is on ability hits', () {
    final state = _soloSpecParty(HeroSpecId.fire, level: 5);
    var world = SpatialCombat.build(state);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    final mage = world.heroes.firstWhere((h) => !h.isPet);
    // Fire ticker sets mild personal heat; spam tax stays on spell hits.
    expect(mage.kitOutMul, closeTo(1.22, 0.001));
    expect(SpatialCombat.casterAbilityTax, closeTo(0.72, 0.001));
  });

  test('Inner Fire sets disc heal mul', () {
    final state = _soloSpecParty(HeroSpecId.discipline, level: 5);
    var world = SpatialCombat.build(state);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    final priest = world.heroes.firstWhere((h) => !h.isPet);
    expect(priest.innerFireActive, isTrue);
    expect(priest.kitHealMul, greaterThan(1.0));
  });

  test('healers open a floor with mana; DPS casters start empty', () {
    final disc = SpatialCombat.build(
      _soloSpecParty(HeroSpecId.discipline, level: 1),
    );
    final fire = SpatialCombat.build(
      _soloSpecParty(HeroSpecId.fire, level: 1),
    );
    expect(
      disc.heroes.firstWhere((h) => !h.isPet).rage,
      SpatialCombat.healerOpeningMana,
    );
    expect(fire.heroes.firstWhere((h) => !h.isPet).rage, 0);
  });

  test('Combat rogue kitOutMul sits near melee band', () {
    final state = _soloSpecParty(HeroSpecId.combat, level: 5);
    var world = SpatialCombat.build(state);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    final rogue = world.heroes.firstWhere((h) => !h.isPet);
    expect(rogue.kitOutMul, closeTo(0.84, 0.001));
  });

  test('Moonkin Form thickens hide; Barkskin is ready at 11', () {
    final bark = ClassKits.forSpec(HeroSpecId.balance).firstWhere(
      (d) => d.id == AbilityId.barkskinBal,
    );
    expect(bark.unlockLevel, lessThanOrEqualTo(12));
    expect(
      ClassKits.hudAbilitiesAtSpec(HeroSpecId.balance, 12).map((d) => d.id),
      contains(AbilityId.barkskinBal),
    );

    final state = _soloSpecParty(HeroSpecId.balance, level: 12);
    var world = SpatialCombat.build(state);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    final owl = world.heroes.firstWhere((h) => !h.isPet);
    expect(owl.kitInMul, lessThan(1.0));
    expect(owl.kitOutMul, closeTo(0.96, 0.001));
  });
}

GameState _soloSpecParty(HeroSpecId specId, {required int level}) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 8, 1));
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  final base = state.heroes.first;
  var hero = base.copyWith(specId: specId);
  while (hero.level < level) {
    hero = hero.levelUp();
  }
  return state.withActiveParty([hero]);
}
