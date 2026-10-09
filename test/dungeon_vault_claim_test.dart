import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/ui/shell/dungeon_top_hud.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9, 12);

  testWidgets('a ready vault shows CLAIM on the cave', (tester) async {
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
      metaDepth: fresh.metaDepth.copyWith(
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
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fresh = GameLogic.createInitialState(now: now).copyWith(
      inDungeon: true,
    );
    final director = GameDirector.preview(initialState: fresh);
    await director.boot();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DungeonTopHud(
            state: fresh,
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
