import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/hub_screen.dart';
import 'package:idle_party/ui/hub/hub_powerups.dart';
import 'package:idle_party/ui/hub/hub_today_card.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/jobs_overlay.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
import 'package:idle_party/ui/shell/settings_overlay.dart';
import 'package:idle_party/ui/shell/home/home_menu_grid.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/menu_surface.dart';
import 'package:idle_party/ui/shell/overlay_scaffold.dart';
import 'package:idle_party/ui/shell/play_shell.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';
import 'package:idle_party/ui/theme.dart';
import 'shell_golden_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  testWidgets('hub screen golden A56', (tester) async {
    bindA56View(tester);
    final director = hubGoldenDirector();
    final router = MenuRouter();
    addTearDown(router.dispose);
    addTearDown(director.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      shellGoldenScaffold(
        RepaintBoundary(
          key: key,
          child: HubScreen(
            director: director,
            router: router,
            onEnterDungeon: (_) {},
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 800);
    await expectShellGolden(tester, find.byKey(key), 'hub_a56.png');
  });

  testWidgets('hub urgent row golden A56', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: shellGoldenMedia,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: GameTheme.ink,
            body: Padding(
              padding: ShellLayout.sheetPadding,
              child: HubUrgentRow(
                claimable: 2,
                canAscend: true,
                ascendLabel: 'ASCEND  +42e',
                onContracts: () {},
                onAscend: () {},
                dailyClaimed: false,
                onDaily: () {},
                weeklyReady: true,
                weeklyProgress: 0,
                weeklyClaimed: false,
                weeklyBestTimedKey: 0,
                vaultClaimEssence: 12,
                onClaimDailyVault: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await expectShellGolden(tester, find.byType(Scaffold), 'hub_urgent_a56.png');
  });

  testWidgets('hub SCROLLS row golden A56', (tester) async {
    bindA56View(tester);
    final director = scrollsGoldenDirector();
    addTearDown(director.dispose);
    await tester.pumpWidget(
      shellGoldenScaffold(
        Padding(
          padding: ShellLayout.sheetPadding,
          child: HubPowerupsFab(
            state: director.state,
            onOpen: () {},
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await expectShellGolden(tester, find.byType(Scaffold), 'hub_scrolls_a56.png');
  });

  testWidgets('home shell SPLIT golden A56', (tester) async {
    bindA56View(tester);
    final director = await homeShellFightGoldenDirector();
    var live = true;
    addTearDown(() {
      if (live) director.dispose();
    });
    final router = MenuRouter();
    addTearDown(router.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: shellGoldenScaffold(
          HomeShell(director: director, router: router, onLeave: () {}),
        ),
      ),
    );
    await waitForFightChrome(tester, director);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    await expectShellGolden(tester, find.byKey(key), 'home_shell_split_a56.png');
    director.dispose();
    live = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('home shell FULL golden A56', (tester) async {
    bindA56View(tester);
    final director = await homeShellFullFightGoldenDirector();
    var live = true;
    addTearDown(() {
      if (live) director.dispose();
    });
    final router = MenuRouter();
    addTearDown(router.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: shellGoldenScaffold(
          HomeShell(director: director, router: router, onLeave: () {}),
        ),
      ),
    );
    await waitForFightChrome(tester, director);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
    await expectShellGolden(tester, find.byKey(key), 'home_shell_full_a56.png');
    director.dispose();
    live = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('home MENU grid golden A56', (tester) async {
    bindA56View(tester);
    final director = homeShellGoldenDirector();
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      shellGoldenScaffold(
        SizedBox(
          height: 640,
          child: HomeMenuGrid(director: director, router: router),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 500);
    await expectShellGolden(
      tester,
      find.byType(HomeMenuGrid),
      'home_menu_grid_a56.png',
    );
  });

  testWidgets('home compact SHOP golden A56', (tester) async {
    bindA56View(tester);
    final director = homeShellGoldenDirector();
    addTearDown(director.dispose);
    ShopDock.goldenTestPriceLabel = '\$4.99';
    addTearDown(() => ShopDock.goldenTestPriceLabel = '');
    final router = MenuRouter();
    addTearDown(router.dispose);
    router.open(MenuRoute.shop);
    await tester.pumpWidget(
      shellGoldenScaffold(
        SizedBox(
          height: 420,
          child: Stack(
            children: [
              MenuSurface(director: director, router: router, home: true),
            ],
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 500);
    expect(find.textContaining('Waiting for Play billing'), findsNothing);
    await expectShellGolden(
      tester,
      find.byType(OverlayScrim),
      'home_shop_compact_a56.png',
    );
  });

  testWidgets('GOLD sheet golden A56', (tester) async {
    bindA56View(tester);
    final director = goldSheetGoldenDirector();
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    router.open(MenuRoute.gold);
    await tester.pumpWidget(
      shellGoldenScaffold(
        SizedBox(
          height: 720,
          child: Stack(
            children: [
              MenuSurface(director: director, router: router),
            ],
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 600);
    await expectShellGolden(
      tester,
      find.byType(OverlayScrim),
      'gold_a56.png',
    );
  });

  testWidgets('FORGE inline SPLIT golden A56', (tester) async {
    bindA56View(tester);
    final director = forgeInlineGoldenDirector();
    addTearDown(director.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      shellGoldenScaffold(
        RepaintBoundary(
          key: key,
          child: SizedBox(
            height: 280,
            child: ForgeOverlay(
              director: director,
              inlineUnderFight: true,
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await expectShellGolden(
      tester,
      find.byKey(key),
      'forge_inline_a56.png',
    );
  });

  testWidgets('GOLD MARKET tab golden A56', (tester) async {
    bindA56View(tester);
    final director = marketGoldenDirector();
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    router.open(MenuRoute.gold);
    router.goldPanel = GoldPanel.market;
    final key = GlobalKey();
    await tester.pumpWidget(
      shellGoldenScaffold(
        RepaintBoundary(
          key: key,
          child: SizedBox(
            height: 720,
            child: Stack(
              children: [
                MenuSurface(director: director, router: router),
              ],
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 600);
    await expectShellGolden(tester, find.byKey(key), 'market_a56.png');
  });

  testWidgets('QUESTS overlay golden A56', (tester) async {
    bindA56View(tester);
    final director = questsGoldenDirector();
    addTearDown(director.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      shellGoldenScaffold(
        RepaintBoundary(
          key: key,
          child: SizedBox(
            height: 680,
            child: SingleChildScrollView(
              child: JobsOverlay(director: director),
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await expectShellGolden(tester, find.byKey(key), 'quests_a56.png');
  });

  testWidgets('SETTINGS overlay golden A56', (tester) async {
    bindA56View(tester);
    final director = settingsGoldenDirector();
    addTearDown(director.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      shellGoldenScaffold(
        RepaintBoundary(
          key: key,
          child: SizedBox(
            height: 680,
            child: SettingsOverlay(
              director: director,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await expectShellGolden(tester, find.byKey(key), 'settings_a56.png');
  });

  testWidgets('ESSENCE sheet golden A56', (tester) async {
    bindA56View(tester);
    final director = essenceSheetGoldenDirector();
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    router.open(MenuRoute.essence);
    await tester.pumpWidget(
      shellGoldenScaffold(
        SizedBox(
          height: 720,
          child: Stack(
            children: [
              MenuSurface(director: director, router: router),
            ],
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 600);
    await expectShellGolden(
      tester,
      find.byType(OverlayScrim),
      'essence_a56.png',
    );
  });

  testWidgets('GEAR sheet golden A56', (tester) async {
    bindA56View(tester);
    final director = gearGoldenDirector();
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    router.open(MenuRoute.gear);
    await tester.pumpWidget(
      shellGoldenScaffold(
        SizedBox(
          height: 720,
          child: Stack(
            children: [
              MenuSurface(director: director, router: router),
            ],
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 600);
    await expectShellGolden(
      tester,
      find.byType(OverlayScrim),
      'gear_a56.png',
    );
  });

  testWidgets('SCROLLS sheet golden A56', (tester) async {
    bindA56View(tester);
    final director = scrollsGoldenDirector();
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: shellGoldenMedia,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SizedBox(
            width: 360,
            height: 680,
            child: scrollsSheetForTest(director: director),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester, ms: 500);
    await expectShellGolden(
      tester,
      find.text('SCROLLS'),
      'scrolls_a56.png',
    );
  });

  testWidgets('SHOP featured is not duplicated in catalog', (tester) async {
    bindA56View(tester);
    final director = shopGoldenDirector();
    addTearDown(director.dispose);
    ShopDock.goldenTestPriceLabel = '\$4.99';
    addTearDown(() => ShopDock.goldenTestPriceLabel = '');
    await tester.pumpWidget(
      MediaQuery(
        data: shellGoldenMedia,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 720,
              child: ShopDock(director: director),
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    expect(
      find.text("Prospector's Bundle"),
      findsOneWidget,
    );
  });

  testWidgets('SHOP sheet golden A56', (tester) async {
    bindA56View(tester);
    final director = shopGoldenDirector();
    addTearDown(director.dispose);
    ShopDock.goldenTestPriceLabel = '\$4.99';
    addTearDown(() => ShopDock.goldenTestPriceLabel = '');
    await tester.pumpWidget(
      MediaQuery(
        data: shellGoldenMedia,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: GameTheme.ink,
            body: SizedBox(
              height: 720,
              child: ShopDock(director: director),
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await expectShellGolden(tester, find.byType(ShopDock), 'shop_a56.png');
  });

  testWidgets('Welcome Back dialog golden A56', (tester) async {
    bindA56View(tester);
    final director = hubGoldenDirector();
    addTearDown(director.dispose);
    await showWelcomeBackGolden(tester, director);
    await expectShellGolden(
      tester,
      find.text('WELCOME BACK'),
      'welcome_back_a56.png',
    );
  });

  testWidgets('fight shell golden A56', (tester) async {
    bindA56View(tester);
    final director = await fightGoldenDirector();
    var directorLive = true;
    addTearDown(() {
      if (directorLive) director.dispose();
    });
    final router = MenuRouter();
    addTearDown(router.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: shellGoldenScaffold(
          PlayShell(director: director, router: router),
        ),
      ),
    );
    await waitForFightChrome(tester, director);
    expect(tester.takeException(), isNull);
    await expectShellGolden(tester, find.byKey(key), 'fight_a56.png');
    director.dispose();
    directorLive = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });
}
