import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/return_week.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/core/ui_feedback.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/hub/hub_today_card.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  GameState weekVaultClaimed() {
    return GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      homeLayout: HomeLayout.home,
      metaDepth: MetaDepthState(
        dailyVaultDate: MetaSystems.dailyDateKey(now),
        dailyVaultClaimed: true,
        checkInDay: 2,
      ),
    );
  }

  test('tomorrow card line names shelf, not wallet gold', () {
    final state = weekVaultClaimed();
    final line = ReturnWeek.tomorrowRewardLine(state);
    expect(line, 'Tomorrow: Sandy Caverns · gold for TRAIN');
    final chase = HubChase.forState(state, now: now);
    expect(chase.detail, line);
    expect(chase.detail, isNot(contains(RegExp(r'\+[\d,]+ gold'))));
  });

  test('hunt title stays off fight top bar in cave', () {
    final state = GameLogic.enterDungeon(weekVaultClaimed());
    final goal = ChaseContract.goalLine(state, inDungeon: true);
    expect(goal == null || !goal.contains('·'), isTrue);
  });

  test('floor clear loot drops when the next floor clock starts', () {
    final ui = UiFeedback();
    ui.pushLootLine('F1 CLEAR · +216 XP');
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(GameLogic.enterDungeon(GameLogic.createInitialState()));
    director.noteLoot('F1 CLEAR · +216 XP');
    expect(director.lootLog.any(UiFeedback.isFloorClearLine), isTrue);
    director.debugBeginFloorClock();
    expect(director.lootLog.any(UiFeedback.isFloorClearLine), isFalse);
  });

  test('shop header does not say packs appear when Play lists them', () {
    final lead = ShopDock.conveniencePolicyLead(
      showEssence: true,
      layout: HomeLayout.home,
    );
    expect(lead.toLowerCase(), isNot(contains('appear when play')));
    expect(ShopCatalog.playChargeableIds, contains('cinder_pouch'));
    expect(ShopCatalog.playChargeableIds, contains('season_pass_premium'));
  });

  testWidgets('home top bar fits 360x640 at typeScaleMax', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final director = GameDirector.preview(
      initialState: weekVaultClaimed(),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(360, 640),
            textScaler: const TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeTopBar(director: director, router: router),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('tomorrow hub card fits 360x640 at typeScaleMax', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chase = HubChase.forState(weekVaultClaimed(), now: now);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: Scaffold(body: HubTodayCard(chase: chase)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Tomorrow: Sandy Caverns · gold for TRAIN'),
      findsOneWidget,
    );
  });

  testWidgets('town home shell fits 360x640 at typeScaleMax', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final director = GameDirector.preview(initialState: weekVaultClaimed());
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(GameTheme.typeScaleMax),
          ),
          child: HomeShell(
            director: director,
            router: router,
            onLeave: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}