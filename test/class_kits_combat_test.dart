import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
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
      containsAll([
        AbilityId.shockwave,
        AbilityId.devastate,
        AbilityId.charge,
        AbilityId.commandingShout,
      ]),
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

  test('signature dumps and panic buttons are ready on a typical floor', () {
    for (final def in ClassKits.all) {
      if (def.tier != AbilityCastTier.signature &&
          def.tier != AbilityCastTier.emergency) {
        continue;
      }
      expect(
        def.unlockLevel,
        lessThanOrEqualTo(12),
        reason: '${def.specId} ${def.name} still waits until ${def.unlockLevel}',
      );
    }
    expect(
      ClassKits.hudAbilitiesAtSpec(HeroSpecId.retribution, 12).map((d) => d.id),
      containsAll([AbilityId.templarsVerdict, AbilityId.divineShield]),
    );
    expect(
      ClassKits.defFor(AbilityId.beastWithin)!.selfBuffKind,
      AbilitySelfBuffKind.amp,
    );
    expect(
      ClassKits.defFor(AbilityId.trueshot)!.selfBuffKind,
      AbilitySelfBuffKind.amp,
    );
    expect(
      ClassKits.defFor(AbilityId.zealotry)!.selfBuffKind,
      AbilitySelfBuffKind.amp,
    );
    expect(
      ClassKits.defFor(AbilityId.pillarOfFrost)!.selfBuffKind,
      AbilitySelfBuffKind.amp,
    );
    expect(
      ClassKits.defFor(AbilityId.metamorphosis)!.selfBuffKind,
      AbilitySelfBuffKind.amp,
    );
  });

  test('signature dumps flash the HUD chip on the first beat of cooldown', () {
    final dump = ClassKits.defFor(AbilityId.templarsVerdict)!;
    expect(dump.tier, AbilityCastTier.signature);
    expect(dump.justFiredHud(dump.cooldown), isTrue);
    expect(dump.justFiredHud(dump.cooldown - 0.1), isTrue);
    expect(dump.justFiredHud(dump.cooldown * 0.4), isFalse);
    expect(dump.justFiredHud(0), isFalse);
    final filler = ClassKits.all.firstWhere(
      (d) => d.tier == AbilityCastTier.filler && d.cooldown > 1,
    );
    expect(filler.justFiredHud(filler.cooldown), isFalse);
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
    warrior.rage = 100;
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

  test('Charge gap-closes Prot warrior onto a distant foe', () {
    final state = _partyAtLevel(15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final warrior =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.warrior);
    warrior
      ..rage = 100
      ..x = target.x - 5.5
      ..y = target.y;
    _padAbilityCds(warrior, except: AbilityId.charge);

    final startDist =
        ((warrior.x - target.x).abs() + (warrior.y - target.y).abs());
    var charged = false;
    for (var i = 0; i < 40; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      final dist =
          ((warrior.x - target.x).abs() + (warrior.y - target.y).abs());
      if (dist + 0.5 < startDist || target.rootTimer > 0) {
        charged = true;
        break;
      }
      warrior.rage = 100;
    }
    expect(charged, isTrue);
  });

  test('Charge refuses targets beyond max range', () {
    final state = _partyAtLevel(15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final warrior =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.warrior);
    // Farther than chargeMaxRange (8) — must not teleport across the map.
    warrior
      ..rage = 100
      ..x = target.x - 14.0
      ..y = target.y;
    _padAbilityCds(warrior, except: AbilityId.charge);

    for (var i = 0; i < 8; i++) {
      // Pin far so we only test out-of-range refuse (not walk-into-range Charge).
      warrior
        ..x = target.x - 14.0
        ..y = target.y
        ..rage = 100;
      _padAbilityCds(warrior, except: AbilityId.charge);
      world = SpatialCombat.step(world, state, dt: 0.1).world;
    }
    expect(target.rootTimer, lessThan(0.1));
    // Pin each step; allow small walk jitter without counting as Charge.
    expect(warrior.x, closeTo(target.x - 14.0, 1.0));
  });

  test('Commanding Shout buffs living party heroes', () {
    final state = _partyAtLevel(15);
    var world = SpatialCombat.build(state);
    final target = _soloEnemy(world);
    final warrior =
        world.heroes.firstWhere((h) => h.heroRole == HeroRole.warrior);
    warrior
      ..rage = 100
      ..x = target.x - 1.2
      ..y = target.y;
    _padAbilityCds(warrior, except: AbilityId.commandingShout);

    var shouted = false;
    for (var i = 0; i < 50; i++) {
      world = SpatialCombat.step(world, state, dt: 0.1).world;
      if (world.heroes.any(
        (h) => !h.isPet && (h.buffTimers['atkShout'] ?? 0) > 0,
      )) {
        shouted = true;
        break;
      }
      warrior.rage = 100;
    }
    expect(shouted, isTrue);
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
