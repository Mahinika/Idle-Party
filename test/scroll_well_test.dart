import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/scroll_well.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  final day = DateTime.utc(2026, 11, 1, 12);

  test('free well claim grants one ticket and advances to step 1', () {
    var state = GameLogic.createInitialState(now: day);
    expect(ScrollWell.canClaimFree(state.metaDepth, now: day), isTrue);
    state = GameLogic.claimScrollWellFree(state, now: day);
    expect(state.metaDepth.adTickets, 1);
    expect(state.metaDepth.scrollWellBonusClaims, 1);
    expect(ScrollWell.canClaimFree(state.metaDepth, now: day), isFalse);
    expect(ScrollWell.canAdvanceWithAd(state.metaDepth, now: day), isTrue);
  });

  test('bonus ad steps advance to 3 then stop', () {
    var state = GameLogic.createInitialState(now: day);
    state = GameLogic.claimScrollWellFree(state, now: day);
    state = GameLogic.advanceScrollWellBonusAd(state, now: day);
    expect(state.metaDepth.scrollWellBonusClaims, 2);
    expect(state.metaDepth.adTickets, 2);
    state = GameLogic.advanceScrollWellBonusAd(state, now: day);
    expect(state.metaDepth.scrollWellBonusClaims, 3);
    expect(state.metaDepth.adTickets, 3);
    expect(ScrollWell.ladderComplete(state.metaDepth, now: day), isTrue);
    expect(ScrollWell.canAdvanceWithAd(state.metaDepth, now: day), isFalse);
    final before = state.metaDepth.adTickets;
    state = GameLogic.advanceScrollWellBonusAd(state, now: day);
    expect(state.metaDepth.adTickets, before);
  });

  test('new UTC day resets well progress', () {
    var state = GameLogic.createInitialState(now: day);
    state = GameLogic.claimScrollWellFree(state, now: day);
    state = GameLogic.advanceScrollWellBonusAd(state, now: day);
    final nextDay = day.add(const Duration(days: 1));
    expect(ScrollWell.canClaimFree(state.metaDepth, now: nextDay), isTrue);
    expect(ScrollWell.bonusClaims(state.metaDepth, now: nextDay), 0);
  });

  test('ad-free uses daily claim only, not well ladder', () {
    var state = GameLogic.createInitialState(now: day).copyWith(
      metaDepth: GameLogic.createInitialState(now: day).metaDepth.copyWith(
        adFree: true,
      ),
    );
    expect(ScrollWell.canClaimFree(state.metaDepth, now: day), isFalse);
    expect(AdBoost.canClaimAdFreeDaily(state.metaDepth, now: day), isTrue);
    state = GameLogic.claimAdFreeDailyTicket(state, now: day);
    expect(state.metaDepth.adTickets, 1);
    expect(state.metaDepth.scrollWellBonusClaims, 0);
  });

  test('scroll well fields round-trip save json', () {
    final md = MetaDepthState(
      scrollWellUtcDay: '2026-11-01',
      scrollWellBonusClaims: 2,
      adTickets: 2,
    );
    final json = md.toJson();
    final loaded = MetaDepthState.fromJson(json);
    expect(loaded.scrollWellUtcDay, '2026-11-01');
    expect(loaded.scrollWellBonusClaims, 2);

    json.remove('scrollWellUtcDay');
    json.remove('scrollWellBonusClaims');
    final legacy = MetaDepthState.fromJson(json);
    expect(legacy.scrollWellUtcDay, '');
    expect(legacy.scrollWellBonusClaims, 0);
  });
}
