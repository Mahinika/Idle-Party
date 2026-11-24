import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/fight_viewport.dart';
import 'package:idle_party/ui/shell/home/home_nav_bar.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';

import 'shell_golden_harness.dart';

/// UI batch 1 (2026-11-22): contrast, chrome baseline, plate kicker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Brightest sandy-lit floor from the Sandy tile ramp (see `generate_floor_props`).
  const brightestCaveSand = Color(0xFFECD4A8);

  double contrast(Color fg, Color bg) {
    double lin(double c) {
      final s = c / 255.0;
      if (s <= 0.04045) return s / 12.92;
      return math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    double lum(Color c) =>
        0.2126 * lin(c.r * 255) +
        0.7152 * lin(c.g * 255) +
        0.0722 * lin(c.b * 255);
    final a = lum(fg);
    final b = lum(bg);
    return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  }

  Color compositeOver(Color layer, Color under) {
    final a = layer.a;
    return Color.from(
      alpha: 1,
      red: layer.r * a + under.r * (1 - a),
      green: layer.g * a + under.g * (1 - a),
      blue: layer.b * a + under.b * (1 - a),
    );
  }

  test('parchmentDim on card over brightest cave sand meets WCAG AA', () {
    final under = compositeOver(GameTheme.card, brightestCaveSand);
    expect(
      contrast(GameTheme.parchmentDim, under),
      greaterThanOrEqualTo(4.5),
    );
  });

  group('home fight chrome baseline A56', () {
    Future<GameDirector> pumpSplit(WidgetTester tester) async {
      bindA56View(tester);
      final director = await homeShellFightGoldenDirector();
      final router = MenuRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia,
          child: MaterialApp(
            home: HomeShell(
              director: director,
              router: router,
              onLeave: () {},
            ),
          ),
        ),
      );
      await waitForFightChrome(tester, director);
      await tester.pump(const Duration(milliseconds: 400));
      return director;
    }

    testWidgets('records cave vs chrome share without a shrink cap', (
      tester,
    ) async {
      final director = await pumpSplit(tester);
      final screen = tester.getSize(find.byType(HomeShell));
      final cave = tester.getSize(find.byType(FightViewport));
      final top = tester.getRect(find.byType(HomeTopBar));
      final seam = tester.getSize(find.byType(FightSeam));
      final nav = tester.getSize(find.byType(HomeNavBar));
      final panel = find.byType(UpgradePanel);
      var chromeBelow = seam.height + nav.height;
      if (panel.evaluate().isNotEmpty) {
        chromeBelow += tester.getSize(panel).height;
      }

      final caveShare = cave.height / screen.height;
      final chromeBelowShare = chromeBelow / screen.height;

      // Measured 2026-11-22 split home fight (flex 3:2 + nav). No 34% cap yet.
      const caveBaseline = 0.224;
      const chromeBelowBaseline = 0.538;

      expect(caveShare, greaterThanOrEqualTo(caveBaseline * 0.98));
      expect(chromeBelowShare, lessThanOrEqualTo(chromeBelowBaseline * 1.02));
      expect(top.bottom, lessThanOrEqualTo(cave.height + top.top + 1));
      expect(find.byKey(TargetCornerHud.stripKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      director.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    });
  });

  testWidgets('writes home fight top HUD artifact', (tester) async {
    bindA56View(tester);
    final director = await homeShellFightGoldenDirector();
    final router = MenuRouter();
    addTearDown(router.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: shellGoldenMedia,
          child: MaterialApp(
            home: HomeShell(
              director: director,
              router: router,
              onLeave: () {},
            ),
          ),
        ),
      ),
    );
    await waitForFightChrome(tester, director);
    await tester.pump(const Duration(milliseconds: 600));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    image!.dispose();
    final dir = Directory('/opt/cursor/artifacts');
    dir.createSync(recursive: true);
    File('${dir.path}/home_fight_top_hud_after.png').writeAsBytesSync(
      bytes!.buffer.asUint8List(),
    );
    await tester.pump(const Duration(milliseconds: 400));
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });
}