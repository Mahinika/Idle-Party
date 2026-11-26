import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

import '../tool/sim_harness.dart';

/// Positioning metrics sweep — used for range tuning proposals.
void main() {
  test('positioning range metrics sweep', () {
    const trials = 4;
    const floor = 5;
    final rows = <Map<String, Object>>[];

    final dpsSpecs = HeroSpecId.values.where((id) {
      final t = HeroSpecs.def(id).roleTag;
      return t == SpecRoleTag.meleeDps ||
          t == SpecRoleTag.rangedDps ||
          t == SpecRoleTag.caster;
    });

    seedEquipmentRng(42);
    for (final spec in dpsSpecs) {
      rows.add(_measureSpec(focus: spec, trials: trials, floor: floor));
    }

    final outPath = Platform.environment['POSITIONING_JSON'];
    if (outPath != null) {
      File(outPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'trials': trials,
          'floor': floor,
          'rows': rows,
        }),
      );
    }

    // Sanity: most kits land a hit within 90s on Sandy F5.
    for (final row in rows) {
      final t = row['focusFirstHitSec']! as double;
      expect(
        t,
        lessThan(89.5),
        reason: '${row['spec']} never attacked in ${trials}x F5',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Map<String, Object> _measureSpec({
  required HeroSpecId focus,
  required int trials,
  required int floor,
}) {
  final firstHits = <double>[];
  final inRangePcts = <double>[];
  final rangedDmg = <int>[];
  final shares = <double>[];

  for (var t = 0; t < trials; t++) {
    final trialSeed = 4000 + t * 97 + floor * 13 + focus.index * 3;
    seedEquipmentRng(42 + t);
    GameLogic.random = Random(trialSeed ^ 0x5EED);
    var state = createPartyState(
      partySpecs: [HeroSpecId.protection, HeroSpecId.discipline, focus],
    );
    state = prepareSimParty(state, band: 'light', partyLevel: 12);
    state = enterFloor(
      state,
      dungeonId: 'sandy',
      floor: floor,
      seed: trialSeed,
    );

    const stepDt = 1 / 60;
    const maxSeconds = 90.0;
    var world = SpatialCombat.build(state);
    var current = state;
    var elapsed = 0.0;
    var focusFirstHit = -1.0;
    var inRangeFrames = 0;
    var totalFrames = 0;
    SpatialActor? focusActor;

    while (elapsed < maxSeconds) {
      final step = SpatialCombat.step(world, current, dt: stepDt);
      world = step.world;
      current = step.state;
      elapsed += stepDt;
      totalFrames++;

      focusActor ??= world.heroes
          .where((h) => h.heroSpecId == focus)
          .cast<SpatialActor?>()
          .firstOrNull;
      final hero = focusActor;
      if (hero != null && hero.isAlive) {
        if (focusFirstHit < 0 && hero.damageDealt > 0) {
          focusFirstHit = elapsed;
        }
        SpatialActor? target;
        for (final e in world.enemies) {
          if (e.isAlive && !e.dormant) {
            target = e;
            break;
          }
        }
        if (target != null) {
          final d = SpatialCombat.actorDist(hero, target);
          if (d <= hero.attackRange + 0.15) {
            inRangeFrames++;
          }
        }
      }

      if (step.roomCleared ||
          step.partyWiped ||
          current.isPartyDefeated ||
          world.heroes.every((h) => !h.isAlive)) {
        break;
      }
    }

    firstHits.add(focusFirstHit < 0 ? maxSeconds : focusFirstHit);
    inRangePcts.add(
      totalFrames > 0 ? 100.0 * inRangeFrames / totalFrames : 0,
    );

    var focusDmg = 0;
    var totalDmg = 0;
    for (final h in world.heroes) {
      totalDmg += h.damageDealt;
      if (h.heroSpecId == focus) focusDmg = h.damageDealt;
    }
    if (totalDmg > 0) shares.add(100.0 * focusDmg / totalDmg);
    rangedDmg.add(focusActor?.rangedOrSpellDamageTaken ?? 0);
  }

  final def = HeroSpecs.def(focus);
  return {
    'spec': focus.name,
    'ranged': def.ranged,
    'preferredRange': def.preferredRange,
    'attackRange': def.attackRange,
    'role': def.roleTag.name,
    'shareMedian': _median(shares),
    'focusFirstHitSec': _median(firstHits),
    'focusInRangePct': _median(inRangePcts),
    'focusRangedDmgTaken': _medianInt(rangedDmg),
  };
}

double _median(List<double> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  return s[s.length ~/ 2];
}

double _medianInt(List<int> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  return s[s.length ~/ 2].toDouble();
}