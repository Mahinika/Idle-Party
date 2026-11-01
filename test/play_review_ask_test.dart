import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/play_review_ask.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 12);

  GameState later({int session = 2}) {
    final state = GameLogic.createInitialState(now: now);
    return state.copyWith(
      bossVictories: 1,
      metaDepth: state.metaDepth.copyWith(sessionCount: session),
    );
  }

  OfflineProgressResult caveWelcome(GameState state) {
    return OfflineProgressResult(
      state: state,
      secondsApplied: 3600,
      goldGained: 40,
      essenceGained: 0,
      roomsCleared: 2,
      highestFloorDelta: 0,
      bossDelta: 0,
      kills: 4,
      wasInDungeon: true,
    );
  }

  test('new save never asks for a Play rating', () {
    final state = GameLogic.createInitialState(now: now);
    expect(state.metaDepth.sessionCount, 0);
    expect(PlayReviewAsk.shouldOffer(state, bossThisSession: true), isFalse);
  });

  test('the first sitting never asks, even after a boss', () {
    final first = later(session: 1);
    expect(
      PlayReviewAsk.shouldOffer(first, bossThisSession: true, now: now),
      isFalse,
    );
    expect(
      PlayReviewAsk.shouldOffer(first, welcome: caveWelcome(first), now: now),
      isFalse,
    );
  });

  test('a later sitting asks after a boss or a cave Welcome Back', () {
    final hub = later();
    expect(PlayReviewAsk.shouldOffer(hub, now: now), isFalse);
    expect(
      PlayReviewAsk.shouldOffer(hub, bossThisSession: true, now: now),
      isTrue,
    );
    expect(
      PlayReviewAsk.shouldOffer(hub, welcome: caveWelcome(hub), now: now),
      isTrue,
    );
    expect(
      PlayReviewAsk.shouldOffer(
        hub.copyWith(inDungeon: true),
        bossThisSession: true,
        now: now,
      ),
      isFalse,
    );

    final small = OfflineProgressResult(
      state: hub,
      secondsApplied: 120,
      goldGained: 5,
      essenceGained: 0,
      roomsCleared: 0,
      highestFloorDelta: 0,
      bossDelta: 0,
    );
    expect(PlayReviewAsk.isBigWelcome(small), isFalse);
    expect(PlayReviewAsk.shouldOffer(hub, welcome: small, now: now), isFalse);

    final filled = OfflineProgressResult(
      state: hub,
      secondsApplied: 12 * 3600,
      secondsAway: 20 * 3600,
      goldGained: 80,
      essenceGained: 0,
      roomsCleared: 0,
      highestFloorDelta: 0,
      bossDelta: 0,
      hubChestCapSec: 12 * 3600,
    );
    expect(filled.hubChestStopped, isTrue);
    expect(PlayReviewAsk.isBigWelcome(filled), isTrue);
  });

  test('NOT NOW waits seven days and stops after three asks', () {
    var state = later();
    final once = PlayReviewAsk.snooze(state, now: now);
    expect(once.metaDepth.reviewAskCount, 1);
    expect(once.metaDepth.reviewPrompted, isFalse);
    expect(PlayReviewAsk.snooze(once, now: now).metaDepth.reviewAskCount, 1);
    expect(
      PlayReviewAsk.shouldOffer(once, bossThisSession: true, now: now),
      isFalse,
    );
    final laterDay = now.add(const Duration(days: 8));
    expect(
      PlayReviewAsk.shouldOffer(once, bossThisSession: true, now: laterDay),
      isTrue,
    );

    state = once;
    state = PlayReviewAsk.snooze(state, now: laterDay);
    state = PlayReviewAsk.snooze(
      state,
      now: laterDay.add(const Duration(days: 8)),
    );
    expect(state.metaDepth.reviewAskCount, PlayReviewAsk.maxAsks);
    expect(state.metaDepth.reviewPrompted, isTrue);
    expect(
      PlayReviewAsk.shouldOffer(
        state,
        bossThisSession: true,
        now: laterDay.add(const Duration(days: 30)),
      ),
      isFalse,
    );
  });

  test('RATE sticks, and an old save defaults the new fields', () {
    final hub = later();
    final rated = PlayReviewAsk.markPrompted(hub);
    expect(PlayReviewAsk.shouldOffer(rated, bossThisSession: true), isFalse);
    expect(rated.metaDepth.reviewPrompted, isTrue);

    final round = MetaDepthState.fromJson(rated.metaDepth.toJson());
    expect(round.reviewPrompted, isTrue);
    expect(round.sessionCount, 2);

    final legacy = MetaDepthState.fromJson(const {});
    expect(legacy.reviewPrompted, isFalse);
    expect(legacy.reviewAskCount, 0);
    expect(legacy.reviewSnoozeUntilMs, 0);
    expect(legacy.sessionCount, 0);

    final snoozed = PlayReviewAsk.snooze(hub, now: now);
    final ascended = GameLogic.ascend(
      snoozed.copyWith(bossVictories: 1),
      now: now,
    );
    expect(ascended.metaDepth.sessionCount, 2);
    expect(ascended.metaDepth.reviewAskCount, 1);
    expect(ascended.metaDepth.reviewSnoozeUntilMs, greaterThan(0));
  });

  test('READY vault claim beats the rating card', () {
    var state = later();
    state = GameLogic.ensureWeeklyContract(state, now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        sessionCount: 2,
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    expect(
      PlayReviewAsk.shouldOffer(state, bossThisSession: true, now: now),
      isFalse,
    );
  });

  test('copy never pays loot for a rating', () {
    expect(PlayReviewAsk.body.toLowerCase(), contains('no reward'));
    expect(PlayReviewAsk.body.toLowerCase(), isNot(contains('essence')));
    expect(PlayReviewAsk.body.toLowerCase(), isNot(contains('ticket')));
  });
}
