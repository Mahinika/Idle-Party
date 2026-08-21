import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/offline_sim.dart';
import 'package:idle_party/models/dungeon_mode.dart';

import 'helpers/seeded.dart';

/// AFK catch-up is credited from a time budget, never from how fast the phone
/// runs it. Slicing the walk so boot can paint must not change a single coin.
void main() {
  test('sliced AFK catch-up lands on the same numbers as one long walk', () {
    final farm = GameLogic.setDungeonMode(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 8, 16)),
        dungeonId: 'sandy',
      ),
      DungeonMode.farm,
    );

    seedAll(4242);
    final oneShot = GameLogic.simulateSpatialOffline(farm, 45 * 60);

    seedAll(4242);
    final sliced = OfflineSim(farm, 45 * 60);
    var slices = 0;
    while (!sliced.done) {
      // Deliberately ragged slice sizes: a pause must never shift the math.
      sliced.runSlice(7 + (slices % 5) * 13);
      slices++;
      expect(slices, lessThan(20000), reason: 'slicing must terminate');
    }

    expect(sliced.roomsCleared, oneShot.roomsCleared);
    expect(sliced.state.gold, oneShot.state.gold);
    expect(sliced.state.essence, oneShot.state.essence);
    expect(sliced.state.highestFloorCleared, oneShot.state.highestFloorCleared);
    expect(sliced.state.bossVictories, oneShot.state.bossVictories);
    expect(sliced.state.gearStash.length, oneShot.state.gearStash.length);
    expect(
      sliced.state.metaDepth.lifetimeAbilityCasts,
      oneShot.state.metaDepth.lifetimeAbilityCasts,
    );
    expect(oneShot.roomsCleared, greaterThan(0), reason: 'sim must do work');
  });

  test('async offline credit matches the sync path', () async {
    final farm = GameLogic.setDungeonMode(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 8, 16)),
        dungeonId: 'sandy',
      ),
      DungeonMode.farm,
    );

    seedAll(99);
    final sync = GameLogic.applyOfflineProgress(
      farm,
      const Duration(minutes: 20),
    );

    seedAll(99);
    final async = await GameLogic.applyOfflineProgressAsync(
      farm,
      const Duration(minutes: 20),
    );

    expect(async.goldGained, sync.goldGained);
    expect(async.roomsCleared, sync.roomsCleared);
    expect(async.secondsApplied, sync.secondsApplied);
    expect(async.highestFloorDelta, sync.highestFloorDelta);
    expect(async.levelsGained, sync.levelsGained);
    expect(async.state.offlineSecondsRecovered, 20 * 60);
  });
}
