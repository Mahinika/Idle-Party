import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ad_boost.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gear/gear_stash.dart';
import 'package:idle_party/core/shop_billing.dart';
import 'package:idle_party/core/shop_catalog.dart';

void main() {
  final now = DateTime.utc(2026, 9, 5, 12);

  test('ad_free persists and marks owned', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.offered.firstWhere((e) => e.id == 'ad_free');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.adFree, isTrue);
    expect(ShopBilling.isOwned(state, item), isTrue);
    expect(state.metaDepth.adBoostUntilMs, greaterThan(now.millisecondsSinceEpoch));
  });

  test('starter boost is one-time', () {
    var state = GameLogic.createInitialState(now: now);
    final item =
        ShopCatalog.offered.firstWhere((e) => e.id == 'starter_boost_6h');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.shopStarterClaimed, isTrue);
    final until = state.metaDepth.adBoostUntilMs;
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.adBoostUntilMs, until);
  });

  test('supporter_qol adds bag slots', () {
    var state = GameLogic.createInitialState(now: now);
    final before = GearStash.maxGearStashFor(state);
    final item =
        ShopCatalog.offered.firstWhere((e) => e.id == 'supporter_qol');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(state.metaDepth.shopBagBonusSlots, item.bagSlots);
    expect(GearStash.maxGearStashFor(state), before + item.bagSlots);
  });

  test('boost hours respect 24h cap', () {
    var state = GameLogic.createInitialState(now: now);
    final item = ShopCatalog.offered.firstWhere((e) => e.id == 'day_boost_24h');
    state = ShopBilling.applyPurchase(state, item, now: now);
    expect(
      AdBoost.remainingMs(
        state.metaDepth.adBoostUntilMs,
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
    final round = GameLogic.stateFromJson(state.toJson());
    expect(round.metaDepth.adFree, isFalse);
  });
}
