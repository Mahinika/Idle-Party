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

  test('KEY jargon hidden until party Lv60', () {
    final early = GameLogic.createInitialState(now: now);
    expect(GameLogic.showKeystoneJargon(early), isFalse);
    expect(MenuTabs.showKey(early), isFalse);

    final mid = early.copyWith(
      ascensionLevel: 2,
      highestDungeonCleared: 0,
    );
    expect(GameLogic.showKeystoneJargon(mid), isFalse);
    expect(MenuTabs.showKey(mid), isFalse);

    final alOnly = early.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      highestDungeonCleared: 14,
    );
    expect(GameLogic.showKeystoneJargon(alOnly), isFalse);
    expect(MenuTabs.showKey(alOnly), isFalse);

    final endgame = alOnly.copyWith(
      heroRoster: [
        for (final h in alOnly.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    expect(GameLogic.showKeystoneJargon(endgame), isTrue);
    expect(MenuTabs.showKey(endgame), isTrue);
  });

  test('fresh POWER is Gold upgrades + Buy supplies only', () {
    final early = GameLogic.createInitialState(now: now);
    expect(MenuTabs.showCamp(early), isFalse);
    expect(MenuTabs.showShop(early), isFalse);
    expect(
      MenuRouter.visiblePowerTabs(early),
      equals(const [PowerTab.forge, PowerTab.market]),
    );

    final afterAscend = early.copyWith(ascensionLevel: 1, essence: 10);
    expect(MenuTabs.showCamp(afterAscend), isTrue);
    expect(
      MenuRouter.visiblePowerTabs(afterAscend),
      equals(const [
        PowerTab.forge,
        PowerTab.market,
        PowerTab.camp,
        PowerTab.shop,
      ]),
    );
  });
}
