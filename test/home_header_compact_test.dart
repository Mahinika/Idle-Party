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
import 'package:idle_party/ui/shell/home/home_shell.dart';

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
    expect(
      HomeClaimRow.vaultLine(state, sheet: false),
      'Claim Daily Vault · CAMP',
    );
    expect(HomeClaimRow.vaultLine(state, sheet: true), isNull);
  });

  testWidgets('vault-ready home shows one claim row, no "Claim CAMP" row', (
    tester,
  ) async {
    final director = GameDirector.preview(initialState: vaultReady(full: true));
    final router = MenuRouter();
    addTearDown(router.dispose);
    await director.boot();

    await tester.pumpWidget(home(director, router));
    await tester.pump();

    expect(find.text('Claim Daily Vault · CAMP'), findsOneWidget);
    expect(find.text('Claim CAMP'), findsNothing);
    expect(
      find.text('Claim Daily Vault'),
      findsNothing,
      reason: 'the top bar drops its copy of the vault title',
    );
    expect(find.text('CLAIM'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-vault-claim-row')), findsOneWidget);

    // Line and CLAIM share one row.
    final line = tester.getRect(find.text('Claim Daily Vault · CAMP'));
    final claim = tester.getRect(find.text('CLAIM'));
    expect((line.center.dy - claim.center.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('CLAIM'));
    await tester.pump();
    expect(director.state.metaDepth.dailyVaultClaimed, isTrue);
    expect(find.byKey(const ValueKey('home-vault-claim-row')), findsNothing);
    expect(find.text('CLAIM'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    director.dispose();
  });

  testWidgets('long shelf ellipsizes and CLAIM stays whole at max scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final director = GameDirector.preview(
      initialState: vaultReady(full: true, day: 6),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      home(director, router, scale: GameTheme.typeScaleMax),
    );
    await tester.pump();

    expect(find.text('Claim Daily Vault · CAMP+FORGE'), findsOneWidget);
    final line = tester.widget<Text>(
      find.text('Claim Daily Vault · CAMP+FORGE'),
    );
    expect(line.maxLines, 1);
    expect(line.overflow, TextOverflow.ellipsis);
    final claim = tester.getRect(find.text('CLAIM'));
    expect(claim.right, lessThanOrEqualTo(360));
    final para = tester.renderObject<RenderParagraph>(find.text('CLAIM'));
    expect(para.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
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
