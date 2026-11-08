import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/nav_intent.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/ui/shell/home/home_catalog.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

void main() {
  test('MENU grid keeps the fight-rail jobs', () {
    final ids = HomeCatalog.entries.map((e) => e.id).toSet();
    expect(ids, containsAll([
      'menu_scrolls',
      'menu_watch',
      'menu_vault',
      'menu_daily',
      'menu_wisp',
      'menu_pouch',
      'menu_update',
      'menu_floors',
    ]));
  });

  test('endgame wipe opens MAP on the hunts', () {
    const line = 'Farm Rift R3 may be high — dial Farm Rift tier on ENDGAME';
    final nav = WipeAdvice.hubNavFor(line);
    expect(nav, NavIntent.endgame);
    expect(WipeAdvice.hubCtaLabelFor(line), 'OPEN ENDGAME');
    expect(
      WipeAdvice.hubNavFor('Spire climb is steep — PB F40; next milestone F50'),
      NavIntent.endgame,
    );
  });

  testWidgets('town shows FORGE; gold intent opens MARKET listings', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 5);
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      homeLayout: HomeLayout.home,
      bossVictories: 1,
      highestFloorCleared: 2,
      seenChangelogVersion: MetaSystems.currentVersion,
      seenTips: const ['first_run', 'discord_thanks'],
      metaDepth: base.metaDepth.copyWith(
        reviewPrompted: true,
        notifyPrompted: true,
      ),
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeShell(director: director, router: router, onLeave: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('FORGE'), findsWidgets);
    expect(tester.takeException(), isNull);

    router.open(MenuRoute.gold, gold: GoldPanel.market);
    expect(router.route, MenuRoute.gold);
    expect(router.goldPanel, GoldPanel.market);
    expect(
      find.text('FORGE opens after the first boss (F2).'),
      findsNothing,
    );
  });
}
