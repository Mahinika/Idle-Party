import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/shell/home/home_gold_dock.dart';
import 'package:idle_party/ui/shell/home/home_nav_bar.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/nav_clearance.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';

/// The raised round FIGHT must never sit on the last buy card once a list
/// under the nav is scrolled to its end.
void main() {
  Future<GameDirector> pumpSplit(
    WidgetTester tester, {
    double scale = 1,
    double bottomInset = 0,
    bool full = false,
    bool inDungeon = true,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.reset);
    final seeded = GameLogic.createInitialState(
      now: DateTime.now().add(const Duration(minutes: 10)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: full,
      bossVictories: 2,
      highestFloorCleared: 3,
      ascensionLevel: 1,
      essence: 5000,
      gold: 5000,
    );
    final director = GameDirector.preview(
      initialState: inDungeon ? GameLogic.enterDungeon(seeded) : seeded,
    );
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
        home: HomeShell(director: director, router: router, onLeave: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return director;
  }

  Rect fightCircle(WidgetTester tester) => tester.getRect(
    find
        .ancestor(
          of: find.descendant(
            of: find.byType(HomeNavBar),
            matching: find.text('FIGHT'),
          ),
          matching: find.byType(InkWell),
        )
        .first,
  );

  Future<void> scrollToEnd(WidgetTester tester) async {
    final list = find
        .descendant(
          of: find.byType(UpgradePanel),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .last;
    await tester.drag(list, const Offset(0, -3000));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  void expectClear(WidgetTester tester, String why) {
    final circle = fightCircle(tester);
    final last = tester.getRect(find.byType(PowerUpgradeRow).last);
    final chip = tester.getRect(find.byType(PowerUpgradePriceChip).last);
    expect(last.bottom, lessThanOrEqualTo(circle.top), reason: '$why card');
    expect(chip.bottom, lessThanOrEqualTo(circle.top), reason: '$why chip');
  }

  for (final (scale, inset) in [
    (1.0, 0.0),
    (GameTheme.typeScaleMax, 0.0),
    (1.0, 34.0),
    (GameTheme.typeScaleMax, 34.0),
  ]) {
    testWidgets('FORGE and CAMP end above FIGHT (scale $scale, inset $inset)', (
      tester,
    ) async {
      await pumpSplit(tester, scale: scale, bottomInset: inset);
      expect(tester.takeException(), isNull);
      final circle = fightCircle(tester);
      final nav = tester.getRect(find.byType(HomeNavBar));
      expect(
        tester.widget<NavClearance>(find.byType(NavClearance)).bottom,
        closeTo(nav.top - circle.top, 0.5),
      );
      await scrollToEnd(tester);
      expectClear(tester, 'CRAFT');

      await tester.tap(find.text('CAMP'));
      await tester.pump();
      await scrollToEnd(tester);
      expectClear(tester, 'CAMP');
      expect(tester.takeException(), isNull);
    });
  }

  for (final (scale, inset) in [
    (1.0, 0.0),
    (GameTheme.typeScaleMax, 0.0),
    (1.0, 34.0),
    (GameTheme.typeScaleMax, 34.0),
  ]) {
    testWidgets('FULL dock sits above FIGHT (scale $scale, inset $inset)', (
      tester,
    ) async {
      await pumpSplit(tester, scale: scale, bottomInset: inset, full: true);
      expect(tester.takeException(), isNull);
      final circle = fightCircle(tester);
      final taps = find.descendant(
        of: find.byType(HomeGoldDock),
        matching: find.byType(InkWell),
      );
      expect(taps, findsNWidgets(3));
      for (final e in taps.evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        expect(r.bottom, lessThanOrEqualTo(circle.top));
        expect(r.height, greaterThanOrEqualTo(GameTheme.minTouch));
      }
    });

    testWidgets('town ENTER sits above FIGHT (scale $scale, inset $inset)', (
      tester,
    ) async {
      await pumpSplit(tester, scale: scale, bottomInset: inset, inDungeon: false);
      expect(tester.takeException(), isNull);
      final circle = fightCircle(tester);
      final enter = tester.getRect(
        find
            .descendant(
              of: find.byType(TownViewport),
              matching: find.byType(GameButton),
            )
            .first,
      );
      expect(enter.bottom, lessThanOrEqualTo(circle.top));
      expect(enter.height, greaterThanOrEqualTo(GameTheme.minTouch));
    });
  }

  testWidgets('lists outside the home fight get no extra clearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(builder: (context) => Text('${NavClearance.of(context)}',
          textDirection: TextDirection.ltr)),
    );
    expect(find.text('0.0'), findsOneWidget);
  });
}
