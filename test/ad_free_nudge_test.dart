import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/ad_free_nudge.dart';
import 'package:idle_party/core/analytics_events.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/meta_depth.dart';

void main() {
  MetaDepthState meta({
    int watches = AdFreeNudge.watchThreshold,
    bool shown = false,
    bool adFree = false,
    int perm = 0,
  }) {
    return MetaDepthState(
      rewardedWatchCount: watches,
      adFreeNudgeShown: shown,
      adFree: adFree,
      shopPermScrolls: perm,
    );
  }

  bool listed(MetaDepthState md, {bool playLists = true}) {
    return AdFreeNudge.show(meta: md, playListsAdFree: playLists);
  }

  test(
    'shows on SCROLLS only after three watches, once, when Play lists it',
    () {
      expect(listed(meta(watches: 0)), isFalse);
      expect(listed(meta(watches: 2)), isFalse);
      expect(listed(meta(watches: 3)), isTrue);
      expect(listed(meta(watches: 9)), isTrue);
      expect(listed(meta(shown: true)), isFalse);
      expect(listed(meta(adFree: true)), isFalse);
      expect(listed(meta(perm: AdBoost.permRest)), isFalse);
      expect(listed(meta(perm: AdBoost.permAll)), isFalse);
      expect(listed(meta(), playLists: false), isFalse);
      expect(
        AdFreeNudge.offerReady(playListsAdFree: false, sideloadQaBuild: false),
        isFalse,
      );
      expect(
        AdFreeNudge.offerReady(playListsAdFree: true, sideloadQaBuild: false),
        isTrue,
      );
      expect(
        AdFreeNudge.offerReady(playListsAdFree: false, sideloadQaBuild: true),
        isTrue,
      );
      expect(
        AdFreeNudge.show(
          meta: meta(adFree: true),
          playListsAdFree: AdFreeNudge.offerReady(
            playListsAdFree: false,
            sideloadQaBuild: true,
          ),
        ),
        isFalse,
      );
      expect(
        AdFreeNudge.show(
          meta: meta(perm: AdBoost.permRest),
          playListsAdFree: AdFreeNudge.offerReady(
            playListsAdFree: false,
            sideloadQaBuild: true,
          ),
        ),
        isFalse,
      );

      final ready = meta();
      expect(
        AdFreeNudge.show(
          meta: ready,
          playListsAdFree: true,
          place: AdFreeNudgePlace.welcomeBack,
        ),
        isFalse,
      );
      expect(
        AdFreeNudge.show(
          meta: ready,
          playListsAdFree: true,
          place: AdFreeNudgePlace.fight,
        ),
        isFalse,
      );
    },
  );

  test(
    'watch count and shown flag default, round-trip, and survive Ascend',
    () {
      final now = DateTime.utc(2026, 11, 1);
      expect(const MetaDepthState().rewardedWatchCount, 0);
      expect(const MetaDepthState().adFreeNudgeShown, isFalse);
      expect(MetaDepthState.fromJson(const {}).rewardedWatchCount, 0);
      expect(MetaDepthState.fromJson(const {}).adFreeNudgeShown, isFalse);

      var state = GameLogic.createInitialState(now: now);
      expect(state.metaDepth.rewardedWatchCount, 0);
      state = AdFreeNudge.noteWatch(state);
      state = AdFreeNudge.noteWatch(state);
      state = AdFreeNudge.noteWatch(state);
      state = AdFreeNudge.markShown(state);
      expect(state.metaDepth.rewardedWatchCount, 3);
      expect(state.metaDepth.adFreeNudgeShown, isTrue);
      expect(AdFreeNudge.noteWatch(state).metaDepth.rewardedWatchCount, 4);
      expect(identical(AdFreeNudge.markShown(state), state), isTrue);

      final legacy = Map<String, dynamic>.from(state.toJson());
      (legacy['metaDepth'] as Map<String, dynamic>)
        ..remove('rewardedWatchCount')
        ..remove('adFreeNudgeShown');
      final loadedLegacy = GameLogic.stateFromJson(legacy);
      expect(loadedLegacy.metaDepth.rewardedWatchCount, 0);
      expect(loadedLegacy.metaDepth.adFreeNudgeShown, isFalse);

      final round = GameLogic.stateFromJson(state.toJson());
      expect(round.metaDepth.rewardedWatchCount, 3);
      expect(round.metaDepth.adFreeNudgeShown, isTrue);

      final ascended = GameLogic.ascend(
        state.copyWith(bossVictories: 1),
        now: now,
      );
      expect(ascended.metaDepth.rewardedWatchCount, 3);
      expect(ascended.metaDepth.adFreeNudgeShown, isTrue);
      expect(ascended.gold, 0);
    },
  );

  test(
    'preview tickets do not count; finished watches and the funnel do',
    () async {
      final director = GameDirector.preview();
      await director.boot();
      final hits = <String>[];
      AppAnalytics.debugSink = (name, params) {
        hits.add(name);
        expect(params?['product_id'], AdFreeNudge.productId);
      };
      addTearDown(() => AppAnalytics.debugSink = null);
      final before = director.state.metaDepth.adTickets;
      director.grantPowerupHour();
      expect(director.state.metaDepth.adTickets, greaterThan(before));
      expect(director.state.metaDepth.rewardedWatchCount, 0);

      director.noteCompletedRewardedWatch();
      director.noteCompletedRewardedWatch();
      expect(
        AdFreeNudge.show(meta: director.state.metaDepth, playListsAdFree: true),
        isFalse,
      );
      director.noteCompletedRewardedWatch();
      expect(director.state.metaDepth.rewardedWatchCount, 3);
      expect(
        AdFreeNudge.show(meta: director.state.metaDepth, playListsAdFree: true),
        isTrue,
      );

      director.markAdFreeNudgeShown();
      expect(director.state.metaDepth.adFreeNudgeShown, isTrue);
      expect(
        AdFreeNudge.show(meta: director.state.metaDepth, playListsAdFree: true),
        isFalse,
      );
      director.markAdFreeNudgeShown();
      director.openAdFreeFromScrollsNudge();
      expect(hits, [
        AnalyticsEvents.adFreeNudgeView,
        AnalyticsEvents.adFreeNudgeTap,
      ]);
      director.dispose();
    },
  );
}
