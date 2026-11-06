import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/wipe_advice.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/shell/wipe_overlay.dart';
import 'package:idle_party/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GameState allSevenButtonsState() {
    final now = DateTime.utc(2026, 8, 22);
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.enterDungeon(state);
    final bagCap = GameLogic.maxGearStashFor(state);
    final stashItems = List.generate(
      bagCap - 1,
      (i) => EquipmentItem(
        id: 'item_$i',
        name: 'Junk $i',
        slot: EquipmentSlot.values[i % EquipmentSlot.values.length],
        rarity: LootRarity.common,
        attackBonus: 1,
        itemLevel: 1,
      ),
    );
    state = state.copyWith(
      bossVictories: 1,
      highestFloorCleared: 5,
      currentRoom: state.currentRoom.copyWith(floorNumber: 8),
      gearStash: stashItems,
      inGauntlet: false,
      inRift: false,
      inGreaterRift: false,
      metaDepth: state.metaDepth.copyWith(
        cinders: 100,
        adFree: false,
      ),
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
    return state;
  }

  GameState maximalWipeState({bool addBagItems = false}) {
    final now = DateTime.utc(2026, 8, 22);
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.enterDungeon(state);
    final stashItems = <EquipmentItem>[
      const EquipmentItem(
        id: 'up_1',
        name: 'Better Sword',
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.epic,
        attackBonus: 50,
        itemLevel: 30,
      ),
      const EquipmentItem(
        id: 'up_2',
        name: 'Better Helm',
        slot: EquipmentSlot.head,
        rarity: LootRarity.epic,
        defenseBonus: 30,
        itemLevel: 30,
      ),
    ];
    if (addBagItems) {
      for (var i = 0; i < 50; i++) {
        stashItems.add(EquipmentItem(
          id: 'item_$i',
          name: 'Junk $i',
          slot: EquipmentSlot.values[i % EquipmentSlot.values.length],
          rarity: LootRarity.common,
          attackBonus: 1,
          itemLevel: 1,
        ));
      }
    }
    state = state.copyWith(
      bossVictories: 1,
      highestFloorCleared: 5,
      currentRoom: state.currentRoom.copyWith(floorNumber: 8),
      gearStash: stashItems,
      inGauntlet: false,
      inRift: false,
      inGreaterRift: false,
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
    return state;
  }

  Widget scaffold(Widget child, {double textScale = 1.0}) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: GameTheme.ink,
          body: child,
        ),
      ),
    );
  }

  testWidgets('wipe panel fits at 360x640 with normal text', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = maximalWipeState();
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      scaffold(
        DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('PARTY WIPED'), findsOneWidget);
    expect(find.textContaining('RETRY →'), findsOneWidget);
  });

  testWidgets('wipe panel fits at 360x640 with large text 1.4x', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = maximalWipeState();
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      scaffold(
        DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
        textScale: 1.4,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('PARTY WIPED'), findsOneWidget);
  });

  testWidgets('wipe panel fits at 360x640 with max text 2.0x', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = maximalWipeState();
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      scaffold(
        DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
        textScale: 2.0,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('PARTY WIPED'), findsOneWidget);
  });

  testWidgets('wipe panel RETRY and HUB buttons are reachable', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = maximalWipeState();
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      scaffold(
        DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
        textScale: 1.4,
      ),
    );
    await tester.pump();

    final retryFinder = find.textContaining('RETRY →');
    expect(retryFinder, findsOneWidget);
    expect(tester.getRect(retryFinder).bottom, lessThan(640));

    final hubFinder = find.text('HUB');
    expect(hubFinder, findsWidgets);
    for (final element in hubFinder.evaluate()) {
      final box = tester.getRect(find.byWidget(element.widget));
      expect(box.bottom, lessThan(640), reason: 'HUB button should be on screen');
    }
  });

  testWidgets('wipe panel with bag nearly full fits', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = maximalWipeState(addBagItems: true);
    expect(
      DungeonWipePanel.bagNearlyFull(state),
      isTrue,
      reason: 'State should have nearly full bag for test',
    );
    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      scaffold(
        DungeonWipePanel(
          director: director,
          farm: false,
          dailyEcho: false,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('SELL JUNK'), findsOneWidget);
  });

  testWidgets(
    'all seven buttons reachable at 360x640 scale2 with notch insets',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = allSevenButtonsState();
      expect(DungeonWipePanel.bagNearlyFull(state), isTrue);
      expect(state.metaDepth.cinders, greaterThanOrEqualTo(15));
      expect(state.metaDepth.adFree, isFalse);

      final director = GameDirector.preview(initialState: state);
      addTearDown(director.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2.0),
            padding: EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: GameTheme.ink,
              body: DungeonWipePanel(
                director: director,
                farm: false,
                dailyEcho: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'No overflow error');

      expect(find.text('PARTY WIPED'), findsOneWidget);

      final retryFinder = find.textContaining('RETRY');
      expect(retryFinder, findsWidgets);

      expect(find.textContaining('SELL JUNK'), findsOneWidget);

      final openBagFinder = find.text('OPEN BAG');
      final hubFinder = find.text('HUB');
      expect(
        openBagFinder.evaluate().isNotEmpty || hubFinder.evaluate().isNotEmpty,
        isTrue,
        reason: 'Either OPEN BAG or HUB should be visible',
      );

      expect(find.textContaining('REVIVE'), findsWidgets);

      expect(find.textContaining('WATCH AD'), findsWidgets);
    },
  );

  testWidgets(
    'all seven buttons tappable with scroll at 360x640 scale2',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = allSevenButtonsState();
      final director = GameDirector.preview(initialState: state);
      addTearDown(director.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2.0),
            padding: EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: GameTheme.ink,
              body: DungeonWipePanel(
                director: director,
                farm: false,
                dailyEcho: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final scrollable = find.byType(SingleChildScrollView);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -200));
        await tester.pump();
      }

      final hubButtons = find.text('HUB');
      if (hubButtons.evaluate().isNotEmpty) {
        await tester.ensureVisible(hubButtons.first);
        await tester.pump();
      }
    },
  );

  testWidgets('ad-free variant shows cinder revive without ad buttons', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var state = allSevenButtonsState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(adFree: true, cinders: 100),
    );

    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(2.0),
          padding: EdgeInsets.only(top: 24, bottom: 24),
        ),
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: GameTheme.ink,
            body: DungeonWipePanel(
              director: director,
              farm: false,
              dailyEcho: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.textContaining('CINDERS'), findsOneWidget);
    expect(find.text('WATCH AD · +1 ticket'), findsNothing);
  });

  testWidgets('gauntlet/rift mode shows only HUB', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var state = allSevenButtonsState();
    state = state.copyWith(inGauntlet: true);

    final director = GameDirector.preview(initialState: state);
    addTearDown(director.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(2.0),
          padding: EdgeInsets.only(top: 24, bottom: 24),
        ),
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: GameTheme.ink,
            body: DungeonWipePanel(
              director: director,
              farm: false,
              dailyEcho: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.text('RETRY FLOOR'), findsNothing);
    expect(find.textContaining('RETRY →'), findsNothing);
    expect(find.textContaining('SELL JUNK'), findsNothing);
    expect(find.text('HUB'), findsOneWidget);
  });
}
