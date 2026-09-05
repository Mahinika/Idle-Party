import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('starter hub rate is a real overnight trickle', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    expect(GoldIncome.hubRawPerMinute(state), 10);
    expect(GoldIncome.hubGoldPerMinute(state), GoldIncome.hubRawPerMinute(state));
    expect(GoldIncome.hubRateLine(state), contains('g/min'));
    expect(GoldIncome.multiplierLine(state), 'Gold +0%');
  });

  test('1s ticks bank remainder then match a 60s apply', () {
    var ticked = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    final startGold = ticked.gold;
    for (var i = 0; i < 60; i++) {
      ticked = GoldIncome.applyHubIdle(ticked, 1);
    }
    var once = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    once = GoldIncome.applyHubIdle(once, 60);
    expect(ticked.gold - startGold, once.gold - startGold);
    expect(ticked.gold - startGold, GoldIncome.hubGoldPerMinute(once));
  });

  test('partial seconds then the remainder credit the first gold', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    final start = state.gold;
    final p = GoldIncome.hubRawPerMinute(state);
    final need = (60 + p - 1) ~/ p;
    state = GoldIncome.applyHubIdle(state, need - 1);
    expect(state.gold, start);
    expect(state.metaDepth.hubIdleSubSec, need - 1);
    state = GoldIncome.applyHubIdle(state, 1);
    expect(state.gold, start + 1);
    expect(state.metaDepth.hubIdleSubSec, 0);
  });

  test('Gold Find level raises hub g/min', () {
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 20),
    ).copyWith(sanctuaryGoldLevel: 2);
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    expect(
      GoldIncome.hubGoldPerMinute(state),
      greaterThan(GoldIncome.hubGoldPerMinute(base)),
    );
    expect(GoldIncome.nextGoldFindDeltaPerMinute(base), greaterThan(0));
  });

  test('CAMP gold % shows on the multiplier line', () {
    final state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 20),
    ).copyWith(sanctuaryGoldLevel: 4, ascensionLevel: 2);
    final line = GoldIncome.multiplierLine(state);
    expect(line, contains('AL'));
    expect(line, contains('Essence'));
  });

  test('legacy metaDepth json defaults hub idle remainders to 0', () {
    final md = MetaDepthState.fromJson({'playGamesOptIn': false});
    expect(md.hubIdleSubSec, 0);
    expect(md.hubAfkSec, 0);
  });

  test('10 minutes of hub AFK can grant essence', () {
    var state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 20),
    ).copyWith(sanctuaryPowerLevel: 2);
    final startE = state.essence;
    state = GoldIncome.applyHubIdle(state, 600);
    expect(state.essence, greaterThan(startE));
  });

  test('run gold/min uses credited samples after warmup, not a burst', () {
    const t0 = 1_000_000;
    final samples = <(int, int)>[
      (t0, 40),
      (t0 + 20000, 40),
    ];
    expect(
      GoldIncome.runGoldPerMinuteFromSamples(samples, nowMs: t0 + 5000),
      0,
    );
    expect(
      GoldIncome.runGoldPerMinuteFromSamples(samples, nowMs: t0 + 20000),
      240,
    );
  });

  test('gold-find percent scales an observed run rate', () {
    expect(GoldIncome.scaledGpm(100, 0, 10), 110);
    expect(GoldIncome.goldFindDeltaOnRate(100, 0, 10), 10);
  });

  test('rates line adds Run only when the session has a rate', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    expect(GoldIncome.ratesLine(state), GoldIncome.hubRateLine(state));
    expect(GoldIncome.ratesLine(state, runGpm: 180), contains('Run 180g/min'));
  });

  test('gold find bulk respects essence cap and max levels', () {
    var state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 20),
    ).copyWith(essence: 500);
    expect(GoldIncome.goldFindBulkAffordableLevels(state), 5);
    state = state.copyWith(essence: 20);
    expect(GoldIncome.goldFindBulkAffordableLevels(state), 1);
    final before = state.sanctuaryGoldLevel;
    final afford = GoldIncome.goldFindBulkAffordableLevels(state);
    final bulked = GameLogic.upgradeSanctuaryBulk(state, 'gold', maxLevels: 5);
    expect(bulked.sanctuaryGoldLevel, before + afford);
  });
}
