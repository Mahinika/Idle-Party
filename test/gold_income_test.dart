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
    expect(GoldIncome.awayPromise(state), contains('While you are away'));
    expect(GoldIncome.awayPromise(state), contains('12 hours'));
    final owned = state.copyWith(
      metaDepth: state.metaDepth.copyWith(shopLongAway: true),
    );
    expect(GoldIncome.awayPromise(owned), contains('24 hours'));
    expect(GoldIncome.hubRateCompact(owned), contains('24h'));
    expect(GoldIncome.awayPromise(state).toLowerCase(), contains('stops'));
    expect(GoldIncome.awayPromise(state).toLowerCase(), contains('cave'));
    expect(
      GoldIncome.awayPromise(state, wasInDungeon: true),
      contains('kept fighting in the cave'),
    );
    expect(
      GoldIncome.awayPromise(state, wasInDungeon: true),
      isNot(contains('While you are away the hub pays')),
    );
    expect(GoldIncome.hubRateCompact(state), contains('12h'));
    expect(GoldIncome.multiplierLine(state), 'Gold +0%');
  });

  test('an open hub keeps paying after the away chest would stop', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    final chest = GoldIncome.applyHubIdle(state, GoldIncome.hubChestCapSec);
    final longer = GoldIncome.applyHubIdle(state, 20 * 3600);
    expect(longer.gold, greaterThan(chest.gold));
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

  test('income line names relic and star gold the hub rate uses', () {
    final bare = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    final state = bare.copyWith(
      sanctuaryGoldLevel: 40,
      unlockedRelics: const ['porch_lantern'],
      metaDepth: bare.metaDepth.copyWith(
        constellationNodes: const ['for_gold'],
      ),
    );
    final paced = bare.copyWith(sanctuaryGoldLevel: 40);
    final line = GoldIncome.multiplierLine(state);
    expect(line, contains('Relic +6%'));
    expect(line, contains('Stars +3%'));
    expect(
      GoldIncome.hubGoldPerMinute(state),
      greaterThan(GoldIncome.hubGoldPerMinute(paced)),
    );
  });

  test('legacy metaDepth json defaults hub idle remainders to 0', () {
    final md = MetaDepthState.fromJson({'playGamesOptIn': false});
    expect(md.hubIdleSubSec, 0);
    expect(md.hubAfkSec, 0);
  });

  test('10 minutes of hub AFK opens the essence gate; first tick at ~12.5 min', () {
    var state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 20),
    ).copyWith(sanctuaryPowerLevel: 0);
    final startE = state.essence;
    state = GoldIncome.applyHubIdle(state, 600);
    expect(state.essence, startE);
    state = GoldIncome.applyHubIdle(state, 150);
    expect(state.essence, greaterThan(startE));
  });

  test('War Altar raises ongoing hub AFK essence rate', () {
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 20));
    final plainStart = base.essence;
    final poweredStart = base.essence;
    final plain = GoldIncome.applyHubIdle(base, 3600);
    final powered = GoldIncome.applyHubIdle(
      base.copyWith(sanctuaryPowerLevel: 12),
      3600,
    );
    expect(powered.essence - poweredStart, greaterThan(plain.essence - plainStart));
    expect(
      GoldIncome.essenceDue(3600, 12) - GoldIncome.essenceDue(1800, 12),
      greaterThan(
        GoldIncome.essenceDue(3600, 0) - GoldIncome.essenceDue(1800, 0),
      ),
    );
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
