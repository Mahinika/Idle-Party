import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/away_fight_tip.dart';
import 'package:idle_party/core/funnel_analytics.dart';
import 'package:idle_party/core/game_guides.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);

  test('new save hides the hub line until they have entered', () {
    final state = GameLogic.createInitialState(now: now);
    expect(AwayFightTip.shouldShow(state, bossStairs: false), isFalse);
    expect(AwayFightTip.shouldShow(state, bossStairs: true), isTrue);
    expect(
      AwayFightTip.shouldShow(state, bossStairs: false, inCave: true),
      isTrue,
    );
    expect(AwayFightTip.lineFor(state), AwayFightTip.line);
    expect(AwayFightTip.lineFor(state, onHub: true), AwayFightTip.hubLine);
    expect(AwayFightTip.hubLine.toLowerCase(), contains('gold'));
    expect(AwayFightTip.hubLine.toLowerCase(), contains('cave'));

    final entered = FunnelAnalytics.onFirstEnter(
      state,
      now,
      dungeonId: 'sandy',
    ).state;
    expect(AwayFightTip.shouldShow(entered, bossStairs: false), isTrue);
    expect(AwayFightTip.lineFor(entered, onHub: true), AwayFightTip.hubLine);
  });

  test('after the first boss the hub names tomorrow for that day', () {
    final fresh = GameLogic.createInitialState(now: now);
    final hub = fresh.copyWith(bossVictories: 1);
    expect(AwayFightTip.shouldShow(hub, bossStairs: false, now: now), isTrue);
    final empty = AwayFightTip.lineFor(hub, onHub: true).toLowerCase();
    expect(empty, contains('one cave'));
    expect(empty, contains('keeps fighting'));
    expect(empty, isNot(contains('tomorrow')));
    expect(empty, isNot(contains('on the hub')));

    final ready = hub.copyWith(
      metaDepth: hub.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
      ),
    );
    final claim = AwayFightTip.lineFor(ready, onHub: true).toLowerCase();
    expect(claim, contains('tap claim'));
    expect(claim, contains('before the day ends'));
    expect(claim, isNot(contains('tomorrow')));

    final claimed = hub.copyWith(
      metaDepth: hub.metaDepth.copyWith(dailyVaultClaimed: true),
    );
    final text = AwayFightTip.lineFor(claimed, onHub: true).toLowerCase();
    expect(text, contains('tomorrow'));
    expect(text, contains('essence'));
    expect(text, contains('keeps fighting'));
    expect(text, isNot(contains('on the hub')));

    final armed = AwayFightTip.arm(hub, now);
    expect(armed.metaDepth.awayPromiseUtc, '2026-10-07');
    expect(AwayFightTip.shouldShow(armed, bossStairs: false, now: now), isTrue);
    final nextDay = DateTime.utc(2026, 10, 8, 12);
    expect(
      AwayFightTip.shouldShow(armed, bossStairs: false, now: nextDay),
      isFalse,
    );

    final round = MetaDepthState.fromJson(armed.metaDepth.toJson());
    expect(round.awayPromiseUtc, '2026-10-07');
    expect(MetaDepthState.fromJson(const {}).awayPromiseUtc, isEmpty);

    final seen = AwayFightTip.markSeen(hub);
    expect(AwayFightTip.shouldShow(seen, bossStairs: false, now: now), isFalse);
  });

  test('ascend keeps the away appointment', () {
    final fresh = GameLogic.createInitialState(now: now);
    final armed = AwayFightTip.arm(fresh.copyWith(bossVictories: 1, essence: 40), now);
    final ascended = GameLogic.ascend(
      armed,
      now: now.add(const Duration(days: 1)),
    );
    expect(ascended.metaDepth.awayPromiseUtc, '2026-10-07');
    expect(ascended.ascensionLevel, 1);
    expect(
      AwayFightTip.shouldShow(
        ascended,
        bossStairs: false,
        now: now.add(const Duration(days: 1)),
      ),
      isFalse,
    );
  });

  test('first hour guide says the party keeps fighting', () {
    final state = GameLogic.createInitialState(now: now);
    expect(GameGuides.firstHourTopicIds, contains('away'));
    final away = GameGuides.topicsFor(state).firstWhere((t) => t.id == 'away');
    expect(away.body.toLowerCase(), contains('close the app'));
    expect(away.body.toLowerCase(), contains('keep fighting'));
    expect(away.body.toLowerCase(), contains('gold'));
    expect(away.body.toUpperCase(), isNot(contains('ESSENCE')));
  });
}
