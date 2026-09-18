import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/play_review_ask.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 12);

  test('new save never asks for a Play rating', () {
    final state = GameLogic.createInitialState(now: now);
    expect(PlayReviewAsk.shouldOffer(state), isFalse);
  });

  test('after first boss on the hub, offer once — never in combat', () {
    var hub = GameLogic.createInitialState(now: now);
    hub = hub.copyWith(bossVictories: 1);
    expect(PlayReviewAsk.shouldOffer(hub), isTrue);
    expect(
      PlayReviewAsk.shouldOffer(hub.copyWith(inDungeon: true)),
      isFalse,
    );

    final dismissed = PlayReviewAsk.markPrompted(hub);
    expect(PlayReviewAsk.shouldOffer(dismissed), isFalse);
    expect(dismissed.metaDepth.reviewPrompted, isTrue);

    final round = MetaDepthState.fromJson(dismissed.metaDepth.toJson());
    expect(round.reviewPrompted, isTrue);
    expect(MetaDepthState.fromJson(const {}).reviewPrompted, isFalse);
  });

  test('READY vault claim beats the rating card', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(state, now: now);
    state = state.copyWith(
      bossVictories: 1,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
      ),
    );
    expect(PlayReviewAsk.shouldOffer(state), isFalse);
  });

  test('copy never pays loot for a rating', () {
    expect(PlayReviewAsk.body.toLowerCase(), contains('no reward'));
    expect(PlayReviewAsk.body.toLowerCase(), isNot(contains('essence')));
    expect(PlayReviewAsk.body.toLowerCase(), isNot(contains('ticket')));
  });
}
