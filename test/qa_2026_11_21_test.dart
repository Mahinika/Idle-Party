import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/away_fight_tip.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/home_layout.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/return_week.dart';
import 'package:idle_party/core/ui_feedback.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/floater_banner_stack.dart';
import 'package:idle_party/ui/game_button.dart';
import 'package:idle_party/ui/game_theme.dart';
import 'package:idle_party/ui/shell/dungeon_target_hud.dart';
import 'package:idle_party/ui/shell/home/fight_seam.dart';
import 'package:idle_party/ui/shell/home/home_fight_tools.dart';
import 'package:idle_party/ui/shell/home/home_shell.dart';
import 'package:idle_party/ui/shell/home/home_top_bar.dart';
import 'package:idle_party/ui/shell/home/town_viewport.dart';
import 'package:idle_party/ui/shell/menu_surface.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 12);

  GameState claimedWeek() {
    return GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      homeLayout: HomeLayout.home,
      metaDepth: MetaDepthState(
        dailyVaultDate: MetaSystems.dailyDateKey(now),
        dailyVaultClaimed: true,
        checkInDay: 3,
      ),
    );
  }

  test('floor CLEAR lines drop on wipe and other loot stays', () {
    final ui = UiFeedback();
    ui.pushLootLine('F4 CLEAR · +54g · +243 XP');
    expect(ui.dropFloorClearLines(), isTrue);
    expect(ui.lootLog, isEmpty);
    ui.pushLootLine('Rusty Dagger');
    expect(ui.dropFloorClearLines(), isFalse);
    expect(ui.lootLog, ['Rusty Dagger']);
  });

  test('ability names stack and raw hits stay put', () {
    expect(
      FloaterBannerStack.isStackable(
        speech: false,
        priority: 0,
        text: 'POWER WORD: SHIELD',
      ),
      isTrue,
    );
    expect(FloaterBannerStack.isAbilityName('POWER WORD: SHIELD'), isTrue);
    expect(FloaterBannerStack.isAbilityName('+54g'), isFalse);
    expect(FloaterBannerStack.isAbilityName('+243 XP'), isFalse);
    expect(
      FloaterBannerStack.isStackable(speech: false, priority: 0, text: '18'),
      isFalse,
    );
    final dy = FloaterBannerStack.dyById(const [
      FloaterBannerSpec(
        id: 0,
        x: 3,
        y: 4,
        priority: 0,
        born: 1,
        heightTiles: 0.4,
      ),
      FloaterBannerSpec(
        id: 1,
        x: 3.1,
        y: 4,
        priority: 0,
        born: 2,
        heightTiles: 0.4,
      ),
    ]);
    expect(dy[0], isNot(dy[1]));
  });

  test('tomorrow teaser stays off the top bar, sheets, and fight tip', () {
    final state = claimedWeek();
    expect(ReturnWeek.coachLine(state), 'Tomorrow: Sandy Caverns');
    final goal = ChaseContract.goalLine(state, inDungeon: false);
    expect(goal == null || !goal.startsWith('Tomorrow:'), isTrue);
    final fight = ChaseContract.goalLine(state, inDungeon: true);
    expect(fight == null || !fight.startsWith('Tomorrow:'), isTrue);
    expect(AwayFightTip.lineFor(state), isNot(contains('Tomorrow:')));
    expect(
      AwayFightTip.lineFor(state, onHub: true).toLowerCase(),
      contains('tomorrow'),
    );
  });

  test('IP-072 save label level matches active party mean after role migration', () {
    var state = GameLogic.createInitialState();
    final roster = [
      for (var i = 0; i < state.heroRoster.length; i++)
        state.heroRoster[i].copyWith(level: 10),
    ];
    state = state.copyWith(heroRoster: roster);
    expect(GameLogic.partyMeanLevel(state), 10);
    final raw = jsonEncode(state.toJson());
    expect(SaveSlotSummary.fromBlob(0, raw).partyLevel, 10);
    expect(SaveSlotSummary.fromState(0, state).partyLevel, 10);
  });

  test('save list level is the active party, then refreshes on SAVES', () {
    const raw =
        '{"partyName":"The Party","dungeonId":"sandy",'
        '"activeHeroIds":["a","b"],'
        '"heroRoster":[{"id":"a","level":10},{"id":"b","level":12},'
        '{"id":"c","level":40}]}';
    expect(SaveSlotSummary.fromBlob(0, raw).partyLevel, 11);

    final base = GameLogic.createInitialState();
    final roster = [
      for (var i = 0; i < base.heroRoster.length; i++)
        base.heroRoster[i].copyWith(level: i == 0 ? 4 : 40),
    ];
    final state = base.copyWith(
      heroRoster: roster,
      activeHeroIds: [roster.first.id],
    );
    expect(GameLogic.partyMeanLevel(state), 4);
    expect(
      SaveSlotSummary.fromBlob(0, jsonEncode(state.toJson())).partyLevel,
      SaveSlotSummary.fromState(0, state).partyLevel,
    );

    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(state);
    expect(director.saveSlots[0].partyLevel, isNull);
    director.requestStartMenu();
    expect(director.saveSlots[0].partyLevel, 4);
  });

  test('town QUESTS back closes, MENU QUESTS back returns to the grid', () {
    final router = MenuRouter();
    addTearDown(router.dispose);
    router.open(
      MenuRoute.more,
      more: MoreSection.quests,
      closeOnBack: true,
    );
    expect(router.route, MenuRoute.more);
    expect(router.moreSection, MoreSection.quests);
    expect(router.homeAtSub, isFalse);
    expect(router.back(), isTrue);
    expect(router.route, MenuRoute.none);

    router.open(MenuRoute.more, more: MoreSection.quests);
    expect(router.homeAtSub, isTrue);
    expect(router.back(), isTrue);
    expect(router.route, MenuRoute.more);
    expect(router.homeAtSub, isFalse);
    expect(router.moreSection, MoreSection.info);
  });

  test('speed tip replaces a leftover wipe toast', () {
    final ui = UiFeedback();
    expect(ui.showToast('Floor restarted — fight on', life: 2.5), isTrue);
    expect(
      ui.showToast('Fight speed 2×', life: 1.4, replace: true),
      isTrue,
    );
    expect(ui.toast, 'Fight speed 2×');

    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(GameLogic.createInitialState());
    director.showToast('Floor restarted — fight on', life: 2.5);
    director.cycleCombatPace();
    expect(director.toast, 'Fight speed 2×');
    expect(director.toast, isNot(contains('Floor restarted')));
  });

  testWidgets('wipe scrim covers fight tools and the header says WIPED', (
    tester,
  ) async {
    final director = GameDirector.preview();
    addTearDown(director.dispose);
    director.debugHoldSave(GameLogic.createInitialState());
    director.noteLoot('F4 CLEAR · +54g · +243 XP');
    director.noteLoot('Rusty Dagger');
    director.debugSetAwaitingWipe(true);
    final router = MenuRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 420,
            child: Column(
              children: [
                HomeTopBar(director: director, router: router),
                Expanded(
                  child: Stack(
                    children: [
                      HomeFightTools(director: director),
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(height: 80),
                      ),
                    ],
                  ),
                ),
                FightFieldControls(
                  director: director,
                  router: router,
                  onLeave: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('F4 CLEAR'), findsNothing);
    expect(find.text('Rusty Dagger'), findsOneWidget);
    expect(find.byKey(HomeFightTools.wipeScrimKey), findsOneWidget);
    final lock = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('fight-mode-wipe-lock')),
    );
    expect(lock.ignoring, isTrue);
    await tester.pumpWidget(
      MaterialApp(home: TargetCornerHud(director: director)),
    );
    expect(find.text('WIPED'), findsWidgets);
    expect(find.text('BOSS'), findsNothing);
  });

  testWidgets('tomorrow line is on the town card, not the bar or settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = claimedWeek();
    final director = GameDirector.preview(initialState: state);
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
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
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(TownViewport),
        matching: find.textContaining('Tomorrow: Sandy Caverns'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(HomeTopBar),
        matching: find.textContaining('Tomorrow:'),
      ),
      findsNothing,
    );
    router.open(MenuRoute.more, more: MoreSection.settings);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(MenuSurface),
        matching: find.textContaining('Tomorrow:'),
      ),
      findsNothing,
    );
  });

  testWidgets('MENU stays visible at text scale 1.45', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final director = GameDirector.preview(
      initialState: GameLogic.createInitialState().copyWith(
        homeLayout: HomeLayout.home,
      ),
    );
    final router = MenuRouter();
    addTearDown(director.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.45),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeTopBar(director: director, router: router),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('MENU'), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('primary CTA face is at least 44 and the tap is at least 48', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: GameButton(
                label: 'CLAIM QUESTS',
                primary: true,
                style: GameButtonStyle.go,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(GameButton);
    final ink = tester.getSize(
      find.descendant(of: button, matching: find.byType(Ink)),
    );
    final tap = tester.getSize(
      find.descendant(of: button, matching: find.byType(InkWell)),
    );
    expect(ink.height, greaterThanOrEqualTo(GameTheme.minTouch));
    expect(tap.height, greaterThanOrEqualTo(GameTheme.primaryTouch));
  });
}
