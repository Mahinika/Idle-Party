import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/funnel_analytics.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/local_reminders.dart';
import 'package:idle_party/models/pet.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/meta/notify_opt_in.dart';

GameState _afterFirstLoot({bool inDungeon = false}) {
  final now = DateTime.utc(2026, 9, 12, 14);
  var state = FunnelAnalytics.onNewInstall(
    GameLogic.createInitialState(now: now),
    now,
  ).state;
  state = FunnelAnalytics.onFirstEnter(state, now, dungeonId: 'sandy').state;
  state = FunnelAnalytics.onFirstReward(state).state;
  if (inDungeon) {
    state = state.copyWith(inDungeon: true);
  }
  return state;
}

void main() {
  test('new save never offers the ping card', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 9, 12));
    expect(LocalReminders.shouldOfferOptIn(state), isFalse);
    expect(LocalReminders.showSettingsToggle(state), isFalse);
    expect(LocalReminders.plan(state, DateTime.utc(2026, 9, 12)), isEmpty);
  });

  test('first_enter alone is not enough — wait for a reward', () {
    final now = DateTime.utc(2026, 9, 12, 14);
    var state = FunnelAnalytics.onNewInstall(
      GameLogic.createInitialState(now: now),
      now,
    ).state;
    state = FunnelAnalytics.onFirstEnter(state, now, dungeonId: 'sandy').state;
    expect(LocalReminders.shouldOfferOptIn(state), isFalse);
  });

  test('first loot is not the ping — wait until the first boss', () {
    final hub = _afterFirstLoot();
    expect(LocalReminders.shouldOfferOptIn(hub), isFalse);
    expect(
      LocalReminders.shouldOfferOptIn(
        hub.copyWith(
          metaDepth: hub.metaDepth.copyWith(hubAfkSec: 60),
        ),
      ),
      isFalse,
    );
    expect(LocalReminders.showSettingsToggle(hub), isTrue);
  });

  test('after the first boss, offer once — never in a fight', () {
    final ticking = _afterFirstLoot().copyWith(bossVictories: 1);
    expect(LocalReminders.shouldOfferOptIn(ticking), isTrue);
    expect(LocalReminders.showSettingsToggle(ticking), isTrue);
    expect(
      LocalReminders.shouldOfferOptIn(ticking.copyWith(inDungeon: true)),
      isFalse,
    );
    expect(
      LocalReminders.shouldOfferOnFloorClear(
        ticking.copyWith(inDungeon: true),
        floorClear: false,
      ),
      isFalse,
    );
    expect(
      LocalReminders.shouldOfferOnFloorClear(
        ticking.copyWith(inDungeon: true),
        floorClear: true,
      ),
      isTrue,
    );
    expect(
      LocalReminders.shouldOfferOnFloorClear(
        _afterFirstLoot().copyWith(inDungeon: true),
        floorClear: true,
      ),
      isFalse,
    );

    final dismissed = LocalReminders.setOptIn(ticking, enabled: false);
    expect(LocalReminders.shouldOfferOptIn(dismissed), isFalse);
    expect(dismissed.metaDepth.notifyPrompted, isTrue);
    expect(dismissed.metaDepth.notifyOptIn, isFalse);
  });

  test('opt-in plans chest full and morning or evening, never KEY', () {
    final now = DateTime.utc(2026, 9, 12, 8);
    final opted = LocalReminders.setOptIn(_afterFirstLoot(), enabled: true);
    final pings = LocalReminders.plan(opted, now);
    expect(pings.map((p) => p.id), contains(LocalPing.goldId));
    expect(
      pings.map((p) => p.id),
      containsAll([LocalPing.morningId, LocalPing.eveningId]),
    );
    final byDay = <DateTime, int>{};
    for (final ping in pings) {
      expect(ping.fireAt.difference(now) <= LocalReminders.horizon, isTrue);
      final day = LocalReminders.utcDay(ping.fireAt);
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    expect(byDay.values.every((n) => n <= LocalReminders.maxPerUtcDay), isTrue);
    final gold = pings.firstWhere((p) => p.id == LocalPing.goldId);
    expect(
      gold.fireAt.difference(now),
      Duration(seconds: GoldIncome.hubChestCapSec),
    );
    final amount = GoldIncome.groupDigits(
      GoldIncome.hubGoldForSeconds(opted, GoldIncome.hubChestCapSec),
    );
    expect(gold.body, contains(amount));
    expect(gold.body.toLowerCase(), contains('full'));
    final tray = LocalReminders.chestTray(opted, now);
    expect(tray, isNotNull);
    expect(tray!.body, contains(amount));
    final blob = pings
        .map((p) => '${p.title} ${p.body}')
        .join(' ')
        .toLowerCase();
    expect(blob, contains('gold'));
    expect(blob, isNot(contains('key')));
    expect(blob, isNot(contains('essence')));
    expect(blob, isNot(contains('combat')));
    expect(LocalReminders.optInBody.toLowerCase(), contains('settings'));
    expect(LocalReminders.optInBody.toLowerCase(), contains('12 hours'));
    expect(LocalReminders.optInBody.toLowerCase(), contains('chest'));
    expect(LocalReminders.optInBody.toLowerCase(), isNot(contains('key')));
  });

  test('after the first boss the prize ping names the check-in', () {
    final now = DateTime.utc(2026, 9, 12, 8);
    final opted = LocalReminders.setOptIn(
      _afterFirstLoot().copyWith(bossVictories: 1),
      enabled: true,
    );
    final pings = LocalReminders.plan(opted, now);
    final prize = pings.where(
      (p) => p.id == LocalPing.morningId || p.id == LocalPing.eveningId,
    );
    expect(prize, isNotEmpty);
    expect(prize.first.body.toLowerCase(), contains('one cave'));
    expect(prize.first.body.toLowerCase(), isNot(contains('check-in')));
    expect(prize.first.body.toLowerCase(), isNot(contains('key')));

    final ready = opted.copyWith(
      metaDepth: opted.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
      ),
    );
    final readyPing = LocalReminders.plan(ready, now).firstWhere(
      (p) => p.id == LocalPing.morningId || p.id == LocalPing.eveningId,
    );
    expect(readyPing.body.toLowerCase(), contains('claim'));
    expect(readyPing.body.toLowerCase(), contains('before the day ends'));
    expect(readyPing.body.toLowerCase(), contains('essence'));

    final claimed = opted.copyWith(
      metaDepth: opted.metaDepth.copyWith(dailyVaultClaimed: true),
    );
    final claimedPing = LocalReminders.plan(claimed, now).firstWhere(
      (p) => p.id == LocalPing.morningId || p.id == LocalPing.eveningId,
    );
    expect(claimedPing.body, contains('Check-in'));
    expect(claimedPing.body.toLowerCase(), contains('tomorrow'));
  });

  test('a dungeon leave does not promise hub gold', () {
    final now = DateTime.utc(2026, 9, 12, 8);
    final opted = LocalReminders.setOptIn(
      _afterFirstLoot(inDungeon: true),
      enabled: true,
    );
    final pings = LocalReminders.plan(opted, now);
    expect(pings.where((p) => p.id == LocalPing.goldId), isEmpty);
    expect(LocalReminders.chestTray(opted, now), isNull);
  });

  test('a pet coming home keeps a ping slot over the evening prize', () {
    final now = DateTime.utc(2026, 9, 12, 8);
    const pet = Pet(
      id: 'cave_bat_1',
      name: 'Cave Bat',
      attackBonus: 3,
      speciesId: 'cave_bat',
    );
    var state = _afterFirstLoot().copyWith(ownedPets: const [pet]);
    state = GameLogic.sendPetErrand(state, pet.id, 4, now: now);
    state = LocalReminders.setOptIn(state, enabled: true);
    final pings = LocalReminders.plan(state, now);
    expect(pings.map((p) => p.id), contains(LocalPing.petId));
    expect(pings.map((p) => p.id), contains(LocalPing.goldId));
    expect(pings.map((p) => p.id), isNot(contains(LocalPing.eveningId)));
    expect(
      pings.firstWhere((p) => p.id == LocalPing.petId).body,
      contains('Cave Bat is home'),
    );
  });

  test('UTC day cap skips a same-day gold ping when two already fired', () {
    final now = DateTime.utc(2026, 9, 12, 10);
    var state = LocalReminders.setOptIn(_afterFirstLoot(), enabled: true);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        notifyPingMs: [
          DateTime.utc(2026, 9, 12, 1).millisecondsSinceEpoch,
          DateTime.utc(2026, 9, 12, 2).millisecondsSinceEpoch,
        ],
      ),
    );
    final pings = LocalReminders.plan(state, now);
    expect(pings, hasLength(1));
    expect(pings.single.id, LocalPing.morningId);
    expect(
      LocalReminders.utcDay(pings.single.fireAt),
      isNot(LocalReminders.utcDay(now)),
    );
  });

  test('legacy metaDepth omits reminder fields', () {
    final md = MetaDepthState.fromJson(<String, dynamic>{'weeklyProgress': 1});
    expect(md.notifyOptIn, isFalse);
    expect(md.notifyPrompted, isFalse);
    expect(md.notifyPingMs, isEmpty);

    final opted = LocalReminders.setOptIn(_afterFirstLoot(), enabled: true);
    final round = MetaDepthState.fromJson(opted.metaDepth.toJson());
    expect(round.notifyOptIn, isTrue);
    expect(round.notifyPrompted, isTrue);
  });

  test('Ascend keeps notify opt-in', () {
    final now = DateTime.utc(2026, 9, 12, 14);
    var state = LocalReminders.setOptIn(_afterFirstLoot(), enabled: true);
    state = GameLogic.ascend(state, now: now);
    expect(state.metaDepth.notifyOptIn, isTrue);
    expect(state.metaDepth.notifyPrompted, isTrue);
  });

  test(
    'background pause records the plan; resume drops unsent futures',
    () async {
      final opted = LocalReminders.setOptIn(_afterFirstLoot(), enabled: true);
      final director = GameDirector.preview(initialState: opted);
      addTearDown(director.dispose);
      director.setAppPaused(true);
      await Future<void>.delayed(Duration.zero);
      expect(director.state.metaDepth.notifyPingMs, isNotEmpty);
      expect(
        director.state.metaDepth.notifyPingMs.length,
        lessThanOrEqualTo(4),
      );
      director.setAppPaused(false);
      await Future<void>.delayed(Duration.zero);
      expect(director.state.metaDepth.notifyPingMs, isEmpty);
    },
  );

  testWidgets('NOT NOW marks prompted and does not enable pings', (
    tester,
  ) async {
    final director = GameDirector.preview(initialState: _afterFirstLoot());
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => NotifyOptInOverlay.show(ctx, director),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text(LocalReminders.optInTitle), findsOneWidget);
    expect(find.textContaining('KEY'), findsNothing);
    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();
    expect(director.state.metaDepth.notifyPrompted, isTrue);
    expect(director.state.metaDepth.notifyOptIn, isFalse);
  });

  testWidgets('YES closes the card before OS permission returns', (
    tester,
  ) async {
    final director = GameDirector.preview(initialState: _afterFirstLoot());
    addTearDown(director.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => NotifyOptInOverlay.show(ctx, director),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YES'));
    await tester.pumpAndSettle();
    expect(find.text(LocalReminders.optInTitle), findsNothing);
  });
}
