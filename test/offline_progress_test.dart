import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/ui/meta/offline_welcome.dart';

void main() {
  OfflineProgressResult result({
    int bosses = 0,
    int floors = 0,
    int rooms = 0,
    int gold = 0,
    int essence = 0,
    int seconds = 120,
    int levels = 0,
    int gear = 0,
    bool wasInDungeon = false,
    int ascension = 0,
  }) {
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 8),
    ).copyWith(ascensionLevel: ascension);
    return OfflineProgressResult(
      state: state,
      secondsApplied: seconds,
      goldGained: gold,
      essenceGained: essence,
      roomsCleared: rooms,
      highestFloorDelta: floors,
      bossDelta: bosses,
      levelsGained: levels,
      gearFinds: gear,
      wasInDungeon: wasInDungeon,
    );
  }

  test('hasSummary shows gold/clears under 20s; other rewards need 20s', () {
    expect(result(gold: 10, seconds: 5).hasSummary, isTrue);
    expect(result(rooms: 1, seconds: 8, wasInDungeon: true).hasSummary, isTrue);
    expect(result(essence: 3, seconds: 10).hasSummary, isFalse);
    expect(result(essence: 3, seconds: 20).hasSummary, isTrue);
    expect(result(seconds: 60).hasSummary, isFalse);
    expect(result(seconds: 59, wasInDungeon: true).hasSummary, isFalse);
    final held = result(seconds: 60, wasInDungeon: true);
    expect(held.hasSummary, isTrue);
    expect(held.goldGained, 0);
    expect(held.roomsCleared, 0);
    expect(held.headline, startsWith('Dungeon held'));
    expect(held.welcomeLead.toLowerCase(), contains('held the dungeon floor'));
  });

  test('banner headline is wow + away, not a number dump', () {
    final r = result(
      bosses: 2,
      gold: 500,
      essence: 12,
      rooms: 4,
      wasInDungeon: true,
    );
    expect(r.headline, startsWith('Bosses fell'));
    expect(r.headline, contains('Away'));
    expect(r.headline, isNot(contains('+500g')));
    expect(r.headline, isNot(contains('ess')));
  });

  test('welcomeLead prioritizes bosses over floors', () {
    final r = result(
      bosses: 1,
      floors: 3,
      rooms: 5,
      gold: 99,
      wasInDungeon: true,
    );
    expect(r.welcomeLead.toLowerCase(), contains('boss'));
    expect(r.welcomeLead.toLowerCase(), isNot(contains('rooms')));
    expect(r.welcomeLead.toLowerCase(), isNot(contains('ascend')));
  });

  test('after the first Ascend a boss while away says Ascend moved', () {
    final r = result(bosses: 1, ascension: 1, wasInDungeon: true);
    expect(r.welcomeLead.toLowerCase(), contains('ascend'));
  });

  test('welcomeLead prefers party levels over rooms when no boss', () {
    final r = result(
      levels: 2,
      floors: 3,
      rooms: 8,
      gold: 40,
      wasInDungeon: true,
    );
    expect(r.welcomeLead.toLowerCase(), contains('level'));
    expect(r.headline, startsWith('Party grew'));
    expect(r.highlightRows.first.$1, 'Party levels');
  });

  test('highlightRows caps at 3 and ranks bosses first', () {
    final r = result(
      bosses: 2,
      floors: 3,
      rooms: 8,
      essence: 10,
      gold: 400,
      wasInDungeon: true,
    );
    expect(r.highlightRows.length, OfflineProgressResult.maxHighlightRows);
    expect(r.highlightRows.first.$1, 'Bosses defeated');
    expect(r.highlightRows.map((e) => e.$1), isNot(contains('Combat gold')));
  });

  test('sanctuary AFK uses calm lead and gold/essence rows', () {
    final r = result(gold: 80, essence: 5);
    expect(r.wasInDungeon, isFalse);
    expect(r.foughtWhileAway, isFalse);
    expect(r.afkWhereLine.toLowerCase(), contains('hub'));
    expect(r.afkWhereLine.toLowerCase(), contains('keeps fighting'));
    expect(r.afkWhereLine.toLowerCase(), isNot(contains('no combat')));
    expect(r.welcomeLead.toLowerCase(), contains('gold'));
    expect(r.welcomeLead.toLowerCase(), isNot(contains('sanctuary')));
    expect(r.headline, startsWith('Gold while away'));
    expect(r.highlightRows.map((e) => e.$1), contains('Gold'));
  });

  test('dungeon AFK gold is never labeled sanctuary', () {
    final r = result(gold: 80, wasInDungeon: true);
    expect(r.afkWhereLine.toLowerCase(), contains('dungeon'));
    expect(r.headline, startsWith('Party fought'));
    expect(r.welcomeLead.toLowerCase(), contains('dungeon'));
    expect(r.welcomeLead.toLowerCase(), isNot(contains('sanctuary')));
    expect(r.welcomeLead.toUpperCase(), isNot(contains('AFK')));
    expect(r.highlightRows.map((e) => e.$1), contains('Combat gold'));
  });

  test('welcomeLead never teaches AFK assist', () {
    final r = result(gold: 80, rooms: 3, floors: 1, wasInDungeon: true);
    expect(r.welcomeLead.toUpperCase(), isNot(contains('AFK')));
    expect(r.welcomeLead.toLowerCase(), isNot(contains('assist')));
  });

  test('hub applyOfflineProgress sets wasInDungeon false', () {
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 9, 10),
    ).copyWith(autoCaveOnLeave: false);
    expect(state.inDungeon, isFalse);
    final r = OfflineProgress.applyOfflineProgress(
      state,
      const Duration(hours: 1),
    );
    expect(r.wasInDungeon, isFalse);
    expect(r.afkWhereLine.toLowerCase(), contains('hub'));
    if (r.goldGained > 0) {
      expect(r.headline, startsWith('Gold while away'));
    }
  });

  test('Up next kind matches ChaseContract for same state', () {
    final r = result(gold: 10);
    final contract = ChaseContract.fromState(r.state);
    expect(contract.kind, isNot(HubChaseKind.claimDailyVault));
    expect(contract.upNextLine, startsWith('Up next'));
  });

  testWidgets('Welcome Back is wow, highlights, Up next — not a syllabus', (
    tester,
  ) async {
    final director = GameDirector.preview();
    director.uiFeedback.presentOffline(result(gold: 40, essence: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.textContaining('While you are away'), findsOneWidget);
    expect(find.textContaining('keep fighting'), findsOneWidget);
    expect(find.textContaining('Up next:'), findsOneWidget);
    expect(find.textContaining('AFK'), findsNothing);
    expect(find.textContaining('Sanctuary'), findsNothing);
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.text('CLAIM'), findsNothing);
    expect(find.textContaining('WATCH AD'), findsNothing);
    expect(find.textContaining('40 gold'), findsWidgets);
  });

  testWidgets('day-2–7 Welcome Back Up next is one cave today', (tester) async {
    final now = DateTime.utc(2026, 8, 8);
    final state = GameLogic.createInitialState(
      now: now,
    ).copyWith(bossVictories: 1);
    final summary = OfflineProgressResult(
      state: state,
      secondsApplied: 3600,
      goldGained: 40,
      essenceGained: 2,
      roomsCleared: 0,
      highestFloorDelta: 0,
      bossDelta: 0,
    );
    expect(summary.highlightRows.length, lessThanOrEqualTo(3));
    final director = GameDirector.preview();
    director.uiFeedback.presentOffline(summary);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(
      find.textContaining('Up next: Clear one cave today'),
      findsOneWidget,
    );
    expect(
      find.textContaining('While you are away the hub pays'),
      findsOneWidget,
    );
    expect(find.textContaining('Daily Run'), findsNothing);
    expect(find.textContaining('KEY'), findsNothing);
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.text('CLAIM'), findsNothing);
    expect(find.textContaining('WATCH AD'), findsOneWidget);
    expect(find.textContaining('Optional. Watch an ad'), findsOneWidget);
    expect(find.textContaining('40 gold'), findsWidgets);
    final gold = director.state.gold;
    await tester.tap(find.textContaining('WATCH AD'));
    await tester.pump();
    expect(director.state.gold, gold);
    expect(find.text('WELCOME BACK'), findsOneWidget);
  });

  testWidgets('a cave Welcome Back does not say the hub was paying', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 8);
    final state = GameLogic.createInitialState(
      now: now,
    ).copyWith(inDungeon: true, bossVictories: 1);
    final summary = OfflineProgressResult(
      state: state,
      secondsApplied: 3600,
      goldGained: 0,
      essenceGained: 0,
      roomsCleared: 0,
      highestFloorDelta: 0,
      bossDelta: 0,
      wasInDungeon: true,
    );
    final director = GameDirector.preview();
    director.uiFeedback.presentOffline(summary);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kept fighting in the cave'), findsOneWidget);
    expect(
      find.textContaining('While you are away the hub pays'),
      findsNothing,
    );
    expect(find.textContaining('On the hub, gold gathers'), findsNothing);
  });

  testWidgets('a ready vault is the one claim on Welcome Back', (tester) async {
    final now = DateTime.utc(2026, 10, 9, 12);
    final fresh = GameLogic.ensureWeeklyContract(
      GameLogic.createInitialState(now: now),
      now: now,
    );
    final ready = fresh.copyWith(
      metaDepth: fresh.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    final director = GameDirector.preview(initialState: ready);
    addTearDown(director.dispose);
    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: ready,
        secondsApplied: 3600,
        goldGained: 10,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
        wasInDungeon: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('ENTER DUNGEON'), findsOneWidget);
    expect(find.text('CLOSE'), findsNothing);
    expect(find.text('CLAIM'), findsNothing);
    expect(find.textContaining('CLAIM VAULT'), findsOneWidget);
  });

  testWidgets('Welcome Back on the hub enters the cave', (tester) async {
    final director = GameDirector.preview();
    await director.boot();
    director.uiFeedback.presentOffline(result(gold: 40, essence: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(director.state.inDungeon, isFalse);
    await tester.tap(find.text('ENTER DUNGEON'));
    await tester.pumpAndSettle();
    expect(director.state.inDungeon, isTrue);
    expect(director.offlineSummary, isNull);
    director.dispose();
  });

  testWidgets('Welcome Back in the cave continues the fight', (tester) async {
    final fighting = GameLogic.enterDungeon(GameLogic.createInitialState());
    final director = GameDirector.preview(initialState: fighting);
    addTearDown(director.dispose);
    director.uiFeedback.presentOffline(
      OfflineProgressResult(
        state: fighting,
        secondsApplied: 120,
        goldGained: 0,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
        wasInDungeon: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('ENTER DUNGEON'), findsNothing);
    final floor = director.state.currentRoom.floorNumber;
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(director.state.inDungeon, isTrue);
    expect(director.state.currentRoom.floorNumber, floor);
  });

  test('hub gold fills for 12 hours and then stops', () {
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 9, 10),
    ).copyWith(autoCaveOnLeave: false);
    final full = OfflineProgress.applyOfflineProgress(
      state,
      const Duration(hours: 12),
    );
    final over = OfflineProgress.applyOfflineProgress(
      state,
      const Duration(hours: 30),
    );
    final two = OfflineProgress.applyOfflineProgress(
      state,
      const Duration(hours: 2),
    );
    final paid = OfflineProgress.applyHubIdleProgress(
      state,
      GoldIncome.hubChestCapSec,
    );

    expect(full.hubChestStopped, isFalse);
    expect(full.state.gold, paid.gold);
    expect(over.hubChestStopped, isTrue);
    expect(over.secondsApplied, GoldIncome.hubChestCapSec);
    expect(over.awayForSeconds, 30 * 3600);
    expect(over.state.gold, full.state.gold);

    final owned = state.copyWith(
      metaDepth: state.metaDepth.copyWith(shopLongAway: true),
    );
    final longFull = OfflineProgress.applyOfflineProgress(
      owned,
      const Duration(hours: 24),
    );
    final longOver = OfflineProgress.applyOfflineProgress(
      owned,
      const Duration(hours: 30),
    );
    expect(longFull.secondsApplied, GoldIncome.hubChestLongSec);
    expect(longFull.hubChestStopped, isFalse);
    expect(longOver.hubChestStopped, isTrue);
    expect(longOver.secondsApplied, GoldIncome.hubChestLongSec);
    expect(longOver.state.gold, longFull.state.gold);
    expect(longFull.state.gold, greaterThan(full.state.gold));
    expect(longOver.afkWhereLine.toLowerCase(), contains('24 hours'));
    expect(over.headline, 'Gold full · stopped at 12h');
    expect(over.welcomeLead.toLowerCase(), contains('stopped'));
    expect(over.welcomeLead.toLowerCase(), isNot(contains('sanctuary')));
    expect(over.highlightRows.map((e) => e.$2).join(' '), contains('full'));
    expect(over.afkWhereLine.toLowerCase(), contains('12 hours'));
    expect(two.hubChestStopped, isFalse);
    expect(two.state.gold, lessThan(full.state.gold));
    expect(two.headline, startsWith('Gold while away'));
  });

  test('missing autoCaveOnLeave stays on', () {
    final raw = GameLogic.createInitialState().toJson();
    raw.remove('autoCaveOnLeave');
    expect(GameLogic.stateFromJson(raw).autoCaveOnLeave, isTrue);
    final off = GameLogic.createInitialState().copyWith(
      autoCaveOnLeave: false,
      bossVictories: GameLogic.bossesRequiredForAscension(0),
      essence: 9999,
    );
    expect(GameLogic.stateFromJson(off.toJson()).autoCaveOnLeave, isFalse);
    expect(GameLogic.ascend(off).autoCaveOnLeave, isFalse);
  });

  test('hub away keeps the KEY dial and does not start a key', () {
    final hub = GameLogic.leaveDungeon(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime.utc(2026, 10, 2)),
        dungeonId: 'sandy',
      ),
    ).copyWith(hardmodeLevel: 4);
    final r = OfflineProgress.applyOfflineProgress(
      hub,
      const Duration(minutes: 5),
    );
    expect(r.autoEnteredCave, isTrue);
    expect(r.state.hardmodeLevel, 4);
    expect(r.state.keystoneRunActive, isFalse);
  });

  test('hub away fights the last cave and keeps the floor', () {
    final hub = GameLogic.leaveDungeon(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime.utc(2026, 10, 2)),
        dungeonId: 'sandy',
      ),
    );
    expect(hub.inDungeon, isFalse);
    expect(hub.autoCaveOnLeave, isTrue);
    expect(hub.dungeonId, 'sandy');

    final r = OfflineProgress.applyOfflineProgress(
      hub,
      const Duration(minutes: 5),
    );
    expect(r.autoEnteredCave, isTrue);
    expect(r.wasInDungeon, isTrue);
    expect(r.state.dungeonId, 'sandy');
    expect(
      r.state.highestFloorCleared,
      greaterThanOrEqualTo(hub.highestFloorCleared),
    );
    expect(r.roomsCleared, greaterThan(0));
    expect(r.kills, greaterThan(0));
    expect(r.goldGained, greaterThan(0));
    expect(r.afkWhereLine.toLowerCase(), contains('last cave'));
    expect(r.afkWhereLine.toLowerCase(), isNot(contains('no combat')));
  });

  test('hub away keeps a climbed floor in the last cave', () {
    final climbed = GameLogic.leaveDungeon(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(
          now: DateTime.utc(2026, 10, 2),
        ).copyWith(bossVictories: 1),
        dungeonId: 'sandy',
      ).copyWith(highestFloorCleared: 4),
    );
    final r = OfflineProgress.applyOfflineProgress(
      climbed,
      const Duration(minutes: 5),
    );
    expect(r.autoEnteredCave, isTrue);
    expect(r.wasInDungeon, isTrue);
    expect(r.state.dungeonId, 'sandy');
    expect(r.state.highestFloorCleared, greaterThanOrEqualTo(4));
  });

  test('hub away under 5 min stays on the chest', () {
    final hub = GameLogic.leaveDungeon(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime.utc(2026, 10, 2)),
        dungeonId: 'sandy',
      ),
    );
    final r = OfflineProgress.applyOfflineProgress(
      hub,
      const Duration(minutes: 4),
    );
    expect(r.autoEnteredCave, isFalse);
    expect(r.wasInDungeon, isFalse);
    expect(r.state.inDungeon, isFalse);
    final chest = OfflineProgress.applyHubIdleProgress(hub, 4 * 60);
    expect(r.state.gold, chest.gold);
    expect(r.afkWhereLine.toLowerCase(), contains('hub'));
  });

  test('a long hub away keeps the 12h and 24h chest cap in the cave', () {
    final hub = GameLogic.leaveDungeon(
      GameLogic.enterDungeon(
        GameLogic.createInitialState(now: DateTime.utc(2026, 10, 2)),
        dungeonId: 'sandy',
      ),
    );
    final r = OfflineProgress.applyOfflineProgress(
      hub,
      const Duration(hours: 13),
    );
    expect(r.autoEnteredCave, isTrue);
    expect(r.secondsApplied, GoldIncome.hubChestCapSec);
    expect(
      r.goldGained,
      greaterThanOrEqualTo(
        GoldIncome.hubGoldForSeconds(hub, GoldIncome.hubChestCapSec),
      ),
    );

    final owned = hub.copyWith(
      metaDepth: hub.metaDepth.copyWith(shopLongAway: true),
    );
    final long = OfflineProgress.applyOfflineProgress(
      owned,
      const Duration(hours: 30),
    );
    expect(long.autoEnteredCave, isTrue);
    expect(long.secondsApplied, GoldIncome.hubChestLongSec);
    expect(
      long.goldGained,
      greaterThanOrEqualTo(
        GoldIncome.hubGoldForSeconds(owned, GoldIncome.hubChestLongSec),
      ),
    );
  });

  test('claim all pays ready quests', () async {
    final now = DateTime.now().toUtc();
    final seeded = GameLogic.createInitialState(now: now);
    final state = seeded.copyWith(
      missions: [
        for (final m in seeded.missions) m.copyWith(progress: m.target),
      ],
      metaDepth: seeded.metaDepth.copyWith(
        questWeekKey: GameLogic.isoWeekKey(now),
      ),
    );
    final director = GameDirector.preview(initialState: state);
    await director.boot();
    final gold = director.state.gold;
    final essence = director.state.essence;
    final n = director.claimAllReadyMissions();
    expect(n, greaterThan(0));
    expect(
      director.state.gold > gold || director.state.essence > essence,
      isTrue,
    );
    expect(director.state.missions.any((m) => m.canClaim), isFalse);
    director.dispose();
  });

  testWidgets('Welcome Back collects ready quests', (tester) async {
    final now = DateTime.now().toUtc();
    final seeded = GameLogic.createInitialState(now: now);
    final state = seeded.copyWith(
      missions: [
        for (final m in seeded.missions) m.copyWith(progress: m.target),
      ],
      metaDepth: seeded.metaDepth.copyWith(
        questWeekKey: GameLogic.isoWeekKey(now),
      ),
    );
    final director = GameDirector.preview(initialState: state);
    await director.boot();
    director.uiFeedback.presentOffline(result(gold: 40));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('COLLECT ALL'), findsOneWidget);
    final gold = director.state.gold;
    await tester.tap(find.text('COLLECT ALL'));
    await tester.pumpAndSettle();
    expect(director.state.gold, greaterThan(gold));
    expect(director.state.missions.any((m) => m.canClaim), isFalse);
    expect(find.text('COLLECT ALL'), findsNothing);
    director.dispose();
  });

  testWidgets('a long best-item name stays above the Welcome Back buttons', (
    tester,
  ) async {
    const longName =
        'Ancient Veilglass Staff of the Mothveil Hollow Night Watch';
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 8),
    ).copyWith(bossVictories: 1);
    final summary = OfflineProgressResult(
      state: state,
      secondsApplied: 3600,
      goldGained: 40,
      essenceGained: 2,
      roomsCleared: 4,
      highestFloorDelta: 1,
      bossDelta: 0,
      levelsGained: 2,
      kills: 18,
      bestDrop: longName,
      wasInDungeon: true,
    );
    expect(summary.awayReport, contains('Best $longName'));
    final director = GameDirector.preview();
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showOfflineProgressDialog(context, director),
            child: const Text('open'),
          ),
        ),
      ),
    );
    director.uiFeedback.presentOffline(summary);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final line = find.textContaining(longName);
    expect(line, findsOneWidget);
    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsOneWidget);
    await tester.scrollUntilVisible(line, 40, scrollable: scrollable.first);
    await tester.pumpAndSettle();

    final textRect = tester.getRect(line);
    final viewRect = tester.getRect(scrollable.first);
    final buttonRect = tester.getRect(find.text('ENTER DUNGEON'));
    final visible = textRect.intersect(viewRect);
    expect(visible.height, greaterThan(8));
    expect(viewRect.bottom, lessThanOrEqualTo(buttonRect.top + 1));
    expect(visible.bottom, lessThanOrEqualTo(buttonRect.top + 1));
    expect(visible.bottom, lessThanOrEqualTo(640));
  });
}
