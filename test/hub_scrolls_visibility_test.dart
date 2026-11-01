import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hub_screen.dart';

/// Hub cards stay quiet so the SCROLLS row is the thing under test.
GameState _quiet(GameState state) {
  return state.copyWith(
    seenChangelogVersion: MetaSystems.currentVersion,
    seenTips: const ['discord_thanks', 'first_run'],
    metaDepth: state.metaDepth.copyWith(
      notifyPrompted: true,
      reviewPrompted: true,
    ),
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 21);

  Future<void> pumpHub(WidgetTester tester, GameState state) async {
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: HubScreen(
                  director: director,
                  router: router,
                  onEnterDungeon: (_) {},
                ),
              ),
              const SizedBox(height: GameTheme.bottomNavHeight),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    // HubScreen waits 450ms, then offers cards. Quiet saves decline them.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('SCROLLS stays off the hub until the first boss', (tester) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) overflows.add(text);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fresh = _quiet(GameLogic.createInitialState(now: now));
    expect(MenuTabs.showScrolls(fresh), isFalse);
    await pumpHub(tester, fresh);
    expect(find.bySemanticsLabel(RegExp(r'^SCROLLS')), findsNothing);
    expect(find.text('SCROLLS'), findsNothing);
    expect(find.text('Watch an ad for 1 ticket'), findsNothing);
    expect(overflows, isEmpty);
  });

  testWidgets('after the first boss SCROLLS is one tap under the cave button', (
    tester,
  ) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) overflows.add(text);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bossed = _quiet(
      GameLogic.createInitialState(now: now).copyWith(
        bossVictories: 1,
        highestFloorCleared: 2,
      ),
    );
    expect(MenuTabs.showScrolls(bossed), isTrue);
    await pumpHub(tester, bossed);

    final scrolls = find.bySemanticsLabel('SCROLLS. SCROLLS');
    expect(scrolls, findsOneWidget);
    expect(find.text('Watch an ad for 1 ticket'), findsOneWidget);

    final rect = tester.getRect(scrolls);
    final hubBottom = 780 - GameTheme.bottomNavHeight;
    expect(rect.top, greaterThan(0));
    expect(rect.bottom, lessThan(hubBottom));
    expect(rect.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(rect.width, greaterThan(200));

    await tester.tap(scrolls);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Scroll of Rest'), findsOneWidget);
    expect(find.text('WATCH AD · +1 TICKET'), findsNothing);
    expect(find.text('PREVIEW +1 TICKET'), findsOneWidget);
    expect(overflows, isEmpty);
  });

  testWidgets('Ascend keeps the SCROLLS row after boss victories reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ascended = _quiet(
      GameLogic.createInitialState(now: now).copyWith(ascensionLevel: 1),
    );
    expect(ascended.bossVictories, 0);
    expect(MenuTabs.showScrolls(ascended), isTrue);
    await pumpHub(tester, ascended);
    expect(find.bySemanticsLabel('SCROLLS. SCROLLS'), findsOneWidget);
    expect(find.text('Watch an ad for 1 ticket'), findsOneWidget);
  });
}
