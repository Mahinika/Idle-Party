import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/return_week.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/home/home_claim_row.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/home/fight_viewport.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';

import 'shell_golden_harness.dart';

/// 1.13.18 header: a ready vault is one row, and the seam toggle says
/// what the tap does.
void main() {
  GameState vaultReady({required bool full, int day = 1}) {
    final today = DateTime.now().toUtc();
    final base = GameLogic.createInitialState(now: today).copyWith(
      bossVictories: 1,
      highestFloorCleared: 2,
      homeLayout: HomeLayout.home,
      homePanelFull: full,
      seenChangelogVersion: MetaSystems.currentVersion,
    );
    return GameLogic.enterDungeon(
      base.copyWith(
        metaDepth: MetaDepthState(
          dailyVaultDate: MetaSystems.dailyDateKey(today),
          dailyVaultClears: GameLogic.dailyVaultClearTarget,
          checkInDay: day,
          reviewPrompted: true,
        ),
      ),
      dungeonId: 'sandy',
    );
  }

  Widget home(GameDirector director, MenuRouter router, {double scale = 1}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: AnimatedBuilder(
            animation: director,
            builder: (context, _) =>
                HomeShell(director: director, router: router, onLeave: () {}),
          ),
        ),
      ),
    );
  }

  test('vault line names the vault and the check-in shelf', () {
    final state = vaultReady(full: true);
    expect(GameLogic.canClaimDailyVault(state), isTrue);
    expect(ReturnWeek.active(state), isTrue);
    expect(ReturnWeek.coachLine(state), 'Claim CAMP');
    expect(HomeClaimRow.vaultLine(state), 'Claim Daily Vault · CAMP');
    expect(HomeClaimRow.showChip(state), isTrue);
    expect(HomeClaimRow.chipHint(state), 'Daily Vault · CAMP');
  });

  testWidgets('vault-ready home: CLAIM in the top row, no claim rows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final director = GameDirector.preview(initialState: vaultReady(full: true));
    final router = MenuRouter();
    addTearDown(router.dispose);
    await director.boot();

    await tester.pumpWidget(home(director, router));
    await tester.pump();

    expect(find.text('Claim CAMP'), findsNothing);
    expect(find.text('Claim Daily Vault'), findsNothing);
    expect(find.text('Claim Daily Vault · CAMP'), findsNothing);
    expect(find.text('CLAIM'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeTopBar),
        matching: find.text('CLAIM'),
      ),
      findsOneWidget,
      reason: 'CLAIM sits in the resource row next to gold',
    );
    // Same row as gold and speed.
    final claimRect = tester.getRect(find.text('CLAIM'));
    final speed = tester.getRect(find.text('1×'));
    expect((claimRect.center.dy - speed.center.dy).abs(), lessThan(3));
    // Small art, full touch target.
    final hit = tester.getSize(find.byKey(const ValueKey('home-top-claim')));
    expect(hit.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(hit.width, greaterThanOrEqualTo(GameTheme.minTouch));
    // The shelf is still there for screen readers and long-press.
    expect(
      find.bySemanticsLabel('Claim the daily vault. Daily Vault · CAMP'),
      findsOneWidget,
    );
    expect(find.byTooltip('Claim Daily Vault · CAMP'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('CLAIM'));
    await tester.pump();
    expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
    expect(find.text('CLAIM'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    director.dispose();
    handle.dispose();
  });

  testWidgets('top CLAIM stays whole at max scale with a big wallet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final director = GameDirector.preview(
      initialState: vaultReady(
        full: true,
        day: 6,
      ).copyWith(gold: 987654321, essence: 987654, ascensionLevel: 0),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      home(director, router, scale: GameTheme.typeScaleMax),
    );
    await tester.pump();

    expect(find.text('CLAIM'), findsOneWidget);
    final claim = tester.getRect(find.text('CLAIM'));
    expect(claim.left, greaterThanOrEqualTo(0));
    expect(claim.right, lessThanOrEqualTo(360));
    final para = tester.renderObject<RenderParagraph>(find.text('CLAIM'));
    expect(para.didExceedMaxLines, isFalse);
    expect(
      para.size.width,
      greaterThanOrEqualTo(para.getMaxIntrinsicWidth(double.infinity) - 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('first climb keeps its line and uses the top CLAIM', (
    tester,
  ) async {
    final today = DateTime.now().toUtc();
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(
        now: today,
      ).copyWith(homeLayout: HomeLayout.home, homePanelFull: true),
      dungeonId: 'sandy',
    );
    state = state.copyWith(
      highestFloorCleared: 1,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultDate: MetaSystems.dailyDateKey(today),
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
      ),
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(home(director, router));
    await tester.pump();
    expect(find.text('Tap CLAIM. The boss is on floor 2.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeTopBar),
        matching: find.text('CLAIM'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home fight chrome skips the cutout and clears the floor line', (
    tester,
  ) async {
    bindA56View(tester);
    final director = await homeShellFightGoldenDirector();
    final router = MenuRouter();
    addTearDown(router.dispose);
    for (final scale in [1.0, GameTheme.typeScaleMax]) {
      await tester.pumpWidget(
        MediaQuery(
          data: shellGoldenMedia.copyWith(
            padding: const EdgeInsets.only(top: 40, bottom: 24),
            viewPadding: const EdgeInsets.only(top: 40, bottom: 24),
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: HomeShell(
                director: director,
                router: router,
                onLeave: () {},
              ),
            ),
          ),
        ),
      );
      await waitForFightChrome(tester, director);
      final view = tester.getRect(find.byType(FightViewport));
      final floor = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label ?? '').startsWith('Floor line'),
        ),
      );
      final target = tester.getRect(find.byType(TargetCornerHud));
      expect(
        target.top - view.top,
        lessThan(40),
        reason: 'the cutout inset is paid once, by the top bar ($scale)',
      );
      expect(
        target.top,
        greaterThanOrEqualTo(floor.bottom),
        reason: 'target box sits under the floor line ($scale)',
      );
      // Top bar still keeps its art below the cutout.
      final speed = tester.getRect(find.text('1×'));
      expect(speed.top, greaterThanOrEqualTo(40));
      expect(tester.takeException(), isNull);
    }
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('seam toggle reads HIDE when open and MENU when docked', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final director = GameDirector.preview(
      initialState: vaultReady(full: false),
    );
    final router = MenuRouter();
    addTearDown(router.dispose);
    await director.boot();

    await tester.pumpWidget(home(director, router));
    await tester.pump();

    expect(director.state.homePanelFull, isFalse);
    expect(find.text('HIDE'), findsOneWidget);
    expect(find.text('MENU', skipOffstage: false), findsNothing);
    expect(find.text('TALL'), findsNothing);
    // The mode line under the seam is gone; the toggle keeps it as a hint.
    expect(find.text('FARM loops. PUSH climbs.'), findsNothing);
    expect(find.text('Repeat loots. Next goes deeper.'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.hint == 'FARM loops. PUSH climbs.' ||
                w.properties.hint == 'Repeat loots. Next goes deeper.'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Hide the forge panel')),
      findsOneWidget,
    );

    await tester.tap(find.text('HIDE'));
    await tester.pump();
    expect(director.state.homePanelFull, isTrue);
    expect(find.text('MENU'), findsOneWidget);
    expect(find.text('HIDE'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('^Show the forge menu')),
      findsOneWidget,
    );
    // The gold dock tabs keep their names.
    expect(find.text('FORGE'), findsWidgets);
    // Docked: the MENU-list button next to LEAVE says EXTRAS, not MORE.
    expect(find.text('EXTRAS'), findsOneWidget);
    expect(find.text('MORE'), findsNothing);

    await tester.tap(find.text('MENU'));
    await tester.pump();
    expect(director.state.homePanelFull, isFalse);
    expect(find.text('HIDE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    director.dispose();
    handle.dispose();
  });
}
