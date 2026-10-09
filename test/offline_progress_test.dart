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
    expect(
      held.welcomeLead.toLowerCase(),
      contains('held the dungeon floor'),
    );
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
    expect(r.afkWhereLine.toLowerCase(), contains('no combat'));
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
    final r = result(
      gold: 80,
      rooms: 3,
      floors: 1,
      wasInDungeon: true,
    );
    expect(r.welcomeLead.toUpperCase(), isNot(contains('AFK')));
    expect(r.welcomeLead.toLowerCase(), isNot(contains('assist')));
  });

  test('hub applyOfflineProgress sets wasInDungeon false', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 9, 10));
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
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.textContaining('While you are away'), findsOneWidget);
    expect(find.textContaining('keep fighting'), findsOneWidget);
    expect(find.textContaining('Up next:'), findsOneWidget);
    expect(find.textContaining('AFK'), findsNothing);
    expect(find.textContaining('Sanctuary'), findsNothing);
    expect(find.text('CLAIM'), findsOneWidget);
    expect(find.textContaining('40 gold'), findsWidgets);
  });

  testWidgets('day-2–7 Welcome Back Up next is one cave today', (tester) async {
    final now = DateTime.utc(2026, 8, 8);
    final state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
    );
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
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.textContaining('Up next: Clear one cave today'), findsOneWidget);
    expect(find.textContaining('While you are away the hub pays'), findsOneWidget);
    expect(find.textContaining('Daily Run'), findsNothing);
    expect(find.textContaining('KEY'), findsNothing);
    expect(find.text('CLAIM'), findsOneWidget);
    expect(find.textContaining('40 gold'), findsWidgets);
  });

  testWidgets('a cave Welcome Back does not say the hub was paying', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 8);
    final state = GameLogic.createInitialState(now: now).copyWith(
      inDungeon: true,
      bossVictories: 1,
    );
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
    expect(find.textContaining('While you are away the hub pays'), findsNothing);
    expect(find.textContaining('On the hub, gold gathers'), findsOneWidget);
  });

  test('hub gold fills for 12 hours and then stops', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 9, 10));
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
}
