import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gear/gear_stash.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';

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
    final item =
        ShopCatalog.offered.firstWhere((e) => e.id == 'starter_boost_6h');
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
    final item =
        ShopCatalog.offered.firstWhere((e) => e.id == 'supporter_qol');
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
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(adTickets: 5),
    );
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.adTickets, 5);
  });

  test('day pack beats 12h pack on dollars per Full Boost hour', () {
    double usd(ShopCatalogItem item) =>
        double.parse(item.priceLabel.replaceAll(r'$', ''));
    double perHour(ShopCatalogItem item) => usd(item) / item.boostHours;
    final mid = ShopCatalog.byId['boost_12h']!;
    final day = ShopCatalog.byId['day_boost_24h']!;
    expect(mid.boostHours, 12);
    expect(day.boostHours, 24);
    expect(perHour(day), lessThan(perHour(mid)));
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
}
