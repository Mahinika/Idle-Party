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
    heroRole: HeroSpecs.def(spec).gearAffinity,
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

  test('AbilityVfxSpec boltStyle and groundDisc on signature kits', () {
    final cons = ClassKits.defFor(AbilityId.consecration)!;
    expect(cons.boltStyle, SpellBoltStyle.holy);
    expect(cons.vfx?.groundDisc, isTrue);
    expect(
      SpatialCombat.boltStyleForAbility(
        _hero(HeroSpecId.protPaladin),
        def: cons,
      ),
      SpellBoltStyle.holy,
    );

    final storm = ClassKits.defFor(AbilityId.bladestorm)!;
    expect(storm.vfx?.groundDisc, isTrue);
    expect(storm.boltStyle, SpellBoltStyle.weapon);

    final fury = ClassKits.defFor(AbilityId.shadowfury)!;
    expect(fury.boltStyle, SpellBoltStyle.shadow);
    expect(fury.vfx?.groundDisc, isTrue);
    expect(
      SpatialCombat.boltStyleForAbility(
        _hero(HeroSpecId.destruction),
        def: fury,
      ),
      SpellBoltStyle.shadow,
    );
  });

  test('P0 keyword false-positives resolve correctly', () {
    final cases = <(AbilityId, HeroSpecId, SpellBoltStyle)>[
      // Rogue *Shot / kill* must not become arrows
      (AbilityId.cheapShot, HeroSpecId.subtlety, SpellBoltStyle.weapon),
      (AbilityId.kidneyShot, HeroSpecId.combat, SpellBoltStyle.weapon),
      (AbilityId.killingSpree, HeroSpecId.combat, SpellBoltStyle.weapon),
      // Hunter melee / traps
      (AbilityId.mongooseBite, HeroSpecId.survival, SpellBoltStyle.weapon),
      (AbilityId.freezingTrap, HeroSpecId.survival, SpellBoltStyle.frost),
      (AbilityId.explosiveTrap, HeroSpecId.survival, SpellBoltStyle.fire),
      // Resto shaman must be nature, not holy/lightning
      (AbilityId.healingWave, HeroSpecId.restorationShaman, SpellBoltStyle.nature),
      (AbilityId.chainHeal, HeroSpecId.restorationShaman, SpellBoltStyle.nature),
      (AbilityId.healingRain, HeroSpecId.restorationShaman, SpellBoltStyle.nature),
      (AbilityId.riptide, HeroSpecId.restorationShaman, SpellBoltStyle.nature),
      (AbilityId.earthShield, HeroSpecId.restorationShaman, SpellBoltStyle.nature),
      (AbilityId.spiritLink, HeroSpecId.restorationShaman, SpellBoltStyle.nature),
      // Feral / guardian physical ≠ nature
      (AbilityId.shred, HeroSpecId.feral, SpellBoltStyle.weapon),
      (AbilityId.rake, HeroSpecId.feral, SpellBoltStyle.weapon),
      (AbilityId.ferociousBite, HeroSpecId.feral, SpellBoltStyle.weapon),
      (AbilityId.rip, HeroSpecId.feral, SpellBoltStyle.weapon),
      (AbilityId.mangleBear, HeroSpecId.guardian, SpellBoltStyle.weapon),
      (AbilityId.swipe, HeroSpecId.guardian, SpellBoltStyle.weapon),
      (AbilityId.maul, HeroSpecId.guardian, SpellBoltStyle.weapon),
    ];

    for (final (id, spec, want) in cases) {
      final def = ClassKits.defFor(id);
      expect(def, isNotNull, reason: '$id missing def');
      final got = SpatialCombat.boltStyleForAbility(
        _hero(spec, ranged: false),
        def: def,
      );
      expect(got, want, reason: '${def!.name} ($id) expected $want got $got');
    }
  });

  test('all specs have themed styles for HUD damage/aoe/heal abilities', () {
    // Spot-check one signature per non-legacy-heavy path.
    final cases = <(AbilityId, HeroSpecId, SpellBoltStyle)>[
      (AbilityId.mortalStrike, HeroSpecId.arms, SpellBoltStyle.weapon),
      (AbilityId.bloodthirst, HeroSpecId.fury, SpellBoltStyle.weapon),
      (AbilityId.crusaderStrike, HeroSpecId.retribution, SpellBoltStyle.holy),
      (AbilityId.aimedShot, HeroSpecId.marksmanship, SpellBoltStyle.arrow),
      (AbilityId.volley, HeroSpecId.marksmanship, SpellBoltStyle.arrow),
      (AbilityId.envenom, HeroSpecId.assassination, SpellBoltStyle.nature),
      (AbilityId.mindBlast, HeroSpecId.shadow, SpellBoltStyle.shadow),
      (AbilityId.heartStrike, HeroSpecId.blood, SpellBoltStyle.weapon),
      (AbilityId.deathCoil, HeroSpecId.unholy, SpellBoltStyle.shadow),
      (AbilityId.lightningBolt, HeroSpecId.elemental, SpellBoltStyle.lightning),
      (AbilityId.arcaneBlast, HeroSpecId.arcane, SpellBoltStyle.arcane),
      (AbilityId.frostbolt, HeroSpecId.frostMage, SpellBoltStyle.frost),
      (AbilityId.corruption, HeroSpecId.affliction, SpellBoltStyle.shadow),
      (AbilityId.starfire, HeroSpecId.balance, SpellBoltStyle.arcane),
      (AbilityId.rejuvenation, HeroSpecId.restorationDruid, SpellBoltStyle.nature),
      (AbilityId.holyShock, HeroSpecId.holyPaladin, SpellBoltStyle.holy),
      (AbilityId.garrote, HeroSpecId.assassination, SpellBoltStyle.nature),
      (AbilityId.handOfGuldan, HeroSpecId.demonology, SpellBoltStyle.shadow),
    ];

    for (final (id, spec, want) in cases) {
      final def = ClassKits.defFor(id);
      expect(def, isNotNull, reason: '$id missing def');
      final got = SpatialCombat.boltStyleForAbility(_hero(spec), def: def);
      expect(got, want, reason: '${def!.name} ($id) expected $want got $got');
    }
  });

  test('signature AOEs have ground disc lives', () {
    for (final id in [
      AbilityId.consecration,
      AbilityId.bladestorm,
      AbilityId.shadowfury,
      AbilityId.whirlwind,
      AbilityId.divineStorm,
      AbilityId.thunderClap,
      AbilityId.fireNova,
      AbilityId.healingRain,
      AbilityId.bloodBoil,
      AbilityId.swipe,
      AbilityId.arcaneExplosion,
      AbilityId.bladeFlurry,
    ]) {
      expect(
        SpatialCombat.groundDiscLifeFor(id),
        isNotNull,
        reason: '$id should have a ground disc',
      );
    }
  });
}
