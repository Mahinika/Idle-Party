import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// New AbilityId values from the abilities-61 batch (must stay 61).
const _newIds = <AbilityId>{
  AbilityId.colossusSmash,
  AbilityId.dieByTheSword,
  AbilityId.armsCharge,
  AbilityId.executeFury,
  AbilityId.piercingHowl,
  AbilityId.lightOfDawn,
  AbilityId.hammerOfJusticeHoly,
  AbilityId.ardentDefender,
  AbilityId.wordOfGloryProt,
  AbilityId.consecrationRet,
  AbilityId.hammerOfJusticeRet,
  AbilityId.wordOfGloryRet,
  AbilityId.stampede,
  AbilityId.killShotBm,
  AbilityId.claw,
  AbilityId.killShotMm,
  AbilityId.bindingShot,
  AbilityId.wildfireBomb,
  AbilityId.harpoonSurvival,
  AbilityId.kidneyShotAssa,
  AbilityId.crimsonVial,
  AbilityId.adrenalineRush,
  AbilityId.revealingStrike,
  AbilityId.secretTechnique,
  AbilityId.powerWordBarrier,
  AbilityId.halo,
  AbilityId.shadowfiendDisc,
  AbilityId.holyFire,
  AbilityId.holyWordSanctify,
  AbilityId.prayerOfMendingHoly,
  AbilityId.shadowWordDeath,
  AbilityId.shadowfiendShadow,
  AbilityId.frozenOrb,
  AbilityId.breathOfSindragosa,
  AbilityId.empowerRuneWeapon,
  AbilityId.soulReaper,
  AbilityId.darkTransformation,
  AbilityId.fireElemental,
  AbilityId.crashLightning,
  AbilityId.healingSurge,
  AbilityId.healingTideTotem,
  AbilityId.earthbindTotem,
  AbilityId.manaTideTotem,
  AbilityId.arcaneBarrage,
  AbilityId.prismaticBarrier,
  AbilityId.evocation,
  AbilityId.meteor,
  AbilityId.iceBarrierFrost,
  AbilityId.frostMageConeOfCold,
  AbilityId.darkSoul,
  AbilityId.howlOfTerror,
  AbilityId.callDreadstalkers,
  AbilityId.soulFireDemo,
  AbilityId.summonInfernal,
  AbilityId.shadowburn,
  AbilityId.starsurge,
  AbilityId.forceOfNature,
  AbilityId.maim,
  AbilityId.ironbark,
  AbilityId.innervateDruid,
  AbilityId.entanglingRoots,
};

const _expectedPerSpec = <HeroSpecId, int>{
  HeroSpecId.protection: 13,
  HeroSpecId.blood: 11,
  HeroSpecId.guardian: 11,
};

/// Legacy coeffs frozen on main — proves we did not retune shipped abilities.
const _legacyCoeffs = <AbilityId, double>{
  AbilityId.mortalStrike: 2.35,
  AbilityId.killCommand: 1.48,
  AbilityId.arcaneBlast: 1.1,
  AbilityId.holyShock: 1.3,
  AbilityId.obliterate: 2.10,
  AbilityId.chainLightning: 0.72,
};

void main() {
  test('catalog totals 343 rows and 343 unique ids', () {
    expect(ClassKits.all.length, 343);
    expect(ClassKits.all.map((d) => d.id).toSet().length, 343);
    expect(_newIds.length, 61);
    for (final id in _newIds) {
      expect(ClassKits.defFor(id), isNotNull, reason: '$id missing from map');
    }
  });

  test('each spec hits 11 abilities (protection stays 13)', () {
    for (final spec in HeroSpecId.values) {
      final n = ClassKits.forSpec(spec).length;
      final want = _expectedPerSpec[spec] ?? 11;
      expect(n, want, reason: '${spec.name} count $n != $want');
    }
  });

  test('legacy ability coeffs unchanged', () {
    for (final e in _legacyCoeffs.entries) {
      final def = ClassKits.defFor(e.key)!;
      expect(def.coeff, e.value, reason: '${e.key.name} coeff');
    }
  });

  test('old save JSON still loads after new AbilityId enum values', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 1));
    final encoded = jsonEncode(state.toJson());
    final round = GameState.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expect(round.heroes.length, state.heroes.length);
    for (final h in round.heroes) {
      final kit = ClassKits.forSpec(h.specId);
      expect(kit, isNotEmpty);
      expect(kit.every((d) => d.specId == h.specId), isTrue);
    }
  });

  test('each new ability resolves in SpatialCombat build', () {
    for (final id in _newIds) {
      final def = ClassKits.all.firstWhere((d) => d.id == id);
      final state = _soloSpecParty(def.specId!, level: 15);
      var world = SpatialCombat.build(state);
      final hero = world.heroes.firstWhere((h) => !h.isPet);
      _primeCastWindow(world, hero, def);
      var fired = false;
      for (var i = 0; i < 160; i++) {
        final before = hero.abilityCd[def.id.name] ?? 0;
        world = SpatialCombat.step(world, state, dt: 0.1).world;
        final after = hero.abilityCd[def.id.name] ?? 0;
        if (before <= 0.05 && after > 0.5) {
          fired = true;
          break;
        }
        _primeCastWindow(world, hero, def);
      }
      expect(fired, isTrue, reason: '${def.name} ($id) never entered cooldown');
    }
  });

  test('Mortal Strike coeff and cooldown unchanged', () {
    final ms = ClassKits.defFor(AbilityId.mortalStrike)!;
    expect(ms.coeff, 2.35);
    expect(ms.cooldown, 3.0);
    expect(ms.resourceCost, 16);
  });
}

SpatialActor _focusEnemy(SpatialWorld world) {
  for (final e in world.enemies) {
    e
      ..dormant = false
      ..hp = math.max(e.hp, 80);
    return e;
  }
  throw StateError('no enemies in spatial build');
}

void _primeCastWindow(
  SpatialWorld world,
  SpatialActor hero,
  ClassAbilityDef def,
) {
  final foe = _focusEnemy(world);
  for (final d in ClassKits.forSpec(hero.heroSpecId!)) {
    if (d.id == def.id || d.cooldown <= 0) continue;
    hero.abilityCd[d.id.name] = 99;
  }
  hero.abilityCd[def.id.name] = 0;
  hero.rage = math.max(100, def.resourceCost + 20);
  if (def.gate.executeHpFrac != null) {
    foe.hp = math.max(
      1,
      (foe.maxHp * def.gate.executeHpFrac! * 0.85).floor(),
    );
    hero.x = foe.x - 1.5;
    hero.y = foe.y;
  }
  if (def.effect == AbilityEffectKind.heal || def.effect == AbilityEffectKind.absorb) {
    for (final h in world.heroes) {
      if (!h.isPet) h.hp = math.max(1, (h.maxHp * 0.55).round());
    }
  }
  if (def.gate.packMin > 1) {
    var alive = world.enemies.where((e) => !e.dormant && e.hp > 0).length;
    while (alive < def.gate.packMin) {
      final donor = world.enemies.firstWhere((e) => !e.dormant);
      donor.hp = donor.maxHp;
      donor.dormant = false;
      alive++;
    }
  }
  if (def.gate.requireFocus == true) {
    foe.hp = math.max(foe.hp, 400);
    final minR = def.gate.minRange ?? 0.0;
    final maxR = def.gate.maxRange ?? 6.0;
    final gap = math.min(maxR - 0.5, math.max(minR + 0.3, 4.5));
    hero.x = foe.x - gap;
    hero.y = foe.y;
  }
  if (def.customId == AbilityCustomId.charge) {
    hero.rage = math.max(hero.rage, 25);
  }
  if (def.gate.comboMin > 0) {
    hero.comboPoints = def.gate.comboMin;
  }
  if (def.tier == AbilityCastTier.emergency) {
    hero.hp = math.max(1, (hero.maxHp * 0.22).round());
  }
  if (def.gate.casterHpMax != null) {
    hero.hp = math.max(1, (hero.maxHp * def.gate.casterHpMax! * 0.9).round());
  }
}

GameState _soloSpecParty(HeroSpecId specId, {required int level}) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 8, 1));
  state = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  var hero = state.heroes.first.copyWith(specId: specId);
  while (hero.level < level) {
    hero = hero.levelUp();
  }
  return state.withActiveParty([hero]);
}