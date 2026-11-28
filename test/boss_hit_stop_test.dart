import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/boss_hit_stop.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('hit-stop is 75 ms and skips 2x, 4x, and reduce-motion', () {
    expect(BossHitStop.seconds, inInclusiveRange(0.06, 0.09));
    expect(
      BossHitStop.allow(
        pace: 1,
        debugScale: 1,
        vfx: VfxQuality.full,
        steps: 1,
      ),
      isTrue,
    );
    expect(
      BossHitStop.allow(
        pace: 2,
        debugScale: 1,
        vfx: VfxQuality.full,
        steps: 1,
      ),
      isFalse,
    );
    expect(
      BossHitStop.allow(
        pace: 1,
        debugScale: 4,
        vfx: VfxQuality.full,
        steps: 1,
      ),
      isFalse,
    );
    expect(
      BossHitStop.allow(
        pace: 1,
        debugScale: 1,
        vfx: VfxQuality.minimal,
        steps: 1,
      ),
      isFalse,
    );
  });

  test('hit-stop freezes combat and still moves the fountain', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 11, 28));
    final world = SpatialCombat.build(state);
    final lootBefore = world.groundLoot.length;
    final elapsed = world.combatElapsed;
    final heroX = world.heroes.first.x;
    SpatialCombat.spawnBossLootFountain(world, 4, 4);
    final spark = world.bursts.last;
    final startY = spark.y;
    world.hitStopSec = BossHitStop.seconds;

    final result = SpatialCombat.step(world, state, dt: 0.05);

    expect(result.goldFromKills, 0);
    expect(world.combatElapsed, elapsed);
    expect(world.heroes.first.x, heroX);
    expect(world.groundLoot.length, lootBefore);
    expect(world.hitStopSec, closeTo(0.025, 0.0001));
    expect(spark.y, isNot(closeTo(startY, 0.0001)));
  });
}
