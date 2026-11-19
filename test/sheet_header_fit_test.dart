import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/overlay_scaffold.dart';

import 'shell_golden_harness.dart';

/// Sheet titles (ESSENCE, SHOP, MAP, ...) are whole at the 1.45 text cap:
/// the wallet moves under the title instead of cutting it. No FittedBox.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  for (final route in [MenuRoute.essence, MenuRoute.shop, MenuRoute.map]) {
    for (final scale in [1.0, GameTheme.typeScaleMax]) {
      testWidgets('${route.name} sheet title is whole at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final director = await withShellGoldenWeek(() async {
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
          final d =
              GameDirector.preview(initialState: GameLogic.enterDungeon(s));
          await d.boot(deferCombatLoop: true);
          d.dismissOfflineSummary();
          d.clearToast();
          return d;
        });
        final router = MenuRouter();
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
        router.open(route);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(tester.takeException(), isNull);
        final titleSize = GameTheme.title().fontSize;
        final titles = find.descendant(
          of: find.byType(OverlayScrim),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.style?.fontSize == titleSize &&
                w.overflow == TextOverflow.fade &&
                (w.data ?? '').isNotEmpty,
          ),
        );
        expect(titles, findsWidgets);
        for (final e in titles.evaluate()) {
          final text = e.widget as Text;
          final paragraph = e.renderObject! as RenderParagraph;
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(1e9) - 0.5),
            reason: '${text.data} is cut',
          );
          final r = tester.getRect(find.byWidget(text));
          expect(r.right, lessThanOrEqualTo(360), reason: text.data);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        director.dispose();
        router.dispose();
        await tester.pump();
      });
    }
  }
}
