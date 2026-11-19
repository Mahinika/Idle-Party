import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/chunky_face.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';

import 'audit100_harness.dart';
import 'shell_golden_harness.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Audit 100, batch 3: button and color meaning.
void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  test('F007 a disabled label reads 4.5:1 on its face', () {
    for (final bg in [
      GameTheme.buttonDisabledTop,
      GameTheme.buttonDisabledBottom,
    ]) {
      expect(
        _contrast(GameTheme.buttonDisabledText, bg),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('F043/F017 go and essence faces read 4.5:1', () {
    for (final bg in [GameTheme.goTop, GameTheme.goBottom]) {
      expect(_contrast(GameTheme.goText, bg), greaterThanOrEqualTo(4.5));
    }
    for (final bg in [GameTheme.essenceBuyTop, GameTheme.essenceBuyBottom]) {
      expect(
        _contrast(GameTheme.essenceBuyText, bg),
        greaterThanOrEqualTo(4.5),
      );
    }
    // Go is not the buy gold and not the 2× boost orange.
    expect(GameTheme.goTop, isNot(GameTheme.buyGoldTop));
    expect(GameTheme.goTop, isNot(GameTheme.boostOrangeTop));
  });

  test('F055 run-scope section labels are not the gain green', () {
    expect(GameTheme.scopeRun, isNot(GameTheme.mossLit));
    expect(GameTheme.scopeRun, isNot(GameTheme.gainGreen));
  });

  Widget chip({required bool essence, int? q, bool enabled = true}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PowerUpgradePriceChip(
              label: '15',
              essence: essence,
              quantity: q,
              onPressed: enabled ? () {} : null,
            ),
          ),
        ),
      );

  testWidgets('F017 an essence price uses the essence face', (tester) async {
    await tester.pumpWidget(chip(essence: true, q: 1));
    expect(
      tester.widget<ChunkyFace>(find.byType(ChunkyFace)).tone,
      ChunkyTone.essence,
    );
    await tester.pumpWidget(chip(essence: false, q: 1));
    expect(
      tester.widget<ChunkyFace>(find.byType(ChunkyFace)).tone,
      ChunkyTone.gold,
    );
    await tester.pumpWidget(chip(essence: true, enabled: false));
    expect(
      tester.widget<ChunkyFace>(find.byType(ChunkyFace)).tone,
      ChunkyTone.grey,
    );
  });

  testWidgets('F059 ×1 has no badge; ×10 does', (tester) async {
    await tester.pumpWidget(chip(essence: false, q: 1));
    expect(find.byType(QtyBadge), findsNothing);
    await tester.pumpWidget(chip(essence: false, q: 10));
    expect(find.byType(QtyBadge), findsOneWidget);
    expect(find.text('×10'), findsOneWidget);
  });

  a100TestHome('F008 the selected tab in SETTINGS is the plum face', (
    tester,
  ) async {
    final (_, router) = await a100Pump(tester, const Size(360, 780), 1);
    router.open(MenuRoute.more);
    await a100Settle(tester);
    await tester.tap(find.text('SETTINGS').first);
    await a100Settle(tester);
    final bars = tester.widgetList<TabBar>(find.byType(TabBar)).toList();
    expect(bars, isNotEmpty);
    for (final bar in bars) {
      final box = bar.indicator! as BoxDecoration;
      final g = box.gradient! as LinearGradient;
      expect(g.colors, contains(GameTheme.toggleOnTop));
      expect(bar.labelColor, GameTheme.toggleOnText);
    }
  });

  a100TestHome(
    'F013 bag space sits at the end of the bag scroll with a need line',
    (tester) async {
      final (_, router) = await a100Pump(
        tester,
        const Size(360, 780),
        1,
        gold: 100,
      );
      router.open(MenuRoute.gear, gear: GearPanel.bag);
      await a100Settle(tester);
      final buy = find.byKey(InventoryDock.bagGoldBuyKey);
      expect(buy, findsOneWidget);
      expect(tester.widget<GameButton>(buy).style, GameButtonStyle.grey);
      expect(find.textContaining('Need '), findsWidgets);
      // EXPAND BAG lives in the bag scroll, after the items, not among the
      // pinned bag buttons.
      expect(
        find.descendant(
          of: find.byKey(InventoryDock.bagScrollKey),
          matching: buy,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(InventoryDock.bagScrollKey),
          matching: find.text(InventoryDock.emptyBagLine),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(buy).top,
        greaterThan(
          tester.getRect(find.text(InventoryDock.emptyBagLine)).bottom,
        ),
      );
    },
  );

  a100TestHome('F023 LEAVE is an outline, not a red slab', (tester) async {
    await a100Pump(tester, const Size(360, 780), 1);
    await a100Settle(tester);
    final face = tester.widget<ChunkyFace>(find.byKey(FightSeam.leaveFaceKey));
    expect(face.tone, isNot(ChunkyTone.red));
    expect(face.edgeColor, GameTheme.blood);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.byKey(FightSeam.leaveFaceKey),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(GameTheme.minTouch),
    );
  });

  for (final gold in [0, 999999]) {
    a100TestHome('F024 reroll is gold when payable, grey when short ($gold)', (
      tester,
    ) async {
      final (director, _) = await a100Pump(
        tester,
        const Size(360, 780),
        1,
        gold: gold,
      );
      await a100Settle(tester);
      await tester.tap(find.text('MARKET').first);
      await a100Settle(tester);
      final f = find.byKey(MarketHeaderControls.rerollKey);
      if (f.evaluate().isEmpty) return; // fresh stock: no reroll chip
      final tone = tester.widget<ChunkyFace>(f).tone;
      expect(tone, gold == 0 ? ChunkyTone.grey : ChunkyTone.gold);
      expect(director.state.gold, gold);
    });
  }

  a100TestHome('F043 town ENTER is the amber go face', (tester) async {
    await a100Pump(tester, const Size(360, 780), 1, inDungeon: false);
    await a100Settle(tester);
    final go = tester
        .widgetList<GameButton>(find.byType(GameButton))
        .where((b) => b.style == GameButtonStyle.go);
    expect(go, isNotEmpty);
  });
}
