import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('every ability has usable tooltip copy', () {
    for (final def in ClassKits.all) {
      expect(def.name, isNotEmpty);
      expect(def.description, isNotEmpty);
      expect(def.tooltipMessage, contains(def.name));
      expect(def.tooltipMessage, contains(def.description));
      if (def.requiresShield) {
        expect(def.tooltipMessage, contains('shield'));
      }
    }
  });

  test('HUD kits at 15 expose signature abilities', () {
    expect(
      ClassKits.hudAbilitiesAt(HeroRole.warrior, 15).map((d) => d.id),
      containsAll([AbilityId.shockwave, AbilityId.devastate]),
    );
    expect(
      ClassKits.hudAbilitiesAt(HeroRole.healer, 15).map((d) => d.id),
      containsAll([
        AbilityId.prayerOfMending,
        AbilityId.powerInfusion,
      ]),
    );
    expect(
      ClassKits.unlockedAt(HeroRole.healer, 15).map((d) => d.id),
      contains(AbilityId.innerFire),
    );
    expect(
      ClassKits.hudAbilitiesAt(HeroRole.mage, 15).map((d) => d.id),
      containsAll([AbilityId.livingBomb, AbilityId.blastWave]),
    );
    expect(
      ClassKits.hudAbilitiesAt(HeroRole.rogue, 15).map((d) => d.id),
      contains(AbilityId.killingSpree),
    );
  });

  test('Inner Fire arms on Disc Priest once combat ticks', () {
    final state = _partyAtLevel(15);
    var world = SpatialCombat.build(state);
    _soloEnemy(world);
    final priest =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.healer);
    expect(priest.innerFireActive, isFalse);
    world = SpatialCombat.step(world, state, dt: 0.1).world;
    final after =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.healer);
    expect(after.innerFireActive, isTrue);
  });

  test('Living Bomb applies DoT mark to focus enemy', () {
    final state = _partyAtLevel(15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final mage = world.heroes.firstWhere((h) => h.heroRole == HeroRole.mage);
    mage
      ..rage = 100
      ..x = target.x - 2
      ..y = target.y;
    _padAbilityCds(mage, except: AbilityId.livingBomb);

    var armed = false;
    for (var i = 0; i < 40; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (world.enemies.any((e) => e.livingBombTimer > 0)) {
        armed = true;
        break;
      }
      mage.rage = 100;
    }
    expect(armed, isTrue);
    expect(mage.livingBombArmed, greaterThan(0));
    final marked =
        world.enemies.firstWhere((e) => e.livingBombTimer > 0);
    expect(marked.livingBombDps, greaterThan(0));
  });

  test('Shockwave roots a pack when warrior has rage', () {
    final state = _partyAtLevel(15);
    var world = SpatialCombat.build(state);
    expect(world.enemies.length, greaterThanOrEqualTo(2));

    final warrior =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.warrior);
    final a = world.enemies[0];
    final b = world.enemies[1];
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    a
      ..dormant = false
      ..hp = 500
      ..x = warrior.x + 1.2
      ..y = warrior.y;
    b
      ..dormant = false
      ..hp = 500
      ..x = warrior.x + 1.4
      ..y = warrior.y + 0.3;
    warrior
      ..rage = 100;
    _padAbilityCds(warrior, except: AbilityId.shockwave);

    var waved = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (warrior.shockwaveFlash > 0 ||
          a.rootTimer > 0 ||
          b.rootTimer > 0) {
        waved = true;
        break;
      }
      warrior.rage = 100;
    }
    expect(waved, isTrue);
  });

  test('Power Infusion buffs a living DPS', () {
    final state = _partyAtLevel(15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final priest =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.healer);
    priest
      ..rage = 100
      ..x = target.x - 2.5
      ..y = target.y;
    _padAbilityCds(priest, except: AbilityId.powerInfusion);

    var infused = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (world.heroes.any(
        (h) => !h.isPet && h.powerInfusionTimer > 0,
      )) {
        infused = true;
        break;
      }
      priest.rage = 100;
    }
    expect(infused, isTrue);
  });

  test('Killing Spree arms Combat Rogue on packs', () {
    final state = _partyAtLevel(15, unlockRogue: true);
    var world = SpatialCombat.build(state);
    final rogue =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.rogue);
    for (final e in world.enemies) {
      e
        ..hp = 0
        ..dormant = true;
    }
    for (final e in world.enemies.take(3)) {
      e
        ..dormant = false
        ..hp = 300
        ..x = rogue.x + 1.1
        ..y = rogue.y;
    }
    rogue.rage = 100;
    _padAbilityCds(rogue, except: AbilityId.killingSpree);

    var active = false;
    for (var i = 0; i < 60; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (rogue.killingSpreeTimer > 0) {
        active = true;
        break;
      }
      rogue.rage = 100;
    }
    expect(active, isTrue);
  });
}

GameState _partyAtLevel(int level, {bool unlockRogue = false}) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 7, 30));
  if (unlockRogue) {
    state = state.copyWith(rogueUnlocked: true);
    state = GameLogic.ensureRogueHero(state);
  }
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  return state.copyWith(
    heroes: [
      for (final h in state.heroes) _levelTo(h, level),
    ],
  );
}

PartyHero _levelTo(PartyHero hero, int level) {
  var h = hero;
  while (h.level < level) {
    h = h.levelUp();
  }
  return h;
}

/// One living foe so focus targeting is deterministic.
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
    ..hp = mathMax(keep.hp, 500);
  for (final h in world.heroes) {
    if (!h.isPet) h.hp = h.maxHp;
  }
  return keep;
}

int mathMax(int a, int b) => a > b ? a : b;

void _padAbilityCds(SpatialActor actor, {required AbilityId except}) {
  for (final def in ClassKits.all) {
    if (def.id == except || def.cooldown <= 0) continue;
    actor.abilityCd[def.id.name] = 99;
  }
}
