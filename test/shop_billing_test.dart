import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/app_analytics.dart';
import 'package:idle_party/core/build_stamp.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/gear/gear_stash.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/offline_progress.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/meta_depth.dart';
import 'package:idle_party/ui/shell/shop_dock.dart';

void main() {
  final now = DateTime.utc(2026, 9, 5, 12);

  test('ad_free persists, grants tickets, and marks owned', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.offered.firstWhere((e) => e.id == 'ad_free');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.adFree, isTrue);
    expect(ShopBilling.isOwned(state, item), isTrue);
    expect(state.metaDepth.adTickets, 2);
  });

  test('starter boost is one-time Full Boost hours', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.offered.firstWhere(
      (e) => e.id == 'starter_boost_6h',
    );
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.shopStarterClaimed, isTrue);
    final until = state.metaDepth.adAtkUntilMs;
    expect(until, greaterThan(now.millisecondsSinceEpoch));
    expect(state.metaDepth.adGoldUntilMs, until);
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.adAtkUntilMs, until);
  });

  test('supporter_qol adds bag slots once (restore-safe)', () {
    var state = GameLogic.createInitialState(now: now);
    final before = GearStash.maxGearStashFor(state);
    final item = ShopCatalog.offered.firstWhere((e) => e.id == 'supporter_qol');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.shopBagBonusSlots, item.bagSlots);
    expect(GearStash.maxGearStashFor(state), before + item.bagSlots);
    final after = ShopBilling.applyPurchase(state, item, now: now);
    expect(after.metaDepth.shopBagBonusSlots, item.bagSlots);
  });

  test('ad_free restore does not re-grant tickets', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.offered.firstWhere((e) => e.id == 'ad_free');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.adTickets, 2);
    state = state.copyWith(metaDepth: state.metaDepth.copyWith(adTickets: 5));
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.adTickets, 5);
  });

  test('day pack covers a full day and the 12h pack is shorter', () {
    expect(ShopCatalog.byId['boost_12h']!.boostHours, 12);
    expect(ShopCatalog.byId['day_boost_24h']!.boostHours, 24);
  });

  test('consumable boost packs are marked consumable', () {
    expect(ShopCatalog.byId['boost_12h']!.isConsumable, isTrue);
    expect(ShopCatalog.byId['day_boost_24h']!.isConsumable, isTrue);
    expect(ShopCatalog.byId['starter_boost_6h']!.isConsumable, isFalse);
    expect(ShopCatalog.byId['ad_free']!.isConsumable, isFalse);
    expect(ShopBilling.billingReady, isTrue);
  });

  test('boost hours respect 24h cap on both timers', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.offered.firstWhere((e) => e.id == 'day_boost_24h');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(
      AdBoost.remainingMs(
        state.metaDepth.adAtkUntilMs,
        nowMs: now.millisecondsSinceEpoch,
      ),
      lessThanOrEqualTo(AdBoost.maxStackMs),
    );
    expect(
      AdBoost.remainingMs(
        state.metaDepth.adGoldUntilMs,
        nowMs: now.millisecondsSinceEpoch,
      ),
      lessThanOrEqualTo(AdBoost.maxStackMs),
    );
  });

  test('old saves default shop billing fields', () {
    final state = GameLogic.createInitialState(now: now);
    expect(state.metaDepth.adFree, isFalse);
    expect(state.metaDepth.shopStarterClaimed, isFalse);
    expect(state.metaDepth.shopBagBonusSlots, 0);
    expect(state.metaDepth.adTickets, 0);
    final round = GameLogic.stateFromJson(state.toJson());
    expect(round.metaDepth.adFree, isFalse);
    expect(round.metaDepth.adTickets, 0);
  });

  test('forever scroll SKU grants perm bit and marks owned', () {
    var state = GameLogic.createInitialState(now: now);
    final atk = ShopCatalog.byId['perm_scroll_atk']!;
    state = ShopBilling.applyPurchase(state, atk, now: now);
    expect(state.metaDepth.shopPermScrolls & AdBoost.permAtk, AdBoost.permAtk);
    expect(ShopBilling.isOwned(state, atk), isTrue);
    expect(AdBoost.atkActive(state.metaDepth), isTrue);
    final again = ShopBilling.applyPurchase(state, atk, now: now);
    expect(again.metaDepth.shopPermScrolls, state.metaDepth.shopPermScrolls);
  });

  test('forever bundle owns all scrolls and stays off the shelf until Play lists it', () {
    expect(ShopCatalog.foreverSingles.length, 7);
    expect(ShopCatalog.foreverBundle.single.id, 'perm_scrolls_all');
    expect(ShopCatalog.timePacks.length, 3); // restore-only, not listed in SHOP
    expect(ShopCatalog.shelf().map((e) => e.id), [
      'ad_free',
      'long_away',
      'supporter_qol',
    ]);
    expect(
      ShopCatalog.shelf().every(
        (e) =>
            e.kind != ShopOfferKind.boostHours &&
            e.kind != ShopOfferKind.permScroll &&
            e.kind != ShopOfferKind.cinders,
      ),
      isTrue,
    );
    expect(ShopCatalog.extraPacks.map((e) => e.id), [
      'ad_free',
      'long_away',
      'supporter_qol',
    ]);
    expect(
      ShopCatalog.shelf(
        playListed: {
          'perm_scroll_atk',
          'starter_boost_6h',
          'cinder_pouch',
          'ad_free',
        },
      ).map((e) => e.id),
      [
        'perm_scroll_atk',
        'ad_free',
        'long_away',
        'cinder_pouch',
        'supporter_qol',
      ],
    );
    expect(ShopCatalog.mayBuy('boost_12h', playLists: true), isFalse);
    expect(ShopCatalog.mayBuy('perm_scroll_atk', playLists: false), isFalse);
    expect(ShopCatalog.mayBuy('perm_scroll_atk', playLists: true), isTrue);
    expect(ShopCatalog.mayBuy('cinder_pouch', playLists: false), isFalse);
    expect(ShopCatalog.mayBuy('ad_free', playLists: false), isTrue);
    expect(ShopBilling.grantOnRestore(ShopCatalog.byId['ad_free']!), isTrue);
    expect(ShopBilling.grantOnRestore(ShopCatalog.byId['long_away']!), isTrue);
    expect(
      ShopBilling.grantOnRestore(ShopCatalog.byId['supporter_qol']!),
      isTrue,
    );
    expect(
      ShopBilling.grantOnRestore(ShopCatalog.byId['starter_boost_6h']!),
      isTrue,
    );
    expect(
      ShopBilling.grantOnRestore(ShopCatalog.byId['perm_scrolls_all']!),
      isTrue,
    );
    expect(ShopBilling.grantOnRestore(ShopCatalog.byId['boost_12h']!), isFalse);
    expect(
      ShopBilling.grantOnRestore(ShopCatalog.byId['day_boost_24h']!),
      isFalse,
    );
    expect(
      ShopBilling.grantOnRestore(ShopCatalog.byId['cinder_pouch']!),
      isFalse,
    );
    expect(
      ShopBilling.grantOnRestore(ShopCatalog.byId['season_pass_premium']!),
      isTrue,
    );
    final bundle = ShopCatalog.byId['perm_scrolls_all']!;
    var state = GameLogic.createInitialState(now: now);
    state = ShopBilling.applyPurchase(state, bundle, now: now);
    expect(state.metaDepth.shopPermScrolls, AdBoost.permAll);
    for (final item in ShopCatalog.offered.where(
      (e) => e.kind == ShopOfferKind.permScroll,
    )) {
      expect(ShopBilling.isOwned(state, item), isTrue, reason: item.id);
    }
  });

  test('season pass premium is once and owned', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.byId['season_pass_premium']!;
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.paidSeasonPass, isTrue);
    expect(ShopBilling.isOwned(state, item), isTrue);
    final again = ShopBilling.applyPurchase(state, item, now: now);
    expect(identical(again, state), isTrue);
  });

  test('cinder pouch grants once per purchase id', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.byId['cinder_pouch']!;
    expect(
      ShopBilling.shouldGrantPurchase(
        item: item,
        restored: true,
        purchaseId: 'GPA.1',
        alreadyGranted: false,
      ),
      isTrue,
    );
    state = ShopBilling.applyTrackedPurchase(
      state,
      item,
      purchaseId: 'GPA.1',
      now: now,
    );
    expect(state.metaDepth.cinders, 16);
    expect(state.metaDepth.cinderPouchDoubled, isTrue);
    expect(state.metaDepth.grantedShopPurchaseIds, ['GPA.1']);
    expect(
      ShopBilling.shouldGrantPurchase(
        item: item,
        restored: true,
        purchaseId: 'GPA.1',
        alreadyGranted: ShopBilling.alreadyGranted(state, 'GPA.1'),
      ),
      isFalse,
    );
    final again = ShopBilling.applyTrackedPurchase(
      state,
      item,
      purchaseId: 'GPA.1',
      now: now,
    );
    expect(identical(again, state), isTrue);
    state = ShopBilling.applyTrackedPurchase(
      state,
      item,
      purchaseId: 'GPA.2',
      now: now,
    );
    expect(state.metaDepth.cinders, 24);
    expect(state.metaDepth.grantedShopPurchaseIds, ['GPA.1', 'GPA.2']);
    final round = GameLogic.stateFromJson(state.toJson());
    expect(round.metaDepth.cinders, 24);
    expect(round.metaDepth.grantedShopPurchaseIds, ['GPA.1', 'GPA.2']);
    expect(MetaDepthState.fromJson(const {}).grantedShopPurchaseIds, isEmpty);
    expect(
      ShopBilling.shouldGrantPurchase(
        item: item,
        restored: true,
        purchaseId: '',
        alreadyGranted: false,
      ),
      isFalse,
    );
    final ascended = GameLogic.ascend(
      state.copyWith(bossVictories: 1),
      now: now,
    );
    expect(ascended.metaDepth.cinders, 24);
    expect(ascended.metaDepth.grantedShopPurchaseIds, ['GPA.1', 'GPA.2']);
  });

  test('old saves default shopPermScrolls to 0', () {
    expect(const MetaDepthState().shopPermScrolls, 0);
    expect(MetaDepthState.fromJson(const {}).shopPermScrolls, 0);
    expect(const MetaDepthState().shopLongAway, isFalse);
    expect(MetaDepthState.fromJson(const {}).shopLongAway, isFalse);
  });

  test('long away is once, owned, and kept on ascend', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.byId['long_away']!;
    expect(item.oneTime, isTrue);
    expect(item.isConsumable, isFalse);
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.shopLongAway, isTrue);
    expect(ShopBilling.isOwned(state, item), isTrue);
    expect(GoldIncome.hubChestCapSecFor(state), 24 * 3600);
    expect(OfflineProgress.dungeonAwayCapSec(state), 16 * 3600);
    expect(OfflineProgress.offlineRoomCapFor(state), 240);
    expect(OfflineProgress.offlineStepCapFor(state), 24000);
    final again = ShopBilling.applyPurchase(state, item, now: now);
    expect(again.metaDepth.shopLongAway, isTrue);
    final round = GameLogic.stateFromJson(state.toJson());
    expect(round.metaDepth.shopLongAway, isTrue);
    final ascended = GameLogic.ascend(
      state.copyWith(bossVictories: 1),
      now: now,
    );
    expect(ascended.metaDepth.shopLongAway, isTrue);
    expect(GameLogic.offlineFloorBudget(16 * 3600, roomCap: 240), 240);
    expect(GameLogic.offlineFloorBudget(8 * 3600), lessThanOrEqualTo(120));
  });

  testWidgets('SHOP shelf is the three Play packs and BUY does not grant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final director = GameDirector.preview();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ShopDock(director: director)),
        ),
      );
      await tester.pump();

      expect(find.text('Ad-free welcome'), findsOneWidget);
      expect(find.text('Long Away'), findsOneWidget);
      expect(find.text('Supporter pack'), findsOneWidget);
      expect(find.text('Unavailable'), findsNWidgets(3));
      expect(find.text('UNAVAILABLE'), findsNWidgets(3));
      expect(find.text('BUY'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
      expect(find.text('NOT ON PLAY'), findsNothing);
      expect(find.textContaining('Forever'), findsNothing);
      expect(find.text('Cinder pouch'), findsNothing);
      expect(
        find.textContaining('Cinders in GEAR'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('RESTORE'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('RESTORE'), findsOneWidget);
      expect(find.text('REDEEM CODE'), findsOneWidget);

      await tester.tap(find.text('UNAVAILABLE').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(director.state.metaDepth.adFree, isFalse);
      expect(director.state.metaDepth.shopLongAway, isFalse);
      expect(director.state.metaDepth.shopBagBonusSlots, 0);

      await director.buyShopItem('perm_scroll_atk');
      await director.buyShopItem('cinder_pouch');
      await director.buyShopItem('boost_12h');
      await tester.pump();
      expect(director.state.metaDepth.shopPermScrolls, 0);
      expect(director.state.metaDepth.cinders, 0);
      expect(director.state.metaDepth.adAtkUntilMs, 0);
    } finally {
      director.dispose();
    }
  });

  test('build stamp hides until a SHA is compiled in', () {
    expect(BuildStamp.versionLabel('1.13.5'), '1.13.5');
    expect(
      BuildStamp.versionLabel('1.13.5', sha: '56b634e1abcd'),
      '1.13.5 · 56b634e',
    );
    expect(BuildStamp.shortShaOf(''), isEmpty);
  });

  test('past query counts as existing even when Play status is purchased', () {
    expect(
      ShopBilling.countsAsExistingPurchase(
        fromPastQuery: true,
        statusRestored: false,
      ),
      isTrue,
    );
    expect(
      ShopBilling.countsAsExistingPurchase(
        fromPastQuery: false,
        statusRestored: true,
      ),
      isTrue,
    );
    expect(
      ShopBilling.countsAsExistingPurchase(
        fromPastQuery: false,
        statusRestored: false,
      ),
      isFalse,
    );
  });

  test('a failed save does not keep the grant', () async {
    final storage = _DenySaveStorage();
    final director = GameDirector(storage, enableSpatialLoop: false);
    await director.boot();
    await director.startNewGame(HeroSpecs.starterUnlocked);
    expect(director.hasExistingSave, isTrue);
    final goldBefore = director.state.gold;
    storage.duringSave = () => director.debugSetGold(director.state.gold + 40);

    final events = <String>[];
    final previous = AppAnalytics.debugSink;
    AppAnalytics.debugSink = (name, _) {
      if (name == 'store_purchase') events.add(name);
    };
    try {
      director.clearToast();
      final first = await director.debugGrantShopPurchase(
        'ad_free',
        purchaseId: 'GPA.fail',
      );
      expect(first, isFalse);
      expect(director.state.metaDepth.adFree, isFalse);
      expect(director.state.metaDepth.grantedShopPurchaseIds, isEmpty);
      expect(director.state.gold, greaterThan(goldBefore));
      expect(director.toast, isNot(contains('Purchased')));
      expect(events, isEmpty);
      expect(await storage.load(), isNull);

      final again = await director.debugGrantShopPurchase(
        'ad_free',
        purchaseId: 'GPA.fail',
      );
      expect(again, isFalse);
      expect(director.state.metaDepth.adFree, isFalse);
    } finally {
      AppAnalytics.debugSink = previous;
      director.dispose();
    }
  });

  test('a thrown save does not keep the grant', () async {
    final storage = _ThrowSaveStorage();
    final director = GameDirector(storage, enableSpatialLoop: false);
    await director.boot();
    await director.startNewGame(HeroSpecs.starterUnlocked);

    final ok = await director.debugGrantShopPurchase(
      'cinder_pouch',
      purchaseId: 'GPA.throw',
    );
    expect(ok, isFalse);
    expect(director.state.metaDepth.cinders, 0);
    expect(director.state.metaDepth.grantedShopPurchaseIds, isEmpty);
    director.dispose();
  });

  test('an existing purchase does not toast or log a buy', () async {
    final storage = InMemoryGameStorage();
    final director = GameDirector(storage, enableSpatialLoop: false);
    await director.boot();
    await director.startNewGame(HeroSpecs.starterUnlocked);

    final events = <String>[];
    final previous = AppAnalytics.debugSink;
    AppAnalytics.debugSink = (name, _) {
      if (name == 'store_purchase') events.add(name);
    };
    try {
      director.clearToast();
      final restored = await director.debugGrantShopPurchase(
        'ad_free',
        purchaseId: 'GPA.past',
        restored: true,
      );
      expect(restored, isTrue);
      expect(director.state.metaDepth.adFree, isTrue);
      expect(director.toast, isNull);
      expect(events, isEmpty);
      expect((await storage.load())!.metaDepth.adFree, isTrue);

      director.clearToast();
      final live = await director.debugGrantShopPurchase(
        'long_away',
        purchaseId: 'GPA.live',
      );
      expect(live, isTrue);
      expect(director.state.metaDepth.shopLongAway, isTrue);
      expect(director.toast, 'Purchased Long Away');
      expect(events, ['store_purchase']);

      director.clearToast();
      final pouch = await director.debugGrantShopPurchase(
        'cinder_pouch',
        purchaseId: 'GPA.pouch',
        restored: true,
        recovered: true,
      );
      expect(pouch, isTrue);
      expect(director.state.metaDepth.cinders, 16);
      expect(director.toast, 'Purchase restored');
      expect(events, ['store_purchase']);
    } finally {
      AppAnalytics.debugSink = previous;
      director.dispose();
    }
  });
}

class _DenySaveStorage extends InMemoryGameStorage {
  void Function()? duringSave;

  @override
  Future<bool> save(GameState state) async {
    duringSave?.call();
    return false;
  }
}

class _ThrowSaveStorage extends InMemoryGameStorage {
  @override
  Future<bool> save(GameState state) async {
    throw StateError('disk full');
  }
}
