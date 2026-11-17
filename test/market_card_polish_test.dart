import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/market_listings_service.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';

/// Polish 4: MARKET rows use the upgrade card (48 dp icon tile, gold buy
/// face in a 76x48 tap) and the reroll chip fits without a sideways scroll.
Future<GameDirector> _pumpMarket(WidgetTester tester, double scale) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state =
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
      ).copyWith(
        homeLayout: HomeLayout.home,
        homePanelFull: false,
        gold: 5000,
        highestFloorCleared: 5,
        ascensionLevel: 1,
        bossVictories: 1,
      );
  final director = GameDirector.preview(
    initialState: MarketListingsService.regenerate(state),
  );
  addTearDown(director.dispose);
  director.ensureMarketListings();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 780),
        textScaler: TextScaler.linear(scale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              height: 300,
              child: MarketOverlay(director: director, inlineUnderFight: true),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return director;
}

void main() {
  for (final scale in [1.0, 1.45]) {
    testWidgets('market chips wrap without a sideways scroll at $scale', (
      tester,
    ) async {
      await _pumpMarket(tester, scale);
      expect(tester.takeException(), isNull);
      final sideways = find.descendant(
        of: find.byType(MarketOverlay),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Scrollable &&
              (w.axisDirection == AxisDirection.right ||
                  w.axisDirection == AxisDirection.left),
        ),
      );
      expect(sideways, findsNothing);
      final reroll = find.textContaining('Reroll ');
      final fresh = find.text('Fresh stock');
      final chip = reroll.evaluate().isNotEmpty ? reroll : fresh;
      expect(chip, findsOneWidget);
      final r = tester.getRect(chip);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(360));
      // The whole label is laid out on one line, not cut.
      final para = tester.renderObject<RenderParagraph>(
        find.descendant(of: chip, matching: find.byType(RichText)).first,
      );
      expect(para.didExceedMaxLines, isFalse);
    });
  }

  testWidgets('market rows use the upgrade card and a 76x48 buy tap', (
    tester,
  ) async {
    final director = await _pumpMarket(tester, 1);
    final listings = director.state.marketListings;
    expect(listings, isNotEmpty);
    final tiles = find.byType(UpgradeIconTile);
    expect(tiles, findsWidgets);
    final tile = tester.getSize(tiles.first);
    expect(tile.width, GameTheme.primaryTouch);
    expect(tile.height, GameTheme.primaryTouch);
    final chips = find.byType(PowerUpgradePriceChip);
    expect(chips, findsWidgets);
    final tap = tester.getSize(
      find.descendant(of: chips.first, matching: find.byType(InkWell)).first,
    );
    expect(tap.width, greaterThanOrEqualTo(PowerUpgradePriceChip.minTapWidth));
    expect(
      tap.height,
      greaterThanOrEqualTo(PowerUpgradePriceChip.minTapHeight),
    );
    expect(find.byType(PowerUpgradeRow), findsWidgets);
  });
}
