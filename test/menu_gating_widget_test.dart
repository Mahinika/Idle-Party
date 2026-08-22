import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22);

  test('AL20 veteran sees GEAR BAG MERGE ROSTER only', () {
    final veteran = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 20,
      highestDungeonCleared: 14,
    );
    expect(MenuTabs.showMerge(veteran), isTrue);
    expect(MenuTabs.showRoster(veteran), isTrue);
    expect(
      MenuRouter.visiblePartyTabs(veteran),
      equals(const [
        PartyTab.gear,
        PartyTab.bag,
        PartyTab.merge,
        PartyTab.roster,
      ]),
    );
  });

  test('KEY jargon hidden before AL2 and King\'s Fort', () {
    final early = GameLogic.createInitialState(now: now);
    expect(GameLogic.showKeystoneJargon(early), isFalse);
    expect(MenuTabs.showKey(early), isFalse);

    final mid = early.copyWith(
      ascensionLevel: 2,
      highestDungeonCleared: 0,
    );
    expect(GameLogic.showKeystoneJargon(mid), isTrue);
    expect(MenuTabs.showKey(mid), isTrue);
  });
}
