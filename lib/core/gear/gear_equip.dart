import 'dart:math';

import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/market_listing.dart';
import '../../models/proficiency.dart';
import '../../visual/equipment_visual_resolver.dart';
import '../game_state.dart';
import 'gear_stash.dart';

/// Equip / unequip mutations and slot eligibility.
abstract final class GearEquip {
  /// Move worn pieces the hero cannot use into the bag (save migrate).
  static GameState unequipIllegalGear(GameState state) {
    var stash = List<EquipmentItem>.from(state.gearStash);
    final rebuilt = <PartyHero>[];
    var changed = false;
    for (final hero in state.heroRoster) {
      final next = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
      var heroChanged = false;
      for (final e in hero.equipped.entries) {
        if (ClassProficiency.canEquip(
          role: hero.gearAffinity,
          level: hero.level,
          item: e.value,
          specId: hero.specId,
        )) {
          continue;
        }
        next.remove(e.key);
        stash.add(e.value);
        heroChanged = true;
        changed = true;
      }
      rebuilt.add(heroChanged ? hero.copyWith(equipped: next) : hero);
    }
    if (!changed) return state;
    return state.copyWith(
      heroRoster: rebuilt,
      gearStash: stash,
      lastUpdated: DateTime.now(),
    );
  }

  /// Stamp missing [EquipmentItem.visualSetId] so BAG icons match the doll.
  static GameState stampMissingVisualSetIds(GameState state) {
    var changed = false;

    EquipmentItem stamp(EquipmentItem item) {
      final next = EquipmentVisualResolver.stampMissingVisualSetId(item);
      if (next.visualSetId != item.visualSetId) changed = true;
      return next;
    }

    final roster = <PartyHero>[];
    for (final hero in state.heroRoster) {
      final eq = <EquipmentSlot, EquipmentItem>{};
      for (final e in hero.equipped.entries) {
        eq[e.key] = stamp(e.value);
      }
      roster.add(hero.copyWith(equipped: eq));
    }
    final stash = state.gearStash.map(stamp).toList();
    final market = [
      for (final l in state.marketListings)
        MarketListing(
          id: l.id,
          item: stamp(l.item),
          priceGold: l.priceGold,
          targetHeroIndex: l.targetHeroIndex,
          slot: l.slot,
        ),
    ];
    if (!changed) return state;
    return state.copyWith(
      heroRoster: roster,
      gearStash: stash,
      marketListings: market,
      lastUpdated: DateTime.now(),
    );
  }

  /// Slots a stash piece may fill (rings/trinkets share dual slots).
  static List<EquipmentSlot> equipTargetsFor(EquipmentItem item) {
    return switch (item.slot) {
      EquipmentSlot.ring || EquipmentSlot.ring2 => <EquipmentSlot>[
        EquipmentSlot.ring,
        EquipmentSlot.ring2,
      ],
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => <EquipmentSlot>[
        EquipmentSlot.trinket,
        EquipmentSlot.trinket2,
      ],
      _ => <EquipmentSlot>[item.slot],
    };
  }

  /// Whether [hero] can actually receive [item] into [slot] right now.
  static bool canHeroReceive(
    PartyHero hero,
    EquipmentItem item, {
    required EquipmentSlot slot,
  }) {
    if (item.isApex) {
      final className = item.apexClassId;
      if (className != null && className != hero.spec.classId.name) {
        return false;
      }
      final roleName = item.apexRoleTag;
      if (roleName != null && roleName != hero.spec.roleTag.name) {
        return false;
      }
    }
    final remapped = item.slot == slot ? item : item.copyWith(slot: slot);
    if (!ClassProficiency.canEquip(
      role: hero.gearAffinity,
      level: hero.level,
      item: remapped,
      specId: hero.specId,
    )) {
      return false;
    }
    if (slot == EquipmentSlot.offHand &&
        ClassProficiency.weaponBlocksOffHand(
          hero.itemIn(EquipmentSlot.weapon),
        ) &&
        !ClassProficiency.prefersOneHandAndShield(hero.spec)) {
      return false;
    }
    return true;
  }

  /// Equip a stash item onto a hero slot (current piece moves to stash).
  static GameState equipFromStash(
    GameState state,
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) {
      return state;
    }
    EquipmentItem? item;
    for (final candidate in state.gearStash) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      return state;
    }

    final targetSlot = intoSlot ?? item.slot;
    if (!equipTargetsFor(item).contains(targetSlot)) {
      return state;
    }

    final heroCheck = state.heroes[heroIndex];
    if (!canHeroReceive(heroCheck, item, slot: targetSlot)) {
      return state;
    }
    final wornNow = heroCheck.itemIn(targetSlot);
    if (wornNow != null && wornNow.isApex && !item.isApex) {
      return state;
    }

    final equippedItem = item.slot == targetSlot
        ? item
        : item.copyWith(slot: targetSlot);

    var next = state.copyWith(
      gearStash: state.gearStash.where((g) => g.id != itemId).toList(),
      equipped: const <EquipmentSlot, EquipmentItem>{},
    );
    final hero = next.heroes[heroIndex];
    final current = hero.itemIn(targetSlot);
    if (current != null) {
      next = GearStash.stashEquipment(next, current);
    }

    final vitalityBefore = next.effectiveHeroMaxHp(hero);
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
      next.heroes[heroIndex].equipped,
    )..[targetSlot] = equippedItem;

    if (targetSlot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(equippedItem)) {
      final off = nextGear.remove(EquipmentSlot.offHand);
      if (off != null) {
        next = GearStash.stashEquipment(next, off);
      }
    }
    if (targetSlot == EquipmentSlot.offHand) {
      final wep = nextGear[EquipmentSlot.weapon];
      if (ClassProficiency.weaponBlocksOffHand(wep)) {
        nextGear.remove(EquipmentSlot.weapon);
        next = GearStash.stashEquipment(next, wep!);
      }
    }

    final heroes = [...next.heroes];
    heroes[heroIndex] = next.heroes[heroIndex].copyWith(equipped: nextGear);
    next = next.copyWith(heroes: heroes);
    final updated = next.heroes[heroIndex];
    final vitalityAfter = next.effectiveHeroMaxHp(updated);
    final vitalityDelta = vitalityAfter - vitalityBefore;
    if (vitalityDelta != 0) {
      heroes[heroIndex] = updated.copyWith(
        currentHp: vitalityDelta > 0
            ? min(vitalityAfter, updated.currentHp + vitalityDelta)
            : min(vitalityAfter, updated.currentHp),
      );
      next = next.copyWith(heroes: heroes);
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState unequipSlot(
    GameState state,
    EquipmentSlot slot, {
    int heroIndex = 0,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) {
      return state;
    }
    final hero = state.heroes[heroIndex];
    final current = hero.itemIn(slot);
    if (current == null) {
      return state;
    }
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
      ..remove(slot);
    final heroes = [...state.heroes];
    heroes[heroIndex] = hero.copyWith(equipped: nextGear);
    var next = state.copyWith(
      heroes: heroes,
      equipped: const <EquipmentSlot, EquipmentItem>{},
    );
    next = GearStash.stashEquipment(next, current);
    final updated = next.heroes[heroIndex];
    heroes[heroIndex] = updated.copyWith(
      currentHp: min(next.effectiveHeroMaxHp(updated), updated.currentHp),
    );
    return next.copyWith(heroes: heroes, lastUpdated: DateTime.now());
  }
}
