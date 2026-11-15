import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/home_gold_dock.dart';
import 'package:idle_party/ui/shell/home/home_room_phase.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/spatial_dungeon_view.dart';

import 'shell_golden_harness.dart';

/// 1.13.18 screen review: mid-room the home chrome steps aside for the
/// fight and comes back between rooms.
void main() {
  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  Widget shot(Widget body, {double scale = 1, Key? key}) {
    return RepaintBoundary(
      key: key,
      child: MediaQuery(
        data: shellGoldenMedia.copyWith(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(backgroundColor: GameTheme.ink, body: body),
        ),
      ),
    );
  }

  /// Runs the room clock past [HomeRoomPhaseBuilder.underwayAfter].
  Future<void> runRoom(WidgetTester tester, GameDirector director) async {
    director.spatial!.combatElapsed +=
        HomeRoomPhaseBuilder.underwayAfter + 0.5;
    director.combatFrame.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tearDownShell(WidgetTester tester, GameDirector director) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    director.dispose();
  }

  for (final scale in [1.0, 1.45]) {
    final tag = scale == 1.0 ? '' : '_text_145';
    testWidgets('underway room golden A56$tag', (tester) async {
      debugHoldFloorBake();
      bindA56View(tester);
      final director = await fightHitGoldenDirector();
      final router = MenuRouter();
      addTearDown(router.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        shot(
          HomeShell(director: director, router: router, onLeave: () {}),
          scale: scale,
          key: key,
        ),
      );
      await waitForFightChrome(tester, director);
      await runRoom(tester, director);
      expect(tester.takeException(), isNull);
      await expectShellGolden(
        tester,
        find.byKey(key),
        'home_shell_underway$tag.png'.replaceFirst('.png', '_a56.png'),
      );
      await tearDownShell(tester, director);
    });
  }

  testWidgets('dock and coach line step aside mid-room, back between rooms', (
    tester,
  ) async {
    debugHoldFloorBake();
    bindA56View(tester);
    final director = await fightHitGoldenDirector();
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      shellGoldenScaffold(
        HomeShell(director: director, router: router, onLeave: () {}),
      ),
    );
    await waitForFightChrome(tester, director);

    // Room just started: dock and coach line still there.
    expect(homeRoomFightActive(director), isTrue);
    expect(find.byType(HomeGoldDock), findsOneWidget);
    expect(find.text('Boss on floor 2.'), findsOneWidget);

    await runRoom(tester, director);
    expect(find.byType(HomeGoldDock), findsNothing);
    expect(find.text('FORGE'), findsNothing);
    expect(find.text('Boss on floor 2.'), findsNothing);
    // One floor line over the cave, in plain words.
    expect(find.textContaining('Floor 1'), findsOneWidget);
    expect(find.textContaining('many foes'), findsNothing);
    // MENU and the tabs still reach the forge.
    expect(find.text('MENU'), findsOneWidget);
    expect(find.text('FIGHT'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Stairs: the room is over, the dock and the line come back.
    director.spatial!.awaitingExit = true;
    director.combatFrame.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(homeRoomFightActive(director), isFalse);
    expect(find.byType(HomeGoldDock), findsOneWidget);
    expect(find.text('FORGE'), findsOneWidget);
    expect(find.text('Boss on floor 2.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownShell(tester, director);
  });

  testWidgets('the fist says SMASH when ready, seconds while cooling', (
    tester,
  ) async {
    debugHoldFloorBake();
    bindA56View(tester);
    final director = await homeShellFullFightGoldenDirector();
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      shot(HomeShell(director: director, router: router, onLeave: () {})),
    );
    await waitForFightChrome(tester, director);
    expect(
      find.descendant(
        of: find.byType(GodHandRing),
        matching: find.text('SMASH'),
      ),
      findsOneWidget,
    );
    // The word is part of the 44 px button.
    final ring = tester.getSize(find.byType(GodHandRing));
    expect(ring.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(ring.width, greaterThan(GameTheme.minTouch));

    await tearDownShell(tester, director);

    // Cooling: the ring shows the seconds, no word.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: GodHandRing(
              cooldown: 5,
              maxCooldown: 10,
              dense: true,
              caption: 'SMASH',
            ),
          ),
        ),
      ),
    );
    expect(find.text('SMASH'), findsNothing);
    expect(find.text('5.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scale in [1.0, 1.45]) {
    testWidgets('LEAVE and EXTRAS have a clear break at $scale', (
      tester,
    ) async {
      debugHoldFloorBake();
      bindA56View(tester);
      final director = await homeShellFullFightGoldenDirector();
      final router = MenuRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        shot(
          HomeShell(director: director, router: router, onLeave: () {}),
          scale: scale,
        ),
      );
      await waitForFightChrome(tester, director);
      expect(tester.takeException(), isNull);
      final leave = tester.getRect(find.text('LEAVE'));
      final extras = tester.getRect(find.text('EXTRAS'));
      final line = tester.getRect(
        find.byKey(const ValueKey('seam-leave-divider')),
      );
      expect(line.left, greaterThan(leave.right));
      expect(extras.left, greaterThan(line.right));
      expect(extras.left - leave.right, greaterThanOrEqualTo(12));
      // Big type: the fist keeps its ring and FARM / PUSH stay whole.
      expect(
        find.text('SMASH'),
        scale <= FightSeam.fistWordMaxScale ? findsOneWidget : findsNothing,
      );
      expect(find.text('MENU'), findsOneWidget);
      for (final word in ['FARM', 'PUSH']) {
        final p = tester.renderObject<RenderParagraph>(find.text(word));
        expect(p.didExceedMaxLines, isFalse, reason: '$word is cut');
      }
      await tearDownShell(tester, director);
    });
  }

  for (final scale in [1.0, 1.45]) {
    testWidgets('lead hero name is never cut at $scale', (tester) async {
      debugHoldFloorBake();
      bindA56View(tester);
      final director = await homeShellFullFightGoldenDirector();
      final router = MenuRouter();
      addTearDown(router.dispose);
      router.session.abilityHeroIndex = 0;
      await tester.pumpWidget(
        shot(
          HomeShell(director: director, router: router, onLeave: () {}),
          scale: scale,
        ),
      );
      await waitForFightChrome(tester, director);
      expect(tester.takeException(), isNull);
      final lead = director.state.combatHeroes.first.name.trim();
      final name = tester.renderObject<RenderParagraph>(find.text(lead));
      expect(name.didExceedMaxLines, isFalse, reason: '$lead is cut');
      expect(name.size.width, greaterThanOrEqualTo(name.getMaxIntrinsicWidth(
        double.infinity,
      ) - 0.5));
      await tearDownShell(tester, director);
    });
  }

  GameState vaultReady() {
    final today = DateTime.now().toUtc();
    final base = GameLogic.createInitialState(now: today).copyWith(
      bossVictories: 1,
      highestFloorCleared: 2,
      homeLayout: HomeLayout.home,
      homePanelFull: true,
      seenChangelogVersion: MetaSystems.currentVersion,
    );
    return GameLogic.enterDungeon(
      base.copyWith(
        metaDepth: MetaDepthState(
          dailyVaultDate: MetaSystems.dailyDateKey(today),
          dailyVaultClears: GameLogic.dailyVaultClearTarget,
          checkInDay: 1,
          reviewPrompted: true,
        ),
      ),
      dungeonId: 'sandy',
    );
  }

  testWidgets('CLAIM goes quiet mid-fight and stays tappable', (tester) async {
    final director = GameDirector.preview(initialState: vaultReady());
    final router = MenuRouter();
    addTearDown(router.dispose);
    await director.boot();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: director,
          builder: (context, _) =>
              HomeShell(director: director, router: router, onLeave: () {}),
        ),
      ),
    );
    await tester.pump();

    final world = director.spatial!;
    for (final e in world.enemies) {
      e.dormant = false;
    }
    world.awaitingExit = false;
    director.combatFrame.value++;
    await tester.pump();
    expect(homeRoomFightActive(director), isTrue);
    expect(find.byKey(const ValueKey('home-top-claim-muted')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-top-claim-ready')), findsNothing);
    final hit = tester.getSize(find.byKey(const ValueKey('home-top-claim')));
    expect(hit.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(hit.width, greaterThanOrEqualTo(GameTheme.minTouch));

    // Between rooms: full green again.
    for (final e in world.enemies) {
      e.hp = 0;
    }
    director.combatFrame.value++;
    await tester.pump();
    expect(homeRoomFightActive(director), isFalse);
    expect(find.byKey(const ValueKey('home-top-claim-ready')), findsOneWidget);

    // Still tappable mid-fight.
    for (final e in world.enemies) {
      e.hp = 10;
      e.dormant = false;
    }
    director.combatFrame.value++;
    await tester.pump();
    expect(find.byKey(const ValueKey('home-top-claim-muted')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-top-claim')));
    await tester.pump();
    expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
    expect(tester.takeException(), isNull);
    await tearDownShell(tester, director);
  });
}
