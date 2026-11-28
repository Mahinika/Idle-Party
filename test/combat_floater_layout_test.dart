import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/spatial/combat_floater_layout.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';
import 'package:idle_party/ui/floater_paint.dart';

void main() {
  test('classifies mitigation, heals, and hostile numbers', () {
    expect(
      CombatFloaterLayout.classify(
        text: 'DODGE',
        argb: 0,
        priority: 2,
        healArgb: SpatialCombat.floaterHeal,
        speech: false,
      ),
      CombatFloaterPlacement.unitPill,
    );
    expect(
      CombatFloaterLayout.classify(
        text: '+14',
        argb: SpatialCombat.floaterHeal,
        priority: 1,
        healArgb: SpatialCombat.floaterHeal,
        speech: false,
      ),
      CombatFloaterPlacement.gutterBeneficial,
    );
    expect(
      CombatFloaterLayout.classify(
        text: '42',
        argb: SpatialCombat.floaterDamage,
        priority: 0,
        healArgb: SpatialCombat.floaterHeal,
        speech: false,
      ),
      CombatFloaterPlacement.gutterHostile,
    );
  });

  test('merge window tightens at 2x pace', () {
    expect(
      CombatFloaterLayout.mergeWindowForPace(1),
      CombatFloaterLayout.mergeWindowSec,
    );
    expect(
      CombatFloaterLayout.mergeWindowForPace(2),
      CombatFloaterLayout.mergeWindowSec / 2,
    );
  });

  test('mergeLaneText rolls hostile damage', () {
    final merged = CombatFloaterLayout.mergeLaneText('B 10', 'B 12', hostile: true);
    expect(merged, 'B 22');
    final crit = CombatFloaterLayout.mergeLaneText(
      'B CRIT 30',
      'B 15',
      hostile: true,
    );
    expect(crit, 'B CRIT 45');
  });

  test('minimal VFX still allows mitigation pills', () {
    expect(
      CombatFloaterLayout.visibleAtQuality(
        quality: VfxQuality.minimal,
        placement: CombatFloaterPlacement.unitPill,
        priority: 2,
        mitigationPill: true,
      ),
      isTrue,
    );
    expect(
      CombatFloaterLayout.visibleAtQuality(
        quality: VfxQuality.minimal,
        placement: CombatFloaterPlacement.gutterHostile,
        priority: 0,
        mitigationPill: false,
      ),
      isFalse,
    );
  });

  test('spawnFloater merges rapid hits on same target', () {
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
      combatElapsed: 0,
    );
    SpatialCombat.spawnFloater(
      world,
      x: 5,
      y: 5,
      text: '12',
      argb: SpatialCombat.floaterDamage,
      mergeKey: 'hit:a:t',
      sourceInitial: 'B',
    );
    expect(world.floaters.length, 1);
    world.combatElapsed = 0.2;
    SpatialCombat.spawnFloater(
      world,
      x: 5,
      y: 5,
      text: '8',
      argb: SpatialCombat.floaterDamage,
      mergeKey: 'hit:a:t',
      sourceInitial: 'B',
    );
    expect(world.floaters.length, 1);
    expect(world.floaters.single.text, contains('20'));
  });

  test('gutter lane Y offset stacks upward', () {
    final a = gutterLaneYOffset(stackIndex: 0, lineHeight: 10, rise: 2);
    final b = gutterLaneYOffset(stackIndex: 1, lineHeight: 10, rise: 2);
    expect(a, greaterThan(b));
  });
}