import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/nav_copy.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/coach_pulse.dart';
import 'package:idle_party/ui/shell/overlay_scaffold.dart';
import 'package:idle_party/ui/web_click_bridge.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/home_prompts.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';

void main() {
  test('nav copy renames places only on the home layout', () {
    const raw =
        'GOLD → FORGE and GEAR → BAG and MORE → INFO. ESSENCE → CAMP. the hub.';
    expect(NavCopy.playerText(raw, HomeLayout.classic), raw);
    final home = NavCopy.playerText(raw, HomeLayout.home);
    expect(home.contains('GOLD →'), isFalse);
    expect(home.contains('GEAR →'), isFalse);
    expect(home.contains('MORE →'), isFalse);
    expect(home.contains('ESSENCE → CAMP'), isFalse);
    expect(home.contains('the hub'), isFalse);
    expect(home.contains('FORGE under the fight'), isTrue);
    expect(home.contains('HEROES → BAG'), isTrue);
    expect(home.contains('MENU →'), isTrue);
    expect(home.contains('camp'), isTrue);
    expect(
      NavCopy.playerText('Hub gold fills for 24 hours.', HomeLayout.home),
      'Camp gold fills for 24 hours.',
    );
    expect(
      NavCopy.playerText('Hub gold fills for 24 hours.', HomeLayout.classic),
      'Hub gold fills for 24 hours.',
    );
  });

  test('SHOP blurb uses home place names on the fight shell', () {
    const classic = HomeLayout.classic;
    const home = HomeLayout.home;
    final early = ShopDock.convenienceLine(showEssence: false, layout: classic);
    expect(early.toLowerCase(), contains('hub'));
    expect(early.toUpperCase(), contains('GEAR'));
    final onHome = ShopDock.convenienceLine(showEssence: true, layout: home);
    expect(onHome.toLowerCase(), contains('fight rail'));
    expect(onHome.toUpperCase(), isNot(contains('HUB')));
    expect(onHome.toUpperCase(), contains('HEROES'));
    expect(onHome.toLowerCase(), contains('under the fight'));
  });

  test('guide text scrubbed for home has no old place names', () {
    for (final topic in GameGuides.topics) {
      final text = NavCopy.playerText(
        '${topic.title}\n${topic.body}',
        HomeLayout.home,
      );
      expect(text.contains('GOLD →'), isFalse, reason: topic.id);
      expect(text.contains('GEAR →'), isFalse, reason: topic.id);
      expect(text.contains('MORE →'), isFalse, reason: topic.id);
      expect(text.contains('ESSENCE → CAMP'), isFalse, reason: topic.id);
      expect(text.contains('the hub'), isFalse, reason: topic.id);
    }
  });

  test('home catalog ids are unique', () {
    final ids = HomeCatalog.entries.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('a boss banner is not a calm moment for cards', () {
    final director = GameDirector.preview();
    expect(HomePrompts.calm(director), isTrue);
  });

  testWidgets('home shell shows HEROES and FIGHT without overflow', (tester) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 3)),
    ).copyWith(homeLayout: HomeLayout.home, homePanelFull: true);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);

    Future<void> pumpSize(Size size, {double scale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            director: director,
            router: router,
            onLeave: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('HEROES'), findsOneWidget);
      expect(find.text('FIGHT'), findsOneWidget);
    }

    await pumpSize(const Size(360, 780));
    await pumpSize(const Size(360, 640));
    await pumpSize(const Size(430, 932));
    await pumpSize(const Size(360, 780), scale: 1.4);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    router.open(MenuRoute.gear);
    await tester.pump();
    expect(find.bySemanticsLabel('CLOSE'), findsWidgets);
    expect(find.bySemanticsLabel('Close HEROES'), findsWidgets);
    expect(tester.takeException(), isNull);

    router.open(MenuRoute.gold);
    await tester.pump();
    expect(router.route, MenuRoute.none);
    expect(director.uiPaused, isFalse);
  });

  testWidgets('MAP sheet uses scrim over fight in cave', (tester) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 3)),
    ).copyWith(homeLayout: HomeLayout.home, homePanelFull: true);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    router.open(MenuRoute.map);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          director: director,
          router: router,
          onLeave: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OverlayScrim), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BACK semantics matches visible label', (tester) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 3)),
    ).copyWith(homeLayout: HomeLayout.home);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    router.open(MenuRoute.gear);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          director: director,
          router: router,
          onLeave: () {},
        ),
      ),
    );
    await tester.pump();
    router.pushSub();
    await tester.pump();
    expect(find.text('BACK'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is WebClickScope && w.label == 'BACK',
      ),
      findsOneWidget,
    );
  });

  testWidgets('claim chip semantics names daily vault', (tester) async {
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 3)),
    ).copyWith(homeLayout: HomeLayout.home);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          director: director,
          router: router,
          onLeave: () {},
        ),
      ),
    );
    await tester.pump();
    final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Claim the daily')));
    expect(node.label, contains('daily'));
    expect(node.label.toLowerCase(), isNot(contains('day ends')));
  });

  testWidgets('minimal VFX coach pulse has no ticker', (tester) async {
    var state = GameLogic.createInitialState(now: DateTime(2026, 11, 3));
    state = state.copyWith(vfxQuality: VfxQuality.minimal);
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CoachPulse(
          active: true,
          enabled: false,
          child: const SizedBox(width: 48, height: 48),
        ),
      ),
    );
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('fight marks farm_push seen after first frame in cave', (tester) async {
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 3)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      highestFloorCleared: 1,
      seenTips: const ['first_run', 'godhand'],
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          director: director,
          router: router,
          onLeave: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(director.state.seenTips, contains('farm_push'));
  });
}
