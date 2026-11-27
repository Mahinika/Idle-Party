import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/rail_button.dart';

import 'shell_golden_harness.dart';

/// SCROLLS / QUESTS / VAULT / DAILY stay in the hub seam and every label is
/// whole on a 360 dp phone, up to the 1.45 text cap. No shrink-to-fit.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  Future<(GameDirector, MenuRouter)> pump(WidgetTester tester, double scale) async {
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
      final d = GameDirector.preview(initialState: GameLogic.enterDungeon(s));
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
    await tester.pump(const Duration(milliseconds: 300));
    return (director, router);
  }

  for (final scale in [1.0, 1.2, GameTheme.typeScaleMax]) {
    testWidgets('hub seam labels are whole at text scale $scale', (
      tester,
    ) async {
      final (director, router) = await pump(tester, scale);
      expect(tester.takeException(), isNull);
      final entries = FightSeamRails.visibleEntries(director.state, director);
      final labels = [
        for (final e in entries) e.labelFor?.call(director.state) ?? e.label,
      ];
      expect(labels, containsAll(['SCROLLS', 'QUESTS', 'RUN']));
      expect(labels.any((l) => l == 'VAULT' || l == 'CLAIM'), isTrue);
      final seam = find.byType(FightSeamRails);
      final seamRect = tester.getRect(seam);
      for (final label in labels) {
        final text = find.descendant(of: seam, matching: find.text(label));
        expect(text, findsOneWidget, reason: label);
        final r = tester.getRect(text);
        expect(r.left, greaterThanOrEqualTo(seamRect.left), reason: label);
        expect(r.right, lessThanOrEqualTo(seamRect.right), reason: label);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(paragraph.size.width,
            greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(1e9) - 0.5),
            reason: '$label is not ellipsized');
        final button = tester.getRect(
          find.ancestor(of: text, matching: find.byType(RailButton)),
        );
        expect(button.height, greaterThanOrEqualTo(GameTheme.minTouch));
        expect(button.width, greaterThanOrEqualTo(GameTheme.minTouch));
        expect(button.right, lessThanOrEqualTo(seamRect.right), reason: label);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      director.dispose();
      router.dispose();
      await tester.pump();
    });
  }
}
