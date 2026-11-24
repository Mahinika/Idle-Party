import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/fight_presentation.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/forge_overlay.dart';
import 'package:idle_party/ui/shell/home/fight_seam_rails.dart';
import 'package:idle_party/ui/shell/home/home_gold_dock.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/rail_button.dart';
import 'package:idle_party/ui/shell/power_upgrade_row.dart';
import 'package:idle_party/ui/shell/dungeon_party_hud.dart';
import 'package:idle_party/ui/party_role_icon.dart';

import 'shell_golden_harness.dart';
import 'support/role_icons_fight_harness.dart';

/// UI batch 2 (2026-11-22): discoverability, readable buys, short rails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameDirector> railsDirector() async {
    return withShellGoldenWeek(() async {
      final base = GameLogic.createInitialState(now: shellGoldenNow);
      final s = base.copyWith(
        homeLayout: HomeLayout.home,
        homePanelFull: false,
        ascensionLevel: 2,
        bossVictories: 2,
        highestFloorCleared: 4,
        gold: 12000,
        seenChangelogVersion: MetaSystems.currentVersion,
        metaDepth: base.metaDepth.copyWith(
          lifetimeFloorClears: 6,
          reviewPrompted: true,
        ),
      );
      final d = GameDirector.preview(initialState: GameLogic.enterDungeon(s));
      await d.boot(deferCombatLoop: true);
      d.dismissOfflineSummary();
      d.clearToast();
      return d;
    });
  }

  test('first TRAIN buy keeps FULL fight layout', () {
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 22)).copyWith(
        homeLayout: HomeLayout.home,
        homePanelFull: true,
        gold: 50000,
        highestFloorCleared: 2,
        bossVictories: 1,
      ),
    );
    expect(state.homePanelFull, isTrue);
    final updated = GameLogic.upgradeWithSpendMode(
      state,
      type: PartyUpgradeType.attack,
      mode: ForgeGoldSpendMode.one,
    );
    expect(updated.homePanelFull, isTrue);
    expect(updated.attackBonus, greaterThan(state.attackBonus));
  });

  testWidgets('640h fight rails are icon-only with badge dots', (tester) async {
    final director = await railsDirector();
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 640)),
        child: MaterialApp(
          home: SizedBox(
            height: GameTheme.minTouch,
            child: FightSeamRails(director: director, router: router),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is RailButton && w.iconOnly),
      findsWidgets,
    );
    expect(find.text('SCROLLS'), findsNothing);
    expect(tester.takeException(), isNull);
    director.dispose();
  });

  testWidgets('5-hero party strip at text scale 1.45 has no overflow', (
    tester,
  ) async {
    final state = await roleIconsArtifactFightState();
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    final world = SpatialCombat.build(director.state);
    director.debugAttachSpatial(world);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          textScaler: TextScaler.linear(GameTheme.typeScaleMax),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: PartyCornerHud(
              director: director,
              selectedHeroIndex: 0,
              onSelectHero: (_) {},
              onOpenEquip: () {},
              homeRow: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(director.state.heroes.length, greaterThanOrEqualTo(4));
    for (final h in director.state.heroes) {
      expect(find.text(h.shownName.trim()), findsOneWidget);
    }
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.byType(PartyRoleIcon), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forge shortfall sits on grey buy chip readable', (tester) async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 22)),
    ).copyWith(homeLayout: HomeLayout.home, gold: 0);
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            width: 360,
            child: ForgeOverlay(director: director, inlineUnderFight: true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Need'), findsWidgets);
    expect(find.byType(PowerUpgradePriceChip), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('combat tick is identical across twin directors', () async {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 22)).copyWith(
        homeLayout: HomeLayout.home,
        highestFloorCleared: 1,
        bossVictories: 1,
      ),
    );
    final a = GameDirector.preview(initialState: state);
    final b = GameDirector.preview(initialState: state);
    await a.boot(deferCombatLoop: true);
    await b.boot(deferCombatLoop: true);
    for (var i = 0; i < 60; i++) {
      a.tickDungeonClock();
      b.tickDungeonClock();
    }
    expect(a.state.gold, b.state.gold);
    expect(a.state.attackBonus, b.state.attackBonus);
    expect(a.spatial?.heroes.first.hp, b.spatial?.heroes.first.hp);
    a.dispose();
    b.dispose();
  });

  testWidgets('disableAnimations sets fightPresentationCalm', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            expect(fightPresentationCalm(context), isTrue);
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('FULL fight after TRAIN shows LIST and gold dock', (tester) async {
    bindA56View(tester);
    var state = await roleIconsArtifactFightState();
    state = state.copyWith(homePanelFull: true, gold: 80000);
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: shellGoldenMedia,
        child: MaterialApp(
          home: HomeShell(director: director, router: router, onLeave: () {}),
        ),
      ),
    );
    await waitForFightChrome(tester, director);
    director.upgradeAttack();
    await tester.pump();
    expect(director.state.homePanelFull, isTrue);
    expect(find.byType(HomeGoldDock), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('speed chip is plain 1× without arrow glyph', (tester) async {
    final seeded = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: DateTime(2026, 11, 22)).copyWith(
        homeLayout: HomeLayout.home,
        inDungeon: true,
        bossVictories: 1,
        highestFloorCleared: 2,
      ),
    );
    final director = GameDirector.preview(initialState: seeded);
    addTearDown(director.dispose);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTopBar(director: director, router: router),
      ),
    );
    await tester.pump();
    expect(find.text('▸'), findsNothing);
    expect(find.text('1×'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}