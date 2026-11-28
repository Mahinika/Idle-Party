import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/run_stash_shop.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/kenney_button.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/shell/essence_keep_panel.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/inventory_dock.dart';
import 'package:idle_party/ui/shell/jobs_overlay.dart';
import 'package:idle_party/ui/web_click_bridge.dart';

import 'shell_golden_harness.dart';

/// Polish 6 (fynd 1–13, 17–19): regressions for the bugs found in the
/// 20-point layout audit. Sizes: A56 360x780 and small 360x640, at 1.0 and
/// the 1.45 text cap.
const _sizes = [Size(360, 780), Size(360, 640)];
final _scales = [1.0, GameTheme.typeScaleMax];

Future<GameDirector> _director({bool fresh = false, bool inDungeon = true}) =>
    withShellGoldenWeek(() async {
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
      if (inDungeon) s = GameLogic.enterDungeon(s);
      final d = GameDirector.preview(initialState: s);
      await d.boot(deferCombatLoop: true);
      d.dismissOfflineSummary();
      d.clearToast();
      return d;
    });

Future<(GameDirector, MenuRouter)> _pump(
  WidgetTester tester,
  Size size,
  double scale, {
  bool fresh = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final director = await _director(fresh: fresh);
  final router = MenuRouter();
  _live = (director, router);
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

(GameDirector, MenuRouter)? _live;

/// testWidgets that tears the shell down before the timer check.
void _testHome(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    _live = null;
    await body(tester);
    final live = _live;
    if (live != null) {
      await tester.pumpWidget(const SizedBox.shrink());
      live.$1.dispose();
      live.$2.dispose();
      await tester.pump(const Duration(milliseconds: 20));
    }
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

String _label(Size size, double scale) =>
    '${size.width.toInt()}x${size.height.toInt()} @$scale';

/// Text [text] is drawn whole: no ellipsis, no line cut, wider than its box.
void _expectWhole(WidgetTester tester, Finder text) {
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

double _lin(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  // Fynd 1: BAG overflowed 46 px (1.0) / 140 px (1.45) on 360x640.
  for (final fresh in [false, true]) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        _testHome('BAG fits and every button is reachable '
            '${_label(size, scale)}${fresh ? ' fresh' : ''}', (tester) async {
          final (_, router) = await _pump(tester, size, scale, fresh: fresh);
          router.open(MenuRoute.gear, gear: GearPanel.bag);
          await _settle(tester);
          expect(tester.takeException(), isNull);
          // The bag action row is pinned under the grid: FILTERS is in
          // view without scrolling.
          final filters = find.byKey(InventoryDock.bagFiltersKey);
          expect(filters, findsOneWidget);
          final r = tester.getRect(filters);
          final nav = tester.getRect(
            find.byWidgetPredicate(
              (w) => w is WebClickScope && w.label == 'FIGHT',
            ),
          );
          expect(r.bottom, lessThanOrEqualTo(nav.top + 0.5));
          expect(r.top, greaterThanOrEqualTo(0));
        });
      }
    }
  }

  // Fynd 2: the BACK pill sat on top of the round FIGHT button.
  for (final size in _sizes) {
    for (final scale in _scales) {
      _testHome('BACK does not overlap FIGHT ${_label(size, scale)}', (
        tester,
      ) async {
        final (_, router) = await _pump(tester, size, scale);
        router.open(MenuRoute.more, more: MoreSection.settings);
        router.pushSub();
        await _settle(tester);
        final back = find.byWidgetPredicate(
          (w) => w is WebClickScope && w.label == 'BACK',
        );
        expect(back, findsOneWidget);
        final fight = find.byWidgetPredicate(
          (w) => w is WebClickScope && w.label == 'FIGHT',
        );
        final b = tester.getRect(back);
        final f = tester.getRect(fight);
        expect(b.overlaps(f), isFalse, reason: 'BACK $b FIGHT $f');
        expect(b.height, greaterThanOrEqualTo(GameTheme.minTouch - 0.01));
      });
    }
  }

  // Fynd 3: every locked dock tab said "FORGE opens …".
  _testHome('locked dock names the picked tab', (tester) async {
    await _pump(tester, const Size(360, 780), 1, fresh: true);
    // The dock row opens the locked sheet; its own tab row then switches.
    await tester.tap(find.text('MARKET').first);
    await _settle(tester);
    for (final tab in ['MARKET', 'CAMP', 'TRAIN']) {
      if (tab != 'MARKET') {
        await tester.tap(find.text(tab).last);
        await _settle(tester);
      }
      expect(
        find.text('$tab opens after the first boss (F2).'),
        findsOneWidget,
        reason: tab,
      );
      for (final other in ['TRAIN', 'CAMP', 'MARKET']..remove(tab)) {
        expect(
          find.text('$other opens after the first boss (F2).'),
          findsNothing,
        );
      }
    }
  });

  // Fynd 4: QUESTS rewards were cut to "+3 e…" at 1.45.
  for (final size in _sizes) {
    _testHome('QUESTS rewards are whole ${_label(size, 1.45)}', (tester) async {
      final (director, router) = await _pump(tester, size, 1.45);
      router.open(MenuRoute.more, more: MoreSection.quests);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final m = director.state.metaDepth;
      expect(find.byType(JobsOverlay), findsOneWidget);
      final rewards = find.descendant(
        of: find.byType(JobsOverlay),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('essence'),
        ),
      );
      _expectWhole(tester, rewards.hitTestable());
      expect(
        find.textContaining('Progress: ${m.jobChainCount}/3'),
        findsOneWidget,
      );
      _expectWhole(
        tester,
        find.descendant(
          of: find.byType(JobsOverlay),
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().startsWith('Every 3rd quest claimed'),
          ),
        ),
      );
    });
  }

  // Fynd 5: "17kg" read as kilograms.
  test('BAG gold price never renders as "kg"', () {
    for (final g in [0, 950, 1000, 12000, 17000, 17400, 99999, 250000]) {
      final label = RunStashShop.goldCostLabel(g);
      expect(label, isNot(contains('kg')), reason: '$g');
      expect(label, endsWith('g'));
    }
    expect(RunStashShop.goldCostLabel(17000), '17,000g');
    expect(RunStashShop.goldCostLabel(2500000), isNot(contains('kg')));
    final s = GameLogic.createInitialState(now: DateTime(2026, 11, 17));
    expect(RunStashShop.goldBuyLabel(s), isNot(contains('kg')));
    expect(
      RunStashShop.goldBuyLabel(s),
      contains(RunStashShop.goldCostLabel(RunStashShop.goldBuyCost(s))),
    );
  });

  // Fynd 6: FARM/PUSH hint was 1.1–1.7:1 on lit sand.
  _testHome('fight mode hint sits on a dark capsule', (tester) async {
    await _pump(tester, const Size(360, 780), 1);
    final capsule = tester.widget<DecoratedBox>(
      find.byKey(FightFieldControls.modeHintKey),
    );
    final fill = (capsule.decoration as BoxDecoration).color!;
    expect(fill.a, closeTo(FightFieldControls.modeHintCapsuleAlpha, 0.01));
    // Worst case: the capsule over the brightest sand (#BBAE78).
    const sand = Color(0xFFBBAE78);
    final a = fill.a;
    final under = Color.from(
      alpha: 1,
      red: fill.r * a + sand.r * (1 - a),
      green: fill.g * a + sand.g * (1 - a),
      blue: fill.b * a + sand.b * (1 - a),
    );
    expect(_contrast(GameTheme.parchmentDim, under), greaterThanOrEqualTo(4.5));
  });

  // Fynd 7, 9, 10: labels cut at 1.45.
  _testHome('MERGE slot labels are whole at 1.45', (tester) async {
    final (_, router) = await _pump(tester, const Size(360, 780), 1.45);
    router.open(MenuRoute.gear, gear: GearPanel.merge);
    await _settle(tester);
    for (final label in ['FIRST', 'SECOND']) {
      final p = tester.renderObject<RenderParagraph>(find.text(label));
      // One word: it must fit its column on one line, never spill out.
      expect(
        p.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(p.size.width + 0.5),
        reason: label,
      );
    }
    // The bug read as "SECONDSame slot": the ink touched the value. Demand
    // a visible gap between the label's glyphs and the value text.
    final secondP = tester.renderObject<RenderParagraph>(find.text('SECOND'));
    final inkRight = tester.getRect(find.text('SECOND')).left +
        secondP.getMaxIntrinsicWidth(double.infinity);
    final value = tester.getRect(find.text(InventoryDock.mergePickSecond));
    expect(inkRight + 4, lessThanOrEqualTo(value.left));
  });

  _testHome('GEAR hero chips are whole at 1.45', (tester) async {
    final (director, router) = await _pump(tester, const Size(360, 780), 1.45);
    router.open(MenuRoute.gear, gear: GearPanel.gear);
    await _settle(tester);
    for (var i = 0; i < director.state.heroes.length; i++) {
      final tab = find.byKey(ValueKey('hero-tab-name-$i'));
      expect(tab, findsOneWidget);
      final r = tester.getRect(tab);
      expect(r.right, lessThanOrEqualTo(360));
      _expectWhole(tester, tab);
    }
  });

  for (final size in _sizes) {
    // polish7 P005: one word pair from the first floor on.
    _testHome('first-session FARM/PUSH are whole ${_label(size, 1.45)}', (
      tester,
    ) async {
      await _pump(tester, size, 1.45, fresh: true);
      _expectWhole(tester, find.text('FARM'));
      _expectWhole(tester, find.text('PUSH'));
      expect(find.text('Repeat'), findsNothing);
      expect(find.text('Next'), findsNothing);
    });
  }

  // Fynd 8: empty BAG said the same thing three times, with a "→" the pixel
  // font cannot draw.
  _testHome('empty BAG says it once, with no arrow glyph', (tester) async {
    final (_, router) = await _pump(tester, const Size(360, 780), 1);
    router.open(MenuRoute.gear, gear: GearPanel.bag);
    await _settle(tester);
    expect(find.textContaining('Bag empty'), findsOneWidget);
    expect(find.text(InventoryDock.emptyBagLine), findsOneWidget);
    final texts = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(InventoryDock),
            matching: find.byType(RichText),
          ),
        )
        .map((t) => t.text.toPlainText());
    for (final t in texts) {
      expect(t, isNot(contains('→')), reason: t);
    }
  });

  // Fynd 11: picked God Hand mode was a brown button.
  _testHome('God Hand mode uses the plum segmented toggle', (tester) async {
    final (_, router) = await _pump(tester, const Size(360, 780), 1);
    router.open(MenuRoute.essence, essence: EssencePanel.keep);
    router.pushSub();
    await _settle(tester);
    expect(find.byType(EssenceKeepPanel), findsOneWidget);
    for (final e in EssenceKeepPanel.godHandStyles) {
      expect(find.text(e.$2), findsOneWidget);
      expect(
        find.ancestor(of: find.text(e.$2), matching: find.byType(GameButton)),
        findsNothing,
        reason: '${e.$2} must not be a brown/grey GameButton',
      );
    }
  });

  // Fynd 13: ESSENCE tiles overflowed at 1.45 (first session) and the hub
  // took the last panel's title.
  for (final size in _sizes) {
    _testHome('ESSENCE hub fits and is titled ESSENCE '
        '${_label(size, 1.45)} fresh', (tester) async {
      final (_, router) = await _pump(tester, size, 1.45, fresh: true);
      router.open(MenuRoute.essence, essence: EssencePanel.relics);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('ESSENCE'), findsWidgets);
      expect(find.text('RELICS'), findsOneWidget); // the tile, not a title
      _expectWhole(tester, find.text('After the first boss or Ascend'));
    });
  }

  // Fynd 17: account-scope labels were off-palette blue.
  test('account scope label is a dusk tone with 4.5:1 on panel', () {
    expect(GameTheme.scopeAccount, isNot(GameTheme.accentInfo));
    for (final bg in [
      GameTheme.panel,
      GameTheme.panelInset,
      GameTheme.stoneRaised,
    ]) {
      expect(
        _contrast(GameTheme.scopeAccount.withValues(alpha: 1), bg),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  // Fynd 18: flask and MAX sheets had no grab bar.
  _testHome('MARKET flask sheet shows a grab bar', (tester) async {
    await _pump(tester, const Size(360, 780), 1);
    await tester.tap(find.text('MARKET').first);
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Flasks').first);
    await _settle(tester);
    expect(find.text('MARKET · flasks'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('MARKET · flasks'),
        matching: find.byType(BottomSheet),
      ),
      findsOneWidget,
    );
    expect(_handles(), findsOneWidget);
  });

  _testHome('MAX wallet-slice sheet shows a grab bar', (tester) async {
    await _pump(tester, const Size(360, 780), 1);
    await tester.longPress(find.text('MAX').first);
    await _settle(tester);
    expect(find.text(ForgeOverlay.sliceTitle), findsOneWidget);
    expect(_handles(), findsOneWidget);
  });

  // Fynd 15: at 1.45 the party strip read "A… › L1", "Va…", "Em…".
  for (final size in _sizes) {
    _testHome('party strip names are whole ${_label(size, 1.45)}', (
      tester,
    ) async {
      final (director, _) = await _pump(tester, size, 1.45);
      final hud = find.byType(PartyCornerHud);
      expect(hud, findsOneWidget);
      for (final h in director.state.heroes) {
        final name = find.descendant(of: hud, matching: find.text(h.shownName));
        expect(name, findsOneWidget, reason: h.name);
        final p = tester.renderObject<RenderParagraph>(name);
        expect(p.didExceedMaxLines, isFalse, reason: h.name);
        expect(
          p.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(p.size.width + 0.5),
          reason: h.name,
        );
      }
      // The level left the line; the chip still says it to a reader.
      expect(
        find.bySemanticsLabel(RegExp(r'level \d+ — tap for abilities')),
        findsNWidgets(director.state.heroes.length),
      );
    });
  }

  _testHome('party strip keeps the level at 1.0', (tester) async {
    final (director, _) = await _pump(tester, const Size(360, 780), 1.0);
    final hud = find.byType(PartyCornerHud);
    for (final h in director.state.heroes) {
      expect(
        find.descendant(of: hud, matching: find.text('L${h.level}')),
        findsWidgets,
      );
    }
  });


  // Fynd 16: BUY FLASK, God Hand Damage/CD and the 5th slot were brown,
  // while every other buy is muted gold.
  test('gold buy style reads 4.5:1 on both gradient stops', () {
    for (final bg in [GameTheme.buyGoldTop, GameTheme.buyGoldBottom]) {
      expect(_contrast(GameTheme.buyGoldText, bg), greaterThanOrEqualTo(4.5));
    }
  });

  GameButton buttonWith(WidgetTester tester, Pattern label) =>
      tester.widget<GameButton>(
        find.byWidgetPredicate(
          (w) => w is GameButton && w.label.startsWith(label),
        ),
      );

  _testHome('BUY FLASK is a gold buy when affordable', (tester) async {
    await _pump(tester, const Size(360, 780), 1);
    await tester.tap(find.text('MARKET').first);
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Flasks').first);
    await _settle(tester);
    final buy = buttonWith(tester, 'BUY FLASK');
    expect(buy.onPressed, isNotNull);
    expect(buy.style, GameButtonStyle.gold);
  });

  // Audit 100 F017: essence prices use the essence face (was gold, which
  // read as a gold price).
  _testHome('God Hand Damage / CD are essence buys', (tester) async {
    final (director, router) = await _pump(tester, const Size(360, 780), 1);
    router.open(MenuRoute.essence, essence: EssencePanel.keep);
    router.pushSub();
    await _settle(tester);
    expect(director.state.essence, greaterThan(0));
    expect(buttonWith(tester, 'Damage').style, GameButtonStyle.essence);
    expect(buttonWith(tester, 'CD').style, GameButtonStyle.essence);
  });

}

/// `MenuChrome.sheetHandle`: a 44x4 bar.
Finder _handles() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints == const BoxConstraints.tightFor(width: 44, height: 4),
);
