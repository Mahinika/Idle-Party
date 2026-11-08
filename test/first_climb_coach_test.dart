import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/first_climb_coach.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/first_session_tips.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  test(
    'a new save teaches the Sandy fight and keeps the boss on floor 2',
    () async {
      final director = GameDirector.preview();
      await director.boot();
      await director.startNewGame(HeroSpecs.starterUnlocked);
      expect(director.state.heroes, hasLength(3));
      expect(GameLogic.firstBossFloor, 2);
      expect(GameLogic.firstBossPending(director.state), isTrue);
      expect(GameLogic.bossFloorFor(director.state), 2);
      expect(
        FirstClimbCoach.line(director.state, inDungeon: false),
        isNull,
        reason: 'the porch already says Tap ENTER',
      );
      expect(
        FirstSessionTips.nextTipId(director.state, inDungeon: false),
        'first_run',
      );

      director.enterDungeon(dungeonId: 'sandy');
      expect(director.state.inDungeon, isTrue);
      expect(director.state.dungeonId, 'sandy');
      expect(director.state.currentRoom.floorNumber, 1);
      final fight = FirstClimbCoach.line(director.state, inDungeon: true);
      expect(
        fight,
        'Your party keeps fighting if you close the app. Boss on floor 2.',
      );
      expect(
        FirstClimbCoach.wipeLine(director.state),
        'The boss is still on floor 2.',
      );

      final chase = HubChase.forState(director.state, now: now);
      expect(chase.title, contains('Grow the party'));
      expect(chase.detail, contains('keeps fighting if you close the app'));
      expect(chase.detail, contains('floor 2'));
      director.dispose();
    },
  );

  test('a save with no coach field still shows the first fight line', () {
    final fresh = GameLogic.createInitialState(now: now);
    final legacy = Map<String, dynamic>.from(fresh.toJson())
      ..remove('seenTips');
    final loaded = GameLogic.stateFromJson(legacy);
    final fight = GameLogic.enterDungeon(loaded, dungeonId: 'sandy');
    expect(FirstClimbCoach.line(fight, inDungeon: true), contains('floor 2'));
    final ascended = loaded.copyWith(ascensionLevel: 1);
    expect(FirstClimbCoach.line(ascended, inDungeon: true), isNull);
    expect(
      FirstClimbCoach.line(loaded.copyWith(bossVictories: 1), inDungeon: true),
      isNull,
    );
  });

  test(
    'the first vault claim stays in the cave and then names the boss',
    () async {
      var state = GameLogic.enterDungeon(
        GameLogic.createInitialState(
          now: now,
        ).copyWith(homeLayout: HomeLayout.home),
        dungeonId: 'sandy',
      );
      state = state.copyWith(
        highestFloorCleared: 1,
        lifetimeGoldEarned: 8,
        metaDepth: state.metaDepth.copyWith(
          dailyVaultDate: MetaSystems.dailyDateKey(DateTime.now().toUtc()),
          dailyVaultClears: GameLogic.dailyVaultClearTarget,
        ),
      );
      final director = GameDirector.preview(initialState: state);
      await director.boot();
      expect(GameLogic.canClaimDailyVault(director.state), isTrue);
      expect(GameLogic.showDailyChase(director.state), isFalse);
      expect(
        FirstClimbCoach.line(director.state, inDungeon: true),
        'Tap CLAIM. The boss is on floor 2.',
      );
      expect(
        FightSeamRails.visibleEntries(
          director.state,
          director,
        ).map((e) => e.id),
        contains('vault'),
      );
      final before = director.state.essence;
      director.claimDailyVault();
      expect(director.state.inDungeon, isTrue);
      expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
      expect(director.state.essence, greaterThan(before));
      expect(GameLogic.checkInActive(director.state), isFalse);
      expect(
        FirstClimbCoach.line(director.state, inDungeon: true),
        'Floor 1 paid out. They keep fighting if you close the app. Boss on floor 2.',
      );
      expect(
        FirstClimbCoach.wipeLine(director.state),
        'The boss is still on floor 2.',
      );
      director.dispose();
    },
  );

  test('camp names CLAIM VAULT and a later floor names the boss', () {
    final camp = GameLogic.createInitialState(now: now).copyWith(
      homeLayout: HomeLayout.home,
      highestFloorCleared: 1,
      lifetimeGoldEarned: 8,
    );
    final ready = camp.copyWith(
      metaDepth: camp.metaDepth.copyWith(
        dailyVaultDate: MetaSystems.dailyDateKey(now),
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
      ),
    );
    expect(
      FirstClimbCoach.line(ready, inDungeon: false),
      'Tap CLAIM VAULT. The boss is on floor 2.',
    );
    expect(
      HubChase.forState(ready, now: now).kind,
      HubChaseKind.claimDailyVault,
    );

    final bossFloor = GameLogic.enterDungeon(camp, dungeonId: 'sandy');
    expect(bossFloor.currentRoom.floorNumber, 2);
    expect(
      FirstClimbCoach.line(bossFloor, inDungeon: true),
      'This is the boss. They keep fighting if you close the app.',
    );
  });

  testWidgets('home fight shows the first line and no claim yet', (
    tester,
  ) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(
        now: now,
      ).copyWith(homeLayout: HomeLayout.home, homePanelFull: true),
      dungeonId: 'sandy',
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(_home(director, router));
    await tester.pump();
    expect(
      find.text(
        'Your party keeps fighting if you close the app. Boss on floor 2.',
      ),
      findsOneWidget,
    );
    expect(find.text('CLAIM'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home fight CLAIM pays the vault and keeps the boss ahead', (
    tester,
  ) async {
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(
        now: now,
      ).copyWith(homeLayout: HomeLayout.home, homePanelFull: true),
      dungeonId: 'sandy',
    );
    state = state.copyWith(
      highestFloorCleared: 1,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultDate: MetaSystems.dailyDateKey(DateTime.now().toUtc()),
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
      ),
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    await director.boot();

    await tester.pumpWidget(_home(director, router));
    await tester.pump();
    expect(find.text('Tap CLAIM. The boss is on floor 2.'), findsOneWidget);
    expect(find.text('CLAIM'), findsOneWidget);

    final before = director.state.essence;
    await tester.tap(find.text('CLAIM'));
    await tester.pump();
    expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
    expect(director.state.essence, greaterThan(before));
    expect(director.state.inDungeon, isTrue);
    expect(
      find.text(
        'Floor 1 paid out. They keep fighting if you close the app. Boss on floor 2.',
      ),
      findsOneWidget,
    );
    expect(find.text('CLAIM'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    director.dispose();
    router.dispose();
  });
}

Widget _home(GameDirector director, MenuRouter router) {
  return MaterialApp(
    home: AnimatedBuilder(
      animation: director,
      builder: (context, _) =>
          HomeShell(director: director, router: router, onLeave: () {}),
    ),
  );
}
