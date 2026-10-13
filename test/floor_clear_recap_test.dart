import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('floor clear line names gold, XP, and the best drop', () {
    expect(
      floorClearRecap(
        floor: 4,
        gold: 120,
        xp: 40,
        bestDrop: 'Ash Blade',
      ),
      'F4 CLEAR · +120g · +40 XP · Ash Blade',
    );
    expect(
      floorClearRecap(
        floor: 9,
        gold: 10,
        xp: 0,
        essence: 2,
        gauntlet: true,
      ),
      'Spire F9 · +10g · +2e',
    );
    expect(floorClearRecap(floor: 1, gold: 0, xp: 0), 'F1 CLEAR');
  });

  test('a loot vacuum is one burst and one pickup', () {
    final director = GameDirector.preview();
    final state = GameLogic.enterDungeon(director.state);
    final world = SpatialCombat.build(state);
    for (var i = 0; i < 3; i++) {
      world.groundLoot.add(
        GroundLoot(
          x: 2.0 + i,
          y: 3.0,
          drop: LootDrop(
            name: 'coin',
            amount: 5,
            rarity: LootRarity.common,
            outcome: LootOutcome.gold,
          ),
        ),
      );
    }
    final before = world.bursts.length;
    combatVacuumGroundLoot(world, state);
    expect(world.groundLoot, isEmpty);
    expect(world.pendingFeelPickups, 1);
    expect(world.bursts.length, before + 1);
  });
}
