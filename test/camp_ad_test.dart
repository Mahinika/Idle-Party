import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';

void main() {
  test('a free CAMP ad level does not spend essence and caps at 5 a day', () {
    final now = DateTime.utc(2026, 11, 5, 12);
    final start = GameLogic.createInitialState(now: now).copyWith(
      essence: 40,
      ascensionLevel: 1,
    );
    expect(start.essence, 40);

    int levels(GameState s) =>
        s.sanctuaryGoldLevel +
        s.sanctuaryPowerLevel +
        s.sanctuaryVitalityLevel +
        s.sanctuaryDefenseLevel +
        s.metaDepth.sanctuaryXpLevel;

    var state = start;
    for (var i = 0; i < GameLogic.campAdDailyCap; i++) {
      state = GameLogic.grantCampAdLevel(state, now: now);
    }
    expect(GameLogic.campAdDailyCap, 5);
    expect(levels(state), 5);
    expect(state.essence, 40);
    expect(GameLogic.campAdClaimsToday(state, now: now), 5);

    final blocked = GameLogic.grantCampAdLevel(state, now: now);
    expect(levels(blocked), 5);

    final tomorrow = GameLogic.grantCampAdLevel(
      state,
      now: now.add(const Duration(days: 1)),
    );
    expect(levels(tomorrow), 6);
    expect(
      GameLogic.campAdClaimsToday(
        tomorrow,
        now: now.add(const Duration(days: 1)),
      ),
      1,
    );
  });
}
