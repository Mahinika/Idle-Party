import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  const now = 1_700_000_000_000;

  test('one ad adds one hour from now', () {
    final until = AdBoost.addHour(0, nowMs: now);
    expect(until, now + AdBoost.hourMs);
    expect(AdBoost.isActive(until, nowMs: now), isTrue);
    expect(AdBoost.remainingMs(until, nowMs: now), AdBoost.hourMs);
    expect(AdBoost.formatRemaining(until, nowMs: now), '1h');
  });

  test('watching again stacks on remaining time', () {
    final first = AdBoost.addHour(0, nowMs: now);
    final second = AdBoost.addHour(first, nowMs: now);
    expect(second, now + 2 * AdBoost.hourMs);
    expect(AdBoost.formatRemaining(second, nowMs: now), '2h');
  });

  test('stack caps at 24 hours remaining', () {
    var until = 0;
    for (var i = 0; i < 30; i++) {
      until = AdBoost.addHour(until, nowMs: now);
    }
    expect(AdBoost.remainingMs(until, nowMs: now), AdBoost.maxStackMs);
    expect(AdBoost.atStackCap(until, nowMs: now), isTrue);
    expect(AdBoost.addHour(until, nowMs: now), until);
  });

  test('expired boost is ignored', () {
    expect(AdBoost.isActive(now - 1, nowMs: now), isFalse);
    expect(AdBoost.remainingMs(now - 1, nowMs: now), 0);
    expect(AdBoost.formatRemaining(now - 1, nowMs: now), '');
  });

  test('grant persists on metaDepth and survives a JSON round-trip', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    state = GameLogic.grantAdBoostHour(state, nowMs: now);
    state = GameLogic.grantAdBoostHour(state, nowMs: now);
    expect(state.metaDepth.adBoostUntilMs, now + 2 * AdBoost.hourMs);

    final loaded = MetaDepthState.fromJson(state.metaDepth.toJson());
    expect(loaded.adBoostUntilMs, state.metaDepth.adBoostUntilMs);

    final legacy = MetaDepthState.fromJson({'playGamesOptIn': false});
    expect(legacy.adBoostUntilMs, 0);
  });

  test('active boost doubles hub gold and combat gold', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    final boosted = GameLogic.grantAdBoostHour(base, nowMs: now);
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

  test('active boost raises party attack by 25 percent', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final base = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 21));
    final hero = base.heroes.first;
    final raw = base.ratingsFor(hero).effectiveAttack;
    final boosted = GameLogic.grantAdBoostHour(base, nowMs: now);
    expect(
      boosted.ratingsFor(hero).effectiveAttack,
      raw + (raw * AdBoost.attackPercent) ~/ 100,
    );
  });

  test('Ascend keeps remaining POWERUPS time', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    var state = GameLogic.createInitialState(
      now: DateTime.utc(2026, 8, 21),
    ).copyWith(bossVictories: 1);
    state = GameLogic.grantAdBoostHour(state, nowMs: now);
    final until = state.metaDepth.adBoostUntilMs;
    final after = GameLogic.ascend(state, now: DateTime.utc(2026, 8, 21));
    expect(after.ascensionLevel, 1);
    expect(after.metaDepth.adBoostUntilMs, until);
  });
}
