import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/vfx_quality.dart';
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
      (AbilityId.earthquake, HeroSpecId.elemental, SpellBoltStyle.nature),
      (AbilityId.lavaBurst, HeroSpecId.elemental, SpellBoltStyle.fire),
      (AbilityId.hurricane, HeroSpecId.balance, SpellBoltStyle.nature),
      (AbilityId.insectSwarm, HeroSpecId.balance, SpellBoltStyle.nature),
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
      (AbilityId.fanOfKnivesCombat, HeroSpecId.combat, SpellBoltStyle.weapon),
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
      (AbilityId.envenom, HeroSpecId.assassination, SpellBoltStyle.poison),
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
      (AbilityId.garrote, HeroSpecId.assassination, SpellBoltStyle.poison),
      (AbilityId.handOfGuldan, HeroSpecId.demonology, SpellBoltStyle.demon),
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
      AbilityId.tranquility,
      AbilityId.holyWrath,
      AbilityId.hungeringCold,
      AbilityId.spiritLink,
      AbilityId.shockwave,
      AbilityId.killingSpree,
      AbilityId.armyOfDead,
    ]) {
      expect(
        SpatialCombat.groundDiscLifeFor(id),
        isNotNull,
        reason: '$id should have a ground disc',
      );
    }
  });

  test('Lite VFX spawns ground discs without routine burst FX', () {
    final state = GameLogic.createInitialState(
      now: DateTime(2026, 9, 10),
    ).copyWith(vfxQuality: VfxQuality.lite);
    expect(state.spawnPersistentVfx, isTrue);
    expect(state.reducedVfx, isTrue);

    var world = SpatialCombat.build(
      GameLogic.enterDungeon(state, dungeonId: 'sandy'),
    );
    world = SpatialCombat.step(world, state, dt: 0.01).world;
    expect(world.spawnPersistentVfx, isTrue);

    final target = world.enemies.first
      ..dormant = false
      ..hp = 800
      ..moveSpeed = 0;
    final packMate = SpatialActor(
      id: 'pack2',
      name: 'Mob',
      team: SpatialTeam.enemy,
      x: target.x + 0.8,
      y: target.y,
      hp: 800,
      maxHp: 800,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 9,
      role: EnemyRole.normal,
    );
    world.enemies
      ..clear()
      ..addAll([target, packMate]);

    final paladin = SpatialActor(
      id: 'pala',
      name: 'Pala',
      team: SpatialTeam.hero,
      x: target.x - 1.0,
      y: target.y,
      hp: 200,
      maxHp: 200,
      attack: 40,
      defense: 5,
      moveSpeed: 0,
      attackRange: 2,
      attackCooldown: 9,
      fireCooldown: 9,
      heroRole: HeroRole.warrior,
      heroSpecId: HeroSpecId.protPaladin,
      heroLevel: 15,
      assetIndex: 0,
    );
    world.heroes
      ..clear()
      ..add(paladin);
    paladin.rage = 100;
    for (final def in ClassKits.all) {
      if (def.id == AbilityId.consecration || def.cooldown <= 0) continue;
      paladin.abilityCd[def.id.name] = 99;
    }
    world.spawnPersistentVfx = true;
    world.reducedVfx = true;

    AbilityEffectRunner.tick(
      world,
      paladin,
      state,
      dt: 0.1,
      rng: math.Random(3),
      reducedVfx: true,
      hasShield: false,
    );

    expect(world.groundFx, isNotEmpty, reason: 'Lite should spawn holy disc');
    expect(world.bursts, isEmpty, reason: 'Lite skips routine cast bursts');
  });

  test('VfxQuality Lite keeps discs/auras; Minimal strips motion layers', () {
    expect(VfxQuality.full.showBurstsAndFloaters, isTrue);
    expect(VfxQuality.full.showPriorityFloaters, isTrue);
    expect(VfxQuality.full.showGroundFx, isTrue);
    expect(VfxQuality.full.showActorAuras, isTrue);
    expect(VfxQuality.full.showProjectileTrails, isTrue);

    expect(VfxQuality.lite.showBurstsAndFloaters, isFalse);
    expect(VfxQuality.lite.showPriorityFloaters, isTrue);
    expect(VfxQuality.lite.showGroundFx, isTrue);
    expect(VfxQuality.lite.showActorAuras, isTrue);
    expect(VfxQuality.lite.showProjectileTrails, isFalse);
    expect(VfxQuality.lite.reduced, isTrue);

    expect(VfxQuality.minimal.showBurstsAndFloaters, isFalse);
    expect(VfxQuality.minimal.showPriorityFloaters, isFalse);
    expect(VfxQuality.minimal.showGroundFx, isFalse);
    expect(VfxQuality.minimal.showActorAuras, isFalse);
    expect(VfxQuality.minimal.showGuideAndPulse, isFalse);
  });

  test('signature damage/buff kits carry AbilityVfxSpec', () {
    for (final id in [
      AbilityId.pyroblast,
      AbilityId.armsExecute,
      AbilityId.templarsVerdict,
      AbilityId.chaosBolt,
      AbilityId.mindBlast,
      AbilityId.trueshot,
      AbilityId.earthShock,
      AbilityId.tranquility,
      AbilityId.divineFavor,
      AbilityId.blackArrow,
    ]) {
      final def = ClassKits.defFor(id);
      expect(def, isNotNull, reason: '$id missing');
      expect(def!.vfx, isNotNull, reason: '$id needs AbilityVfxSpec');
      expect(def.vfx!.boltStyle ?? def.boltStyle, isNotNull);
    }
  });

  test('themed burst kinds match spell identity', () {
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.fire,
        id: AbilityId.fireball,
      ),
      SpatialBurstKind.flame,
    );
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.frost,
        id: AbilityId.howlingBlast,
      ),
      SpatialBurstKind.shards,
    );
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.lightning,
        id: AbilityId.chainLightning,
      ),
      SpatialBurstKind.beam,
    );
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.holy,
        id: AbilityId.consecration,
      ),
      SpatialBurstKind.cross,
    );
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.nature,
        shape: AbilityAoeShape.rain,
        id: AbilityId.hurricane,
      ),
      SpatialBurstKind.rain,
    );
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.shadow,
        id: AbilityId.deathCoil,
      ),
      SpatialBurstKind.skull,
    );
    expect(
      SpellVfx.groundKindFor(
        style: SpellBoltStyle.holy,
        id: AbilityId.consecration,
      ),
      SpatialGroundFxKind.holy,
    );
    expect(
      SpellVfx.groundKindFor(
        style: SpellBoltStyle.weapon,
        id: AbilityId.bladestorm,
      ),
      SpatialGroundFxKind.steel,
    );
    expect(
      SpellVfx.groundKindFor(
        style: SpellBoltStyle.poison,
        id: AbilityId.envenom,
      ),
      SpatialGroundFxKind.poison,
    );
    expect(
      SpellVfx.groundKindFor(
        style: SpellBoltStyle.nature,
        id: AbilityId.rejuvenation,
      ),
      isNot(SpatialGroundFxKind.poison),
    );
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.nature,
        id: AbilityId.rejuvenation,
      ),
      SpatialBurstKind.spark,
    );
    expect(
      SpellVfx.burstKindFor(
        style: SpellBoltStyle.fire,
        id: AbilityId.chaosBolt,
      ),
      SpatialBurstKind.flame,
    );
    expect(
      SpatialCombat.boltStyleForAbility(
        _hero(HeroSpecId.assassination),
        def: ClassKits.defFor(AbilityId.vendetta),
      ),
      SpellBoltStyle.shadow,
    );
  });
}
