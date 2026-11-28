import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/spatial/combat_floater_layout.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

import 'shell_golden_harness.dart';

void main() {
  test('spawnFloater routes heals and hits to gutters with lane X', () {
    final world = SpatialWorld(
      map: TileMap(
        cols: 16,
        rows: 16,
        tiles: List.filled(16 * 16, TileKind.floor),
        spawnPoints: const [(2, 2)],
        exitPoint: (14, 14),
        enemySpawns: const [(8, 8)],
      ),
      heroes: const [],
      enemies: const [],
      projectiles: const [],
      groundLoot: const [],
      isTreasure: false,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 8,
      y: 8,
      text: '+12',
      argb: SpatialCombat.floaterHeal,
      priority: 2,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 9,
      y: 8,
      text: '31',
      argb: SpatialCombat.floaterDamage,
    );
    expect(
      world.floaters.every(
        (f) =>
            (f.placement == CombatFloaterPlacement.gutterBeneficial &&
                f.x == CombatFloaterLayout.laneLeftX) ||
            (f.placement == CombatFloaterPlacement.gutterHostile &&
                f.x == CombatFloaterLayout.laneRightX),
      ),
      isTrue,
      reason: 'numeric heal/hit must not keep world anchor X',
    );
  });

  test('stageFightHitProof places hit in right gutter not on scrum', () async {
    final director = await fightHitGoldenDirector();
    addTearDown(director.dispose);
    final world = director.spatial!;
    final hit = world.floaters.where(
      (f) => f.text.contains('18') || f.text.contains('A 18'),
    );
    expect(hit, isNotEmpty);
    final floater = hit.first;
    expect(floater.placement, CombatFloaterPlacement.gutterHostile);
    expect(floater.x, CombatFloaterLayout.laneRightX);
    final gold = world.floaters.where((f) => f.text.contains('g'));
    expect(gold, isNotEmpty);
    expect(
      gold.first.placement,
      anyOf(
        CombatFloaterPlacement.payoff,
        CombatFloaterPlacement.payoffBanner,
      ),
    );
  });

  test('reconcileWorldFloaters repairs legacy world-space damage numbers', () {
    final world = SpatialWorld(
      map: TileMap(
        cols: 16,
        rows: 16,
        tiles: List.filled(16 * 16, TileKind.floor),
        spawnPoints: const [(2, 2)],
        exitPoint: (14, 14),
        enemySpawns: const [(8, 8)],
      ),
      heroes: const [],
      enemies: const [],
      projectiles: const [],
      groundLoot: const [],
      isTreasure: false,
    );
    world.floaters.add(
      SpatialFloater(x: 8.2, y: 7.5, text: '42', argb: SpatialCombat.floaterDamage),
    );
    SpatialCombat.reconcileWorldFloaters(world);
    expect(world.floaters.single.x, CombatFloaterLayout.laneRightX);
    expect(world.floaters.single.placement, CombatFloaterPlacement.gutterHostile);
  });
}