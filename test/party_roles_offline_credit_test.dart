import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';

/// Fresh isolate so [GameLogic.random] is not already consumed.
/// The 12h cap on this fixture is the fight-golden away result.
void main() {
  test('away credits stay on the previous 12h result', () async {
    final now = DateTime.utc(2026, 8, 22, 14);
    final base = GameLogic.createInitialState(now: now);
    final director = GameDirector.preview(
      initialState: base.copyWith(
        highestFloorCleared: 1,
        bossVictories: 1,
        seenChangelogVersion: MetaSystems.currentVersion,
        metaDepth: base.metaDepth.copyWith(
          lifetimeFloorClears: 1,
          reviewPrompted: true,
        ),
      ),
    );
    addTearDown(director.dispose);
    await director.boot();
    final s = director.offlineSummary;
    expect(s, isNotNull);
    expect(s!.goldGained, 7200);
    expect(s.essenceGained, 57);
    expect(s.highestFloorDelta, 4);
    expect(s.roomsCleared, 5);
    expect(s.bossDelta, 1);
    expect(s.levelsGained, 15);
    expect(s.kills, 61);
    expect(s.gearFinds, 28);
    expect(s.bestDrop, 'Runic Cloth Legguards of Power');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
