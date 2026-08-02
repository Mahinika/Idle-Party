import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

SpatialActor _hero(HeroSpecId spec, {bool ranged = true}) {
  return SpatialActor(
    id: 'h',
    name: 'Test',
    team: SpatialTeam.hero,
    x: 0,
    y: 0,
    hp: 100,
    maxHp: 100,
    attack: 10,
    defense: 1,
    moveSpeed: 1,
    attackRange: ranged ? 5 : 1.2,
    attackCooldown: 1,
    heroRole: HeroSpecs.def(spec).legacyRole,
    heroSpecId: spec,
    ranged: ranged,
  );
}

void main() {
  test('P1 spell VFX styles match ability themes', () {
    final cases = <(AbilityId, HeroSpecId, SpellBoltStyle)>[
      (AbilityId.immolateDemo, HeroSpecId.demonology, SpellBoltStyle.fire),
      (AbilityId.immolateDestro, HeroSpecId.destruction, SpellBoltStyle.fire),
      (AbilityId.incinerate, HeroSpecId.destruction, SpellBoltStyle.fire),
      (AbilityId.conflagrate, HeroSpecId.destruction, SpellBoltStyle.fire),
      (AbilityId.holyPriestNova, HeroSpecId.holyPriest, SpellBoltStyle.holy),
      (AbilityId.fireNova, HeroSpecId.enhancement, SpellBoltStyle.fire),
      (AbilityId.frostShock, HeroSpecId.enhancement, SpellBoltStyle.frost),
      (AbilityId.howlingBlast, HeroSpecId.frostDk, SpellBoltStyle.frost),
      (AbilityId.thunderClap, HeroSpecId.protection, SpellBoltStyle.lightning),
      (AbilityId.bladestorm, HeroSpecId.arms, SpellBoltStyle.weapon),
      (AbilityId.divineStorm, HeroSpecId.retribution, SpellBoltStyle.holy),
      (AbilityId.holyWrath, HeroSpecId.protPaladin, SpellBoltStyle.holy),
      (AbilityId.chainLightning, HeroSpecId.elemental, SpellBoltStyle.lightning),
      (AbilityId.lavaBurst, HeroSpecId.elemental, SpellBoltStyle.fire),
      (AbilityId.hurricane, HeroSpecId.balance, SpellBoltStyle.nature),
      (AbilityId.multiShot, HeroSpecId.beastMastery, SpellBoltStyle.arrow),
      (AbilityId.consecration, HeroSpecId.protPaladin, SpellBoltStyle.holy),
    ];

    for (final (id, spec, want) in cases) {
      final def = ClassKits.defFor(id);
      expect(def, isNotNull, reason: '$id missing def');
      final got = SpatialCombat.boltStyleForAbility(_hero(spec), def: def);
      expect(got, want, reason: '${def!.name} ($id) expected $want got $got');
    }
  });

  test('truncated shortLabels alone still resolve via def id', () {
    final def = ClassKits.defFor(AbilityId.immolateDestro)!;
    expect(def.shortLabel.toLowerCase(), 'immo');
    expect(
      SpatialCombat.boltStyleForAbility(
        _hero(HeroSpecId.destruction),
        def: def,
        label: def.shortLabel,
      ),
      SpellBoltStyle.fire,
    );
  });
}
