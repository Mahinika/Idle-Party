import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';

/// Next Ascend should feel like a clear step up, not a flat stipend.
void main() {
  final now = DateTime.utc(2026, 10, 6, 12);

  test('second Ascend pays about 50 to 200 percent more than the first', () {
    // The repeating stipend (not the one-time AL1 milestone) is the step
    // the player feels on every reset. 10/7 is about +43%, inside the band.
    final firstStipend = GameLogic.ascendEssenceReward(1);
    final secondStipend = GameLogic.ascendEssenceReward(2);
    expect(secondStipend / firstStipend, inInclusiveRange(1.4, 3.0));

    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(bossVictories: 9);
    final before = state.essence;
    state = GameLogic.ascend(state, now: now);
    final firstGain = state.essence - before;
    expect(state.ascensionLevel, 1);
    expect(firstGain, greaterThanOrEqualTo(firstStipend));

    state = state.copyWith(bossVictories: 9);
    final mid = state.essence;
    state = GameLogic.ascend(state, now: now);
    final secondGain = state.essence - mid;
    expect(state.ascensionLevel, 2);
    expect(secondGain, greaterThanOrEqualTo(secondStipend));
    expect(secondGain, greaterThan(firstGain - 4));
  });
}
