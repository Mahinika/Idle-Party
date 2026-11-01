import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/shop_nudge.dart';
import 'package:idle_party/models/meta_depth.dart';

GameState _shopOpen() =>
    GameLogic.createInitialState().copyWith(bossVictories: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shop card waits for the 3rd ad, then stays quiet for 7 days', () {
    final start = DateTime.utc(2026, 11, 1);
    var state = _shopOpen();
    for (var i = 0; i < 2; i++) {
      final step = ShopNudge.noteRewardedAd(state, now: start);
      expect(step.offerIds, isEmpty);
      state = step.state;
    }
    expect(state.metaDepth.rewardedAdsWatched, 2);

    final third = ShopNudge.noteRewardedAd(state, now: start);
    expect(third.offerIds, [ShopNudge.adFreeId, ShopNudge.restId]);
    state = third.state;
    expect(state.metaDepth.shopNudgeAtMs, start.millisecondsSinceEpoch);

    final soon = ShopNudge.noteRewardedAd(
      state,
      now: start.add(const Duration(days: 6)),
    );
    expect(soon.offerIds, isEmpty);

    final later = ShopNudge.noteRewardedAd(
      state,
      now: start.add(const Duration(days: 7)),
    );
    expect(later.offerIds, [ShopNudge.adFreeId, ShopNudge.restId]);
  });

  test('owned rows are skipped, and the card waits until SHOP exists', () {
    final now = DateTime.utc(2026, 11, 1);
    final both = _shopOpen().copyWith(
      metaDepth: const MetaDepthState(
        adFree: true,
        shopPermScrolls: AdBoost.permRest,
        rewardedAdsWatched: 2,
      ),
    );
    expect(ShopNudge.noteRewardedAd(both, now: now).offerIds, isEmpty);

    var state = GameLogic.createInitialState();
    for (var i = 0; i < 3; i++) {
      final step = ShopNudge.noteRewardedAd(state, now: now);
      expect(step.offerIds, isEmpty);
      state = step.state;
    }
    expect(state.metaDepth.rewardedAdsWatched, 3);
  });

  test('old saves default the ad count, and Ascend keeps it', () {
    final raw = GameLogic.createInitialState().toJson();
    final meta = Map<String, dynamic>.from(raw['metaDepth'] as Map);
    meta.remove('rewardedAdsWatched');
    meta.remove('shopNudgeAtMs');
    raw['metaDepth'] = meta;
    final loaded = GameLogic.stateFromJson(raw);
    expect(loaded.metaDepth.rewardedAdsWatched, 0);
    expect(loaded.metaDepth.shopNudgeAtMs, 0);

    var state = loaded.copyWith(bossVictories: 1, essence: 500);
    for (var i = 0; i < 3; i++) {
      state = ShopNudge.noteRewardedAd(
        state,
        now: DateTime.utc(2026, 11, 1),
      ).state;
    }
    final ascended = GameLogic.ascend(state);
    expect(
      ascended.metaDepth.rewardedAdsWatched,
      state.metaDepth.rewardedAdsWatched,
    );
  });

  test('the 2× coach shows once, and fight speed does not grow a 3×', () {
    final fresh = GameLogic.createInitialState();
    expect(ShopNudge.speedCoachLine(fresh), isNull);
    final fought = fresh.copyWith(highestFloorCleared: 1);
    expect(ShopNudge.speedCoachLine(fought), ShopNudge.speedLine);
    expect(
      ShopNudge.speedCoachLine(
        fought.copyWith(seenTips: const [ShopNudge.speedTipId]),
      ),
      isNull,
    );
    expect(ShopNudge.speedCoachLine(fought.copyWith(combatPace: 2)), isNull);
    expect(fought.copyWith(combatPace: 3).combatPace, 2);
  });

  test('a rewarded ad on the director arms the shop card', () async {
    final director = GameDirector.preview(
      initialState: _shopOpen(),
    );
    await director.boot();
    final when = DateTime.utc(2026, 11, 1);
    director.noteRewardedAdWatched(now: when);
    director.noteRewardedAdWatched(now: when);
    expect(director.pendingShopOfferIds, isNull);
    director.noteRewardedAdWatched(now: when);
    expect(
      director.pendingShopOfferIds,
      [ShopNudge.adFreeId, ShopNudge.restId],
    );
    expect(director.takeShopNudge(), [ShopNudge.adFreeId, ShopNudge.restId]);
    expect(director.pendingShopOfferIds, isNull);
    director.dispose();
  });
}
