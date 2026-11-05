import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';

void main() {
  test('a free CAMP ad level does not spend essence and caps at 3 a day', () {
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
    for (var i = 0; i < 3; i++) {
      state = GameLogic.grantCampAdLevel(state, now: now);
    }
    expect(levels(state), 3);
    expect(state.essence, 40);
    expect(GameLogic.campAdClaimsToday(state, now: now), 3);

    final blocked = GameLogic.grantCampAdLevel(state, now: now);
    expect(levels(blocked), 3);

    final tomorrow = GameLogic.grantCampAdLevel(
      state,
      now: now.add(const Duration(days: 1)),
    );
    expect(levels(tomorrow), 4);
    expect(
      GameLogic.campAdClaimsToday(
        tomorrow,
        now: now.add(const Duration(days: 1)),
      ),
      1,
    );
  });
}
