import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/chunky_face.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/al_ascension_sheet.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/hud_pills.dart';

/// Batch 4: currency capsules, a floor hex, gold per minute in the cave,
/// an orange 2× and MENU as its own button. Nothing shrinks at 1.45.
void main() {
  Future<(GameDirector, MenuRouter)> pumpBar(
    WidgetTester tester, {
    double scale = 1,
    bool dungeon = true,
    int pace = 1,
    int al = 12,
    int bossVictories = 2,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var seeded = GameLogic.createInitialState(
      now: DateTime(2026, 11, 16),
    ).copyWith(
      homeLayout: HomeLayout.home,
      bossVictories: bossVictories,
      highestFloorCleared: 4,
      gold: 1234567,
      essence: 99999,
      ascensionLevel: al,
      combatPace: pace,
      inDungeon: false,
    );
    if (dungeon) {
      seeded = seeded.copyWith(inDungeon: true);
      seeded = GameLogic.enterDungeon(seeded);
    }
    final director = GameDirector.preview(initialState: seeded);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [HomeTopBar(director: director, router: router)],
          ),
        ),
      ),
    );
    await tester.pump();
    return (director, router);
  }

  testWidgets('cave HUD: pills, hex floor badge, green gold per minute', (
    tester,
  ) async {
    final (director, _) = await pumpBar(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(HudPill), findsNWidgets(3));
    expect(find.text('AL 12'), findsOneWidget);
    final floor = director.state.currentRoom.floorNumber;
    expect(
      find.descendant(
        of: find.byType(HexBadge),
        matching: find.text('F$floor'),
      ),
      findsOneWidget,
    );
    final perMin = GoldIncome.hubGoldPerMinute(director.state);
    if (perMin > 0) {
      final rate = tester.widget<Text>(
        find.text('+${GoldIncome.perMinuteLabel(perMin)}'),
      );
      expect(rate.style?.color, GameTheme.gainGreen);
    }
    final menu = find.ancestor(
      of: find.byType(ChunkyFace).last,
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(menu.first).height,
        greaterThanOrEqualTo(GameTheme.minTouch));
  });

  testWidgets('2× is the orange boost face, 1× is stone', (tester) async {
    await pumpBar(tester, pace: 2);
    final fast = tester.widget<ChunkyFace>(
      find.ancestor(of: find.text('2×'), matching: find.byType(ChunkyFace)),
    );
    expect(fast.tone, ChunkyTone.orange);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpBar(tester, pace: 1);
    final slow = tester.widget<ChunkyFace>(
      find.ancestor(of: find.text('1×'), matching: find.byType(ChunkyFace)),
    );
    expect(slow.tone, ChunkyTone.stone);
  });

  for (final dungeon in [true, false]) {
    testWidgets('HUD fits 360 at text scale 1.45 (dungeon: $dungeon)', (
      tester,
    ) async {
      await pumpBar(tester, scale: GameTheme.typeScaleMax, dungeon: dungeon);
      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsNothing);
      for (final pill in find.byType(HudPill).evaluate()) {
        final r = tester.getRect(find.byWidget(pill.widget));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(360));
      }
      expect(
        tester.getRect(find.bySemanticsLabel('MENU')).right,
        lessThanOrEqualTo(360),
      );
      expect(find.byType(HexBadge), dungeon ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('AL pill semantics label', (tester) async {
    await pumpBar(tester, dungeon: false, al: 9);
    expect(find.bySemanticsLabel('Ascension Level 9'), findsOneWidget);
  });

  testWidgets('AL pill opens Ascension Level sheet', (tester) async {
    await pumpBar(tester, dungeon: false, al: 9, bossVictories: 0);
    await tester.tap(find.bySemanticsLabel('Ascension Level 9'));
    await tester.pumpAndSettle();
    expect(find.text('Ascension Level'), findsOneWidget);
    expect(find.textContaining('AL 9 adds'), findsOneWidget);
  });

  testWidgets('F hex opens floor jump sheet', (tester) async {
    final (director, _) = await pumpBar(tester);
    await tester.tap(
      find.bySemanticsLabel(
        'Floor ${director.state.currentRoom.floorNumber}, open floor list',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FLOORS'), findsOneWidget);
  });

  for (final scale in [1.0, GameTheme.typeScaleMax]) {
    testWidgets('F hex touch target at scale $scale', (tester) async {
      await pumpBar(tester, scale: scale);
      final hit = find.bySemanticsLabel(RegExp(r'^Floor \d+, open floor list'));
      final size = tester.getSize(hit);
      expect(size.width, greaterThanOrEqualTo(GameTheme.minTouch));
      expect(size.height, greaterThanOrEqualTo(GameTheme.minTouch));
    });
  }

  testWidgets('essence pill opens ESSENCE when unlocked', (tester) async {
    final (director, router) = await pumpBar(tester, al: 1, bossVictories: 2);
    expect(MenuTabs.showCamp(director.state), isTrue);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Essence,')));
    await tester.pumpAndSettle();
    expect(router.route, MenuRoute.essence);
  });

  testWidgets('essence pill hit box is at least minTouch', (tester) async {
    await pumpBar(tester);
    final hit = find.bySemanticsLabel(RegExp(r'^Essence,'));
    expect(
      tester.getSize(hit).height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
  });

  testWidgets('AL pill hidden at AL 0 when essence row shows', (tester) async {
    await pumpBar(tester, al: 0, bossVictories: 2, dungeon: false);
    expect(find.text('AL 0'), findsNothing);
    expect(find.byType(HudPill), findsNWidgets(2));
  });

  testWidgets('AL pill touch target is at least minTouch', (tester) async {
    await pumpBar(tester);
    final hit = find.ancestor(
      of: find.text('AL 12'),
      matching: find.byType(InkWell),
    );
    expect(
      tester.getSize(hit.first).height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
  });

  testWidgets('AL sub line: boss progress', (tester) async {
    await pumpBar(tester, al: 2, bossVictories: 1);
    expect(find.text('1/3'), findsOneWidget);
    final state = GameLogic.createInitialState(
      now: DateTime(2026),
    ).copyWith(ascensionLevel: 2, bossVictories: 1);
    expect(alPillSubLine(state), '1/3');
  });

  testWidgets('AL sub line: Ascend ready', (tester) async {
    await pumpBar(tester, al: 1, bossVictories: 2);
    expect(find.text('Ascend ready'), findsOneWidget);
  });

  testWidgets('AL sub line: MAX at AL cap', (tester) async {
    await pumpBar(
      tester,
      al: GameLogic.maxAscensionLevel,
      bossVictories: 99,
    );
    expect(find.text('MAX'), findsOneWidget);
  });

  Future<void> pumpTopBarGolden(
    WidgetTester tester,
    GlobalKey key, {
    required bool dungeon,
    required double scale,
    required int al,
    required int bosses,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final seeded = GameLogic.createInitialState(now: DateTime(2026, 11, 16))
        .copyWith(
          homeLayout: HomeLayout.home,
          bossVictories: bosses,
          highestFloorCleared: 8,
          gold: 99_000,
          essence: 120,
          ascensionLevel: al,
          inDungeon: dungeon,
          homePanelFull: !dungeon,
          combatPace: 1,
        );
    final director = GameDirector.preview(initialState: seeded);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: GameTheme.stoneDeep,
          body: RepaintBoundary(
            key: key,
            child: HomeTopBar(director: director, router: router),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('AL pill golden town scale 1.0 after', (tester) async {
    final key = GlobalKey();
    await pumpTopBarGolden(
      tester,
      key,
      dungeon: false,
      scale: 1,
      al: 9,
      bosses: 1,
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/widgets/al_pill_topbar_town_scale1_after.png'),
    );
  });

  testWidgets('AL pill golden fight scale 1.0 after', (tester) async {
    final key = GlobalKey();
    await pumpTopBarGolden(tester, key, dungeon: true, scale: 1, al: 9, bosses: 1);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/widgets/al_pill_topbar_fight_scale1_after.png'),
    );
  });

  testWidgets('AL pill golden town scale 1.45 after', (tester) async {
    final key = GlobalKey();
    await pumpTopBarGolden(
      tester,
      key,
      dungeon: false,
      scale: GameTheme.typeScaleMax,
      al: 9,
      bosses: 1,
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/widgets/al_pill_topbar_town_scale145_after.png'),
    );
  });

  for (final (bosses, label, al) in [
    (2, 'ready', 2),
    (0, 'progress', 2),
    (99, 'max', GameLogic.maxAscensionLevel),
  ]) {
    testWidgets('AL pill golden subline $label', (tester) async {
      final key = GlobalKey();
      await pumpTopBarGolden(
        tester,
        key,
        dungeon: false,
        scale: 1,
        al: al,
        bosses: bosses,
      );
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/widgets/al_pill_subline_${label}_after.png'),
      );
    });
  }

  testWidgets('AL pill golden sheet after', (tester) async {
    final key = GlobalKey();
    await pumpTopBarGolden(
      tester,
      key,
      dungeon: false,
      scale: 1,
      al: 9,
      bosses: 0,
    );
    await tester.tap(find.bySemanticsLabel('Ascension Level 9'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(AlAscensionSheetKeys.capture),
      matchesGoldenFile('goldens/widgets/al_pill_sheet_after.png'),
    );
  });

  testWidgets('AL HUD fits 360×640 at scale 1.45 AL20', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpBar(
      tester,
      scale: GameTheme.typeScaleMax,
      dungeon: false,
      al: GameLogic.maxAscensionLevel,
      bossVictories: 99,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
    expect(
      tester.getRect(find.bySemanticsLabel('MENU')).right,
      lessThanOrEqualTo(360),
    );
  });
}
