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

  test('KEY jargon hidden until party max level; KEY is sixth hub tab after MORE', () {
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
        MenuRoute.gold,
        MenuRoute.shop,
        MenuRoute.essence,
        MenuRoute.more,
        MenuRoute.key,
      ]),
    );
  });

  test('fresh hub tabs are GEAR MORE; GOLD SHOP ESSENCE unlock later', () {
    final early = GameLogic.createInitialState(now: now);
    expect(MenuTabs.showGold(early), isFalse);
    expect(MenuTabs.showCamp(early), isFalse);
    expect(MenuTabs.showShop(early), isFalse);
    expect(
      MenuRouter.visibleHubTabs(early),
      equals(const [
        MenuRoute.gear,
        MenuRoute.more,
      ]),
    );
    expect(
      MenuRouter.visibleMoreMetaRows(early),
      isEmpty,
    );
    expect(MenuTabs.showQuests(early), isFalse);

    final afterFloor = early.copyWith(highestFloorCleared: 1);
    expect(MenuTabs.showGold(afterFloor), isTrue);
    expect(MenuTabs.showShop(afterFloor), isFalse);
    expect(MenuTabs.showCamp(afterFloor), isFalse);
    expect(
      MenuRouter.visibleHubTabs(afterFloor),
      equals(const [
        MenuRoute.gear,
        MenuRoute.gold,
        MenuRoute.more,
      ]),
    );
    expect(MenuTabs.showQuests(afterFloor), isTrue);
    expect(
      MenuRouter.visibleMoreMetaRows(afterFloor),
      equals(const [MoreSection.quests]),
    );

    final afterBoss = early.copyWith(bossVictories: 1, highestFloorCleared: 1);
    expect(MenuTabs.showShop(afterBoss), isTrue);
    expect(MenuTabs.showCamp(afterBoss), isFalse);
    expect(
      MenuRouter.visibleHubTabs(afterBoss),
      equals(const [
        MenuRoute.gear,
        MenuRoute.gold,
        MenuRoute.shop,
        MenuRoute.more,
      ]),
    );

    final afterAscend = early.copyWith(ascensionLevel: 1, essence: 10);
    expect(MenuTabs.showCamp(afterAscend), isTrue);
    expect(MenuTabs.showShop(afterAscend), isTrue);
    expect(MenuTabs.showRelics(afterAscend), isTrue);
    expect(
      MenuRouter.visibleHubTabs(afterAscend),
      equals(const [
        MenuRoute.gear,
        MenuRoute.gold,
        MenuRoute.shop,
        MenuRoute.essence,
        MenuRoute.more,
      ]),
    );
    expect(
      MenuRouter.visibleMoreMetaRows(afterAscend),
      equals(const [
        MoreSection.quests,
        MoreSection.craft,
      ]),
    );
    expect(
      MenuRouter.visibleEssencePanels(afterAscend),
      containsAll([
        EssencePanel.tracks,
        EssencePanel.keep,
        EssencePanel.relics,
      ]),
    );
  });

  test('dungeon tabs match hub gating on a fresh save', () {
    final s = GameLogic.createInitialState(now: now);
    expect(
      MenuRouter.visibleDungeonTabs(s),
      equals(const [
        MenuRoute.gear,
        MenuRoute.more,
      ]),
    );
    final graph = DestinationGraph.dungeon(s);
    expect(graph.destinations, MenuRouter.visibleDungeonTabs(s));
  });

  test('hub and dungeon share the same gated tabs; KEY / LEAVE is extra', () {
    final early = GameLogic.createInitialState(now: now);
    expect(
      MenuRouter.visibleHubTabs(early),
      equals(MenuRouter.visibleDungeonTabs(early)),
    );

    final endgame = early.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      highestDungeonCleared: 14,
      heroRoster: [
        for (final h in early.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    final hub = MenuRouter.visibleHubTabs(endgame);
    final dungeon = MenuRouter.visibleDungeonTabs(endgame);
    expect(hub.take(5), equals(dungeon));
    expect(hub.last, MenuRoute.key);
  });

  test('open sheets expose a short English job hint', () {
    final router = MenuRouter();
    expect(router.jobHint, isEmpty);
    router.open(MenuRoute.gold);
    expect(router.jobHint, contains('gold'));
    router.open(MenuRoute.gear, gear: GearPanel.bag);
    expect(router.jobHint.toLowerCase(), contains('loot'));
    router.open(MenuRoute.more, more: MoreSection.quests);
    expect(router.jobHint.toLowerCase(), contains('daily'));
    router.open(MenuRoute.shop);
    expect(router.jobHint.toLowerCase(), contains('boost'));
    expect(router.jobHint.toLowerCase(), contains('ad-free'));
    router.open(MenuRoute.gold, gold: GoldPanel.market);
    expect(router.jobHint.toLowerCase(), contains('flask'));
    router.open(MenuRoute.essence, essence: EssencePanel.relics);
    expect(router.jobHint.toLowerCase(), contains('aura'));
  });
}
