import 'dart:math';

import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/market_listing.dart';
import '../models/proficiency.dart';
import 'equipment_factory.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'gear/gear_equip.dart';
import 'gear/gear_scorer.dart';
import 'gear_service.dart';
import 'loot_pipeline.dart';

/// WoW-AH-style gear listings on POWER → MARKET (run-scoped gold sink).
abstract final class MarketListingsService {
  static const int listingCount = 8;
  static const int targetedCount = 3;
  static const int refreshIntervalMs = 6 * 60 * 60 * 1000;
  static const int paidRefreshBaseGold = 25000;
  static const int targetedRerollAttempts = 8;
  static const int largeGapILvlThreshold = 12;

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static int paidRefreshCost(GameState state) =>
      paidRefreshBaseGold + state.ascensionLevel * 1000;

  static bool isStale(GameState state, {int? nowMs}) {
    final now = nowMs ?? MarketListingsService.nowMs();
    if (state.marketListings.isEmpty) return true;
    if (state.marketListingsRefreshMs <= 0) return true;
    return now >= state.marketListingsRefreshMs + refreshIntervalMs;
  }

  static int refreshRemainingMs(GameState state, {int? nowMs}) {
    final now = nowMs ?? MarketListingsService.nowMs();
    if (state.marketListingsRefreshMs <= 0) return 0;
    final next = state.marketListingsRefreshMs + refreshIntervalMs;
    return max(0, next - now);
  }

  static String formatRefreshRemaining(GameState state, {int? nowMs}) {
    final ms = refreshRemainingMs(state, nowMs: nowMs);
    if (ms <= 0) return 'refresh ready';
    final totalMin = (ms + 59999) ~/ 60000;
    if (totalMin >= 60) {
      final h = totalMin ~/ 60;
      final m = totalMin % 60;
      return m <= 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${totalMin}m';
  }

  static GameState ensureFresh(GameState state, {int? nowMs}) {
    if (!isStale(state, nowMs: nowMs)) return state;
    return regenerate(state, nowMs: nowMs);
  }

  static GameState regenerate(GameState state, {int? nowMs}) {
    final now = nowMs ?? MarketListingsService.nowMs();
    final rng = Random(now ^ state.ascensionLevel ^ 0x5741724B);
    final listings = _generateListings(state, rng: rng, nowMs: now);
    return state.copyWith(
      marketListings: listings,
      marketListingsRefreshMs: now,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState paidRefresh(GameState state, {int? nowMs}) {
    final cost = paidRefreshCost(state);
    if (state.gold < cost) return state;
    final now = nowMs ?? MarketListingsService.nowMs();
    final rng = Random(now ^ state.ascensionLevel ^ 0x52454652);
    final listings = _generateListings(state, rng: rng, nowMs: now);
    return state.copyWith(
      gold: state.gold - cost,
      marketListings: listings,
      marketListingsRefreshMs: now,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState buyListing(GameState state, String listingId) {
    final idx = state.marketListings.indexWhere((l) => l.id == listingId);
    if (idx < 0) return state;
    final listing = state.marketListings[idx];
    if (state.gold < listing.priceGold) return state;

    var next = GearService.stashEquipment(
      state.copyWith(gold: state.gold - listing.priceGold),
      listing.item,
    );
    final nextListings = [
      for (var i = 0; i < state.marketListings.length; i++)
        if (i != idx) state.marketListings[i],
    ];
    return next.copyWith(
      marketListings: nextListings,
      lastUpdated: DateTime.now(),
    );
  }

  static bool isUpgradeForAnyHero(
    GameState state,
    EquipmentItem item,
    EquipmentSlot slot,
  ) {
    for (var hi = 0; hi < state.heroes.length; hi++) {
      final hero = state.heroes[hi];
      if (!GearEquip.canHeroReceive(hero, item, slot: slot)) continue;
      final cmp = GearScorer.compareForHeroSlot(
        hero,
        item,
        slot,
        pairingStash: state.gearStash,
      );
      if (cmp.isUpgrade) return true;
    }
    return false;
  }

  static bool hasAffordableUpgradeListing(GameState state) {
    return bestAffordableUpgradeListing(state) != null;
  }

  /// Cheapest affordable listing that is an UPGRADE for someone in the party.
  static MarketListing? bestAffordableUpgradeListing(GameState state) {
    MarketListing? best;
    for (final listing in state.marketListings) {
      if (state.gold < listing.priceGold) continue;
      if (!isUpgradeForAnyHero(state, listing.item, listing.slot)) continue;
      if (best == null || listing.priceGold < best.priceGold) {
        best = listing;
      }
    }
    return best;
  }

  static int priceForItem(
    GameState state,
    EquipmentItem item,
    EquipmentSlot slot,
  ) {
    var base = LootPipeline.equipmentGoldValue(item) * 5;
    if (isUpgradeForAnyHero(state, item, slot)) {
      base = base * 125 ~/ 100;
    }
    if (slot == EquipmentSlot.weapon ||
        slot == EquipmentSlot.trinket ||
        slot == EquipmentSlot.trinket2) {
      base = base * 110 ~/ 100;
    }
    return max(1, base);
  }

  static int marketBattleNumber(GameState state) =>
      max(1, state.battleNumber - 2);

  static int liveDropItemLevel(GameState state, LootRarity rarity) =>
      EquipmentFactory.itemLevelFor(
        battleNumber: max(1, state.battleNumber),
        rarity: rarity,
        dungeonId: state.dungeonId,
        ascensionLevel: state.ascensionLevel,
        hardmodeLevel: state.hardmodeLevel,
      );

  static List<MarketListing> _generateListings(
    GameState state, {
    required Random rng,
    required int nowMs,
  }) {
    final listings = <MarketListing>[];
    var salt = 0;

    final gaps = _computeGapSlots(state);
    for (var i = 0; i < targetedCount && i < gaps.length; i++) {
      final gap = gaps[i];
      final hero = state.heroes[gap.heroIndex];
      final slot = gap.slot;
      final listing = _rollListing(
        state,
        heroIndex: gap.heroIndex,
        hero: hero,
        slot: slot,
        rng: rng,
        nowMs: nowMs,
        salt: salt++,
        slotGap: gap.gap,
      );
      listings.add(listing);
    }

    while (listings.length < listingCount) {
      final (slot, hero) = _pickFillerSlotAndHero(state, rng);
      final heroIndex = hero == null
          ? -1
          : state.heroes.indexWhere((h) => h.id == hero.id);
      final listing = _rollListing(
        state,
        heroIndex: heroIndex,
        hero: hero ?? (state.heroes.isNotEmpty ? state.heroes.first : null),
        slot: slot,
        rng: rng,
        nowMs: nowMs,
        salt: salt++,
        targeted: false,
      );
      listings.add(listing);
    }

    return List<MarketListing>.unmodifiable(listings);
  }

  static MarketListing _rollListing(
    GameState state, {
    required int heroIndex,
    required PartyHero? hero,
    required EquipmentSlot slot,
    required Random rng,
    required int nowMs,
    required int salt,
    bool targeted = true,
    int slotGap = 0,
  }) {
    if (targeted) {
      return _rollTargetedListing(
        state,
        heroIndex: heroIndex,
        hero: hero,
        slot: slot,
        rng: rng,
        nowMs: nowMs,
        salt: salt,
        slotGap: slotGap,
      );
    }

    final item = _createListingItem(
      state,
      hero: hero,
      slot: slot,
      rng: rng,
      battleNumber: marketBattleNumber(state),
      slotGap: 0,
      attempt: 0,
    );
    final resolvedSlot = _resolveEquipSlot(slot, item);
    final price = priceForItem(state, item, resolvedSlot);
    final id = 'ml_${nowMs}_${salt}_${rng.nextInt(99999)}';
    return MarketListing(
      id: id,
      item: item,
      priceGold: price,
      targetHeroIndex: -1,
      slot: resolvedSlot,
    );
  }

  /// Gap-targeted row: re-roll for budget-honest UPGRADE; large gaps bump iLvl.
  static MarketListing _rollTargetedListing(
    GameState state, {
    required int heroIndex,
    required PartyHero? hero,
    required EquipmentSlot slot,
    required Random rng,
    required int nowMs,
    required int salt,
    required int slotGap,
  }) {
    final largeGap = slotGap > largeGapILvlThreshold;
    final battleNumber = largeGap
        ? max(1, state.battleNumber)
        : marketBattleNumber(state);

    EquipmentItem chosen = _createListingItem(
      state,
      hero: hero,
      slot: slot,
      rng: rng,
      battleNumber: battleNumber,
      slotGap: slotGap,
      attempt: 0,
    );
    EquipmentSlot chosenSlot = _resolveEquipSlot(slot, chosen);

    for (var attempt = 0; attempt < targetedRerollAttempts; attempt++) {
      final item = _createListingItem(
        state,
        hero: hero,
        slot: slot,
        rng: rng,
        battleNumber: battleNumber,
        slotGap: slotGap,
        attempt: attempt + salt,
      );
      final resolvedSlot = _resolveEquipSlot(slot, item);
      if (isUpgradeForAnyHero(state, item, resolvedSlot)) {
        chosen = item;
        chosenSlot = resolvedSlot;
        break;
      }
      chosen = item;
      chosenSlot = resolvedSlot;
    }

    final price = priceForItem(state, chosen, chosenSlot);
    final id = 'ml_${nowMs}_${salt}_${rng.nextInt(99999)}';
    return MarketListing(
      id: id,
      item: chosen,
      priceGold: price,
      targetHeroIndex: heroIndex >= 0 ? heroIndex : -1,
      slot: chosenSlot,
    );
  }

  static EquipmentItem _createListingItem(
    GameState state, {
    required PartyHero? hero,
    required EquipmentSlot slot,
    required Random rng,
    required int battleNumber,
    required int slotGap,
    required int attempt,
  }) {
    var rarity = LootPipeline.rarityForBattle(
      battleNumber + attempt,
      hardmodeLevel: state.hardmodeLevel,
      rng: rng,
    );
    if (slotGap > largeGapILvlThreshold &&
        rarity.index < LootRarity.epic.index) {
      rarity = LootRarity.epic;
    }

    HeroRole bias = HeroRole.warrior;
    ArmorType? preferredArmor;
    SpecRoleTag? roleTag;
    HeroSpecId? lootSpecId;
    if (hero != null) {
      bias = hero.spec.gearAffinity;
      preferredArmor = GameLogic.preferredArmorForSpec(
        hero.spec,
        max(1, hero.level),
      );
      roleTag = hero.spec.roleTag;
      lootSpecId = hero.specId;
    }
    return LootPipeline.createEquipment(
      slot: slot,
      rarity: rarity,
      battleNumber: battleNumber,
      bias: bias,
      preferredArmor: preferredArmor,
      roleTag: roleTag,
      lootSpecId: lootSpecId,
      dungeonId: state.dungeonId,
      ascensionLevel: state.ascensionLevel,
      hardmodeLevel: state.hardmodeLevel,
    );
  }

  /// Targeted listing for a hero slot that is not a budget UPGRADE (GAP FILL).
  static bool isGapFillListing(GameState state, MarketListing listing) {
    if (listing.targetHeroIndex < 0) return false;
    return !isUpgradeForAnyHero(state, listing.item, listing.slot);
  }

  /// Worn iLvl on the gap-target hero for GAP FILL copy.
  static int? wornItemLevelForListing(GameState state, MarketListing listing) {
    if (listing.targetHeroIndex < 0 ||
        listing.targetHeroIndex >= state.heroes.length) {
      return null;
    }
    final worn = state.heroes[listing.targetHeroIndex].itemIn(listing.slot);
    return worn?.effectiveItemLevel;
  }

  static EquipmentSlot _resolveEquipSlot(EquipmentSlot slot, EquipmentItem item) {
    if (slot == EquipmentSlot.ring || slot == EquipmentSlot.ring2) {
      return item.slot == EquipmentSlot.ring2
          ? EquipmentSlot.ring2
          : EquipmentSlot.ring;
    }
    if (slot == EquipmentSlot.trinket || slot == EquipmentSlot.trinket2) {
      return item.slot == EquipmentSlot.trinket2
          ? EquipmentSlot.trinket2
          : EquipmentSlot.trinket;
    }
    return item.slot;
  }

  static List<({int heroIndex, EquipmentSlot slot, int gap})> _computeGapSlots(
    GameState state,
  ) {
    if (state.heroes.isEmpty) return const [];

    final targetILvl = EquipmentFactory.itemLevelFor(
      battleNumber: max(1, state.battleNumber),
      rarity: LootRarity.rare,
      dungeonId: state.dungeonId,
      ascensionLevel: state.ascensionLevel,
      hardmodeLevel: state.hardmodeLevel,
    );

    final gaps = <({int heroIndex, EquipmentSlot slot, int gap})>[];
    for (var hi = 0; hi < state.heroes.length; hi++) {
      final hero = state.heroes[hi];
      final weapon = hero.itemIn(EquipmentSlot.weapon);
      final blocksOffHand =
          weapon != null && ClassProficiency.weaponBlocksOffHand(weapon);

      for (final group in GearScorer.equipSlotGroups()) {
        for (final slot in group) {
          if (slot == EquipmentSlot.offHand && blocksOffHand) continue;
          if (slot == EquipmentSlot.ranged &&
              !ClassProficiency.usesRangedSlot(hero.spec)) {
            continue;
          }
          if (slot == EquipmentSlot.offHand &&
              !ClassProficiency.usesOffHandSlot(hero.spec)) {
            continue;
          }
          final worn = hero.itemIn(slot);
          if (worn != null &&
              !GearEquip.canHeroReceive(hero, worn, slot: slot)) {
            continue;
          }
          final wornILvl = worn?.effectiveItemLevel ?? 0;
          final gap = targetILvl - wornILvl;
          gaps.add((heroIndex: hi, slot: slot, gap: gap));
        }
      }
    }

    gaps.sort((a, b) => b.gap.compareTo(a.gap));

    final picked = <({int heroIndex, EquipmentSlot slot, int gap})>[];
    final usedHeroes = <int>{};
    for (final g in gaps) {
      if (picked.length >= targetedCount) break;
      if (usedHeroes.contains(g.heroIndex)) continue;
      picked.add(g);
      usedHeroes.add(g.heroIndex);
    }

    if (picked.length < targetedCount) {
      for (final g in gaps) {
        if (picked.length >= targetedCount) break;
        if (picked.any((p) => p.heroIndex == g.heroIndex && p.slot == g.slot)) {
          continue;
        }
        picked.add(g);
      }
    }

    return picked;
  }

  static (EquipmentSlot slot, PartyHero? hero) _pickFillerSlotAndHero(
    GameState state,
    Random rng,
  ) {
    final party = state.heroes;
    if (party.isEmpty) {
      return (
        LootPipeline.dropFamilies[rng.nextInt(LootPipeline.dropFamilies.length)],
        null,
      );
    }
    final living = [for (final h in party) if (h.isAlive) h];
    final pool = living.isNotEmpty ? living : party;
    final usable = [
      for (final s in LootPipeline.dropFamilies)
        if (pool.any((h) => _heroUsesDropSlot(h, s))) s,
    ];
    final slotPool = usable.isNotEmpty ? usable : LootPipeline.dropFamilies;
    final slot = slotPool[rng.nextInt(slotPool.length)];
    final candidates = [
      for (final h in pool)
        if (_heroUsesDropSlot(h, slot)) h,
    ];
    if (candidates.isEmpty) {
      return (slot, pool[rng.nextInt(pool.length)]);
    }
    return (slot, candidates[rng.nextInt(candidates.length)]);
  }

  static bool _heroUsesDropSlot(PartyHero hero, EquipmentSlot slot) {
    return switch (slot) {
      EquipmentSlot.ranged => ClassProficiency.usesRangedSlot(hero.spec),
      EquipmentSlot.offHand => ClassProficiency.usesOffHandSlot(hero.spec),
      EquipmentSlot.consumable => false,
      _ => true,
    };
  }
}
