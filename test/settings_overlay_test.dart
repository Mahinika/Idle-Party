import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/funnel_analytics.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/ui/shell/power_meta_pillars.dart';
import 'package:idle_party/ui/shell/settings_overlay.dart';

void main() {
  test('credits name the studio and owned art', () {
    expect(MoreList.creditsBody, contains('Cognifox Studio'));
    expect(MoreList.creditsBody.toLowerCase(), isNot(contains('kenney')));
  });

  testWidgets('settings splits sound display bag and account into local tabs', (
    tester,
  ) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);

    await tester.pumpWidget(_host(director));

    expect(find.text('Mute all sound'), findsOneWidget);
    expect(find.text('UI text scale'), findsNothing);

    await tester.tap(_tab('DISPLAY'));
    await tester.pumpAndSettle();
    expect(find.text('UI text scale'), findsOneWidget);
    expect(find.text('Colorblind-friendly combat numbers'), findsOneWidget);
    expect(find.text('Mute all sound'), findsNothing);

    await tester.tap(_tab('BAG'));
    await tester.pumpAndSettle();
    expect(find.text('AUTO-SELL · GOLD'), findsOneWidget);
    expect(find.text('UI text scale'), findsNothing);

    await tester.tap(_tab('ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('PLAY NOTES (LOCAL)'), findsOneWidget);
    expect(find.text('Away reminders'), findsNothing);
    expect(find.text('AUTO-SELL · GOLD'), findsNothing);
    expect(find.text('RATE ON PLAY'), findsOneWidget);
    expect(find.text('JOIN DISCORD'), findsOneWidget);
  });

  testWidgets('bag cleanup deep link opens the BAG tab', (tester) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);

    await tester.pumpWidget(_host(director, bagFiltersScrollNonce: 1));
    await tester.pumpAndSettle();

    expect(find.text('AUTO-SELL · GOLD'), findsOneWidget);
    expect(find.text('Mute all sound'), findsNothing);
  });

  testWidgets('ACCOUNT shows away reminders after first loot', (tester) async {
    final now = DateTime.utc(2026, 9, 12, 14);
    var state = FunnelAnalytics.onNewInstall(
      GameLogic.createInitialState(now: now),
      now,
    ).state;
    state = FunnelAnalytics.onFirstEnter(
      state,
      now,
      dungeonId: 'sandy',
    ).state;
    state = FunnelAnalytics.onFirstReward(state).state;
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(_host(director));
    await tester.tap(_tab('ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('Away reminders'), findsOneWidget);
  });

  test('CODEX chase asks for the codex page, not the guide', () {
    final router = MenuRouter();
    addTearDown(router.dispose);
    router.open(MenuRoute.more, more: MoreSection.info, infoPane: 1);
    expect(router.moreSection, MoreSection.info);
    expect(router.moreInfoPane, 1);
    router.open(MenuRoute.more, more: MoreSection.info);
    expect(router.moreInfoPane, 0);
  });

  testWidgets('discovered monster shows on the codex page', (tester) async {
    final state = GameLogic.createInitialState().copyWith(
      highestFloorCleared: 1,
      codexEnemies: const ['Earth Kraken'],
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: MoreList(
              director: director,
              section: MoreSection.info,
              initialInfoPane: 1,
              onSectionChanged: (_) {},
              onOpenWhatsNew: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Earth Kraken'), findsOneWidget);
    expect(find.text('MONSTERS (1)'), findsOneWidget);
    expect(find.text('QUESTS'), findsOneWidget);
    expect(find.text('BACK'), findsNothing);
  });

  testWidgets('MORE quests is a tab, not a BACK sheet', (tester) async {
    final state = GameLogic.createInitialState().copyWith(
      highestFloorCleared: 1,
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: MoreList(
              director: director,
              section: MoreSection.quests,
              onSectionChanged: (_) {},
              onOpenWhatsNew: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('BACK'), findsNothing);
    expect(find.textContaining('claim while you dungeon'), findsOneWidget);
  });
}

Widget _host(GameDirector director, {int bagFiltersScrollNonce = 0}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 700,
        child: SettingsOverlay(
          director: director,
          onClose: () {},
          bagFiltersScrollNonce: bagFiltersScrollNonce,
        ),
      ),
    ),
  );
}

Finder _tab(String label) {
  return find.descendant(of: find.byType(TabBar), matching: find.text(label));
}
