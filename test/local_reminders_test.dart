import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/funnel_analytics.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/local_reminders.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/meta/notify_opt_in.dart';

GameState _afterFirstLoot({bool inDungeon = false}) {
  final now = DateTime.utc(2026, 9, 12, 14);
  var state = FunnelAnalytics.onNewInstall(
    GameLogic.createInitialState(now: now),
    now,
  ).state;
  state = FunnelAnalytics.onFirstEnter(
    state,
    now,
    dungeonId: 'sandy',
  ).state;
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

  test('after first loot on the hub, offer once — never in combat', () {
    final hub = _afterFirstLoot();
    expect(LocalReminders.shouldOfferOptIn(hub), isTrue);
    expect(LocalReminders.showSettingsToggle(hub), isTrue);
    expect(
      LocalReminders.shouldOfferOptIn(_afterFirstLoot(inDungeon: true)),
      isFalse,
    );

    final dismissed = LocalReminders.setOptIn(hub, enabled: false);
    expect(LocalReminders.shouldOfferOptIn(dismissed), isFalse);
    expect(dismissed.metaDepth.notifyPrompted, isTrue);
    expect(dismissed.metaDepth.notifyOptIn, isFalse);
  });

  test('opt-in plans at most two pings and never names KEY or ESSENCE', () {
    final now = DateTime.utc(2026, 9, 12, 8);
    final opted = LocalReminders.setOptIn(_afterFirstLoot(), enabled: true);
    final pings = LocalReminders.plan(opted, now);
    expect(pings, hasLength(2));
    expect(pings.map((p) => p.id).toSet(), {LocalPing.goldId, LocalPing.caveId});
    expect(pings.first.fireAt.difference(now), LocalReminders.goldDelay);
    expect(pings.last.fireAt.difference(now), LocalReminders.caveDelay);
    final blob = pings.map((p) => '${p.title} ${p.body}').join(' ').toLowerCase();
    expect(blob, contains('gold'));
    expect(blob, isNot(contains('key')));
    expect(blob, isNot(contains('essence')));
    expect(blob, isNot(contains('combat')));
    expect(LocalReminders.optInBody.toLowerCase(), contains('settings'));
    expect(LocalReminders.optInBody.toLowerCase(), isNot(contains('key')));
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
    expect(pings.single.id, LocalPing.caveId);
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

  test('background pause records the plan; resume drops unsent futures', () async {
    final opted = LocalReminders.setOptIn(_afterFirstLoot(), enabled: true);
    final director = GameDirector.preview(initialState: opted);
    addTearDown(director.dispose);
    director.setAppPaused(true);
    await Future<void>.delayed(Duration.zero);
    expect(director.state.metaDepth.notifyPingMs, isNotEmpty);
    expect(director.state.metaDepth.notifyPingMs.length, lessThanOrEqualTo(2));
    director.setAppPaused(false);
    await Future<void>.delayed(Duration.zero);
    expect(director.state.metaDepth.notifyPingMs, isEmpty);
  });

  testWidgets('NOT NOW marks prompted and does not enable pings', (tester) async {
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

  testWidgets('YES closes the card before OS permission returns', (tester) async {
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
