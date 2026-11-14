import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

/// 1.13.18 calmer combat text: fights keep damage / heal numbers, avoidance
/// words and real events; proc / kit words, speech barks and routine payout
/// text are dropped at spawn.
void main() {
  SpatialWorld freshWorld() {
    final state = GameLogic.createInitialState(now: DateTime(2026, 11, 14));
    final world = SpatialCombat.build(state);
    world.floaters.clear();
    world.bursts.clear();
    return world;
  }

  test('callout words and speech barks are off by default', () {
    expect(SpatialCombat.showCalloutWords, isFalse);
    expect(SpatialCombat.showSpeechBarks, isFalse);
  });

  test('callout and speech floaters are dropped; numbers and events stay', () {
    final world = freshWorld();
    SpatialCombat.spawnFloater(
      world,
      x: 5,
      y: 5,
      text: 'SnD',
      argb: 0xFFFFD070,
      kind: SpatialFloaterKind.callout,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 9,
      y: 5,
      text: 'Gotcha!',
      argb: 0xFFFFFFFF,
      priority: 2,
      kind: SpatialFloaterKind.speech,
    );
    expect(world.floaters, isEmpty);

    SpatialCombat.spawnFloater(
      world,
      x: 5,
      y: 9,
      text: '42',
      argb: SpatialCombat.floaterDamage,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 9,
      y: 9,
      text: '+17',
      argb: SpatialCombat.floaterHeal,
      priority: 2,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 13,
      y: 9,
      text: 'DODGE',
      argb: 0xFF90E0A0,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 17,
      y: 9,
      text: 'BOSS DOWN',
      argb: 0xFFFFE070,
      priority: 3,
    );
    expect(
      world.floaters.map((f) => f.text).toSet(),
      {'42', '+17', 'DODGE', 'BOSS DOWN'},
    );
  });

  test('turning the flags on brings callouts and barks back', () {
    SpatialCombat.showCalloutWords = true;
    SpatialCombat.showSpeechBarks = true;
    addTearDown(() {
      SpatialCombat.showCalloutWords = false;
      SpatialCombat.showSpeechBarks = false;
    });
    final world = freshWorld();
    SpatialCombat.spawnFloater(
      world,
      x: 5,
      y: 5,
      text: 'SnD',
      argb: 0xFFFFD070,
      kind: SpatialFloaterKind.callout,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 9,
      y: 5,
      text: 'Gotcha!',
      argb: 0xFFFFFFFF,
      priority: 2,
      kind: SpatialFloaterKind.speech,
    );
    expect(world.floaters.map((f) => f.text).toSet(), {'SnD', 'Gotcha!'});
  });

  test('important ability announce keeps its burst but drops the word', () {
    final world = freshWorld();
    final hero = world.heroes.first;
    AbilityEffectRunner.announce(
      world,
      hero,
      'LAST STAND',
      0xFFFF7070,
      false,
      important: true,
    );
    expect(world.floaters, isEmpty);
    expect(world.bursts, isNotEmpty);
  });

  test('kill payout pays gold and XP without a +g / XP floater', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 19));
    final world = SpatialCombat.build(state);
    world.floaters.clear();
    final enemy = world.enemies.first;
    final unit = state.enemies[world.enemies.indexOf(enemy)];
    expect(unit.rewardGold, greaterThan(0));
    final beforeXp = state.heroes.fold<int>(0, (sum, h) => sum + h.xp);
    final result = SpatialCombat.onEnemyKilled(
      world,
      state,
      enemy,
      Random(1),
    );
    final afterXp = result.state.heroes.fold<int>(0, (sum, h) => sum + h.xp);
    expect(result.gold, unit.rewardGold);
    expect(afterXp, greaterThan(beforeXp));
    final goldText = RegExp(r'\+\d+g');
    expect(world.floaters.any((f) => f.text.contains('XP')), isFalse);
    expect(world.floaters.any((f) => goldText.hasMatch(f.text)), isFalse);
  });
}
