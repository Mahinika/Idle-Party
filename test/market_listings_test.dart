import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/market_listings_service.dart';
import 'package:idle_party/core/starter_gear.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  const now = 1_750_000_000_000;

  GameState seeded({int al = 20, int gold = 500_000}) {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 22));
    state = GameLogic.enterDungeon(state, dungeonId: 'brass');
    state = state.copyWith(
      ascensionLevel: al,
      gold: gold,
      hardmodeLevel: 12,
      highestFloorCleared: 40,
    );
    return state;
  }

  test('ensureFresh generates eight listings', () {
    final state = seeded();
    final fresh = GameLogic.ensureMarketListings(state, nowMs: now);
    expect(fresh.marketListings.length, MarketListingsService.listingCount);
    expect(fresh.marketListingsRefreshMs, now);
  });

  test('gap targeting surfaces head listings for low priest helm', () {
    final priest = PartyHero.starting(
      name: 'Ana',
      specId: HeroSpecId.holyPriest,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.holyPriest),
      equipped: {
        for (final e in StarterGear.forSpec(HeroSpecId.holyPriest).entries)
          if (e.key != EquipmentSlot.head) e.key: e.value,
      },
      level: 60,
    );
    var state = seeded();
    state = state.copyWith(
      heroRoster: [priest],
      activeHeroIds: [priest.id],
    );
    final fresh = GameLogic.ensureMarketListings(state, nowMs: now + 1);
    final headListings = fresh.marketListings.where(
      (l) => l.slot == EquipmentSlot.head,
    );
    expect(headListings, isNotEmpty);
    expect(
      headListings.any(
        (l) => MarketListingsService.isUpgradeForAnyHero(
          fresh,
          l.item,
          l.slot,
        ),
      ),
      isTrue,
    );
  });

  test('listing iLvl is at or below live drop iLvl for same rarity', () {
    final state = seeded();
    final fresh = GameLogic.ensureMarketListings(state, nowMs: now + 2);
    for (final listing in fresh.marketListings) {
      final live = MarketListingsService.liveDropItemLevel(
        state,
        listing.item.rarity,
      );
      expect(
        listing.item.effectiveItemLevel,
        lessThanOrEqualTo(live),
      );
    }
  });

  test('buy debits gold, stashes item, removes listing', () {
    final state = seeded(gold: 999_999);
    final fresh = GameLogic.ensureMarketListings(state, nowMs: now + 3);
    final listing = fresh.marketListings.first;
    final bought = GameLogic.buyMarketListing(fresh, listing.id);
    expect(bought.gold, fresh.gold - listing.priceGold);
    expect(bought.marketListings.any((l) => l.id == listing.id), isFalse);
    expect(
      bought.gearStash.any((g) => g.id == listing.item.id),
      isTrue,
    );
  });

  test('paid refresh costs gold and rolls new listings', () {
    var state = seeded(gold: 999_999);
    state = GameLogic.ensureMarketListings(state, nowMs: now + 4);
    final beforeIds = state.marketListings.map((l) => l.id).toSet();
    final cost = GameLogic.marketListingsPaidRefreshCost(state);
    final refreshed = GameLogic.refreshMarketListingsPaid(state, nowMs: now + 5);
    expect(refreshed.gold, state.gold - cost);
    expect(refreshed.marketListingsRefreshMs, now + 5);
    expect(
      refreshed.marketListings.map((l) => l.id).toSet(),
      isNot(equals(beforeIds)),
    );
  });

  test('ascend clears market listings', () {
    var state = seeded();
    state = GameLogic.ensureMarketListings(state, nowMs: now + 6);
    expect(state.marketListings, isNotEmpty);
    state = state.copyWith(
      bossVictories: 21,
      metaDepth: state.metaDepth.copyWith(noWipeAscendReady: true),
    );
    final ascended = GameLogic.ascend(state);
    expect(ascended.marketListings, isEmpty);
    expect(ascended.marketListingsRefreshMs, 0);
  });

  test('upgrade listings cost more than vendor baseline', () {
    final item = EquipmentItem(
      id: 'test_chest',
      name: 'Runed Robe',
      slot: EquipmentSlot.chest,
      rarity: LootRarity.rare,
      intellectBonus: 40,
      spiritBonus: 20,
      itemLevel: 120,
      iconId: 'chest',
      armorType: ArmorType.cloth,
    );
    final state = seeded();
    final base = MarketListingsService.priceForItem(
      state,
      item,
      EquipmentSlot.chest,
    );
    expect(base, greaterThan(0));
    expect(
      base,
      greaterThan(5 * 8),
    );
  });

  test('market listings round-trip save JSON', () {
    var state = seeded();
    state = GameLogic.ensureMarketListings(state, nowMs: now + 7);
    final raw = state.toJson();
    final encoded = jsonEncode(raw);
    final decoded = GameLogic.stateFromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expect(decoded.marketListings.length, state.marketListings.length);
    expect(decoded.marketListingsRefreshMs, state.marketListingsRefreshMs);
    expect(decoded.marketListings.first.item.name, state.marketListings.first.item.name);
  });
}
