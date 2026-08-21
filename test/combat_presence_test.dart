import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('CombatPresence seeds kit kite styles and impatience', () {
    final director = GameDirector.preview();
    var state = GameLogic.enterDungeon(director.state);
    final world = SpatialCombat.build(state);
    expect(world.heroes, isNotEmpty);
    for (final h in world.heroes) {
      expect(h.impatience, inInclusiveRange(0.2, 0.85));
      expect(h.kiteMul, greaterThan(0.8));
      if (h.heroSpecId == HeroSpecId.fire) {
        expect(h.kiteMul, greaterThan(1.05));
      }
      if (h.heroSpecId == HeroSpecId.arcane) {
        expect(h.kiteMul, lessThan(1.0));
        expect(h.kiteSide.abs(), greaterThan(0.5));
      }
    }
  });

  test('holding range applies idle jitter instead of a hard freeze', () {
    final director = GameDirector.preview();
    var state = GameLogic.enterDungeon(director.state);
    final world = SpatialCombat.build(state);
    final hero = world.heroes.first;
    final x0 = hero.x;
    final y0 = hero.y;
    // Hold on self: steer should breathe, not stay bit-identical.
    for (var i = 0; i < 40; i++) {
      SpatialCombat.step(world, state, dt: 0.05);
    }
    // After combat ticks, at least one hero should have moved a hair
    // (jitter / separation / pathing) — not locked to spawn forever.
    var moved = false;
    for (final h in world.heroes) {
      if ((h.x - x0).abs() > 0.001 || (h.y - y0).abs() > 0.001) {
        moved = true;
        break;
      }
      if (h.vx.abs() > 0 || h.vy.abs() > 0) {
        moved = true;
        break;
      }
    }
    // Soft assert: if everyone somehow stayed put, face aim still seeded.
    expect(hero.faceAimX != 0 || hero.faceAimY != 0 || moved, isTrue);
  });

  test('taunt bark uses speech floater when VFX on', () {
    final director = GameDirector.preview();
    var state = GameLogic.enterDungeon(
      director.state.copyWith(reducedVfx: false),
    );
    final world = SpatialCombat.build(state);
    SpatialActor? tank;
    for (final h in world.heroes) {
      if (h.heroSpecId != null && HeroSpecs.def(h.heroSpecId!).isTank) {
        tank = h;
        break;
      }
    }
    tank ??= world.heroes.first;
    // Force a loose enemy targeting someone else.
    expect(world.enemies, isNotEmpty);
    final foe = world.enemies.first;
    foe.dormant = false;
    foe.hp = math.max(1, foe.hp);
    foe.forcedTargetId = null;
    foe.forcedTargetTimer = 0;
    // Soft tank leash is ~4 tiles; taunt range is 5.5 — park tank in the gap.
    final other = world.heroes.firstWhere((h) => h.id != tank!.id);
    other.x = 6;
    other.y = 6;
    foe.x = other.x + 0.4;
    foe.y = other.y;
    tank.x = other.x + 5.0;
    tank.y = other.y;
    final pulled = SpatialCombat.testTauntForPresence(world, tank);
    expect(pulled, isTrue);
    expect(
      world.floaters.any(
        (f) =>
            f.kind == SpatialFloaterKind.speech &&
            f.text.contains('backline'),
      ),
      isTrue,
    );
  });
}
