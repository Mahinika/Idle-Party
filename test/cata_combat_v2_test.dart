import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/combat_ratings.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/spec_mastery.dart';
import 'package:idle_party/spatial/combat_avoidance.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('CombatAvoidance block reduces melee by 30% then flat value', () {
    final rng = Random(42);
    var blocked = 0;
    for (var i = 0; i < 200; i++) {
      final r = CombatAvoidance.resolveIncomingMelee(
        rawDamage: 100,
        dodgePercent: 0,
        parryPercent: 0,
        blockChance: 1.0,
        blockValue: 5,
        shieldBlockActive: false,
        rng: rng,
      );
      expect(r.blocked, isTrue);
      expect(r.damage, lessThan(75));
      blocked++;
    }
    expect(blocked, 200);
  });

  test('CC root DR shortens repeat roots', () {
    expect(CombatAvoidance.ccRootDuration(2.0, 0), 2.0);
    expect(CombatAvoidance.ccRootDuration(2.0, 1), 1.0);
    expect(CombatAvoidance.ccRootDuration(2.0, 3), 0.0);
  });

  test('Prot warrior builds with mastery block and avoidance', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 1))
        .withActiveParty([
          GameLogic.createInitialState().heroes.first.copyWith(
            specId: HeroSpecId.protection,
            level: 20,
          ),
        ]);
    final world = SpatialCombat.build(state);
    final tank = world.heroes.single;
    expect(tank.uncrittable, isTrue);
    expect(tank.blockChance, greaterThan(0));
    expect(tank.dodgePercent, greaterThan(0));
    expect(tank.physicalAttack, greaterThan(0));
  });

  test('Fire mage uses spell power for Fireball', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 1))
        .withActiveParty([
          GameLogic.createInitialState().heroes.first.copyWith(
            specId: HeroSpecId.fire,
            level: 15,
          ),
        ]);
    final world = SpatialCombat.build(state);
    final mage = world.heroes.single;
    expect(mage.spellPower, greaterThan(mage.physicalAttack));
    final fireball = ClassKits.forSpec(HeroSpecId.fire)
        .firstWhere((d) => d.id == AbilityId.fireball);
    expect(ClassAbilityDef.inferUsesSpellPower(fireball), isTrue);
  });

  test('Deep Healing mastery scales with missing HP', () {
    const hero = MasteryCombatant(
      specId: HeroSpecId.restorationShaman,
      masteryPoints: 8,
    );
    final low = SpecMastery.healMul(hero, 0.8);
    final high = SpecMastery.healMul(hero, 0.1);
    expect(low, greaterThan(high));
  });

  test('Arms / MM / Combat white-hit mastery procs have real chances', () {
    const arms = MasteryCombatant(
      specId: HeroSpecId.arms,
      masteryPoints: 10,
    );
    const mm = MasteryCombatant(
      specId: HeroSpecId.marksmanship,
      masteryPoints: 10,
    );
    const combat = MasteryCombatant(
      specId: HeroSpecId.combat,
      masteryPoints: 10,
    );
    expect(SpecMastery.extraSwingProcChance(arms), greaterThan(0.04));
    expect(SpecMastery.extraAutoShotProcChance(mm), greaterThan(0.05));
    expect(SpecMastery.mainGaucheProcChance(combat), greaterThan(0.04));
    expect(
      SpecMastery.extraSwingProcChance(
        const MasteryCombatant(specId: HeroSpecId.fury),
      ),
      0,
    );
  });

  test('Arms white-hit mastery can tag SWING floaters', () {
    final base = GameLogic.createInitialState(now: DateTime(2026, 8, 1));
    final state = base.withActiveParty([
      base.heroes.first.copyWith(
        specId: HeroSpecId.arms,
        level: 20,
      ),
    ]);
    var world = SpatialCombat.build(state);
    final hero = world.heroes.firstWhere((h) => !h.isPet);
    hero.masteryPoints = 40; // ~28% swing chance ceiling path
    var sawSwing = false;
    for (var i = 0; i < 400 && !sawSwing; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
      for (final f in world.floaters) {
        if (f.text == 'SWING') {
          sawSwing = true;
          break;
        }
      }
      // Keep packs alive so whites keep landing.
      for (final e in world.enemies) {
        if (e.hp > 0 && !e.dormant) {
          e.hp = max(e.hp, 500);
        }
      }
      hero.fireCooldown = 0;
    }
    expect(sawSwing, isTrue);
  });

  test('tank sheet skips Agi DEF crumb but keeps dodge', () {
    final prot = GameLogic.createInitialState().heroes.first.copyWith(
      specId: HeroSpecId.protection,
      level: 20,
    );
    final ratings = CombatRatings.fromHeroSheet(
      hero: prot,
      gearAgility: 40,
    );
    expect(ratings.dodgePercent, greaterThan(0));
  });
}
