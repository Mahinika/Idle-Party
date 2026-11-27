import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_dispatcher.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/town_building.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/ui/shell/home/home_nav_bar.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';

void main() {
  final now = DateTime(2026, 11, 19);

  GameState quietTown({int boss = 0, int floor = 0, int al = 0}) {
    final base = GameLogic.createInitialState(now: now);
    return base.copyWith(
      inDungeon: false,
      homeLayout: HomeLayout.home,
      bossVictories: boss,
      highestFloorCleared: floor,
      ascensionLevel: al,
      seenChangelogVersion: MetaSystems.currentVersion,
      vfxQuality: VfxQuality.minimal,
      seenTips: const [
        'first_run',
        'discord_thanks',
        'hub_enter',
        'godhand',
        'farm_push',
        'kit_abilities',
        'bag',
        'forge',
        'sanctuary',
      ],
      metaDepth: base.metaDepth.copyWith(
        reviewPrompted: true,
        notifyPrompted: true,
        notifyOptIn: true,
      ),
    );
  }

  GameState vaultReadyTown({int al = 2}) {
    final stamp = DateTime.now().toUtc();
    var state = quietTown(boss: 1, floor: 2, al: al);
    state = GameLogic.ensureWeeklyContract(state, now: stamp);
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
  }

  Future<void> settleTimers(
    WidgetTester tester,
    GameDirector director,
  ) async {
    await tester.pump(const Duration(milliseconds: 400));
    director.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> pumpHome(
    WidgetTester tester,
    GameDirector director,
    MenuRouter router,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    director.debugHoldSave(director.state);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: director,
          builder: (context, _) => HomeShell(
            director: director,
            router: router,
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('claim vault chase still offers ENTER DUNGEON', (tester) async {
    final director = GameDirector.preview(initialState: vaultReadyTown());
    final router = MenuRouter();
    addTearDown(router.dispose);
    await pumpHome(tester, director, router);

    final hub = HubChase.forState(director.state, now: now);
    final plan = ChaseDispatcher.plan(hub, state: director.state);
    expect(plan.label, 'CLAIM VAULT');
    expect(find.text('ENTER DUNGEON'), findsOneWidget);

    await tester.tap(find.text('ENTER DUNGEON'));
    await tester.pump();
    expect(director.state.inDungeon, isTrue);
    await settleTimers(tester, director);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FIGHT in town enters the cave', (tester) async {
    final director = GameDirector.preview(
      initialState: quietTown(boss: 1, floor: 2, al: 1),
    );
    final router = MenuRouter();
    addTearDown(router.dispose);
    await pumpHome(tester, director, router);

    await tester.tap(find.text('FIGHT'));
    await tester.pump();
    expect(director.state.inDungeon, isTrue);
    await settleTimers(tester, director);
    expect(tester.takeException(), isNull);
  });

  testWidgets('town card ignores double tap after MAP closes', (tester) async {
    final director = GameDirector.preview(
      initialState: vaultReadyTown(al: 0),
    );
    final router = MenuRouter();
    addTearDown(router.dispose);
    await pumpHome(tester, director, router);
    expect(GameLogic.canAscend(director.state), isTrue);

    await tester.tap(find.text('MAP'));
    await tester.pump();
    await tester.tap(
      find.bySemanticsLabel(HomeNavBar.tabSemantics('MAP', selected: true)),
    );
    await tester.pump();

    await tester.tap(find.text('ASCEND'));
    await tester.pump();
    expect(find.text('Ascend?'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('ASCEND'));
    await tester.pump();
    expect(find.text('Ascend?'), findsOneWidget);
    await settleTimers(tester, director);
    expect(tester.takeException(), isNull);
  });

  testWidgets('INN locked at AL0 even with pending meet kits', (tester) async {
    final base = quietTown(boss: 1, floor: 2);
    final state = base.copyWith(
      metaDepth: base.metaDepth.copyWith(pendingHeroReveals: const ['combat']),
    );
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await pumpHome(tester, director, router);

    await tester.tap(find.byKey(ValueKey('town-${TownBuildingId.inn.name}')));
    await tester.pump();
    expect(router.isOpen, isFalse);
    expect(
      find.textContaining('First Ascend unlocks party swaps'),
      findsOneWidget,
    );
    await settleTimers(tester, director);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stat upgrade tab is labeled TRAIN in the dock', (tester) async {
    final director = GameDirector.preview(
      initialState: GameLogic.enterDungeon(
        quietTown(boss: 1, floor: 2, al: 1).copyWith(homePanelFull: false),
        dungeonId: 'sandy',
      ),
    );
    final router = MenuRouter();
    addTearDown(router.dispose);
    await pumpHome(tester, director, router);
    expect(find.text('TRAIN'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(HomeShell),
        matching: find.text('FORGE'),
      ),
      findsNothing,
    );
    await settleTimers(tester, director);
    expect(tester.takeException(), isNull);
  });
}