import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/town_access.dart';
import 'package:idle_party/models/town_building.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/kenney_button.dart';
import 'package:idle_party/ui/meta/notify_opt_in.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/home_prompts.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';

void main() {
  final now = DateTime(2026, 11, 8);

  GameState quietTown({
    int boss = 0,
    int floor = 0,
    int al = 0,
    bool inDungeon = false,
  }) {
    final base = GameLogic.createInitialState(now: now);
    return base.copyWith(
      inDungeon: inDungeon,
      homeLayout: HomeLayout.home,
      bossVictories: boss,
      highestFloorCleared: floor,
      ascensionLevel: al,
      seenChangelogVersion: MetaSystems.currentVersion,
      vfxQuality: VfxQuality.minimal,
      seenTips: const [
        'first_run',
        'discord_thanks',
        'hub_enter',
        'godhand',
        'farm_push',
        'kit_abilities',
        'bag',
        'forge',
        'sanctuary',
      ],
      metaDepth: base.metaDepth.copyWith(
        reviewPrompted: true,
        notifyPrompted: true,
        notifyOptIn: true,
      ),
    );
  }

  GameState vaultReady() {
    final stamp = DateTime.now().toUtc();
    var state = quietTown(boss: 1, floor: 2);
    state = GameLogic.ensureWeeklyContract(state, now: stamp);
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
  }

  Future<void> pumpShell(
    WidgetTester tester,
    GameDirector director,
    MenuRouter router, {
    Size size = const Size(360, 780),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    director.debugHoldSave(director.state);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: director,
          builder: (context, _) => HomeShell(
            director: director,
            router: router,
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapBuilding(WidgetTester tester, TownBuildingId id) async {
    await tester.tap(find.byKey(ValueKey('town-${id.name}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('HomeShell town is TownViewport, not the gold dock',
      (tester) async {
    final director = GameDirector.preview(initialState: quietTown());
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    expect(find.byType(TownViewport), findsOneWidget);
    expect(find.text('FORGE'), findsOneWidget);
    expect(find.text('MARKET'), findsOneWidget);
    expect(find.text('INN'), findsOneWidget);
    expect(find.text('GUILD'), findsOneWidget);
    expect(find.text('VAULT'), findsOneWidget);
    expect(find.text('FORGE opens after the first boss (F2).'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first-game buildings stay locked and can reopen', (tester) async {
    final director = GameDirector.preview(initialState: quietTown());
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);

    await tapBuilding(tester, TownBuildingId.forge);
    expect(router.isOpen, isFalse);
    expect(find.text('CRAFT opens after the first boss.'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    expect(find.text('CRAFT opens after the first boss.'), findsNothing);
    await tapBuilding(tester, TownBuildingId.forge);
    expect(find.text('CRAFT opens after the first boss.'), findsOneWidget);

    await tester.tap(find.text('CLOSE'));
    await tester.pump();
    await tapBuilding(tester, TownBuildingId.inn);
    expect(router.route, MenuRoute.none);
    expect(
      find.textContaining('Party swaps unlock at first Ascend'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FORGE CRAFT opens, dismisses, reopens on HomeShell',
      (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    await tapBuilding(tester, TownBuildingId.forge);
    expect(router.route, MenuRoute.more);
    expect(router.moreSection, MoreSection.craft);
    expect(find.textContaining('Tap a hero, pick a slot'), findsOneWidget);
    await tester.tap(find.text('FIGHT'));
    await tester.pump();
    expect(router.isOpen, isFalse);
    await tapBuilding(tester, TownBuildingId.forge);
    expect(router.moreSection, MoreSection.craft);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MARKET listings open as GoldDock, not the fight gold sheet',
      (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    await tapBuilding(tester, TownBuildingId.market);
    expect(router.route, MenuRoute.gold);
    expect(router.goldPanel, GoldPanel.market);
    expect(find.text('MARKET'), findsWidgets);
    await tester.tap(find.text('CLOSE').first);
    await tester.pump();
    expect(router.isOpen, isFalse);
    await tapBuilding(tester, TownBuildingId.market);
    expect(router.route, MenuRoute.gold);
    expect(tester.takeException(), isNull);
  });

  testWidgets('INN ROSTER opens after Ascend; HEROES still dismisses',
      (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2, al: 1),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    expect(TownAccess.innOpen(director.state), isTrue);
    await tapBuilding(tester, TownBuildingId.inn);
    expect(router.route, MenuRoute.gear);
    expect(router.gearPanel, GearPanel.roster);
    expect(find.textContaining('Pick up to'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close HEROES'));
    await tester.pump();
    expect(router.isOpen, isFalse);
    await tapBuilding(tester, TownBuildingId.inn);
    expect(router.gearPanel, GearPanel.roster);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GUILD quests open and dismiss on HomeShell', (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    await tapBuilding(tester, TownBuildingId.guild);
    expect(router.route, MenuRoute.more);
    expect(router.moreSection, MoreSection.quests);
    expect(find.textContaining('Claim 3 in a row'), findsOneWidget);
    await tester.tap(find.text('CLOSE').first);
    await tester.pump();
    expect(router.isOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VAULT claim uses existing command with no duplicate credit',
      (tester) async {
    final director = GameDirector.preview(initialState: vaultReady());
    director.debugHoldSave(director.state);
    final router = MenuRouter();
    addTearDown(router.dispose);
    expect(TownAccess.vaultClaimable(director.state), isTrue);
    final essenceBefore = director.state.essence;
    await pumpShell(tester, director, router);
    await tapBuilding(tester, TownBuildingId.vault);
    expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
    final essenceAfter = director.state.essence;
    expect(essenceAfter, greaterThanOrEqualTo(essenceBefore));
    await tapBuilding(tester, TownBuildingId.vault);
    expect(director.state.essence, essenceAfter);
    expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
    expect(find.text('Vault claimed today.'), findsOneWidget);
    director.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub ENTER then leaveDungeon returns to town', (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2),
    );
    final router = MenuRouter();
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    expect(find.byType(TownViewport), findsOneWidget);
    expect(find.widgetWithText(GameButton, 'ENTER'), findsOneWidget);
    director.enterDungeon(dungeonId: 'sandy');
    await tester.pump();
    expect(director.state.inDungeon, isTrue);
    expect(find.byType(TownViewport), findsNothing);
    director.leaveDungeon();
    await tester.pump();
    expect(director.state.inDungeon, isFalse);
    expect(find.byType(TownViewport), findsOneWidget);
    expect(find.text('FORGE'), findsOneWidget);
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Welcome Back still covers town', (tester) async {
    final state = quietTown(boss: 1, floor: 2);
    final director = GameDirector.preview(initialState: state);
    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: state,
        secondsApplied: 3600,
        goldGained: 40,
        essenceGained: 2,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
        secondsAway: 3600,
      ),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.byType(TownViewport), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WATCH and WISP are not hub chips; SCROLLS still opens ads',
      (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    expect(find.text('WATCH'), findsNothing);
    expect(find.text('WISP'), findsNothing);
    expect(find.text('POUCH'), findsNothing);
    expect(find.text('SCROLLS'), findsWidgets);
    final railIds = FightSeamRails.visibleEntries(director.state, director)
        .map((e) => e.id)
        .toSet();
    expect(railIds.contains('watch'), isFalse);
    expect(railIds.contains('wisp'), isFalse);
    expect(railIds, contains('scrolls'));
    await tester.tap(find.text('SCROLLS').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ad Tickets'), findsOneWidget);
    expect(
      find.textContaining('Watch for a ticket').evaluate().isNotEmpty ||
          find.textContaining('WATCH AD').evaluate().isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  test('HomeCatalog.of hides duplicate ads chips but entries keep them', () {
    final visible = {
      ...HomeCatalog.of(HomePlace.leftRail),
      ...HomeCatalog.of(HomePlace.rightRail),
      ...HomeCatalog.of(HomePlace.menuGrid),
    }.map((e) => e.id).toSet();
    expect(visible.contains('watch'), isFalse);
    expect(visible.contains('wisp'), isFalse);
    expect(visible.contains('menu_watch'), isFalse);
    expect(visible.contains('menu_wisp'), isFalse);
    expect(visible, contains('scrolls'));
    expect(visible.contains('menu_scrolls'), isFalse);
    expect(visible.contains('menu_quests'), isFalse);
    final defined = HomeCatalog.entries.map((e) => e.id).toSet();
    expect(defined, containsAll(['watch', 'wisp', 'menu_watch', 'menu_wisp']));
  });

  testWidgets('in-dungeon GOLD still intercepts to the fight dock',
      (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(
        quietTown(boss: 1, floor: 2, inDungeon: false),
      ),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    expect(find.byType(TownViewport), findsNothing);
    router.open(MenuRoute.gold, gold: GoldPanel.market);
    await tester.pump();
    expect(router.route, MenuRoute.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification host stays ready on town', (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await pumpShell(tester, director, router);
    expect(find.byType(HomePromptHost), findsOneWidget);
    expect(HomePrompts.calm(director), isTrue);
    expect(NotifyOptInOverlay.shouldOffer(director), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('town hub fits 1.45, raw 2, and 360x640', (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2, al: 1),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);

    Future<void> check(Size size, {double scale = 1}) async {
      await pumpShell(tester, director, router, size: size, scale: scale);
      expect(find.byType(TownViewport), findsOneWidget);
      expect(find.text('ENTER'), findsOneWidget);
      expect(find.text('HEROES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await check(const Size(360, 780), scale: 1.45);
    await check(const Size(360, 780), scale: 2);
    await check(const Size(360, 640));
  });
}
