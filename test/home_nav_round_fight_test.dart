import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_icon.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_nav_bar.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

/// Batch 5: round FIGHT over the bar, padlocks on tabs that are not open.
void main() {
  Future<(GameDirector, MenuRouter)> pumpShell(
    WidgetTester tester, {
    required bool unlocked,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var seeded = GameLogic.createInitialState(
      now: DateTime(2026, 11, 16),
    ).copyWith(homeLayout: HomeLayout.home);
    if (unlocked) {
      seeded = seeded.copyWith(
        bossVictories: 2,
        highestFloorCleared: 3,
        ascensionLevel: 1,
        essence: 10,
      );
    }
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(seeded),
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
    return (director, router);
  }

  Finder lockSemantics(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && (w.properties.label ?? '').startsWith('$label locked'),
  );

  testWidgets('locked tabs show a padlock and what opens them', (tester) async {
    await pumpShell(tester, unlocked: false);
    expect(tester.takeException(), isNull);
    for (final tab in ['ESSENCE', 'MAP', 'SHOP']) {
      expect(lockSemantics(tab), findsOneWidget, reason: tab);
    }
    expect(find.text('Boss F2'), findsNWidgets(3));
    final locks = find.byWidgetPredicate(
      (w) => w is GameIcon && w.glyph == UiGlyph.lock,
    );
    expect(locks, findsNWidgets(3));
    expect(find.text('SHOP'), findsNothing);
    expect(find.text('HEROES'), findsOneWidget);
  });

  testWidgets('unlocked tabs drop the padlocks', (tester) async {
    await pumpShell(tester, unlocked: true);
    for (final tab in ['ESSENCE', 'MAP', 'SHOP']) {
      expect(lockSemantics(tab), findsNothing, reason: tab);
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
  });

  testWidgets('FIGHT is a 68 dp circle that rises over the bar', (
    tester,
  ) async {
    final (_, router) = await pumpShell(tester, unlocked: true);
    final nav = tester.getRect(find.byType(HomeNavBar));
    final fight = find.ancestor(
      of: find.text('FIGHT'),
      matching: find.byType(InkWell),
    );
    final circle = tester.getRect(fight.first);
    expect(circle.width, closeTo(68, 0.5));
    expect(circle.height, closeTo(68, 0.5));
    expect(circle.top, lessThan(nav.top));
    expect(nav.top - circle.top, closeTo(HomeNavBar.fightLift, 0.5));
    // Tappable part stays inside the bar and above the 48 dp floor.
    expect(circle.bottom - nav.top, greaterThanOrEqualTo(GameTheme.primaryTouch));

    await tester.tap(find.text('HEROES'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.route, MenuRoute.gear);
    expect(find.text('CLOSE'), findsOneWidget);
    await tester.tapAt(Offset(circle.center.dx, nav.top + 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.route, MenuRoute.none);
  });

  testWidgets('round FIGHT keeps its size and labels at 1.45', (tester) async {
    await pumpShell(tester, unlocked: false, scale: GameTheme.typeScaleMax);
    expect(tester.takeException(), isNull);
    expect(HomeNavBar.fightDiameter(GameTheme.typeScaleMax), 68);
    expect(find.text('FIGHT'), findsOneWidget);
    expect(find.text('Boss F2'), findsNWidgets(3));
    expect(find.byType(FittedBox), findsNothing);
  });
}
