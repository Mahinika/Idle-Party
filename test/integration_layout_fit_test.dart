import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/first_climb_coach.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/models/apex_craft.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';
import 'package:idle_party/ui/shell/craft_overlay.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/wipe_overlay.dart';

/// Combined UI on a short phone. Safe area is 44 top / 34 bottom.
void main() {
  const scales = <double>[1, 1.4, 2];

  void bindPhone(WidgetTester tester, double scale) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.viewPadding = const FakeViewPadding(top: 88, bottom: 68);
    tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
  }

  void release(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }

  testWidgets('nav and first-climb line fit 360x640 at scale 1, 1.4, and 2', (
    tester,
  ) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    ).copyWith(homeLayout: HomeLayout.home);
    final line = FirstClimbCoach.line(state, inDungeon: true);
    expect(line, isNotNull);
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    addTearDown(() => release(tester));
    for (final scale in scales) {
      bindPhone(tester, scale);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(director: director, router: router, onLeave: () {}),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'nav scale $scale');
      expect(find.text('HEROES'), findsOneWidget);
      expect(find.text('FIGHT'), findsOneWidget);
      expect(find.text(line!), findsOneWidget);
    }
  });

  testWidgets('CRAFT fits 360x640 at scale 1, 1.4, and 2', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    );
    addTearDown(() => release(tester));
    await director.boot(deferCombatLoop: true);
    for (final scale in scales) {
      bindPhone(tester, scale);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CraftOverlay(director: director)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'craft scale $scale');
      expect(find.text('CRAFT R1'), findsOneWidget);
    }
    director.dispose();
  });

  testWidgets('Welcome Back fits 360x640 at scale 1, 1.4, and 2', (
    tester,
  ) async {
    final state = GameLogic.createInitialState(now: DateTime(2026, 11, 7));
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    addTearDown(() => release(tester));
    final summary = OfflineProgressResult(
      state: state,
      secondsApplied: 120,
      goldGained: 40,
      essenceGained: 1,
      roomsCleared: 2,
      highestFloorDelta: 0,
      bossDelta: 0,
      secondsAway: 120,
      wasInDungeon: true,
      materialsGained: const {ApexCraft.slagId: 2},
    );
    expect(summary.materialsLine, contains('Apex Slag'));
    for (final scale in scales) {
      bindPhone(tester, scale);
      director.uiFeedback.presentOffline(summary);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOfflineProgressDialog(context, director),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'welcome scale $scale');
      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text(summary.materialsLine), findsOneWidget);
      await tester.tap(find.text('ENTER DUNGEON'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('wipe actions fit 360x640 at scale 1, 1.4, and 2', (
    tester,
  ) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 7)),
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(() => release(tester));
    await director.boot(deferCombatLoop: true);
    for (final scale in scales) {
      bindPhone(tester, scale);
      director.debugOpenWipeChoice();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DungeonWipePanel(
              director: director,
              farm: false,
              dailyEcho: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'wipe scale $scale');
      expect(find.text('RETRY FLOOR'), findsOneWidget);
      expect(
        find.text(FirstClimbCoach.wipeLine(director.state)!),
        findsOneWidget,
      );
    }
    director.dispose();
  });
}
