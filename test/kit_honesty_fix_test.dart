import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('Vendetta arms damage amp for Assassination', () {
    final state = _soloSpecParty(HeroSpecId.assassination, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    // Signatures are held on healthy trash — drop HP into execute window.
    target.hp = (target.maxHp * 0.35).round();
    final rogue = world.heroes.firstWhere((h) => !h.isPet);
    rogue
      ..rage = 100
      ..x = target.x - 1.2
      ..y = target.y;
    _padAbilityCds(rogue, except: AbilityId.vendetta);

    var amped = false;
    for (var i = 0; i < 60; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (rogue.combustionTimer > 0) {
        amped = true;
        break;
      }
      rogue.rage = 100;
      if (target.hp < 10) target.hp = (target.maxHp * 0.35).round();
    }
    expect(amped, isTrue);
  });

  test('Unholy AMS absorbs on self, not lowest ally', () {
    final state = _soloSpecParty(HeroSpecId.unholy, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final dk = world.heroes.firstWhere((h) => !h.isPet);
    // Spawn a hurt ally so old bug would bubble them instead.
    final ally = SpatialActor(
      id: 'hurt_ally',
      name: 'Ally',
      team: SpatialTeam.hero,
      x: dk.x + 0.5,
      y: dk.y,
      hp: 20,
      maxHp: 200,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    world.heroes.add(ally);
    dk
      ..rage = 100
      ..hp = (dk.maxHp * 0.9).round()
      ..absorbShield = 0
      ..x = target.x - 1.5
      ..y = target.y;
    _padAbilityCds(dk, except: AbilityId.antiMagicShell);

    var selfShelled = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (dk.absorbShield > 0) {
        selfShelled = true;
        break;
      }
      dk.rage = 100;
      // Keep ally more hurt than DK so lowest-ally logic would pick them.
      ally.hp = 15;
      dk.hp = (dk.maxHp * 0.9).round();
    }
    expect(selfShelled, isTrue);
    expect(ally.absorbShield, 0);
  });

  test('Blood Bone Shield absorbs on self, not lowest ally', () {
    final state = _soloSpecParty(HeroSpecId.blood, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final dk = world.heroes.firstWhere((h) => !h.isPet);
    final ally = SpatialActor(
      id: 'hurt_ally',
      name: 'Ally',
      team: SpatialTeam.hero,
      x: dk.x + 0.5,
      y: dk.y,
      hp: 20,
      maxHp: 200,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    world.heroes.add(ally);
    dk
      ..rage = 100
      ..hp = (dk.maxHp * 0.9).round()
      ..absorbShield = 0
      ..x = target.x - 1.5
      ..y = target.y;
    _padAbilityCds(dk, except: AbilityId.boneShield);

    var selfShelled = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (dk.absorbShield > 0) {
        selfShelled = true;
        break;
      }
      dk.rage = 100;
      ally.hp = 15;
      dk.hp = (dk.maxHp * 0.9).round();
    }
    expect(selfShelled, isTrue);
    expect(ally.absorbShield, 0);
  });

  test('Unholy Gargoyle summons a temp pet', () {
    final state = _soloSpecParty(HeroSpecId.unholy, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    target.hp = (target.maxHp * 0.35).round();
    final dk = world.heroes.firstWhere((h) => !h.isPet);
    dk
      ..rage = 100
      ..x = target.x - 1.2
      ..y = target.y;
    _padAbilityCds(dk, except: AbilityId.gargoyle);

    var summoned = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (world.pets.any(
        (p) => p.petOwnerId == dk.id && p.id.contains('garg'),
      )) {
        summoned = true;
        break;
      }
      dk.rage = 100;
      if (target.hp < 10) target.hp = (target.maxHp * 0.35).round();
    }
    expect(summoned, isTrue);
  });

  test('Subtlety Preparation resets other kit cooldowns', () {
    final state = _soloSpecParty(HeroSpecId.subtlety, level: 16);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final rogue = world.heroes.firstWhere((h) => !h.isPet);
    rogue
      ..rage = 100
      ..hp = (rogue.maxHp * 0.25).round()
      ..x = target.x - 1.2
      ..y = target.y
      ..abilityCd[AbilityId.shadowDance.name] = 40
      ..abilityCd[AbilityId.hemorrhage.name] = 8;
    _padAbilityCds(rogue, except: AbilityId.preparation);
    rogue.abilityCd[AbilityId.shadowDance.name] = 40;
    rogue.abilityCd[AbilityId.hemorrhage.name] = 8;

    var prepped = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((rogue.abilityCd[AbilityId.preparation.name] ?? 0) > 0 &&
          (rogue.abilityCd[AbilityId.shadowDance.name] ?? 0) <= 0 &&
          (rogue.abilityCd[AbilityId.hemorrhage.name] ?? 0) <= 0) {
        prepped = true;
        break;
      }
      rogue.rage = 100;
      rogue.hp = (rogue.maxHp * 0.25).round();
    }
    expect(prepped, isTrue);
  });

  test('Elemental Flame Shock applies maintain DoT', () {
    final state = _soloSpecParty(HeroSpecId.elemental, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final sham = world.heroes.firstWhere((h) => !h.isPet);
    sham
      ..rage = 100
      ..x = target.x - 3
      ..y = target.y;
    _padAbilityCds(sham, except: AbilityId.flameShock);

    var dotted = false;
    for (var i = 0; i < 60; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (target.bleedTimer > 0 &&
          target.bleedAbilityId == AbilityId.flameShock.name) {
        dotted = true;
        break;
      }
      sham.rage = 100;
    }
    expect(dotted, isTrue);
  });

  test('Lifebloom applies HoT, not absorb', () {
    final state = _soloSpecParty(HeroSpecId.restorationDruid, level: 12);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final druid = world.heroes.firstWhere((h) => !h.isPet);
    final ally = SpatialActor(
      id: 'hurt',
      name: 'Hurt',
      team: SpatialTeam.hero,
      x: druid.x,
      y: druid.y,
      hp: 60,
      maxHp: 200,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    world.heroes.add(ally);
    druid
      ..rage = 100
      ..x = target.x - 2.5
      ..y = target.y;
    _padAbilityCds(druid, except: AbilityId.lifebloom);

    var bloomed = false;
    for (var i = 0; i < 100; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((ally.buffTimers['hot'] ?? 0) > 0 && ally.hotHps > 0) {
        bloomed = true;
        break;
      }
      druid.rage = 100;
      ally.hp = 60;
    }
    expect(bloomed, isTrue);
    expect(ally.absorbShield, 0);
  });

  test('Guardian Spirit emergency-saves lowest ally', () {
    final state = _soloSpecParty(HeroSpecId.holyPriest, level: 12);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final priest = world.heroes.firstWhere((h) => !h.isPet);
    final ally = SpatialActor(
      id: 'hurt',
      name: 'Hurt',
      team: SpatialTeam.hero,
      x: priest.x,
      y: priest.y,
      hp: 20,
      maxHp: 200,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    world.heroes.add(ally);
    priest
      ..rage = 100
      ..hp = (priest.maxHp * 0.9).round()
      ..x = target.x - 2.5
      ..y = target.y;
    _padAbilityCds(priest, except: AbilityId.guardianSpirit);

    var saved = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (ally.absorbShield > 0 && ally.shieldWallTimer > 0) {
        saved = true;
        break;
      }
      priest.rage = 100;
      ally.hp = 20;
      priest.hp = (priest.maxHp * 0.9).round();
    }
    expect(saved, isTrue);
  });

  test('Shamanistic Rage grants resource and DR', () {
    final state = _soloSpecParty(HeroSpecId.enhancement, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    target.hp = (target.maxHp * 0.35).round();
    final sham = world.heroes.firstWhere((h) => !h.isPet);
    sham
      ..rage = 40
      ..x = target.x - 1.2
      ..y = target.y;
    _padAbilityCds(sham, except: AbilityId.shamanisticRage);

    var fired = false;
    for (var i = 0; i < 60; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (sham.shieldWallTimer > 0) {
        fired = true;
        break;
      }
      sham.rage = 40;
      if (target.hp < 10) target.hp = (target.maxHp * 0.35).round();
    }
    expect(fired, isTrue);
    expect(sham.rage, greaterThan(40));
  });

  test('Frost Mage Nova roots a pack', () {
    final state = _soloSpecParty(HeroSpecId.frostMage, level: 15);
    var world = SpatialCombat.build(state);
    expect(world.enemies.length, greaterThanOrEqualTo(2));
    final mage = world.heroes.firstWhere((h) => !h.isPet);
    // Cluster mage on pack center.
    final pack = world.enemies.where((e) => e.hp > 0 && !e.dormant).take(3);
    final cx = pack.map((e) => e.x).reduce((a, b) => a + b) / pack.length;
    final cy = pack.map((e) => e.y).reduce((a, b) => a + b) / pack.length;
    mage
      ..rage = 100
      ..x = cx
      ..y = cy;
    for (final e in pack) {
      e
        ..x = cx + 0.4
        ..y = cy
        ..dormant = false
        ..hp = math.max(e.hp, 300);
    }
    _padAbilityCds(mage, except: AbilityId.frostNovaMage);

    var rooted = 0;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      rooted = world.enemies.where((e) => e.rootTimer > 0).length;
      if (rooted >= 2) break;
      mage.rage = 100;
    }
    expect(rooted, greaterThanOrEqualTo(2));
  });

  test('Arcane Blast builds charges', () {
    final state = _soloSpecParty(HeroSpecId.arcane, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final mage = world.heroes.firstWhere((h) => !h.isPet);
    mage
      ..rage = 100
      ..arcaneCharges = 0
      ..x = target.x - 3
      ..y = target.y;
    _padAbilityCds(mage, except: AbilityId.arcaneBlast);

    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (mage.arcaneCharges >= 2) break;
      mage.rage = 100;
      // Keep Missiles locked so Blast can stack.
      mage.abilityCd[AbilityId.arcaneMissiles.name] = 99;
      mage.abilityCd[AbilityId.arcaneExplosion.name] = 99;
    }
    expect(mage.arcaneCharges, greaterThanOrEqualTo(2));
  });

  test('Shadow Word: Pain applies maintain DoT', () {
    final state = _soloSpecParty(HeroSpecId.shadow, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final priest = world.heroes.firstWhere((h) => !h.isPet);
    priest
      ..rage = 100
      ..x = target.x - 3
      ..y = target.y;
    _padAbilityCds(priest, except: AbilityId.shadowWordPain);

    var dotted = false;
    for (var i = 0; i < 60; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (target.bleedTimer > 0 &&
          target.bleedAbilityId == AbilityId.shadowWordPain.name) {
        dotted = true;
        break;
      }
      priest.rage = 100;
    }
    expect(dotted, isTrue);
  });

  test('Guardian Frenzied Regen heals self', () {
    final state = _soloSpecParty(HeroSpecId.guardian, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final bear = world.heroes.firstWhere((h) => !h.isPet);
    bear
      ..rage = 100
      ..hp = (bear.maxHp * 0.4).round()
      ..x = target.x - 1.2
      ..y = target.y;
    final before = bear.hp;
    _padAbilityCds(bear, except: AbilityId.frenziedRegen);

    var healed = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (bear.hp > before) {
        healed = true;
        break;
      }
      bear.rage = 100;
      if (bear.hp > before + 5) break;
    }
    expect(healed, isTrue);
  });

  test('Fire Hot Streak unlocks free Pyroblast', () {
    final state = _soloSpecParty(HeroSpecId.fire, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final mage = world.heroes.firstWhere((h) => !h.isPet);
    mage
      ..rage = 100
      ..hotStreakReady = true
      ..hotStreakStack = 0
      ..x = target.x - 3
      ..y = target.y;
    _padAbilityCds(mage, except: AbilityId.pyroblast);
    // Lock fillers so Pyro is the cast.
    mage.abilityCd[AbilityId.fireball.name] = 99;
    mage.abilityCd[AbilityId.livingBomb.name] = 99;
    mage.abilityCd[AbilityId.combustion.name] = 99;

    var pyro = false;
    for (var i = 0; i < 40; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (!mage.hotStreakReady &&
          (mage.abilityCd[AbilityId.pyroblast.name] ?? 0) > 0) {
        pyro = true;
        break;
      }
      mage.rage = 100;
      mage.hotStreakReady = true;
    }
    expect(pyro, isTrue);
  });

  test('Feign Death drops forced target and vanishes briefly', () {
    final state = _soloSpecParty(HeroSpecId.beastMastery, level: 16);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final hunter = world.heroes.firstWhere((h) => !h.isPet);
    hunter
      ..rage = 100
      ..hp = (hunter.maxHp * 0.25).round()
      ..x = target.x - 2.0
      ..y = target.y;
    target
      ..forcedTargetId = hunter.id
      ..forcedTargetTimer = 5;
    _padAbilityCds(hunter, except: AbilityId.feignDeath);

    var feigned = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (hunter.vanishTimer > 0) {
        feigned = true;
        break;
      }
      hunter.rage = 100;
      hunter.hp = (hunter.maxHp * 0.25).round();
    }
    expect(feigned, isTrue);
    expect(target.forcedTargetId, isNull);
  });

  test('Disengage grants sprint kite', () {
    final state = _soloSpecParty(HeroSpecId.survival, level: 16);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final hunter = world.heroes.firstWhere((h) => !h.isPet);
    hunter
      ..rage = 100
      ..hp = (hunter.maxHp * 0.25).round()
      ..x = target.x - 2.0
      ..y = target.y;
    _padAbilityCds(hunter, except: AbilityId.disengage);

    var kited = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (hunter.sprintTimer > 0) {
        kited = true;
        break;
      }
      hunter.rage = 100;
      hunter.hp = (hunter.maxHp * 0.25).round();
    }
    expect(kited, isTrue);
  });

  test('Circle of Healing splashes multiple allies', () {
    final state = _soloSpecParty(HeroSpecId.holyPriest, level: 12);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final priest = world.heroes.firstWhere((h) => !h.isPet);
    final a = SpatialActor(
      id: 'a1',
      name: 'A',
      team: SpatialTeam.hero,
      x: priest.x,
      y: priest.y,
      hp: 40,
      maxHp: 200,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    final b = SpatialActor(
      id: 'a2',
      name: 'B',
      team: SpatialTeam.hero,
      x: priest.x + 0.4,
      y: priest.y,
      hp: 40,
      maxHp: 200,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    world.heroes.addAll([a, b]);
    priest
      ..rage = 100
      ..hp = 50
      ..x = target.x - 2.5
      ..y = target.y;
    _padAbilityCds(priest, except: AbilityId.circleOfHealing);

    var splash = false;
    for (var i = 0; i < 100; i++) {
      final beforeA = a.hp;
      final beforeB = b.hp;
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (a.hp > beforeA && b.hp > beforeB) {
        splash = true;
        break;
      }
      priest.rage = 100;
      a.hp = 40;
      b.hp = 40;
      priest.hp = 50;
    }
    expect(splash, isTrue);
  });

  test('Riptide applies HoT that ticks after cast', () {
    final state = _soloSpecParty(HeroSpecId.restorationShaman, level: 12);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final shaman = world.heroes.firstWhere((h) => !h.isPet);
    final ally = SpatialActor(
      id: 'hurt',
      name: 'Hurt',
      team: SpatialTeam.hero,
      x: shaman.x,
      y: shaman.y,
      hp: 60,
      maxHp: 200,
      attack: 1,
      defense: 0,
      moveSpeed: 0,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    world.heroes.add(ally);
    shaman
      ..rage = 100
      ..x = target.x - 2.5
      ..y = target.y;
    _padAbilityCds(shaman, except: AbilityId.riptide);

    var hotApplied = false;
    for (var i = 0; i < 100; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((ally.buffTimers['hot'] ?? 0) > 0 && ally.hotHps > 0) {
        hotApplied = true;
        break;
      }
      shaman.rage = 100;
      ally.hp = 60;
    }
    expect(hotApplied, isTrue);
    final mid = ally.hp;
    for (var i = 0; i < 20; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
    }
    expect(ally.hp, greaterThan(mid));
  });

  test('Blood Boil applies Blood Plague disease bleed', () {
    final state = _soloSpecParty(HeroSpecId.blood, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final packmate = SpatialActor(
      id: 'pack2',
      name: 'Pack',
      team: SpatialTeam.enemy,
      x: target.x + 0.8,
      y: target.y,
      hp: 400,
      maxHp: 400,
      attack: 5,
      defense: 0,
      moveSpeed: 0.5,
      attackRange: 1,
      attackCooldown: 1,
      fireCooldown: 1,
    );
    world.enemies.add(packmate);
    final dk = world.heroes.firstWhere((h) => !h.isPet);
    dk
      ..rage = 100
      ..x = target.x - 1.2
      ..y = target.y;
    _padAbilityCds(dk, except: AbilityId.bloodBoil);

    var diseased = false;
    for (var i = 0; i < 120; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (target.bleedTimer > 0) {
        diseased = true;
        break;
      }
      dk.rage = 100;
      if (target.hp < 50) target.hp = 800;
      if (packmate.hp < 10) packmate.hp = 400;
    }
    expect(diseased, isTrue);
    expect(target.bleedAbilityId, AbilityId.bloodBoil.name);
  });

  test('Hungering Cold roots a pack', () {
    final state = _soloSpecParty(HeroSpecId.frostDk, level: 15);
    var world = SpatialCombat.build(state);
    expect(world.enemies.length, greaterThanOrEqualTo(2));
    final dk = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.where((e) => e.hp > 0 && !e.dormant).take(3);
    final cx = pack.map((e) => e.x).reduce((a, b) => a + b) / pack.length;
    final cy = pack.map((e) => e.y).reduce((a, b) => a + b) / pack.length;
    dk
      ..rage = 100
      ..x = cx
      ..y = cy;
    for (final e in pack) {
      e
        ..x = cx + 0.4
        ..y = cy
        ..dormant = false
        ..hp = math.max(e.hp, 300);
    }
    _padAbilityCds(dk, except: AbilityId.hungeringCold);

    var rooted = 0;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      rooted = world.enemies.where((e) => e.rootTimer > 0).length;
      if (rooted >= 2) break;
      dk.rage = 100;
    }
    expect(rooted, greaterThanOrEqualTo(2));
  });

  test('Fury Recklessness is an all-in damage window at full HP', () {
    final state = _soloSpecParty(HeroSpecId.fury, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final fury = world.heroes.firstWhere((h) => !h.isPet);
    fury
      ..rage = 100
      ..hp = fury.maxHp
      ..x = target.x - 1.2
      ..y = target.y;
    _padAbilityCds(fury, except: AbilityId.furyRecklessness);

    var amped = false;
    for (var i = 0; i < 60; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (fury.combustionTimer > 0) {
        amped = true;
        break;
      }
      fury
        ..rage = 100
        ..hp = fury.maxHp;
      if (target.hp < 10) target.hp = (target.maxHp * 0.35).round();
    }
    expect(amped, isTrue);
    expect(fury.shieldWallTimer, 0);
  });

  test('Bloodthirst returns rage on hit', () {
    final state = _soloSpecParty(HeroSpecId.fury, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final fury = world.heroes.firstWhere((h) => !h.isPet);
    fury
      ..rage = 50
      ..fireCooldown = 99
      ..x = target.x - 1.2
      ..y = target.y;
    _padAbilityCds(fury, except: AbilityId.bloodthirst);

    var fired = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((fury.abilityCd[AbilityId.bloodthirst.name] ?? 0) > 0) {
        fired = true;
        break;
      }
      fury.fireCooldown = 99;
    }
    expect(fired, isTrue);
    expect(fury.rage, greaterThan(30));
  });

  test('Sweeping Strikes is a cleave window, not an AoE nova', () {
    expect(
      ClassKits.defFor(AbilityId.sweepingStrikes)!.effect,
      AbilityEffectKind.selfBuff,
    );
    final state = _soloSpecParty(HeroSpecId.arms, level: 15);
    var world = SpatialCombat.build(state);
    final a = _soloEnemy(world);
    SpatialActor? b;
    for (final e in world.enemies) {
      if (identical(e, a)) continue;
      e
        ..dormant = false
        ..hp = math.max(e.hp, 800)
        ..x = a.x + 0.8
        ..y = a.y;
      b = e;
      break;
    }
    expect(b, isNotNull);
    final arms = world.heroes.firstWhere((h) => !h.isPet);
    arms
      ..rage = 100
      ..fireCooldown = 99
      ..x = a.x - 1.2
      ..y = a.y;
    _padAbilityCds(arms, except: AbilityId.sweepingStrikes);

    var windowed = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (arms.bladeFlurryTimer > 0) {
        windowed = true;
        break;
      }
      arms.rage = 100;
      arms.fireCooldown = 99;
      if (a.hp < 40) a.hp = 800;
      if (b!.hp < 40) b.hp = 800;
    }
    expect(windowed, isTrue);

    final otherHp = b!.hp;
    arms.fireCooldown = 0;
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    expect(b.hp, lessThan(otherHp));
  });

  test('Holy Shield blocks while healthy, not only as a panic wall', () {
    final def = ClassKits.defFor(AbilityId.holyShield)!;
    expect(def.effect, AbilityEffectKind.selfBuff);
    expect(def.tier, isNot(AbilityCastTier.emergency));
    final state = _soloSpecParty(HeroSpecId.protPaladin, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final pala = world.heroes.firstWhere((h) => !h.isPet);
    pala
      ..rage = 100
      ..hp = (pala.maxHp * 0.9).round()
      ..x = target.x - 1.4
      ..y = target.y;
    _padAbilityCds(pala, except: AbilityId.holyShield);

    var blocked = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (pala.shieldBlockTimer > 0) {
        blocked = true;
        break;
      }
      pala.rage = 100;
      pala.hp = (pala.maxHp * 0.9).round();
    }
    expect(blocked, isTrue);
    expect(pala.shieldWallTimer, 0);
  });

  test('Beacon peels a Holy Light onto the marked tank', () {
    final def = ClassKits.defFor(AbilityId.beaconOfLight)!;
    expect(def.effect, AbilityEffectKind.selfBuff);
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 10));
    state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
    var pala = state.heroes.first.copyWith(specId: HeroSpecId.holyPaladin);
    var tank = state.heroes[1].copyWith(specId: HeroSpecId.protection);
    while (pala.level < 15) {
      pala = pala.levelUp();
    }
    while (tank.level < 15) {
      tank = tank.levelUp();
    }
    state = state.withActiveParty([pala, tank]);
    var world = SpatialCombat.build(state);
    final healer = world.heroes.firstWhere(
      (h) => h.heroSpecId == HeroSpecId.holyPaladin,
    );
    final marked = world.heroes.firstWhere(
      (h) => h.heroSpecId == HeroSpecId.protection,
    );
    final foe = _soloEnemy(world);
    healer
      ..rage = 100
      ..hp = (healer.maxHp * 0.4).round()
      ..x = foe.x - 2.2
      ..y = foe.y;
    marked
      ..hp = (marked.maxHp * 0.55).round()
      ..x = healer.x + 0.6
      ..y = healer.y;
    _padAbilityCds(healer, except: AbilityId.beaconOfLight);

    var markedBeacon = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (healer.beaconTimer > 0 && healer.beaconTargetId == marked.id) {
        markedBeacon = true;
        break;
      }
      healer.rage = 100;
      healer.hp = (healer.maxHp * 0.4).round();
      marked.hp = (marked.maxHp * 0.55).round();
    }
    expect(markedBeacon, isTrue);

    final tankHp = marked.hp;
    healer.rage = 100;
    _padAbilityCds(healer, except: AbilityId.holyLight);
    healer.hp = (healer.maxHp * 0.35).round();
    var peeled = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (marked.hp > tankHp) {
        peeled = true;
        break;
      }
      healer.rage = 100;
      healer.hp = (healer.maxHp * 0.35).round();
    }
    expect(peeled, isTrue);
  });

  test('Holy Shock smites when the party is topped', () {
    final state = _soloSpecParty(HeroSpecId.holyPaladin, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final pala = world.heroes.firstWhere((h) => !h.isPet);
    pala
      ..rage = 100
      ..hp = pala.maxHp
      ..x = target.x - 2.4
      ..y = target.y;
    _padAbilityCds(pala, except: AbilityId.holyShock);
    final hpBefore = target.hp;
    var smote = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (target.hp < hpBefore) {
        smote = true;
        break;
      }
      pala.rage = 100;
      pala.hp = pala.maxHp;
    }
    expect(smote, isTrue);
  });

  test('Divine Favor is a heal window, not haste', () {
    final def = ClassKits.defFor(AbilityId.divineFavor)!;
    expect(def.effect, AbilityEffectKind.selfBuff);
    final state = _soloSpecParty(HeroSpecId.holyPaladin, level: 15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final pala = world.heroes.firstWhere((h) => !h.isPet);
    pala
      ..rage = 100
      ..hp = (pala.maxHp * 0.9).round()
      ..x = target.x - 2.2
      ..y = target.y;
    target.hp = (target.maxHp * 0.3).round();
    _padAbilityCds(pala, except: AbilityId.divineFavor);

    var favored = false;
    for (var i = 0; i < 80; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((pala.buffTimers['favor'] ?? 0) > 0) {
        favored = true;
        break;
      }
      pala.rage = 100;
      pala.hp = (pala.maxHp * 0.9).round();
    }
    expect(favored, isTrue);
    expect(pala.powerInfusionTimer, 0);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    expect(pala.kitHealMul, greaterThan(1.32));
  });

  test('Marksmanship Volley hits a pack, not a single-target root', () {
    final def = ClassKits.defFor(AbilityId.volley)!;
    expect(def.effect, AbilityEffectKind.aoe);
    expect(ClassKits.defFor(AbilityId.scatterShot), isNull);
    final state = _soloSpecParty(HeroSpecId.marksmanship, level: 15);
    var world = SpatialCombat.build(state);
    SpatialActor? a;
    SpatialActor? b;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      a ??= e;
      if (identical(e, a)) continue;
      e
        ..dormant = false
        ..hp = math.max(e.hp, 800)
        ..x = a.x + 0.8
        ..y = a.y;
      b = e;
      break;
    }
    expect(b, isNotNull);
    for (final e in world.enemies) {
      if (!identical(e, a) && !identical(e, b)) {
        e
          ..hp = 0
          ..dormant = true;
      }
    }
    a!.dormant = false;
    b!.dormant = false;
    final hunter = world.heroes.firstWhere((h) => !h.isPet);
    hunter
      ..rage = 100
      ..fireCooldown = 99
      ..moveSpeed = 0;
    a
      ..moveSpeed = 0
      ..dormant = false
      ..hp = math.max(a.hp, 800)
      ..x = hunter.x + 1.1
      ..y = hunter.y;
    b
      ..moveSpeed = 0
      ..dormant = false
      ..hp = math.max(b.hp, 800)
      ..x = hunter.x + 1.7
      ..y = hunter.y;
    _padAbilityCds(hunter, except: AbilityId.volley);
    AbilityEffectRunner.tick(
      world,
      hunter,
      state,
      dt: 0.1,
      rng: math.Random(1),
      reducedVfx: false,
      hasShield: false,
    );
    expect(
      hunter.abilityCd[AbilityId.volley.name] ?? 0,
      greaterThan(0),
      reason: 'Volley should start its cooldown',
    );
    expect(
      world.projectiles.length,
      greaterThanOrEqualTo(2),
      reason: 'Volley should rain arrows on the pack',
    );
    expect(a.rootTimer, 0);
    expect(b.rootTimer, 0);
  });
}

GameState _soloSpecParty(HeroSpecId specId, {required int level}) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 8, 10));
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  final base = state.heroes.first;
  var hero = base.copyWith(specId: specId);
  while (hero.level < level) {
    hero = hero.levelUp();
  }
  return state.withActiveParty([hero]);
}

SpatialActor _soloEnemy(SpatialWorld world) {
  final keep = world.enemies.first;
  for (final e in world.enemies) {
    if (!identical(e, keep)) {
      e
        ..hp = 0
        ..dormant = true;
    }
  }
  keep
    ..dormant = false
    ..hp = math.max(keep.hp, 800);
  for (final h in world.heroes) {
    if (!h.isPet) h.hp = h.maxHp;
  }
  return keep;
}

void _padAbilityCds(SpatialActor actor, {required AbilityId except}) {
  for (final def in ClassKits.all) {
    if (def.id == except || def.cooldown <= 0) continue;
    actor.abilityCd[def.id.name] = 99;
  }
}
