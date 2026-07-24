import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('spatial combat eventually clears a weakened room', () {
    final room = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    var state = room.copyWith(
      enemies: room.enemies
          .map((e) => e.copyWith(currentHp: 3, stats: e.stats))
          .toList(),
    );
    // Boost hero damage via forge so the room ends quickly.
    state = state.copyWith(attackBonus: 40);
    var world = SpatialCombat.build(state);

    var cleared = false;
    for (var i = 0; i < 400; i++) {
      final step = SpatialCombat.step(world, state, dt: 0.05);
      world = step.world;
      state = step.state;
      if (step.roomCleared) {
        cleared = true;
        break;
      }
      expect(step.partyWiped, isFalse);
    }

    expect(cleared, isTrue);
    expect(state.aliveEnemies, isEmpty);
  });

  test('god hand damages nearby enemies', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 7, 4));
    final world = SpatialCombat.build(state);
    final target = world.enemies.first;
    final before = target.hp;
    SpatialCombat.godHand(
      world,
      state,
      tileX: target.x,
      tileY: target.y,
      baseDamage: 50,
    );
    expect(target.hp, lessThan(before));
  });
}
