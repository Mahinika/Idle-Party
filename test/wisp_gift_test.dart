import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/wisp_gift.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  test('watch gold is 10× keep gold', () {
    final state = GameLogic.createInitialState();
    final keep = WispGift.keepGold(state);
    final watch = WispGift.watchGold(state);
    expect(watch, keep * 10);
  });

  test('grant watch adds gold hour and clears pending', () {
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        wispPendingWatchGold: 5000,
        wispPendingKeepGold: 500,
      ),
    );
    final beforeGold = state.gold;
    state = WispGift.grantWatchReward(state, nowMs: now);
    expect(state.gold, beforeGold + 5000);
    expect(state.metaDepth.wispPendingWatchGold, 0);
    expect(
      state.metaDepth.adGoldUntilMs,
      now + WispGift.watchGoldHourMs,
    );
  });

  test('gold hour respects 24h stack cap', () {
    final now = 1_700_000_000_000;
    final capUntil = now + AdBoost.maxStackMs;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        wispPendingWatchGold: 100,
        adGoldUntilMs: capUntil,
      ),
    );
    state = WispGift.grantWatchReward(state, nowMs: now);
    expect(state.metaDepth.adGoldUntilMs, capUntil);
    expect(state.gold, greaterThan(0));
  });

  test('debug cadence does not stop after six claims', () {
    final now = DateTime.utc(2026, 9, 28, 12);
    var md = MetaDepthState.empty.copyWith(
      wispUnlocked: true,
      wispGiftUtcDay: WispGift.utcDayKey(now),
      wispGiftClaimsToday: 6,
    );
    expect(WispGift.unlimitedToday, isTrue);
    expect(WispGift.canTapToday(md, now: now), isTrue);
    expect(WispGift.intervalMs, 20 * 1000);
  });

  test('on wisp tap locks pending watch amount', () {
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: WispGift.unlockOnFirstEnter(state.metaDepth, nowMs: now),
    );
    final watch = WispGift.watchGold(state);
    final keep = WispGift.keepGold(state);
    final goldBefore = state.gold;
    state = WispGift.onWispTapped(state, nowMs: now);
    expect(state.gold, goldBefore + keep);
    expect(state.metaDepth.wispPendingWatchGold, watch);
    expect(state.metaDepth.wispGiftClaimsToday, 1);
  });

  test('missed wisp pushes next spawn', () {
    final now = 1_700_000_000_000;
    var state = GameLogic.createInitialState();
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        wispUnlocked: true,
        wispNextSpawnMs: now - 1,
      ),
    );
    state = WispGift.onWispMissed(state, nowMs: now);
    expect(
      state.metaDepth.wispNextSpawnMs,
      now + WispGift.intervalMs,
    );
  });

  test('old save JSON defaults wisp fields to zero', () {
    final md = MetaDepthState.fromJson(<String, dynamic>{});
    expect(md.wispUnlocked, isFalse);
    expect(md.wispGiftClaimsToday, 0);
    expect(md.wispPendingWatchGold, 0);
  });
}
