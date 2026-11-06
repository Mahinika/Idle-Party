import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_rewarded.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/menu_alerts.dart';
import 'package:idle_party/core/menu_router.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/models/dungeon_mode.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/shell/wipe_overlay.dart';
import 'package:idle_party/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const retryLabel = 'RETRY → F5';
  const sellLabel = 'SELL JUNK (near full)';
  const bagLabel = 'OPEN BAG';
  const hubLabel = 'HUB';
  const reviveAdLabel = 'REVIVE — WATCH AD';
  final reviveCinderLabel =
      'REVIVE · ${GameLogic.wipeReviveCinderCost} CINDERS';
  const ticketAdLabel = 'WATCH AD · +1 ticket';

  /// Normal cave, near-full bag, bag upgrade (OPEN BAG), cinders, ads on.
  /// Advice comes from [GameLogic.notePartyWipe], not a hand-written line.
  GameState sevenActionCave() {
    final now = DateTime.utc(2026, 8, 22);
    var state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: now),
    );
    final cap = GameLogic.maxGearStashFor(state);
    final junk = <EquipmentItem>[
      for (var i = 0; i < cap - 2; i++)
        EquipmentItem(
          id: 'junk_$i',
          name: 'Scrap $i',
          slot: EquipmentSlot.values[i % EquipmentSlot.values.length],
          rarity: LootRarity.common,
          attackBonus: 1,
          itemLevel: 1,
        ),
    ];
    // Above the default sell (iLvl 48 / uncommon) and scrap (iLvl 48 / rare)
    // caps, so SELL JUNK clears the commons and leaves this upgrade.
    const upgrade = EquipmentItem(
      id: 'up_sword',
      name: 'Cave Sword',
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.legendary,
      attackBonus: 80,
      itemLevel: 60,
    );
    state = state.copyWith(
      highestFloorCleared: 5,
      currentRoom: state.currentRoom.copyWith(floorNumber: 8),
      gearStash: [...junk, upgrade],
      dungeonMode: DungeonMode.push,
      inGauntlet: false,
      inRift: false,
      inGreaterRift: false,
      metaDepth: state.metaDepth.copyWith(cinders: 40, adFree: false),
    );
    const fight = WipeFightSnapshot(
      waveHp: 10000,
      remainingHp: 7000,
      damageDealt: 3000,
      damageTaken: 400,
      partyMaxHp: 400,
      elapsedSec: 20,
    );
    state = GameLogic.notePartyWipe(state, fight);
    state = GameLogic.notePartyWipe(state, fight);
    expect(state.inDungeon, isTrue, reason: 'cave wipe is in a dungeon');
    expect(state.wipeStreakCount, 2);
    expect(
      MenuAlerts.bagUpgradeCount(state),
      greaterThan(0),
      reason: 'OPEN BAG needs a real bag upgrade',
    );
    expect(
      state.wipeAdviceLine.startsWith('Equip'),
      isTrue,
      reason: 'notePartyWipe produced: ${state.wipeAdviceLine}',
    );
    expect(WipeAdvice.hubCtaLabelFor(state.wipeAdviceLine), bagLabel);
    expect(WipeAdvice.hubNavFor(state.wipeAdviceLine)?.gear, GearPanel.bag);
    expect(DungeonWipePanel.bagNearlyFull(state), isTrue);
    expect(state.gearStash.length, lessThan(cap));
    expect(GameLogic.canWipeReviveAd(state), isTrue);
    expect(GameLogic.canWipeReviveWithCinders(state), isTrue);
    expect(state.metaDepth.adFree, isFalse);
    expect(state.highestFloorCleared, 5);
    expect(state.currentRoom.floorNumber, 8);
    // Boot catch-up uses the gap since lastUpdated. Keep it current so the
    // loaded cave is still this wipe, not months of offline progress.
    return state.copyWith(lastUpdated: DateTime.now());
  }

  void bindPhone(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1280);
    // 44 / 34 logical px. View padding is physical pixels.
    tester.view.viewPadding = const FakeViewPadding(top: 88, bottom: 68);
    tester.view.padding = const FakeViewPadding(top: 88, bottom: 68);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final liveDirectors = <GameDirector>{};

  void finish(GameDirector director) {
    if (liveDirectors.remove(director)) director.dispose();
  }

  Future<GameDirector> pumpPanel(
    WidgetTester tester,
    GameState state, {
    int countdown = 0,
  }) async {
    bindPhone(tester);
    final director = GameDirector.preview(initialState: state);
    liveDirectors.add(director);
    addTearDown(() => finish(director));
    await director.boot(deferCombatLoop: true);
    expect(director.state.wipeAdviceLine, state.wipeAdviceLine);
    expect(director.state.gearStash.length, state.gearStash.length);
    expect(director.state.metaDepth.cinders, state.metaDepth.cinders);
    director.debugOpenWipeChoice();
    if (countdown > 0) director.wipeAutoSeconds.value = countdown;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: GameTheme.ink,
          body: DungeonWipePanel(
            director: director,
            farm: false,
            dailyEcho: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.platformDispatcher.textScaleFactor,
      2,
      reason: 'text scale must come from the test view, not a dead MediaQuery',
    );
    final padding = MediaQueryData.fromView(tester.view).padding;
    expect(padding.top, 44);
    expect(padding.bottom, 34);
    return director;
  }

  Future<void> expandWhy(WidgetTester tester, String advice) async {
    final why = find.text('Why?');
    expect(why, findsOneWidget);
    await tester.scrollUntilVisible(
      why,
      80,
      scrollable: find.byType(Scrollable),
    );
    expect(why.hitTestable(), findsOneWidget);
    await tester.tap(why.hitTestable());
    await tester.pump();
    expect(find.text('HIDE'), findsOneWidget);
    expect(find.text(advice), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  Finder action(String label) => find.widgetWithText(GameButton, label);

  Future<void> tapAction(WidgetTester tester, String label) async {
    final finder = action(label);
    expect(finder, findsOneWidget, reason: 'missing $label');
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
    expect(
      finder.hitTestable(),
      findsOneWidget,
      reason: '$label center is not hit-testable after scroll',
    );
    await tester.tap(finder.hitTestable());
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'tap $label overflowed');
  }

  void expectSeven(WidgetTester tester) {
    expect(action(retryLabel), findsOneWidget);
    expect(action(sellLabel), findsOneWidget);
    expect(action(bagLabel), findsOneWidget);
    expect(action(hubLabel), findsOneWidget);
    expect(action(reviveAdLabel), findsOneWidget);
    expect(action(reviveCinderLabel), findsOneWidget);
    expect(action(ticketAdLabel), findsOneWidget);
  }

  testWidgets(
    'normal cave shows all seven actions together at 360x640 scale 2',
    (tester) async {
      final state = sevenActionCave();
      final director = await pumpPanel(tester, state, countdown: 3);
      expect(find.text('Fighting again in 3'), findsOneWidget);
      expect(director.wipeAutoSeconds.value, 3);
      await expandWhy(tester, state.wipeAdviceLine);
      expectSeven(tester);
      expect(tester.takeException(), isNull);
      finish(director);
    },
  );

  testWidgets('RETRY tap farms the last cleared floor', (tester) async {
    final state = sevenActionCave();
    final director = await pumpPanel(tester, state, countdown: 3);
    await expandWhy(tester, state.wipeAdviceLine);
    expectSeven(tester);
    final cinders = director.state.metaDepth.cinders;
    await tapAction(tester, retryLabel);
    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isTrue);
    expect(director.state.dungeonMode, DungeonMode.farm);
    expect(director.state.currentRoom.floorNumber, 5);
    expect(director.state.pushResumeFloor, 8);
    expect(director.state.metaDepth.cinders, cinders);
    expect(director.state.wipeReviveUsed, isFalse);
    expect(director.takePendingHubNav(), isNull);
    expect(director.toast, contains('Farming floor 5'));
    finish(director);
  });

  testWidgets('SELL JUNK tap removes scrap and keeps the upgrade', (
    tester,
  ) async {
    final state = sevenActionCave();
    final director = await pumpPanel(tester, state, countdown: 3);
    await expandWhy(tester, state.wipeAdviceLine);
    expectSeven(tester);
    final before = director.state.gearStash.length;
    final cinders = director.state.metaDepth.cinders;
    await tapAction(tester, sellLabel);
    expect(director.state.gearStash.length, lessThan(before));
    expect(
      director.state.gearStash.map((item) => item.id),
      contains('up_sword'),
    );
    expect(director.awaitingWipeChoice, isTrue);
    expect(director.state.inDungeon, isTrue);
    expect(director.state.currentRoom.floorNumber, 8);
    expect(director.state.metaDepth.cinders, cinders);
    expect(director.state.wipeReviveUsed, isFalse);
    expect(director.toast, contains('Cleaned'));
    finish(director);
  });

  testWidgets('OPEN BAG tap leaves the cave into the bag', (tester) async {
    final state = sevenActionCave();
    final director = await pumpPanel(tester, state, countdown: 3);
    await expandWhy(tester, state.wipeAdviceLine);
    expectSeven(tester);
    await tapAction(tester, bagLabel);
    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isFalse);
    final nav = director.takePendingHubNav();
    expect(nav, isNotNull);
    expect(nav!.route, MenuRoute.gear);
    expect(nav.gear, GearPanel.bag);
    expect(director.toast, 'Returned to hub');
    finish(director);
  });

  testWidgets('HUB tap leaves the cave with no menu destination', (
    tester,
  ) async {
    final state = sevenActionCave();
    final director = await pumpPanel(tester, state, countdown: 3);
    await expandWhy(tester, state.wipeAdviceLine);
    expectSeven(tester);
    await tapAction(tester, hubLabel);
    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isFalse);
    expect(director.takePendingHubNav(), isNull);
    expect(director.toast, 'Returned to hub');
    finish(director);
  });

  testWidgets('REVIVE WATCH AD tap does not revive when ads are unavailable', (
    tester,
  ) async {
    expect(AdRewarded.realAdsAvailable, isFalse);
    final state = sevenActionCave();
    final director = await pumpPanel(tester, state, countdown: 3);
    await expandWhy(tester, state.wipeAdviceLine);
    expectSeven(tester);
    final cinders = director.state.metaDepth.cinders;
    final tickets = director.state.metaDepth.adTickets;
    await tapAction(tester, reviveAdLabel);
    expect(director.toast, 'Ads play on the Android app');
    expect(director.wipeAutoSeconds.value, 0);
    expect(director.awaitingWipeChoice, isTrue);
    expect(director.state.inDungeon, isTrue);
    expect(director.state.wipeReviveUsed, isFalse);
    expect(director.state.metaDepth.cinders, cinders);
    expect(director.state.metaDepth.adTickets, tickets);
    expect(director.state.currentRoom.floorNumber, 8);
    finish(director);
  });

  testWidgets('REVIVE CINDERS tap spends 15 and revives in place', (
    tester,
  ) async {
    final state = sevenActionCave();
    final director = await pumpPanel(tester, state, countdown: 3);
    await expandWhy(tester, state.wipeAdviceLine);
    expectSeven(tester);
    final before = director.state.metaDepth.cinders;
    await tapAction(tester, reviveCinderLabel);
    expect(
      director.state.metaDepth.cinders,
      before - GameLogic.wipeReviveCinderCost,
    );
    expect(director.state.wipeReviveUsed, isTrue);
    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isTrue);
    expect(director.state.dungeonMode, DungeonMode.push);
    expect(director.state.currentRoom.floorNumber, 8);
    expect(director.takePendingHubNav(), isNull);
    expect(director.toast, 'Party revived — fight on');
    for (final hero in director.state.heroes) {
      expect(
        hero.currentHp,
        (director.state.effectiveHeroMaxHp(hero) * 0.5).round(),
      );
    }
    finish(director);
  });

  testWidgets('WATCH AD tap does not grant a ticket and rearms the countdown', (
    tester,
  ) async {
    expect(AdRewarded.realAdsAvailable, isFalse);
    final state = sevenActionCave();
    // 2, not 3: a missed tap would leave 2. A real watch rearms at 3.
    final director = await pumpPanel(tester, state, countdown: 2);
    await expandWhy(tester, state.wipeAdviceLine);
    expect(find.text('Fighting again in 2'), findsOneWidget);
    expectSeven(tester);
    final tickets = director.state.metaDepth.adTickets;
    final cinders = director.state.metaDepth.cinders;
    await tapAction(tester, ticketAdLabel);
    expect(director.toast, 'Ads play on the Android app');
    expect(director.wipeAutoSeconds.value, 3);
    expect(director.state.metaDepth.adTickets, tickets);
    expect(director.state.metaDepth.cinders, cinders);
    expect(director.state.wipeReviveUsed, isFalse);
    expect(director.awaitingWipeChoice, isTrue);
    expect(director.state.inDungeon, isTrue);
    expect(director.state.currentRoom.floorNumber, 8);
    finish(director);
  });

  testWidgets('ad-free hides both ads and the cinder tap still revives', (
    tester,
  ) async {
    final paid = sevenActionCave();
    final state = paid.copyWith(
      metaDepth: paid.metaDepth.copyWith(adFree: true),
    );
    expect(state.metaDepth.adFree, isTrue);
    expect(GameLogic.canWipeReviveAd(state), isTrue);
    expect(GameLogic.canWipeReviveWithCinders(state), isTrue);
    final director = await pumpPanel(tester, state, countdown: 3);
    await expandWhy(tester, state.wipeAdviceLine);
    expect(action(retryLabel), findsOneWidget);
    expect(action(sellLabel), findsOneWidget);
    expect(action(bagLabel), findsOneWidget);
    expect(action(hubLabel), findsOneWidget);
    expect(action(reviveCinderLabel), findsOneWidget);
    expect(action(reviveAdLabel), findsNothing);
    expect(action(ticketAdLabel), findsNothing);
    expect(find.textContaining('WATCH AD'), findsNothing);
    final before = director.state.metaDepth.cinders;
    await tapAction(tester, reviveCinderLabel);
    expect(
      director.state.metaDepth.cinders,
      before - GameLogic.wipeReviveCinderCost,
    );
    expect(director.state.wipeReviveUsed, isTrue);
    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isTrue);
    expect(director.state.currentRoom.floorNumber, 8);
    expect(director.toast, 'Party revived — fight on');
    finish(director);
  });

  Future<void> expectRiftChrome(
    WidgetTester tester,
    GameDirector director, {
    required bool greater,
  }) async {
    expect(director.state.inAnyRiftMode, isTrue);
    expect(director.state.inRift, !greater);
    expect(director.state.inGreaterRift, greater);
    expect(GameLogic.canWipeReviveAd(director.state), isFalse);
    expect(GameLogic.canWipeReviveWithCinders(director.state), isFalse);
    expect(action(retryLabel), findsNothing);
    expect(action('RETRY FLOOR'), findsNothing);
    expect(find.textContaining('SELL JUNK'), findsNothing);
    expect(action(reviveAdLabel), findsNothing);
    expect(action(reviveCinderLabel), findsNothing);
    expect(action(bagLabel), findsOneWidget);
    expect(action(hubLabel), findsOneWidget);
    expect(action(ticketAdLabel), findsOneWidget);
    expect(find.textContaining('Fighting again'), findsNothing);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Farm Rift hides retry and revive; HUB tap leaves', (
    tester,
  ) async {
    final state = sevenActionCave().copyWith(inRift: true, inGreaterRift: false);
    final director = await pumpPanel(tester, state);
    await expandWhy(tester, state.wipeAdviceLine);
    await expectRiftChrome(tester, director, greater: false);
    await tapAction(tester, hubLabel);
    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isFalse);
    expect(director.takePendingHubNav(), isNull);
    expect(director.state.inRift, isFalse);
    expect(director.toast, contains('Rift R'));
    expect(director.toast, contains('ended'));
    finish(director);
  });

  testWidgets('Ranked GR hides retry and revive; HUB tap leaves', (
    tester,
  ) async {
    final state = sevenActionCave().copyWith(inRift: false, inGreaterRift: true);
    final director = await pumpPanel(tester, state);
    await expandWhy(tester, state.wipeAdviceLine);
    await expectRiftChrome(tester, director, greater: true);
    await tapAction(tester, hubLabel);
    expect(director.awaitingWipeChoice, isFalse);
    expect(director.state.inDungeon, isFalse);
    expect(director.takePendingHubNav(), isNull);
    expect(director.state.inGreaterRift, isFalse);
    expect(director.toast, contains('Greater Rift'));
    expect(director.toast, contains('ended'));
    finish(director);
  });
}
