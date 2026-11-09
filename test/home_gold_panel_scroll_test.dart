import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/market_overlay.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';

void main() {
  testWidgets('inline SPLIT forge lists all tracks without All tracks link', (
    tester,
  ) async {
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      gold: 5000,
      highestFloorCleared: 2,
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: ForgeOverlay(
              director: director,
              inlineUnderFight: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('All tracks'), findsNothing);
    expect(find.text('AP'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('MASTERY'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MASTERY'), findsOneWidget);
  });

  testWidgets('inline SPLIT camp lists all tracks and scrolls to Lore Font', (
    tester,
  ) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      essence: 500,
      ascensionLevel: 1,
      bossVictories: 1,
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: SanctuaryOverlay(
              director: director,
              inlineUnderFight: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('All tracks'), findsNothing);
    expect(find.text('Gold Find'), findsOneWidget);
    expect(find.text('War Altar (Attack)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Lore Font'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lore Font'), findsOneWidget);
    expect(find.text('15e'), findsWidgets);
  });

  testWidgets('inline SPLIT market scrolls listings and shows flask chips', (
    tester,
  ) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 4)),
    ).copyWith(
      homeLayout: HomeLayout.home,
      homePanelFull: false,
      gold: 50000,
      highestFloorCleared: 5,
      ascensionLevel: 1,
      bossVictories: 1,
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    director.ensureMarketListings();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 260,
            child: MarketOverlay(
              director: director,
              inlineUnderFight: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All listings'), findsNothing);
    expect(find.textContaining('Flask'), findsWidgets);
    expect(find.byType(ListView), findsOneWidget);

    if (director.state.marketListings.length > 1) {
      await tester.scrollUntilVisible(
        find.text(director.state.marketListings.last.item.name),
        120,
        scrollable: find.byType(Scrollable).first,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
