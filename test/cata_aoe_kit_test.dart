import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('Cata pack tools exist on the right specs', () {
    expect(ClassKits.defFor(AbilityId.earthquake)!.specId, HeroSpecId.elemental);
    expect(ClassKits.defFor(AbilityId.earthquake)!.aoeShape, AbilityAoeShape.ground);
    expect(ClassKits.defFor(AbilityId.earthquake)!.gate.packMin, 3);

    expect(ClassKits.defFor(AbilityId.flamestrike)!.specId, HeroSpecId.fire);
    expect(ClassKits.defFor(AbilityId.deathAndDecayBlood)!.specId, HeroSpecId.blood);
    expect(ClassKits.defFor(AbilityId.deathAndDecayUnholy)!.specId, HeroSpecId.unholy);
    expect(ClassKits.defFor(AbilityId.fanOfKnivesCombat)!.specId, HeroSpecId.combat);
    expect(ClassKits.defFor(AbilityId.fanOfKnivesCombat)!.gate.packMin, 4);
    expect(ClassKits.defFor(AbilityId.feralThrash)!.specId, HeroSpecId.feral);
    expect(ClassKits.defFor(AbilityId.guardianThrash)!.specId, HeroSpecId.guardian);
    expect(ClassKits.defFor(AbilityId.multiShotMm)!.specId, HeroSpecId.marksmanship);
    expect(ClassKits.defFor(AbilityId.hellfire)!.specId, HeroSpecId.demonology);
    expect(ClassKits.defFor(AbilityId.hellfire)!.gate.packMin, 2);
    expect(ClassKits.defFor(AbilityId.hellfire)!.resourceCost, 14);
    expect(ClassKits.defFor(AbilityId.howlingBlast)!.aoeShape, AbilityAoeShape.ground);
    expect(ClassKits.defFor(AbilityId.magmaTotem)!.specId, HeroSpecId.enhancement);
  });

  test('Combat Blade Flurry cleaves one extra foe, not the whole pack', () {
    final state = _soloSpecParty(HeroSpecId.combat, level: 15);
    var world = SpatialCombat.build(state);
    final rogue = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    expect(pack.length, greaterThanOrEqualTo(4));
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 4000
        ..maxHp = 4000
        ..x = rogue.x + 0.6
        ..y = rogue.y + i * 0.15
        ..moveSpeed = 0;
    }
    rogue
      ..rage = 0
      ..bladeFlurryTimer = 4
      ..fireCooldown = 0
      ..x = pack.first.x - 1.0
      ..y = pack.first.y
      ..moveSpeed = 0;
    _padAllCds(rogue);

    final before = [for (final e in pack) e.hp];
    world = SpatialCombat.step(world, state, dt: 0.12).world;
    final dropped = [
      for (var i = 0; i < pack.length; i++)
        if (pack[i].hp < before[i]) i,
    ];
    expect(dropped, isNotEmpty, reason: 'main swing should land');
    expect(
      dropped.length,
      lessThanOrEqualTo(2),
      reason: 'Cata Flurry is one extra target, got $dropped',
    );
  });

  test('Arms Sweeping Strikes cleaves one extra foe, not the whole pack', () {
    final state = _soloSpecParty(HeroSpecId.arms, level: 15);
    var world = SpatialCombat.build(state);
    final arms = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    expect(pack.length, greaterThanOrEqualTo(4));
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 4000
        ..maxHp = 4000
        ..x = arms.x + 0.6
        ..y = arms.y + i * 0.15
        ..moveSpeed = 0;
    }
    arms
      ..rage = 0
      ..bladeFlurryTimer = 7
      ..fireCooldown = 0
      ..x = pack.first.x - 1.0
      ..y = pack.first.y
      ..moveSpeed = 0;
    _padAllCds(arms);

    final before = [for (final e in pack) e.hp];
    world = SpatialCombat.step(world, state, dt: 0.12).world;
    final dropped = [
      for (var i = 0; i < pack.length; i++)
        if (pack[i].hp < before[i]) i,
    ];
    expect(dropped, isNotEmpty, reason: 'main swing should land');
    expect(
      dropped.length,
      lessThanOrEqualTo(2),
      reason: 'Cata Sweeping is one extra target, got $dropped',
    );
  });

  test('Elemental Earthquake enters cooldown on a stacked pack', () {
    final state = _soloSpecParty(HeroSpecId.elemental, level: 15);
    var world = SpatialCombat.build(state);
    final sham = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 2000
        ..x = sham.x + 0.5
        ..y = sham.y + i * 0.1
        ..moveSpeed = 0;
    }
    sham
      ..rage = 100
      ..x = pack.first.x - 1.2
      ..y = pack.first.y
      ..moveSpeed = 0
      ..fireCooldown = 99;
    _padAllCds(sham, except: AbilityId.earthquake);

    var fired = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((sham.abilityCd[AbilityId.earthquake.name] ?? 0) > 0.05) {
        fired = true;
        break;
      }
      sham.rage = 100;
    }
    expect(fired, isTrue);
    expect(pack.where((e) => e.hp < 2000).length, greaterThanOrEqualTo(3));
  });

  test('Arcane Explosion hits a stacked pack instead of Blast', () {
    final state = _soloSpecParty(HeroSpecId.arcane, level: 15);
    var world = SpatialCombat.build(state);
    final mage = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 2500
        ..maxHp = 2500
        ..x = mage.x + 3.2
        ..y = mage.y + i * 0.12
        ..moveSpeed = 0;
    }
    mage
      ..rage = 100
      ..arcaneCharges = 0
      ..x = pack.first.x - 3.4
      ..y = pack.first.y
      ..moveSpeed = 0
      ..fireCooldown = 99;
    _padAllCds(mage, except: AbilityId.arcaneExplosion);

    var fired = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((mage.abilityCd[AbilityId.arcaneExplosion.name] ?? 0) > 0.05) {
        fired = true;
        break;
      }
      mage.rage = 100;
    }
    expect(fired, isTrue);
    expect(pack.where((e) => e.hp < 2500).length, greaterThanOrEqualTo(3));
  });

  test('Frost Blizzard hits a stacked pack from kite range', () {
    final state = _soloSpecParty(HeroSpecId.frostMage, level: 15);
    var world = SpatialCombat.build(state);
    final mage = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 2500
        ..maxHp = 2500
        ..x = mage.x + 3.2
        ..y = mage.y + i * 0.12
        ..moveSpeed = 0;
    }
    mage
      ..rage = 100
      ..x = pack.first.x - 3.4
      ..y = pack.first.y
      ..moveSpeed = 0
      ..fireCooldown = 99;
    _padAllCds(mage, except: AbilityId.blizzard);

    var fired = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((mage.abilityCd[AbilityId.blizzard.name] ?? 0) > 0.05) {
        fired = true;
        break;
      }
      mage.rage = 100;
    }
    expect(fired, isTrue);
    expect(pack.where((e) => e.hp < 2500).length, greaterThanOrEqualTo(3));
  });

  test('Destruction Rain of Fire hits a pack instead of Chaos Bolt', () {
    final state = _soloSpecParty(HeroSpecId.destruction, level: 15);
    var world = SpatialCombat.build(state);
    final lock = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 2500
        ..maxHp = 2500
        ..x = lock.x + 3.2
        ..y = lock.y + i * 0.12
        ..moveSpeed = 0;
    }
    lock
      ..rage = 100
      ..x = pack.first.x - 3.4
      ..y = pack.first.y
      ..moveSpeed = 0
      ..fireCooldown = 99;
    _padAllCds(lock, except: AbilityId.rainOfFire);
    lock.abilityCd.remove(AbilityId.chaosBolt.name);

    var fired = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((lock.abilityCd[AbilityId.rainOfFire.name] ?? 0) > 0.05) {
        fired = true;
        break;
      }
      lock.rage = 100;
    }
    expect(fired, isTrue);
    expect(lock.abilityCd[AbilityId.chaosBolt.name] ?? 0, lessThan(0.05));
    expect(pack.where((e) => e.hp < 2500).length, greaterThanOrEqualTo(3));
  });

  test('Assassination Fan of Knives hits a pack instead of Envenom', () {
    final state = _soloSpecParty(HeroSpecId.assassination, level: 15);
    var world = SpatialCombat.build(state);
    final rogue = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 2500
        ..maxHp = 2500
        ..x = rogue.x + 0.8
        ..y = rogue.y + i * 0.12
        ..moveSpeed = 0;
    }
    rogue
      ..rage = 100
      ..comboPoints = 5
      ..x = pack.first.x - 1.0
      ..y = pack.first.y
      ..moveSpeed = 0
      ..fireCooldown = 99;
    _padAllCds(rogue, except: AbilityId.fanOfKnives);
    rogue.abilityCd.remove(AbilityId.envenom.name);

    var fired = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((rogue.abilityCd[AbilityId.fanOfKnives.name] ?? 0) > 0.05) {
        fired = true;
        break;
      }
      rogue
        ..rage = 100
        ..comboPoints = 5;
    }
    expect(fired, isTrue);
    expect(rogue.abilityCd[AbilityId.envenom.name] ?? 0, lessThan(0.05));
    expect(pack.where((e) => e.hp < 2500).length, greaterThanOrEqualTo(3));
  });

  test('Frost DK Howling Blast recasts on a pack with DoT already up', () {
    final state = _soloSpecParty(HeroSpecId.frostDk, level: 15);
    var world = SpatialCombat.build(state);
    final dk = world.heroes.firstWhere((h) => !h.isPet);
    final pack = world.enemies.take(4).toList();
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (var i = 0; i < pack.length; i++) {
      pack[i]
        ..dormant = false
        ..hp = 2500
        ..maxHp = 2500
        ..x = dk.x + 0.8
        ..y = dk.y + i * 0.12
        ..moveSpeed = 0
        ..bleedTimer = 8
        ..bleedAbilityId = AbilityId.howlingBlast.name;
    }
    dk
      ..rage = 100
      ..x = pack.first.x - 1.0
      ..y = pack.first.y
      ..moveSpeed = 0
      ..fireCooldown = 99;
    _padAllCds(dk, except: AbilityId.howlingBlast);

    var fired = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if ((dk.abilityCd[AbilityId.howlingBlast.name] ?? 0) > 0.05) {
        fired = true;
        break;
      }
      dk.rage = 100;
    }
    expect(fired, isTrue);
    expect(pack.where((e) => e.hp < 2500).length, greaterThanOrEqualTo(3));
  });
}

GameState _soloSpecParty(HeroSpecId specId, {required int level}) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 9, 13));
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  final base = state.heroes.first;
  var hero = base.copyWith(specId: specId);
  while (hero.level < level) {
    hero = hero.levelUp();
  }
  return state.withActiveParty([hero]);
}

void _padAllCds(SpatialActor actor, {AbilityId? except}) {
  for (final def in ClassKits.all) {
    if (def.id == except || def.cooldown <= 0) continue;
    actor.abilityCd[def.id.name] = 99;
  }
}
