import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/ui/menu_chrome.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/market_listings_service.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_nav_bar.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/upgrade_panel.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';

import 'shell_golden_harness.dart';

/// SPLIT MARKET under the fight: the first listing and its buy button are
/// whole on screen without scrolling, at 1.0 and the 1.45 text cap, on the
/// A56 and the small 360x640 surface. The chip rows above it must not push
/// it below the fold.
Future<GameDirector> _director() => withShellGoldenWeek(() async {
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
  final d = GameDirector.preview(
    initialState: MarketListingsService.regenerate(GameLogic.enterDungeon(s)),
  );
  await d.boot(deferCombatLoop: true);
  d.dismissOfflineSummary();
  d.clearToast();
  return d;
});

void main() {
  setUpAll(() async => ensureShellGoldenFonts());

  for (final size in const [Size(360, 780), Size(360, 640)]) {
    for (final scale in [1.0, GameTheme.typeScaleMax]) {
      testWidgets('first MARKET listing is whole above the fold '
          '${size.width.toInt()}x${size.height.toInt()} @$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final director = await _director();
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
        await tester.tap(find.text('MARKET').first);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(tester.takeException(), isNull);
        expect(director.state.marketListings, isNotEmpty);

        final market = find.byType(MarketOverlay);
        expect(market, findsOneWidget);
        final viewport = tester.getRect(
          find.descendant(of: market, matching: find.byType(Scrollable)).first,
        );
        final nav = tester.getRect(find.byType(HomeNavBar));
        // The fold is the top of the raised FIGHT circle: the bar top
        // minus how far FIGHT rises above it.
        final navContext = tester.element(find.byType(HomeNavBar));
        final fold =
            nav.bottom -
            HomeNavBar.labelHeight(navContext) -
            HomeNavBar.fightOverhang(navContext);
        final card = tester.getRect(
          find
              .descendant(of: market, matching: find.byType(PowerUpgradeRow))
              .first,
        );
        final buy = tester.getRect(
          find
              .descendant(
                of: market,
                matching: find.byType(PowerUpgradePriceChip),
              )
              .first,
        );
        for (final r in [card, buy]) {
          expect(r.top, greaterThanOrEqualTo(viewport.top - 0.5));
          expect(r.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
          expect(r.bottom, lessThanOrEqualTo(fold + 0.5));
          expect(r.right, lessThanOrEqualTo(size.width));
        }
        // The controls moved to the header: whole, 48x48 taps, on screen,
        // no sideways scroll, and the tab labels are not cut.
        final header = find.byType(MarketHeaderControls);
        expect(header, findsOneWidget);
        final reroll = find.bySemanticsLabel(
          RegExp(r'^(Reroll \d|Fresh stock)'),
        );
        expect(reroll, findsOneWidget);
        for (final ink
            in find
                .descendant(of: header, matching: find.byType(InkWell))
                .evaluate()) {
          final r = tester.getRect(find.byWidget(ink.widget));
          expect(r.width, greaterThanOrEqualTo(GameTheme.primaryTouch - 0.01));
          expect(r.height, greaterThanOrEqualTo(GameTheme.primaryTouch - 0.01));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(size.width));
        }
        expect(
          find.descendant(
            of: find.byType(UpgradePanel),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Scrollable &&
                  (w.axisDirection == AxisDirection.left ||
                      w.axisDirection == AxisDirection.right),
            ),
          ),
          findsNothing,
        );
        final filter = find.descendant(
          of: header,
          matching: find.text(MarketHeaderControls.filterUpgradesShort),
        );
        expect(filter, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(filter).didExceedMaxLines,
          isFalse,
        );
        expect(tester.getRect(filter).right, lessThanOrEqualTo(size.width));
        for (final label in ['FORGE', 'CAMP', 'MARKET']) {
          final para = tester.renderObject<RenderParagraph>(
            find
                .descendant(
                  of: find.byType(UpgradePanel),
                  matching: find.text(label),
                )
                .first,
          );
          expect(para.didExceedMaxLines, isFalse, reason: label);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        director.dispose();
        router.dispose();
        await tester.pump();
      });
    }
  }

  // Same fold rule for the other two split tabs (polish 6 #14): at 640
  // and 1.45 the CAMP free-level chip and the SCROLLS rail used to push
  // the first card under FIGHT.
  for (final tab in const ['FORGE', 'CAMP']) {
    for (final size in const [Size(360, 780), Size(360, 640)]) {
      for (final scale in [1.0, GameTheme.typeScaleMax]) {
        testWidgets('first $tab card is whole above the fold '
            '${size.width.toInt()}x${size.height.toInt()} @$scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final director = await _director();
          final router = MenuRouter();
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: HomeShell(
                director: director,
                router: router,
                onLeave: () {},
              ),
            ),
          );
          await tester.pump();
          await tester.tap(
            find
                .descendant(
                  of: find.byType(UpgradePanel),
                  matching: find.text(tab),
                )
                .first,
          );
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          expect(tester.takeException(), isNull);

          final body = find.byType(
            tab == 'FORGE' ? ForgeOverlay : SanctuaryOverlay,
          );
          expect(body, findsOneWidget);
          final viewport = tester.getRect(
            find.descendant(of: body, matching: find.byType(Scrollable)).first,
          );
          final navContext = tester.element(find.byType(HomeNavBar));
          final nav = tester.getRect(find.byType(HomeNavBar));
          final fold =
              nav.bottom -
              HomeNavBar.labelHeight(navContext) -
              HomeNavBar.fightOverhang(navContext);
          final card = tester.getRect(
            find
                .descendant(of: body, matching: find.byType(PowerUpgradeRow))
                .first,
          );
          final buy = tester.getRect(
            find
                .descendant(
                  of: body,
                  matching: find.byType(PowerUpgradePriceChip),
                )
                .first,
          );
          for (final r in [card, buy]) {
            expect(r.top, greaterThanOrEqualTo(viewport.top - 0.5));
            expect(r.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
            expect(r.bottom, lessThanOrEqualTo(fold + 0.5));
            expect(r.right, lessThanOrEqualTo(size.width));
          }
          for (final label in ['FORGE', 'CAMP', 'MARKET']) {
            final para = tester.renderObject<RenderParagraph>(
              find
                  .descendant(
                    of: find.byType(UpgradePanel),
                    matching: find.text(label),
                  )
                  .first,
            );
            expect(para.didExceedMaxLines, isFalse, reason: label);
          }
          if (tab == 'CAMP' && scale > 1.2) {
            // Large text: the same compact button sits under the first
            // card (audit F058: no full-width chip at 1.45).
            final chip = tester.getRect(
              find.byKey(UpgradePanel.campWatchListKey),
            );
            expect(chip.top, greaterThanOrEqualTo(card.bottom));
            expect(chip.width, greaterThanOrEqualTo(GameTheme.primaryTouch - 0.01));
            expect(find.byKey(UpgradePanel.campWatchKey), findsNothing);
            expect(find.text('Watch · free level'), findsNothing);
          }
          if (tab == 'CAMP' && scale <= 1.2) {
            // The free level moved to the header: one 48x48 tap, on screen.
            final watch = find.byKey(UpgradePanel.campWatchKey);
            expect(watch, findsOneWidget);
            final r = tester.getRect(watch);
            expect(r.width, greaterThanOrEqualTo(GameTheme.primaryTouch - 0.01));
            expect(r.height, greaterThanOrEqualTo(GameTheme.primaryTouch - 0.01));
            expect(r.right, lessThanOrEqualTo(size.width));
            expect(find.text('Watch · free level'), findsNothing);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          director.dispose();
          router.dispose();
          await tester.pump();
        });
      }
    }
  }

  testWidgets('SPLIT MARKET flask dropdown buys a flask and sets the filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final director = await _director();
    final router = MenuRouter();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(director: director, router: router, onLeave: () {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('MARKET').first);
    await tester.pump(const Duration(milliseconds: 300));
    final upgradesShown = find.byType(PowerUpgradeRow).evaluate().length;
    expect(
      find.descendant(
        of: find.byType(MarketHeaderControls),
        matching: find.text(MarketHeaderControls.filterUpgradesShort),
      ),
      findsOneWidget,
    );

    // The flask sheet is flasks only; the filter is its own header chip
    // that flips in place (audit F047).
    await tester.tap(find.bySemanticsLabel('Flasks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BUY FLASK'), findsOneWidget);
    expect(find.text('ALL GEAR'), findsNothing);
    await tester.tap(find.byKey(MenuChrome.sheetCloseKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('BUY FLASK'), findsNothing);
    await tester.tap(find.byKey(MarketHeaderControls.filterKey));
    await tester.pumpAndSettle();
    // The chip says which filter is on without opening the sheet.
    final chip = find.byType(MarketHeaderControls);
    expect(
      find.descendant(
        of: chip,
        matching: find.text(MarketHeaderControls.filterAllShort),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: chip,
        matching: find.text(MarketHeaderControls.filterUpgradesShort),
      ),
      findsNothing,
    );
    expect(
      find.byType(PowerUpgradeRow).evaluate().length,
      greaterThanOrEqualTo(upgradesShown),
    );

    final gold = director.state.gold;
    final flaskCost = GameLogic.marketFlaskCost(director.state);
    await tester.tap(find.bySemanticsLabel('Flasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('BUY FLASK'));
    await tester.pumpAndSettle();
    expect(director.state.gold, gold - flaskCost);

    await tester.pumpWidget(const SizedBox.shrink());
    director.dispose();
    router.dispose();
    await tester.pump();
  });
}
