import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/shop_catalog.dart';
import 'package:idle_party/core/shop_hub_offer.dart';

/// SKUs Play Console has activated and the SHOP shelf can sell.
/// `cinder_pouch` and `season_pass_premium` still read Unavailable, and hour
/// packs are restore-only, so the 24h window must never point at them.
const _activated = {'ad_free', 'supporter_qol', 'long_away'};

final _now = DateTime.utc(2026, 11, 1, 12);

GameState _windowOpen() {
  final base = GameLogic.createInitialState().copyWith(bossVictories: 1);
  return ShopHubOffer.ensureWindow(base, now: _now);
}

void main() {
  test('every ladder SKU is activated, chargeable and not an hour pack', () {
    expect(ShopHubOffer.featuredLadder, isNotEmpty);
    for (final id in ShopHubOffer.featuredLadder) {
      final item = ShopCatalog.byId[id];
      expect(item, isNotNull, reason: id);
      expect(_activated, contains(id));
      expect(ShopCatalog.playChargeableIds, contains(id));
      expect(item!.kind, isNot(ShopOfferKind.boostHours), reason: id);
      expect(ShopCatalog.mayBuy(id, playLists: false), isTrue, reason: id);
      expect(ShopHubOffer.sellable(item), isTrue, reason: id);
    }
  });

  test('hour packs and unactivated SKUs are never sellable for the window', () {
    for (final item in ShopCatalog.offered) {
      if (_activated.contains(item.id)) continue;
      expect(ShopHubOffer.sellable(item), isFalse, reason: item.id);
    }
    expect(
      ShopHubOffer.sellable(ShopCatalog.byId['starter_boost_6h']!),
      isFalse,
    );
  });

  test('fresh window features Ad-free, not the restore-only starter', () {
    final state = _windowOpen();
    expect(state.metaDepth.shopStarterClaimed, isFalse);
    final item = ShopHubOffer.featuredItem(state, now: _now);
    expect(item?.id, 'ad_free');
    expect(ShopHubOffer.featuredTitle(item!), item.name);
  });

  test('window never targets an unavailable SKU in any ownership state', () {
    final base = _windowOpen();
    for (var mask = 0; mask < 16; mask++) {
      final state = base.copyWith(
        metaDepth: base.metaDepth.copyWith(
          adFree: mask & 1 != 0,
          shopBagBonusSlots: mask & 2 != 0 ? 4 : 0,
          shopLongAway: mask & 4 != 0,
          shopStarterClaimed: mask & 8 != 0,
        ),
      );
      final item = ShopHubOffer.featuredItem(state, now: _now);
      if (item == null) continue;
      expect(_activated, contains(item.id), reason: 'mask $mask');
      expect(item.kind, isNot(ShopOfferKind.boostHours));
    }
  });

  test('owned packs fall through the ladder, then the offer hides', () {
    var state = _windowOpen();
    state = state.copyWith(metaDepth: state.metaDepth.copyWith(adFree: true));
    expect(ShopHubOffer.featuredItem(state, now: _now)?.id, 'supporter_qol');
    expect(
      ShopHubOffer.featuredTitle(ShopHubOffer.featuredItem(state, now: _now)!),
      "Delver's Kit",
    );
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(shopBagBonusSlots: 4),
    );
    expect(ShopHubOffer.featuredItem(state, now: _now)?.id, 'long_away');
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(shopLongAway: true),
    );
    expect(ShopHubOffer.featuredItem(state, now: _now), isNull);
  });

  test('a SKU Play does not list is skipped; none listed hides the offer', () {
    final state = _windowOpen();
    expect(
      ShopHubOffer.featuredItem(
        state,
        now: _now,
        playListed: {'supporter_qol', 'long_away'},
      )?.id,
      'supporter_qol',
    );
    expect(
      ShopHubOffer.featuredItem(
        state,
        now: _now,
        playListed: {'starter_boost_6h', 'cinder_pouch', 'season_pass_premium'},
      ),
      isNull,
    );
    expect(
      ShopHubOffer.featuredItem(state, now: _now, playListed: const {}),
      isNull,
    );
  });

  test('closed window features nothing', () {
    final state = _windowOpen();
    final later = _now.add(const Duration(hours: 25));
    expect(ShopHubOffer.windowOpen(state, now: later), isFalse);
    expect(ShopHubOffer.featuredItem(state, now: later), isNull);
    expect(ShopHubOffer.showHubBadge(state, now: later), isFalse);
  });
}
