import 'dart:math';

import '../models/hero.dart';
import '../models/loot.dart';
import 'game_state.dart';
import 'gear_service.dart';
import 'keystone.dart';

/// Flasks and bandages: the only things gold buys that get used up.
///
/// Flasks heal the whole party, bandages the one hero who needs it most —
/// both auto-fire during AFK, so the rules live away from UI code.
abstract final class MarketService {
  static bool canUseConsumable(GameState state) =>
      !Keystone.flasksDisabled(state) &&
      (state.heroes.any((h) => h.itemIn(EquipmentSlot.consumable) != null) ||
          state.gearStash.any((g) => g.slot == EquipmentSlot.consumable));

  static GameState useConsumable(GameState state, {int? heroIndex}) {
    if (Keystone.flasksDisabled(state)) {
      return state;
    }
    var sourceIndex = heroIndex;
    EquipmentItem? item;
    var fromStash = false;
    if (sourceIndex != null &&
        sourceIndex >= 0 &&
        sourceIndex < state.heroes.length) {
      item = state.heroes[sourceIndex].itemIn(EquipmentSlot.consumable);
    } else {
      for (var i = 0; i < state.heroes.length; i++) {
        final candidate = state.heroes[i].itemIn(EquipmentSlot.consumable);
        if (candidate != null) {
          item = candidate;
          sourceIndex = i;
          break;
        }
      }
    }
    if (item == null) {
      for (final candidate in state.gearStash) {
        if (candidate.slot == EquipmentSlot.consumable) {
          item = candidate;
          fromStash = true;
          break;
        }
      }
    }
    if (item == null) {
      return state;
    }

    var next = state;
    if (fromStash) {
      next = next.copyWith(
        gearStash: [
          for (final g in next.gearStash)
            if (g.id != item.id) g,
        ],
      );
    } else if (sourceIndex != null) {
      final hero = next.heroes[sourceIndex];
      final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
        ..remove(EquipmentSlot.consumable);
      final heroes = [...next.heroes];
      heroes[sourceIndex] = hero.copyWith(equipped: nextGear);
      next = next.copyWith(heroes: heroes);
      // Refill emptied slot from remaining stash flasks.
      EquipmentItem? refill;
      for (final g in next.gearStash) {
        if (g.slot == EquipmentSlot.consumable) {
          refill = g;
          break;
        }
      }
      if (refill != null) {
        final eq = Map<EquipmentSlot, EquipmentItem>.from(
          next.heroes[sourceIndex].equipped,
        )..[EquipmentSlot.consumable] = refill;
        final heroes2 = [...next.heroes];
        heroes2[sourceIndex] = next.heroes[sourceIndex].copyWith(equipped: eq);
        next = next.copyWith(
          heroes: heroes2,
          gearStash: [
            for (final g in next.gearStash)
              if (g.id != refill.id) g,
          ],
        );
      }
    }

    return next.copyWith(
      heroes: isBandageConsumable(item)
          ? _healLowestHero(next, ratio: 0.40)
          : [
              for (final h in next.heroes)
                if (!h.isAlive)
                  h
                else
                  h.copyWith(
                    currentHp: min(
                      next.effectiveHeroMaxHp(h),
                      h.currentHp + _flaskHealAmount(next, h),
                    ),
                  ),
            ],
    );
  }

  static bool isBandageConsumable(EquipmentItem item) =>
      item.slot == EquipmentSlot.consumable &&
      (item.iconId == 'bandage' || item.name.toLowerCase().contains('bandage'));

  static List<PartyHero> _healLowestHero(
    GameState state, {
    required double ratio,
  }) {
    var bestIndex = -1;
    var bestRatio = 2.0;
    for (var i = 0; i < state.heroes.length; i++) {
      final h = state.heroes[i];
      if (!h.isAlive) continue;
      final maxHp = state.effectiveHeroMaxHp(h);
      if (maxHp <= 0) continue;
      final r = h.currentHp / maxHp;
      if (r < bestRatio) {
        bestRatio = r;
        bestIndex = i;
      }
    }
    if (bestIndex < 0) return state.heroes;
    final target = state.heroes[bestIndex];
    final maxHp = state.effectiveHeroMaxHp(target);
    final heal = max(8, (maxHp * ratio).round());
    final heroes = [...state.heroes];
    heroes[bestIndex] = target.copyWith(
      currentHp: min(maxHp, target.currentHp + heal),
    );
    return heroes;
  }

  /// ~30% of effective max HP (min 8) — scales with level/gear instead of a flat ~13.
  static int _flaskHealAmount(GameState state, PartyHero hero) {
    final maxHp = state.effectiveHeroMaxHp(hero);
    return max(8, (maxHp * 0.30).round());
  }

  static int marketFlaskCost(GameState state) =>
      40 + (state.highestFloorCleared * 3) + (state.ascensionLevel * 15);

  static EquipmentItem createMarketFlask({int salt = 0}) {
    final id = 'flask_${DateTime.now().microsecondsSinceEpoch}_$salt';
    return EquipmentItem(
      id: id,
      name: 'Healing Flask',
      slot: EquipmentSlot.consumable,
      rarity: LootRarity.common,
      vitalityBonus: 1,
      itemLevel: 1,
      iconId: 'flask',
    );
  }

  static GameState buyMarketFlask(GameState state, {int salt = 0}) {
    final cost = marketFlaskCost(state);
    if (state.gold < cost) return state;
    final flask = createMarketFlask(salt: salt);
    var next = state.copyWith(gold: state.gold - cost);
    // Prefer empty consumable slot on first hero, else stash.
    for (var i = 0; i < next.heroes.length; i++) {
      final hero = next.heroes[i];
      if (hero.itemIn(EquipmentSlot.consumable) == null) {
        final eq = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
          ..[EquipmentSlot.consumable] = flask;
        final heroes = List<PartyHero>.from(next.heroes);
        heroes[i] = hero.copyWith(equipped: eq);
        return next.copyWith(heroes: heroes, lastUpdated: DateTime.now());
      }
    }
    next = GearService.stashEquipment(next, flask);
    return next.copyWith(lastUpdated: DateTime.now());
  }

  /// Buy up to [count] flasks (empty consumable slots first, then stash).
  static GameState buyMarketFlasks(GameState state, {int count = 3}) {
    var next = state;
    final n = count.clamp(1, 9);
    for (var i = 0; i < n; i++) {
      final before = next.gold;
      next = buyMarketFlask(next, salt: i);
      if (next.gold >= before) break;
    }
    return next;
  }

  static int marketBandageCost(GameState state) =>
      25 + (state.highestFloorCleared * 2) + (state.ascensionLevel * 10);

  static EquipmentItem createMarketBandage({int salt = 0}) {
    final id = 'bandage_${DateTime.now().microsecondsSinceEpoch}_$salt';
    return EquipmentItem(
      id: id,
      name: 'Field Bandage',
      slot: EquipmentSlot.consumable,
      rarity: LootRarity.common,
      vitalityBonus: 1,
      itemLevel: 1,
      iconId: 'bandage',
    );
  }

  static GameState buyMarketBandage(GameState state, {int salt = 0}) {
    final cost = marketBandageCost(state);
    if (state.gold < cost) return state;
    final bandage = createMarketBandage(salt: salt);
    var next = state.copyWith(gold: state.gold - cost);
    for (var i = 0; i < next.heroes.length; i++) {
      final hero = next.heroes[i];
      if (hero.itemIn(EquipmentSlot.consumable) == null) {
        final eq = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
          ..[EquipmentSlot.consumable] = bandage;
        final heroes = List<PartyHero>.from(next.heroes);
        heroes[i] = hero.copyWith(equipped: eq);
        return next.copyWith(heroes: heroes, lastUpdated: DateTime.now());
      }
    }
    next = GearService.stashEquipment(next, bandage);
    return next.copyWith(lastUpdated: DateTime.now());
  }
}
