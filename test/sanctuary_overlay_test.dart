import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/ad_free_nudge.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/shell/sanctuary_overlay.dart';

void main() {
  testWidgets('CAMP stays up when a track costs more than essence', (
    tester,
  ) async {
    // Gold Find Lv68 costs 831e. 745e matches the live wallet that painted
    // the red "Invalid argument(s): 1" screen after bulk buys.
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        essence: 745,
        ascensionLevel: 1,
        sanctuaryGoldLevel: 68,
      ),
    );
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SanctuaryOverlay(director: director),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Gold Find'), findsWidgets);
    expect(find.textContaining('War Altar'), findsWidgets);
  });

  testWidgets('CAMP offers Ad-free after the third free level', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final day = AdBoost.utcDayKey(now);
    final base = GameLogic.createInitialState(now: now);
    final spent = base.copyWith(
      ascensionLevel: 1,
      essence: 40,
      metaDepth: base.metaDepth.copyWith(
        rewardedWatchCount: AdFreeNudge.watchThreshold,
        campAdUtc: day,
        campAdClaims: GameLogic.campAdDailyCap,
      ),
    );
    final director = GameDirector.preview(initialState: spent);
    final router = MenuRouter();
    await director.boot();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 220,
            child: SanctuaryOverlay(
              director: director,
              inlineUnderFight: true,
              onOpenAdFree: () {
                director.openAdFreeFromScrollsNudge();
                router.open(MenuRoute.shop);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    try {
      expect(find.text('Watch · free level'), findsNothing);
      expect(find.text(AdFreeNudge.line), findsOneWidget);
      await tester.tap(find.text(AdFreeNudge.line));
      await tester.pump();
      expect(router.route, MenuRoute.shop);
      expect(director.state.metaDepth.adFreeNudgeShown, isTrue);
    } finally {
      director.dispose();
      router.dispose();
    }
  });
}
