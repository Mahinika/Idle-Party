import 'dart:math';

import '../../models/gear_loadout.dart';
import '../../models/hero.dart';
import '../../models/loot.dart';
import '../../models/proficiency.dart';
import '../game_logic.dart';
import '../game_state.dart';
import '../logic_notices.dart';
import '../loot_pipeline.dart';
import 'gear_bis_planner.dart';
import 'gear_equip.dart';
import 'gear_scorer.dart';
import 'gear_stash.dart';

/// Bag cleanup, merge/sell/disassemble, and loadout presets.
abstract final class GearCleanup {
  static GameState unstickBagIfNeeded(GameState state) {
    if (!GearStash.isBagJammed(state)) return state;
    return cleanBagJunk(state, unstickBag: true);
  }

  static GameState cleanBagJunk(
    GameState state, {
    bool unstickBag = false,
    bool mergeFirst = true,
    bool manualClean = false,
  }) {
    var next = state;
    if (mergeFirst) {
      next = autoMergeJunk(next).state;
    }
    next = autoSellJunk(
      next,
      unstickBag: unstickBag,
      manualClean: manualClean,
    );
    next = autoDisassembleJunk(
      next,
      unstickBag: unstickBag,
      manualClean: manualClean,
    );
    return next;
  }

  static bool _isProtectedGear(EquipmentItem item) {
    if (item.isApex) return true;
    if (item.id.contains('soulbound')) return true;
    if (item.name.toLowerCase().startsWith('soulbound')) return true;
    return false;
  }

  static bool matchesIlvlRarityFilter(
    EquipmentItem item, {
    required int maxIlvl,
    required int maxRarity,
  }) {
    if (maxIlvl <= 0) return false;
    if (item.effectiveItemLevel > maxIlvl) return false;
    if (item.rarity.index > maxRarity.clamp(0, 4)) return false;
    return true;
  }

  static bool shouldAutoSellOnPickup(GameState state, EquipmentItem item) {
    if (!matchesIlvlRarityFilter(
      item,
      maxIlvl: state.autoSellMaxPower,
      maxRarity: state.autoSellMaxRarity,
    )) {
      return false;
    }
    return !shouldKeepInBag(state, item);
  }

  static bool shouldAutoDisassembleOnPickup(
    GameState state,
    EquipmentItem item,
  ) {
    if (!matchesIlvlRarityFilter(
      item,
      maxIlvl: state.autoDisassembleMaxIlvl,
      maxRarity: state.autoDisassembleMaxRarity,
    )) {
      return false;
    }
    return !shouldKeepInBag(state, item);
  }

  static bool shouldKeepInBag(GameState state, EquipmentItem item) {
    if (item.isApex) return true;
    final probe = state.gearStash.any((g) => g.id == item.id)
        ? state
        : state.copyWith(gearStash: [...state.gearStash, item]);
    final plan = GearBiSPlanner.planBiSAssignments(probe);
    if (plan.any((p) => p.itemId == item.id)) {
      return true;
    }
    for (final hero in state.heroes) {
      for (final slot in GearEquip.equipTargetsFor(item)) {
        if (!GearEquip.canHeroReceive(hero, item, slot: slot)) {
          continue;
        }
        if (hero.itemIn(slot) == null) {
          continue;
        }
        if (GearScorer.compareForHeroSlot(
          hero,
          item,
          slot,
          pairingStash: state.gearStash,
        ).isUpgrade) {
          return true;
        }
      }
    }
    if (isNearIlvlSlotBackup(state, item)) {
      return true;
    }
    return false;
  }

  /// Names of bag items AUTO MERGE skips (BiS / upgrades).
  static List<String> autoMergeKeptNames(GameState state, {int max = 3}) {
    final names = <String>[];
    for (final item in state.gearStash) {
      if (shouldKeepInBag(state, item)) {
        names.add(item.name);
      }
    }
    names.sort();
    return names.take(max).toList();
  }

  static int autoMergeKeptCount(GameState state) {
    var n = 0;
    for (final item in state.gearStash) {
      if (shouldKeepInBag(state, item)) n++;
    }
    return n;
  }

  /// Keeps one non-BiS backup per slot near the party's worn iLvl for that slot.
  static bool isNearIlvlSlotBackup(GameState state, EquipmentItem item) {
    final plan = GearBiSPlanner.planBiSAssignments(state);
    if (plan.any((p) => p.itemId == item.id)) return false;

    var anyHeroCanUse = false;
    for (final hero in state.heroes) {
      for (final slot in GearEquip.equipTargetsFor(item)) {
        if (GearEquip.canHeroReceive(hero, item, slot: slot)) {
          anyHeroCanUse = true;
          break;
        }
      }
      if (anyHeroCanUse) break;
    }
    if (!anyHeroCanUse) return false;

    var refIlvl = 0;
    for (final hero in state.heroes) {
      for (final slot in GearEquip.equipTargetsFor(item)) {
        if (!GearEquip.canHeroReceive(hero, item, slot: slot)) continue;
        final worn = hero.itemIn(slot);
        if (worn != null) {
          refIlvl = max(refIlvl, worn.effectiveItemLevel);
        }
      }
    }
    if (refIlvl <= 0) return false;

    const ilvlWindow = 8;
    if ((item.effectiveItemLevel - refIlvl).abs() > ilvlWindow) {
      return false;
    }

    final bisIds = {for (final p in plan) p.itemId};
    EquipmentItem? bestBackup;
    var bestScore = -999999;
    for (final other in state.gearStash) {
      if (other.slot != item.slot) continue;
      if (bisIds.contains(other.id)) continue;
      final score = partySlotScore(state, other);
      if (score > bestScore) {
        bestBackup = other;
        bestScore = score;
      }
    }
    return bestBackup?.id == item.id;
  }

  static bool shouldKeepWhenCleaning(
    GameState state,
    EquipmentItem item, {
    required bool forSell,
    bool unstickBag = false,
    bool manualClean = false,
  }) {
    if (_isProtectedGear(item)) return true;

    if (manualClean) {
      final matches = forSell
          ? matchesIlvlRarityFilter(
              item,
              maxIlvl: state.autoSellMaxPower,
              maxRarity: state.autoSellMaxRarity,
            )
          : matchesIlvlRarityFilter(
              item,
              maxIlvl: state.autoDisassembleMaxIlvl,
              maxRarity: state.autoDisassembleMaxRarity,
            );
      return !matches;
    }

    if (unstickBag) {
      final plan = GearBiSPlanner.planBiSAssignments(state);
      if (plan.any((p) => p.itemId == item.id)) {
        return true;
      }
      EquipmentItem? best;
      var bestScore = -999999;
      var bestIlvl = -1;
      for (final other in state.gearStash) {
        if (other.slot != item.slot) continue;
        final score = partySlotScore(state, other);
        final ilvl = other.effectiveItemLevel;
        if (score > bestScore || (score == bestScore && ilvl > bestIlvl)) {
          best = other;
          bestScore = score;
          bestIlvl = ilvl;
        }
      }
      if (best?.id == item.id) return true;
      final matches = forSell
          ? matchesIlvlRarityFilter(
              item,
              maxIlvl: state.autoSellMaxPower,
              maxRarity: state.autoSellMaxRarity,
            )
          : matchesIlvlRarityFilter(
              item,
              maxIlvl: state.autoDisassembleMaxIlvl,
              maxRarity: state.autoDisassembleMaxRarity,
            );
      if (!matches) return true;
      return false;
    }
    if (shouldKeepInBag(state, item)) {
      return true;
    }
    final matches = forSell
        ? matchesIlvlRarityFilter(
            item,
            maxIlvl: state.autoSellMaxPower,
            maxRarity: state.autoSellMaxRarity,
          )
        : matchesIlvlRarityFilter(
            item,
            maxIlvl: state.autoDisassembleMaxIlvl,
            maxRarity: state.autoDisassembleMaxRarity,
          );
    if (matches) return false;
    if (item.rarity.index >= LootRarity.rare.index) {
      return true;
    }
    return true;
  }

  static int partySlotScore(GameState state, EquipmentItem item) {
    var best = 0;
    for (final hero in state.heroes) {
      for (final slot in GearEquip.equipTargetsFor(item)) {
        if (!GearEquip.canHeroReceive(hero, item, slot: slot)) continue;
        best = max(
          best,
          GearScorer.slotEquipScore(
            hero,
            item,
            slot: slot,
            pairingStash: state.gearStash,
          ),
        );
      }
    }
    return best;
  }

  static int combineCost(
    EquipmentItem primary,
    EquipmentItem secondary, {
    int combinatorLuck = 0,
  }) => max(
    1,
    20 +
        primary.powerScore +
        secondary.powerScore +
        ((primary.rarity.index + secondary.rarity.index) * 5) -
        combinatorLuck * 3,
  );

  static bool canCombine(EquipmentItem primary, EquipmentItem secondary) =>
      primary.slot == secondary.slot &&
      primary.id != secondary.id &&
      !primary.isApex &&
      !secondary.isApex;

  static LootRarity mergedRarity(LootRarity primary, LootRarity secondary) {
    if (secondary.index > primary.index) {
      return secondary;
    }
    if (secondary.index == primary.index &&
        primary.index < LootRarity.legendary.index) {
      return LootRarity.values[primary.index + 1];
    }
    return primary;
  }

  static EquipmentItem mergeEquipment(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    return mergedEquipment(
      primary,
      secondary,
      id: 'combined_${primary.slot.name}_${GameLogic.random.nextInt(1000000)}',
    );
  }

  static EquipmentItem previewCombine(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    return mergedEquipment(
      primary,
      secondary,
      id: 'preview_${primary.id}_${secondary.id}',
    );
  }

  static EquipmentItem mergedEquipment(
    EquipmentItem primary,
    EquipmentItem secondary, {
    required String id,
  }) {
    final rarity = mergedRarity(primary.rarity, secondary.rarity);
    final pattern = secondary.rarity.index > primary.rarity.index
        ? secondary.pattern
        : primary.pattern;
    final keepSecondaryEffect =
        primary.effectId != GearEffectId.none &&
        secondary.effectId != GearEffectId.none &&
        secondary.effectValue > primary.effectValue;
    final effectId = keepSecondaryEffect
        ? secondary.effectId
        : (primary.effectId != GearEffectId.none
              ? primary.effectId
              : secondary.effectId);
    final effectValue = effectId == GearEffectId.none
        ? 0
        : max(primary.effectValue, secondary.effectValue);
    final affixPrefixId = primary.affixPrefixId ?? secondary.affixPrefixId;
    final affixSuffixId = primary.affixSuffixId ?? secondary.affixSuffixId;
    return EquipmentItem(
      id: id,
      name: LootPipeline.equipmentNameFor(
        primary.slot,
        rarity,
        bias: primary.affinity == null
            ? null
            : HeroRole.values.byName(primary.affinity!),
        armorType: primary.armorType ?? secondary.armorType,
        weaponType: primary.weaponType ?? secondary.weaponType,
        offHandKind: primary.offHandKind ?? secondary.offHandKind,
        handed: primary.handed ?? secondary.handed,
        affixPrefixId: affixPrefixId,
        affixSuffixId: affixSuffixId,
      ),
      slot: primary.slot,
      rarity: rarity,
      strengthBonus:
          primary.strengthBonus + ((secondary.strengthBonus * 50) ~/ 100),
      agilityBonus:
          primary.agilityBonus + ((secondary.agilityBonus * 50) ~/ 100),
      staminaBonus:
          primary.staminaBonus + ((secondary.staminaBonus * 50) ~/ 100),
      intellectBonus:
          primary.intellectBonus + ((secondary.intellectBonus * 50) ~/ 100),
      spiritBonus: primary.spiritBonus + ((secondary.spiritBonus * 50) ~/ 100),
      spellPowerBonus:
          primary.spellPowerBonus + ((secondary.spellPowerBonus * 50) ~/ 100),
      armorBonus: primary.armorBonus + ((secondary.armorBonus * 50) ~/ 100),
      mp5Bonus: primary.mp5Bonus + ((secondary.mp5Bonus * 50) ~/ 100),
      attackBonus: primary.attackBonus + ((secondary.attackBonus * 50) ~/ 100),
      defenseBonus:
          primary.defenseBonus + ((secondary.defenseBonus * 50) ~/ 100),
      vitalityBonus:
          primary.vitalityBonus + ((secondary.vitalityBonus * 50) ~/ 100),
      critChanceBonus:
          primary.critChanceBonus + ((secondary.critChanceBonus * 50) ~/ 100),
      attackSpeedBonus:
          primary.attackSpeedBonus + ((secondary.attackSpeedBonus * 50) ~/ 100),
      moveSpeedBonus: 0,
      pattern: pattern,
      effectId: effectId,
      effectValue: effectValue,
      affinity: primary.affinity,
      itemLevel:
          max(primary.effectiveItemLevel, secondary.effectiveItemLevel) +
          (rarity.index > primary.rarity.index ? 2 : 1),
      armorType: primary.armorType ?? secondary.armorType,
      weaponType: primary.weaponType ?? secondary.weaponType,
      handed: primary.handed ?? secondary.handed,
      offHandKind: primary.offHandKind ?? secondary.offHandKind,
      iconId: primary.iconId ?? secondary.iconId,
      affixPrefixId: affixPrefixId,
      affixSuffixId: affixSuffixId,
      setId: primary.setId,
    );
  }

  static GameState combineGear(
    GameState state, {
    required String primaryId,
    required String secondaryId,
  }) {
    final primary = GearStash.findStashGear(state, primaryId);
    final secondary = GearStash.findStashGear(state, secondaryId);
    if (primary == null || secondary == null) {
      return state;
    }
    if (!canCombine(primary, secondary)) {
      return state;
    }
    final cost = combineCost(
      primary,
      secondary,
      combinatorLuck: state.metaDepth.combinatorLuck,
    );
    if (state.gold < cost) {
      return state;
    }

    var next = state.copyWith(gold: state.gold - cost);
    next = GearStash.removeGear(next, primaryId);
    next = GearStash.removeGear(next, secondaryId);

    final result = mergeEquipment(primary, secondary);
    next = GearStash.stashEquipment(next, result);

    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState sellGear(GameState state, String itemId) {
    final inStash = state.gearStash.any((g) => g.id == itemId);
    if (!inStash) {
      return state;
    }
    final item = GearStash.findGear(state, itemId);
    if (item == null) {
      return state;
    }
    final value = LootPipeline.equipmentEssenceValue(item);
    final next = GearStash.removeGear(state, itemId);
    return next.copyWith(
      essence: next.essence + value,
      heroes: next.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: min(next.effectiveHeroMaxHp(hero), hero.currentHp),
            ),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  static GameState sellGearForGold(GameState state, String itemId) {
    final inStash = state.gearStash.any((g) => g.id == itemId);
    if (!inStash) return state;
    final item = GearStash.findGear(state, itemId);
    if (item == null) return state;
    final value = LootPipeline.equipmentGoldValue(item);
    final next = GearStash.removeGear(state, itemId);
    return next.copyWith(gold: next.gold + value, lastUpdated: DateTime.now());
  }

  static ({GameState state, int merges}) autoMergeJunk(
    GameState state, {
    int maxMerges = 40,
  }) {
    var next = state;
    var merges = 0;
    while (merges < maxMerges) {
      EquipmentItem? base;
      EquipmentItem? fuel;
      var bestScore = 1 << 30;
      for (var i = 0; i < next.gearStash.length; i++) {
        final a = next.gearStash[i];
        if (shouldKeepInBag(next, a)) {
          continue;
        }
        for (var j = i + 1; j < next.gearStash.length; j++) {
          final b = next.gearStash[j];
          if (a.slot != b.slot || shouldKeepInBag(next, b)) {
            continue;
          }
          final cost = combineCost(
            a,
            b,
            combinatorLuck: next.metaDepth.combinatorLuck,
          );
          if (next.gold < cost) {
            continue;
          }
          final score = a.powerScore + b.powerScore;
          if (score >= bestScore) {
            continue;
          }
          bestScore = score;
          if (a.powerScore >= b.powerScore) {
            base = a;
            fuel = b;
          } else {
            base = b;
            fuel = a;
          }
        }
      }
      if (base == null || fuel == null) {
        break;
      }
      final goldBefore = next.gold;
      next = combineGear(next, primaryId: base.id, secondaryId: fuel.id);
      if (next.gold >= goldBefore) {
        break;
      }
      merges++;
    }
    return (state: next, merges: merges);
  }

  static GameState autoSellJunk(
    GameState state, {
    bool unstickBag = false,
    bool manualClean = false,
  }) {
    var gold = state.gold;
    var lifetime = state.lifetimeGoldEarned;
    var stash = List<EquipmentItem>.from(state.gearStash);
    final beforeLen = stash.length;
    var gained = 0;
    var guard = 0;
    while (guard < 64) {
      guard++;
      final probe = state.copyWith(gearStash: stash, gold: gold);
      EquipmentItem? sellItem;
      for (final item in stash) {
        if (!shouldKeepWhenCleaning(
          probe,
          item,
          forSell: true,
          unstickBag: unstickBag,
          manualClean: manualClean,
        )) {
          sellItem = item;
          break;
        }
      }
      if (sellItem == null) break;
      final value = LootPipeline.equipmentGoldValue(sellItem);
      gold += value;
      lifetime += value;
      gained += value;
      stash = stash.where((g) => g.id != sellItem!.id).toList();
    }
    LogicNotices.recordAutoSell(sold: beforeLen - stash.length, gold: gained);
    return state.copyWith(
      gearStash: stash,
      gold: gold,
      lifetimeGoldEarned: lifetime,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState autoDisassembleJunk(
    GameState state, {
    bool unstickBag = false,
    bool manualClean = false,
  }) {
    var essence = state.essence;
    var stash = List<EquipmentItem>.from(state.gearStash);
    final beforeLen = stash.length;
    var gained = 0;
    var guard = 0;
    while (guard < 64) {
      guard++;
      final probe = state.copyWith(gearStash: stash, essence: essence);
      EquipmentItem? scrap;
      for (final item in stash) {
        if (!shouldKeepWhenCleaning(
          probe,
          item,
          forSell: false,
          unstickBag: unstickBag,
          manualClean: manualClean,
        )) {
          scrap = item;
          break;
        }
      }
      if (scrap == null) break;
      final value = LootPipeline.equipmentEssenceValue(scrap);
      essence += value;
      gained += value;
      stash = stash.where((g) => g.id != scrap!.id).toList();
    }
    LogicNotices.recordDisassemble(
      scrapped: beforeLen - stash.length,
      essence: gained,
    );
    return state.copyWith(
      gearStash: stash,
      essence: essence,
      lastUpdated: DateTime.now(),
    );
  }

  static String rarityFilterLabel(int rarityIndex) {
    final i = rarityIndex.clamp(0, LootRarity.values.length - 1);
    return switch (LootRarity.values[i]) {
      LootRarity.common => 'Common',
      LootRarity.uncommon => 'Uncommon',
      LootRarity.rare => 'Rare',
      LootRarity.epic => 'Epic',
      LootRarity.legendary => 'Legendary',
    };
  }

  static const int baseMaxLoadouts = 3;
  static const int maxLoadoutBonus = 2;

  static const int maxLoadouts = baseMaxLoadouts;

  static int maxLoadoutsFor(GameState state) =>
      (baseMaxLoadouts + state.metaDepth.loadoutBonusSlots)
          .clamp(baseMaxLoadouts, baseMaxLoadouts + maxLoadoutBonus);

  static GameState saveLoadout(
    GameState state, {
    required String id,
    required String name,
  }) {
    final heroIds = <String>[for (final hero in state.heroes) hero.id];
    final heroSlots = <Map<String, String>>[
      for (final hero in state.heroes)
        <String, String>{
          for (final entry in hero.equipped.entries)
            entry.key.name: entry.value.id,
        },
    ];
    final loadout = GearLoadout(
      id: id,
      name: name,
      heroSlotItemIds: heroSlots,
      heroIds: heroIds,
    );
    final next = List<GearLoadout>.from(state.loadouts);
    final existingIndex = next.indexWhere((l) => l.id == id);
    final cap = maxLoadoutsFor(state);
    if (existingIndex >= 0) {
      next[existingIndex] = loadout;
    } else {
      if (next.length >= cap) {
        next.removeAt(0);
      }
      next.add(loadout);
    }
    return state.copyWith(loadouts: next, lastUpdated: DateTime.now());
  }

  static GameState deleteLoadout(GameState state, String id) {
    if (!state.loadouts.any((l) => l.id == id)) return state;
    return state.copyWith(
      loadouts: state.loadouts.where((l) => l.id != id).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  static (EquipmentItem?, GameState) extractItemById(
    GameState state,
    String itemId,
  ) {
    for (var i = 0; i < state.heroRoster.length; i++) {
      final hero = state.heroRoster[i];
      for (final entry in hero.equipped.entries) {
        if (entry.value.id == itemId) {
          final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
            ..remove(entry.key);
          final roster = [...state.heroRoster];
          roster[i] = hero.copyWith(equipped: nextGear);
          return (entry.value, state.copyWith(heroRoster: roster));
        }
      }
    }
    for (final item in state.gearStash) {
      if (item.id == itemId) {
        return (
          item,
          state.copyWith(
            gearStash: state.gearStash.where((g) => g.id != itemId).toList(),
          ),
        );
      }
    }
    for (final item in state.apexVault) {
      if (item.id == itemId) {
        return (
          item,
          state.copyWith(
            apexVault: state.apexVault.where((g) => g.id != itemId).toList(),
          ),
        );
      }
    }
    return (null, state);
  }

  static ({GameState state, int skipped}) applyLoadout(
    GameState state,
    String id,
  ) {
    GearLoadout? loadout;
    for (final l in state.loadouts) {
      if (l.id == id) {
        loadout = l;
        break;
      }
    }
    if (loadout == null) return (state: state, skipped: 0);

    var next = state;
    var skipped = 0;
    final useIds =
        loadout.heroIds.isNotEmpty &&
        loadout.heroIds.length == loadout.heroSlotItemIds.length;

    for (
      var slotIndex = 0;
      slotIndex < loadout.heroSlotItemIds.length;
      slotIndex++
    ) {
      late int rosterIndex;
      if (useIds) {
        final heroId = loadout.heroIds[slotIndex];
        final idx = next.heroRoster.indexWhere((h) => h.id == heroId);
        if (idx < 0) continue;
        rosterIndex = idx;
      } else {
        if (slotIndex >= next.heroes.length) break;
        final activeId = next.heroes[slotIndex].id;
        final idx = next.heroRoster.indexWhere((h) => h.id == activeId);
        if (idx < 0) continue;
        rosterIndex = idx;
      }

      for (final entry in loadout.heroSlotItemIds[slotIndex].entries) {
        final slot = EquipmentSlotX.parse(entry.key);
        final itemId = entry.value;
        final target = next.heroRoster[rosterIndex];
        if (target.itemIn(slot)?.id == itemId) {
          continue;
        }
        final extracted = extractItemById(next, itemId);
        final item = extracted.$1;
        next = extracted.$2;
        final resolved = useIds
            ? next.heroRoster.indexWhere(
                (h) => h.id == loadout!.heroIds[slotIndex],
              )
            : next.heroRoster.indexWhere(
                (h) => h.id == next.heroes[slotIndex].id,
              );
        if (resolved < 0) continue;
        rosterIndex = resolved;
        if (item == null) {
          skipped++;
          continue;
        }

        final hero = next.heroRoster[rosterIndex];
        if (!ClassProficiency.canEquip(
          role: hero.gearAffinity,
          level: hero.level,
          item: item,
          specId: hero.specId,
        )) {
          next = GearStash.stashEquipment(next, item);
          skipped++;
          continue;
        }
        final current = hero.itemIn(slot);
        if (current != null) {
          next = GearStash.stashEquipment(next, current);
        }
        final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
          next.heroRoster[rosterIndex].equipped,
        )..[slot] = item;
        final roster = [...next.heroRoster];
        roster[rosterIndex] = next.heroRoster[rosterIndex].copyWith(
          equipped: nextGear,
        );
        next = next.copyWith(heroRoster: roster);
      }
    }

    next = next.copyWith(
      heroes: next.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: min(next.effectiveHeroMaxHp(hero), hero.currentHp),
            ),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
    return (state: next, skipped: skipped);
  }
}
