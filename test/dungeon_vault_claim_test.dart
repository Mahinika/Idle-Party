import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';

void main() {
  testWidgets('a ready vault shows CLAIM on the cave', (tester) async {
    final now = DateTime.now().toUtc();
    final day = MetaSystems.dailyDateKey(now);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fresh = GameLogic.ensureWeeklyContract(
      GameLogic.createInitialState(now: now),
      now: now,
    );
    final ready = fresh.copyWith(
      inDungeon: true,
      lastUpdated: DateTime.now(),
      metaDepth: fresh.metaDepth.copyWith(
        dailyVaultDate: day,
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    final director = GameDirector.preview(initialState: ready);
    await director.boot();
    expect(director.isLoading, isFalse);
    final shown = director.state;
    expect(GameLogic.canClaimDailyVault(shown), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DungeonTopHud(
            state: shown,
            director: director,
            onOpenSettings: () {},
            onOpenContracts: () {},
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Claim the vault before the day ends'),
      findsOneWidget,
    );
    expect(find.text('CLAIM'), findsOneWidget);

    await tester.tap(find.text('CLAIM'));
    await tester.pump();

    expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
    expect(director.state.essence, greaterThan(shown.essence));
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an empty vault hides CLAIM on the cave', (tester) async {
    final now = DateTime.now().toUtc();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fresh = GameLogic.createInitialState(now: now).copyWith(
      inDungeon: true,
      lastUpdated: DateTime.now(),
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
        dailyVaultDate: MetaSystems.dailyDateKey(now),
      ),
    );
    final director = GameDirector.preview(initialState: fresh);
    await director.boot();
    final shown = director.state;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DungeonTopHud(
            state: shown,
            director: director,
            onOpenSettings: () {},
            onOpenContracts: () {},
          ),
        ),
      ),
    );

    expect(find.text('CLAIM'), findsNothing);
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
