import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';

/// Next Ascend should feel like a clear step up, not a flat stipend.
void main() {
  final now = DateTime.utc(2026, 10, 6, 12);

  int shownReward(int newLevel) =>
      GameLogic.ascendEssenceReward(newLevel) +
      MetaSystems.ascendMilestoneReward(newLevel - 1, newLevel);

  test('second Ascend pays 50 to 200 percent more than the first shows', () {
    // The confirm dialog shows stipend plus milestone, not the one-time
    // achievement. 10 then 30 is triple, the top of the band.
    expect(shownReward(1), 10);
    expect(shownReward(2), 30);
    expect(shownReward(2) / shownReward(1), inInclusiveRange(1.5, 3.0));

    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(bossVictories: 9);
    final before = state.essence;
    state = GameLogic.ascend(state, now: now);
    final firstGain = state.essence - before;
    expect(state.ascensionLevel, 1);
    expect(firstGain, greaterThan(shownReward(1)));

    state = state.copyWith(bossVictories: 9);
    final mid = state.essence;
    state = GameLogic.ascend(state, now: now);
    final secondGain = state.essence - mid;
    expect(state.ascensionLevel, 2);
    expect(secondGain, greaterThanOrEqualTo(shownReward(2)));
    expect(secondGain, greaterThan(firstGain));
  });

  test('every later Ascend shows at least half again the one before', () {
    int shown(int level) =>
        GameLogic.ascendEssenceReward(level) +
        MetaSystems.ascendMilestoneReward(level - 1, level);

    expect(shown(3), 58);
    expect(shown(4), 87);
    expect(shown(20), 57653);
    for (var level = 1; level < GameLogic.maxAscensionLevel; level++) {
      final ratio = shown(level + 1) / shown(level);
      expect(ratio, inInclusiveRange(1.5, 3.0), reason: 'AL$level → AL${level + 1}');
      expect(GameLogic.ascendEssenceReward(level), greaterThan(0));
    }
  });
}
