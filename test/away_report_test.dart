import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';

void main() {
  OfflineProgressResult sample({
    int rooms = 2,
    int kills = 14,
    int levels = 1,
    String best = 'Ash Blade',
    bool wipe = false,
    int applied = 8 * 3600,
    int away = 10 * 3600,
    bool dungeon = true,
  }) {
    final state = GameLogic.createInitialState(now: DateTime(2026, 10, 13));
    return OfflineProgressResult(
      state: state,
      secondsApplied: applied,
      secondsAway: away,
      goldGained: 20,
      essenceGained: 0,
      roomsCleared: rooms,
      highestFloorDelta: 0,
      bossDelta: 0,
      levelsGained: levels,
      kills: kills,
      bestDrop: best,
      stoppedOnWipe: wipe,
      wasInDungeon: dungeon,
    );
  }

  test('away report names floors, kills, levels, best drop, and the cap', () {
    final line = sample().awayReport;
    expect(line, contains('2 floors'));
    expect(line, contains('14 kills'));
    expect(line, contains('1 level'));
    expect(line, contains('Best Ash Blade'));
    expect(line, contains('Stopped at the 8h fight cap'));
  });

  test('a wipe stop wins over the fight cap', () {
    expect(sample(wipe: true).stopReason, 'Stopped on a wipe');
  });
}
