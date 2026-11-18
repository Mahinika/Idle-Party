import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';


import 'shell_golden_harness.dart';

/// Shared home-shell harness for the audit-100 regression tests: A56
/// 360x780 and small 360x640, at 1.0 and the 1.45 text cap.
const a100Sizes = [Size(360, 780), Size(360, 640)];
final a100Scales = [1.0, GameTheme.typeScaleMax];

Future<GameDirector> a100Director({
  bool fresh = false,
  bool inDungeon = true,
  bool maxed = false,
  int? gold,
  int? essence,
  bool full = false,
}) => withShellGoldenWeek(() async {
  final base = GameLogic.createInitialState(now: shellGoldenNow);
  var s = fresh
      ? base.copyWith(
          homeLayout: HomeLayout.home,
          vfxQuality: VfxQuality.minimal,
        )
      : base.copyWith(
          homeLayout: HomeLayout.home,
          homePanelFull: false,
          ascensionLevel: 2,
          bossVictories: 2,
          highestDungeonCleared: 1,
          highestFloorCleared: 4,
          gold: 12000,
          essence: 240,
          vfxQuality: VfxQuality.minimal,
          seenChangelogVersion: MetaSystems.currentVersion,
          metaDepth: base.metaDepth.copyWith(
            reviewPrompted: true,
            lifetimeFloorClears: 6,
          ),
        );
  if (maxed) {
    s = s.copyWith(
      heroes: [
        for (final h in s.heroes) h.copyWith(level: GameLogic.maxHeroLevel),
      ],
    );
  }
  if (gold != null) s = s.copyWith(gold: gold);
  if (essence != null) s = s.copyWith(essence: essence);
  if (full) s = s.copyWith(homePanelFull: true);
  if (inDungeon) s = GameLogic.enterDungeon(s);
  final d = GameDirector.preview(initialState: s);
  await d.boot(deferCombatLoop: true);
  d.dismissOfflineSummary();
  d.clearToast();
  return d;
});

Future<(GameDirector, MenuRouter)> a100Pump(
  WidgetTester tester,
  Size size,
  double scale, {
  bool fresh = false,
  bool maxed = false,
  bool inDungeon = true,
  int? gold,
  int? essence,
  bool full = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final director = await a100Director(
    fresh: fresh,
    maxed: maxed,
    inDungeon: inDungeon,
    gold: gold,
    essence: essence,
    full: full,
  );
  final router = MenuRouter();
  a100Live = (director, router);
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

(GameDirector, MenuRouter)? a100Live;

/// testWidgets that tears the shell down before the timer check.
void a100TestHome(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    a100Live = null;
    await body(tester);
    final live = a100Live;
    if (live != null) {
      await tester.pumpWidget(const SizedBox.shrink());
      live.$1.dispose();
      live.$2.dispose();
      await tester.pump(const Duration(milliseconds: 20));
    }
  });
}

Future<void> a100Settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

String a100Label(Size size, double scale) =>
    '${size.width.toInt()}x${size.height.toInt()} @$scale';

/// Text [text] is drawn whole: no ellipsis, no line cut, wider than its box.
void a100ExpectWhole(WidgetTester tester, Finder text) {
  expect(text, findsWidgets);
  for (final e in text.evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
    if (!p.softWrap || p.maxLines == 1) {
      expect(
        p.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(p.size.width + 0.5),
        reason: 'cut: ${p.text.toPlainText()}',
      );
    }
  }
}

