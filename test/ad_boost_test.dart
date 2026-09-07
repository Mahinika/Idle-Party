import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  const now = 1_700_000_000_000;

  test('one ad grants a ticket; spend Full Boost adds hoursPerAd', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    state = GameLogic.grantAdTicket(state);
    expect(state.metaDepth.adTickets, 1);
    state = GameLogic.grantAdTicket(state);
    expect(state.metaDepth.adTickets, 2);
    state = GameLogic.spendAdBuff(state, AdBuffId.bundle, nowMs: now);
    expect(state.metaDepth.adTickets, 0);
    expect(state.metaDepth.adAtkUntilMs, now + AdBoost.rewardMs);
    expect(state.metaDepth.adGoldUntilMs, now + AdBoost.rewardMs);
    expect(AdBoost.formatRemaining(state.metaDepth.adAtkUntilMs, nowMs: now), '3h');
  });

  test('Sharp Edge stacks duration and caps at 24h', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    for (var i = 0; i < 30; i++) {
      state = GameLogic.grantAdTicket(state);
      state = GameLogic.spendAdBuff(state, AdBuffId.atk, nowMs: now);
    }
    expect(
      AdBoost.remainingMs(state.metaDepth.adAtkUntilMs, nowMs: now),
      AdBoost.maxStackMs,
    );
    expect(AdBoost.atStackCap(state.metaDepth.adAtkUntilMs, nowMs: now), isTrue);
  });

  test('legacy adBoostUntilMs migrates into both timers', () {
    final legacy = MetaDepthState.fromJson({
      'adBoostUntilMs': now + AdBoost.hourMs,
    });
    expect(legacy.adAtkUntilMs, now + AdBoost.hourMs);
    expect(legacy.adGoldUntilMs, now + AdBoost.hourMs);
    expect(legacy.adTickets, 0);
  });

  test('tickets and timers persist on JSON round-trip', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    state = GameLogic.grantAdTicket(state, count: 3);
    state = GameLogic.spendAdBuff(state, AdBuffId.atk, nowMs: now);
    final loaded = MetaDepthState.fromJson(state.metaDepth.toJson());
    expect(loaded.adTickets, 2);
    expect(loaded.adAtkUntilMs, state.metaDepth.adAtkUntilMs);
  });

  test('active gold boost doubles hub gold and combat gold', () {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    var boosted = GameLogic.grantAdTicket(base);
    boosted = GameLogic.spendAdBuff(boosted, AdBuffId.gold, nowMs: nowMs);
    expect(
      GoldIncome.hubGoldPerMinute(boosted),
      2 * GoldIncome.hubGoldPerMinute(base),
    );
    expect(
      GameLogic.applyGoldGain(boosted, 100),
      2 * GameLogic.applyGoldGain(base, 100),
    );
    expect(GoldIncome.multiplierLine(boosted), contains('Ad ×2 gold'));
  });

  test('active ATK boost raises party attack by 25 percent', () {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    final hero = base.heroes.first;
    final raw = base.ratingsFor(hero).effectiveAttack;
    var boosted = GameLogic.grantAdTicket(base);
    boosted = GameLogic.spendAdBuff(boosted, AdBuffId.atk, nowMs: nowMs);
    expect(
      boosted.ratingsFor(hero).effectiveAttack,
      raw + (raw * AdBoost.attackPercent) ~/ 100,
    );
  });

  test('Away Bonus doubles next offline gold once', () {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    state = GameLogic.grantAdTicket(state);
    state = GameLogic.spendAdBuff(state, AdBuffId.offline, nowMs: nowMs);
    expect(AdBoost.awayBonusReady(state.metaDepth, nowMs: nowMs), isTrue);
    final afterIdle = GameLogic.applyHubIdleProgress(state, 3600);
    final withBonus = GameLogic.applyAwayBonusToOfflineGold(
      state,
      afterIdle,
      nowMs: nowMs,
    );
    final plain = afterIdle.gold - state.gold;
    expect(withBonus.gold - state.gold, plain * 2);
    expect(withBonus.metaDepth.adOfflineMulPending, isFalse);
  });

  test('Ascend keeps tickets and remaining POWERUPS time', () {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 21),
    ).copyWith(bossVictories: 1);
    state = GameLogic.grantAdTicket(state, count: 4);
    state = GameLogic.spendAdBuff(state, AdBuffId.bundle, nowMs: nowMs);
    final tickets = state.metaDepth.adTickets;
    final atk = state.metaDepth.adAtkUntilMs;
    final after = GameLogic.ascend(state, now: DateTime.utc(2026, 8, 21));
    expect(after.ascensionLevel, 1);
    expect(after.metaDepth.adTickets, tickets);
    expect(after.metaDepth.adAtkUntilMs, atk);
  });

  test('ad-free daily ticket once per UTC day', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    state = state.copyWith(metaDepth: state.metaDepth.copyWith(adFree: true));
    final day = DateTime.utc(2026, 9, 6, 12);
    state = GameLogic.claimAdFreeDailyTicket(state, now: day);
    expect(state.metaDepth.adTickets, 1);
    final again = GameLogic.claimAdFreeDailyTicket(state, now: day);
    expect(again.metaDepth.adTickets, 1);
    final nextDay = GameLogic.claimAdFreeDailyTicket(
      state,
      now: DateTime.utc(2026, 9, 7, 1),
    );
    expect(nextDay.metaDepth.adTickets, 2);
  });

  test('extendUntil helper still caps at 24h', () {
    var until = 0;
    for (var i = 0; i < 30; i++) {
      until = AdBoost.addHour(until, nowMs: now);
    }
    expect(AdBoost.remainingMs(until, nowMs: now), AdBoost.maxStackMs);
    expect(AdBoost.addHour(until, nowMs: now), until);
  });
}
