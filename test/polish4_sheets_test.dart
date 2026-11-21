import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/essence_tiles_screen.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/overlay_scaffold.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';
import 'package:idle_party/ui/shell/shell_common.dart';
import 'package:idle_party/ui/shell/wallet_strip.dart';

import 'shell_golden_harness.dart';

/// Polish 4: ESSENCE tiles carry icons, home sheets do not repeat the
/// wallet the top bar already shows, the selected hero uses the selected
/// colors (amber rim on plum), not buy gold.
Future<GameDirector> _homeDirector() => withShellGoldenWeek(() async {
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  final s = base.copyWith(
    homeLayout: HomeLayout.home,
    homePanelFull: false,
    ascensionLevel: 2,
    bossVictories: 2,
    highestDungeonCleared: 1,
    highestFloorCleared: 4,
    gold: 12000,
    essence: 240,
    seenChangelogVersion: MetaSystems.currentVersion,
    metaDepth: base.metaDepth.copyWith(
      reviewPrompted: true,
      lifetimeFloorClears: 6,
    ),
  );
  final d = GameDirector.preview(initialState: GameLogic.enterDungeon(s));
  await d.boot(deferCombatLoop: true);
  d.dismissOfflineSummary();
  d.clearToast();
  return d;
});

Future<(GameDirector, MenuRouter)> _pumpHome(
  WidgetTester tester,
  double scale,
) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final director = await _homeDirector();
  final router = MenuRouter();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: HomeShell(director: director, router: router, onLeave: () {}),
    ),
  );
  await tester.pump();
  return (director, router);
}

Future<void> _dispose(
  WidgetTester tester,
  GameDirector director,
  MenuRouter router,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  director.dispose();
  router.dispose();
  await tester.pump();
}

void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  testWidgets('every ESSENCE tile has an icon tile; locked ones are dim', (
    tester,
  ) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        highestFloorCleared: 1,
      ),
    );
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EssenceTilesScreen(director: director, router: router),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // CODEX and CRAFT live only in MENU (audit F099).
    expect(find.text('CODEX'), findsNothing);
    expect(find.text('CRAFT'), findsNothing);
    for (final label in ['BLESSING', 'RELICS', 'PETS']) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      final icon = find.descendant(
        of: tile,
        matching: find.byType(UpgradeIconTile),
      );
      expect(icon, findsOneWidget, reason: label);
      final open = tester.widget<InkWell>(tile.first).onTap != null;
      expect(tester.widget<UpgradeIconTile>(icon).dim, !open, reason: label);
    }
  });

  for (final route in [MenuRoute.essence, MenuRoute.shop]) {
    for (final scale in [1.0, GameTheme.typeScaleMax]) {
      testWidgets(
        '${route.name} home sheet does not repeat the wallet at $scale',
        (tester) async {
          final (director, router) = await _pumpHome(tester, scale);
          router.open(route);
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          expect(tester.takeException(), isNull);
          expect(
            find.descendant(
              of: find.byType(OverlayScrim),
              matching: find.byType(WalletStrip),
            ),
            findsNothing,
          );
          // Nothing lost: the top bar still shows gold and essence.
          final bar = find.byType(HomeTopBar);
          expect(
            find.descendant(of: bar, matching: find.text(formatGold(12000))),
            findsOneWidget,
          );
          expect(
            find.descendant(of: bar, matching: find.text('240')),
            findsOneWidget,
          );
          await _dispose(tester, director, router);
        },
      );
    }
  }

  testWidgets('selected hero uses the selected colors, not buy gold', (
    tester,
  ) async {
    final (director, router) = await _pumpHome(tester, 1);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    bool rimmed(Widget w, Color rim) {
      if (w is! Container) return false;
      final d = w.decoration;
      if (d is! BoxDecoration) return false;
      final b = d.border;
      return b is Border && b.top.color == rim;
    }

    expect(
      find.byWidgetPredicate(
        (w) =>
            rimmed(w, GameTheme.toggleOnAccent) &&
            (w as Container).decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == GameTheme.selectedRowFill,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => rimmed(w, GameTheme.torch.withValues(alpha: 0.55)),
      ),
      findsNothing,
    );
    await _dispose(tester, director, router);
  });
}
