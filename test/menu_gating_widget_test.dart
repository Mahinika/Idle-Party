import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22);

  test('AL20 veteran sees GEAR BAG MERGE ROSTER panels', () {
    final veteran = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 20,
      highestDungeonCleared: 14,
    );
    expect(MenuTabs.showMerge(veteran), isTrue);
    expect(MenuTabs.showRoster(veteran), isTrue);
    expect(
      MenuRouter.visibleGearPanels(veteran),
      equals(const [
        GearPanel.gear,
        GearPanel.bag,
        GearPanel.merge,
        GearPanel.roster,
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
    expect(
      MenuRouter.visibleHubTabs(endgame),
      equals(const [
        MenuRoute.gear,
        MenuRoute.power,
        MenuRoute.key,
        MenuRoute.quests,
        MenuRoute.more,
      ]),
    );
  });

  test('fresh POWER segments are Forge + Market only', () {
    final early = GameLogic.createInitialState(now: now);
    expect(MenuTabs.showCamp(early), isFalse);
    expect(MenuTabs.showShop(early), isFalse);
    expect(
      MenuRouter.visiblePowerSegments(early),
      equals(const [PowerSegment.forge, PowerSegment.market]),
    );
    expect(
      MenuRouter.visibleHubTabs(early),
      equals(const [
        MenuRoute.gear,
        MenuRoute.power,
        MenuRoute.quests,
        MenuRoute.more,
      ]),
    );

    final afterAscend = early.copyWith(ascensionLevel: 1, essence: 10);
    expect(MenuTabs.showCamp(afterAscend), isTrue);
    expect(
      MenuRouter.visiblePowerSegments(afterAscend),
      equals(const [
        PowerSegment.forge,
        PowerSegment.market,
        PowerSegment.camp,
      ]),
    );
  });

  test('dungeon tabs are GEAR POWER QUESTS only', () {
    final s = GameLogic.createInitialState(now: now);
    expect(
      MenuRouter.visibleDungeonTabs(s),
      equals(const [
        MenuRoute.gear,
        MenuRoute.power,
        MenuRoute.quests,
      ]),
    );
  });
}
