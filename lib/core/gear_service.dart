import 'dart:math';

import '../models/equip_stat_weights.dart';
import '../models/gear_loadout.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'logic_notices.dart';
import 'meta_systems.dart';
import 'starter_gear.dart';
import 'loot_pipeline.dart';

/// Everything about *where an item goes*: bag, equip, compare, merge, sell.
///
/// Split out of `GameLogic` because gear is the system the player touches most
/// and it kept getting lost between offline math and ascend rules. The BiS
/// planner and the auto-equip pass live here too — one place to answer
/// "is this an upgrade?" (see docs/GEAR_BUDGET.md).
abstract final class GearService {
  static const int maxGearStash = 50;

  static int maxGearStashFor(GameState state) =>
      maxGearStash + state.metaDepth.stashBonusSlots;

  /// Puts gear into the inventory stash. Overflow salvages the oldest piece.
  static GameState stashEquipment(GameState state, EquipmentItem item) {
    return stashEquipmentDetailed(state, item).state;
  }

  /// Like [stashEquipment], also reporting overflow salvage for UI feedback.
  static ({GameState state, int overflowEssence, String? overflowName})
  stashEquipmentDetailed(GameState state, EquipmentItem item) {
    if (item.isApex) {
      return (
        state: state.copyWith(apexVault: [...state.apexVault, item]),
        overflowEssence: 0,
        overflowName: null,
      );
    }
    final stash = List<EquipmentItem>.from(state.gearStash);
    var essence = state.essence;
    var overflowEssence = 0;
    String? overflowName;
    final cap = maxGearStashFor(state);
    if (stash.length >= cap) {
      final overflow = stash.removeAt(0);
      if (overflow.isApex) {
        return (
          state: state.copyWith(
            gearStash: stash,
            apexVault: [...state.apexVault, overflow, item],
            essence: essence,
          ),
          overflowEssence: 0,
          overflowName: null,
        );
      }
      overflowEssence = LootPipeline.equipmentEssenceValue(overflow);
      overflowName = overflow.name;
      essence += overflowEssence;
    }
    stash.add(item);
    return (
      state: state.copyWith(gearStash: stash, essence: essence),
      overflowEssence: overflowEssence,
      overflowName: overflowName,
    );
  }

  static EquipmentItem? findGear(GameState state, String id) {
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        if (item.id == id) return item;
      }
    }
    return findStashGear(state, id);
  }

  /// Bag-only lookup — combinator / merge never touches equipped gear.
  static EquipmentItem? findStashGear(GameState state, String id) {
    for (final item in state.gearStash) {
      if (item.id == id) return item;
    }
    return null;
  }

  static ({int heroIndex, EquipmentSlot slot})? findEquippedLocation(
    GameState state,
    String id,
  ) {
    for (var i = 0; i < state.heroes.length; i++) {
      for (final entry in state.heroes[i].equipped.entries) {
        if (entry.value.id == id) {
          return (heroIndex: i, slot: entry.key);
        }
      }
    }
    return null;
  }

  static GameState removeGear(GameState state, String id) {
    final location = findEquippedLocation(state, id);
    if (location != null) {
      final hero = state.heroes[location.heroIndex];
      final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
        ..remove(location.slot);
      final heroes = [...state.heroes];
      heroes[location.heroIndex] = hero.copyWith(equipped: nextGear);
      return state.copyWith(heroes: heroes);
    }
    return state.copyWith(
      gearStash: state.gearStash.where((item) => item.id != id).toList(),
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
        )) {
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
    // Apex is soul-kept — never overwrite with a normal drop (vault recovers,
    // but accidental tap / Auto Equip must not kick it).
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
      next = stashEquipment(next, current);
    }

    final vitalityBefore = next.effectiveHeroMaxHp(hero);
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
      next.heroes[heroIndex].equipped,
    )..[targetSlot] = equippedItem;

    // 2H main-hand unequips off-hand.
    if (targetSlot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(equippedItem)) {
      final off = nextGear.remove(EquipmentSlot.offHand);
      if (off != null) {
        next = stashEquipment(next, off);
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
    next = stashEquipment(next, current);
    final updated = next.heroes[heroIndex];
    heroes[heroIndex] = updated.copyWith(
      currentHp: min(next.effectiveHeroMaxHp(updated), updated.currentHp),
    );
    return next.copyWith(heroes: heroes, lastUpdated: DateTime.now());
  }

  /// Scrap one stash piece for essence. Refuses equipped gear (unequip first).
  static GameState sellGear(GameState state, String itemId) {
    final inStash = state.gearStash.any((g) => g.id == itemId);
    if (!inStash) {
      return state;
    }
    final item = findGear(state, itemId);
    if (item == null) {
      return state;
    }
    final value = LootPipeline.equipmentEssenceValue(item);
    final next = removeGear(state, itemId);
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

  /// Slot groups for BiS planning: dual ring/trinket, then singletons.
  static List<List<EquipmentSlot>> equipSlotGroups() {
    return <List<EquipmentSlot>>[
      <EquipmentSlot>[EquipmentSlot.ring, EquipmentSlot.ring2],
      <EquipmentSlot>[EquipmentSlot.trinket, EquipmentSlot.trinket2],
      for (final slot in EquipmentSlot.values)
        if (slot != EquipmentSlot.ring &&
            slot != EquipmentSlot.ring2 &&
            slot != EquipmentSlot.trinket &&
            slot != EquipmentSlot.trinket2 &&
            slot != EquipmentSlot.consumable)
          <EquipmentSlot>[slot],
    ];
  }

  /// Net score for putting [item] into [slot] on [hero].
  ///
  /// Two-hand weapons subtract the currently worn off-hand so Auto Equip
  /// does not drop a strong shield/tome for a marginally better 2H.
  ///
  /// One-hand weapons swapping off a two-hand add the best wearable off-hand
  /// from [pairingStash] (bag), so 1H+shield can beat a lonely staff.
  static int slotEquipScore(
    PartyHero hero,
    EquipmentItem? item, {
    required EquipmentSlot slot,
    List<EquipmentItem>? pairingStash,
  }) {
    if (item == null) return 0;
    if (!canHeroReceive(hero, item, slot: slot)) {
      return -999999;
    }
    var score = specEquipScore(hero, item);
    if (slot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(item)) {
      final off = hero.itemIn(EquipmentSlot.offHand);
      if (off != null) {
        score -= specEquipScore(hero, off);
      }
    } else if (slot == EquipmentSlot.weapon &&
        !ClassProficiency.weaponBlocksOffHand(item) &&
        pairingStash != null &&
        ClassProficiency.weaponBlocksOffHand(
          hero.itemIn(EquipmentSlot.weapon),
        )) {
      score += bestPairingOffHandScore(
        hero,
        pairingStash,
        excludeItemId: item.id,
      );
    }
    return score;
  }

  /// Best off-hand score from [stash] as if the hero could wear OH (ignores
  /// current 2H block). Used when scoring a 1H swap off a two-hander.
  static int bestPairingOffHandScore(
    PartyHero hero,
    List<EquipmentItem> stash, {
    String? excludeItemId,
  }) {
    return bestPairingOffHand(
          hero,
          stash,
          excludeItemId: excludeItemId,
        )?.score ??
        0;
  }

  /// Best wearable off-hand from [stash] ignoring the current 2H block.
  static ({EquipmentItem item, int score})? bestPairingOffHand(
    PartyHero hero,
    List<EquipmentItem> stash, {
    String? excludeItemId,
  }) {
    EquipmentItem? bestItem;
    var best = 0;
    for (final raw in stash) {
      if (excludeItemId != null && raw.id == excludeItemId) continue;
      if (!equipTargetsFor(raw).contains(EquipmentSlot.offHand)) continue;
      if (raw.isApex) {
        final className = raw.apexClassId;
        if (className != null && className != hero.spec.classId.name) {
          continue;
        }
      }
      final item = raw.slot == EquipmentSlot.offHand
          ? raw
          : raw.copyWith(slot: EquipmentSlot.offHand);
      if (!ClassProficiency.canEquip(
        role: hero.gearAffinity,
        level: hero.level,
        item: item,
        specId: hero.specId,
      )) {
        continue;
      }
      final sc = specEquipScore(hero, item);
      if (sc > best) {
        best = sc;
        bestItem = raw;
      }
    }
    if (bestItem == null || best <= 0) return null;
    return (item: bestItem, score: best);
  }

  /// Spec-aware score for deciding whether gear is an upgrade for a hero.
  ///
  /// Budget-honest path: role-weighted stats + real effects + Apex tier.
  /// No affinity / armor / rarity / set / raw-iLvl crumbs — see docs/GEAR_BUDGET.md.
  static int specEquipScore(PartyHero hero, EquipmentItem item) {
    return itemBudgetScore(hero, item);
  }

  /// Role-weighted item power for BiS / Auto Equip / UPGRADE (GEAR_BUDGET).
  static int itemBudgetScore(PartyHero hero, EquipmentItem item) {
    final role = _equipScoreRole(hero.spec);
    var score = roleEquipScore(
      role,
      item,
      specId: hero.specId,
      level: hero.level,
    );
    if (item.isApex) {
      score += 80 + item.apexRank * 40;
      if (item.apexClassId == hero.spec.classId.name) {
        score += 40;
      }
      if (item.apexRoleTag == hero.spec.roleTag.name) {
        score += 60;
      }
    }
    return score;
  }

  /// Map talent trees onto the 4 scoring archetypes (not identity labels).
  static HeroRole _equipScoreRole(HeroSpecDef spec) {
    if (spec.classId == HeroClassId.hunter) return HeroRole.rogue;
    return switch (spec.roleTag) {
      SpecRoleTag.tank => HeroRole.warrior,
      SpecRoleTag.healer => HeroRole.healer,
      SpecRoleTag.caster => HeroRole.mage,
      SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
        spec.gearAffinity == HeroRole.mage
            ? HeroRole.mage
            : (spec.gearAffinity == HeroRole.warrior
                  ? HeroRole.warrior
                  : HeroRole.rogue),
    };
  }

  /// Class-aware score for deciding whether gear is an upgrade for a hero.
  ///
  /// When [specId] is set, weights follow [EquipStatWeights.forSpec] so BiS
  /// matches CombatRatings (tank Sta/Armor, Str-DPS, Agi-DPS, Int>SP casters).
  ///
  /// Budget-honest: weighted stats + effects only. No affinity/armor/rarity/iLvl
  /// crumbs — iLvl power is already inside the item's rolled stats.
  static int roleEquipScore(
    HeroRole role,
    EquipmentItem item, {
    HeroSpecId? specId,
    int level = 60,
  }) {
    // [level] reserved for future armor-gate soft hints; hard gate is canEquip.
    final spec = specId != null ? HeroSpecs.def(specId) : null;
    final w = spec != null
        ? EquipStatWeights.forSpec(spec)
        : EquipStatWeights.forRole(role);
    final roleTag = spec?.roleTag;
    assert(level >= 1);
    final effect = switch (item.effectId) {
      GearEffectId.lifesteal => switch (roleTag ?? _tagForRole(role)) {
        SpecRoleTag.tank => item.effectValue * 5,
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps => item.effectValue * 3,
        _ => item.effectValue,
      },
      GearEffectId.pierce => switch (roleTag ?? _tagForRole(role)) {
        SpecRoleTag.caster => 24,
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps => 12,
        _ => 6,
      },
      GearEffectId.crit => switch (roleTag ?? _tagForRole(role)) {
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps => item.effectValue * 4,
        SpecRoleTag.caster => item.effectValue * 3,
        SpecRoleTag.healer => item.effectValue * 2,
        _ => item.effectValue,
      },
      GearEffectId.haste => switch (roleTag ?? _tagForRole(role)) {
        SpecRoleTag.caster || SpecRoleTag.healer => item.effectValue * 3,
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps => item.effectValue * 2,
        _ => item.effectValue,
      },
      GearEffectId.goldFind => item.effectValue,
      GearEffectId.none => 0,
    };
    // Move is not part of loot budget; still count tiny existing Move for
    // honesty on old saves, but weight is already low in EquipStatWeights.
    final core =
        (item.strengthBonus * w.str +
                item.agilityBonus * w.agi +
                item.resolvedStamina * w.sta +
                item.intellectBonus * w.intel +
                item.spiritBonus * w.spi +
                item.spellPowerBonus * w.sp +
                item.resolvedArmor * w.armor +
                item.critChanceBonus * w.crit +
                item.attackSpeedBonus * w.aspd +
                item.moveSpeedBonus * w.move +
                item.mp5Bonus * w.mp5)
            .round() +
        (item.attackBonus * w.flatAtk).round();
    return core + effect;
  }

  static SpecRoleTag _tagForRole(HeroRole role) => switch (role) {
    HeroRole.warrior => SpecRoleTag.meleeDps,
    HeroRole.rogue => SpecRoleTag.meleeDps,
    HeroRole.healer => SpecRoleTag.healer,
    HeroRole.mage => SpecRoleTag.caster,
  };

  /// Compare a bag candidate against what a hero wears in that slot family.
  ///
  /// Rings/trinkets pick the best of the dual slots. Off-hand is not an upgrade
  /// while a two-hand weapon is equipped.
  ///
  /// Pass [pairingStash] (usually bag) so 1H vs worn 2H can credit a shield/tome.
  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
    EquipmentSlot intoSlot,
  })
  compareForHero(
    PartyHero hero,
    EquipmentItem candidate, {
    EquipmentSlot? intoSlot,
    List<EquipmentItem>? pairingStash,
  }) {
    final targets = intoSlot != null
        ? <EquipmentSlot>[intoSlot]
        : equipTargetsFor(candidate);

    var bestDelta = -99999;
    var best = (
      powerDelta: -9999,
      atkDelta: 0,
      defDelta: 0,
      vitDelta: 0,
      isUpgrade: false,
      intoSlot: targets.first,
    );

    for (final slot in targets) {
      final cmp = _compareForHeroSlot(
        hero,
        candidate,
        slot,
        pairingStash: pairingStash,
      );
      if (cmp.powerDelta > bestDelta) {
        bestDelta = cmp.powerDelta;
        best = (
          powerDelta: cmp.powerDelta,
          atkDelta: cmp.atkDelta,
          defDelta: cmp.defDelta,
          vitDelta: cmp.vitDelta,
          isUpgrade: cmp.isUpgrade,
          intoSlot: slot,
        );
      }
    }
    return best;
  }

  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
  })
  _compareForHeroSlot(
    PartyHero hero,
    EquipmentItem candidate,
    EquipmentSlot slot, {
    List<EquipmentItem>? pairingStash,
  }) {
    if (!canHeroReceive(hero, candidate, slot: slot)) {
      return (
        powerDelta: -9999,
        atkDelta: 0,
        defDelta: 0,
        vitDelta: 0,
        isUpgrade: false,
      );
    }
    final current = hero.itemIn(slot);
    if (current != null && current.isApex && !candidate.isApex) {
      return (
        powerDelta: -9999,
        atkDelta: 0,
        defDelta: 0,
        vitDelta: 0,
        isUpgrade: false,
      );
    }
    final curScore = slotEquipScore(
      hero,
      current,
      slot: slot,
      pairingStash: pairingStash,
    );
    final newScore = slotEquipScore(
      hero,
      candidate,
      slot: slot,
      pairingStash: pairingStash,
    );
    final curAtk =
        (current?.strengthBonus ?? 0) +
        (current?.agilityBonus ?? 0) +
        (current?.intellectBonus ?? 0) +
        (current?.spellPowerBonus ?? 0) +
        (current?.attackBonus ?? 0);
    final curDef = current?.resolvedArmor ?? 0;
    final curVit = current?.resolvedStamina ?? 0;
    final newAtk =
        candidate.strengthBonus +
        candidate.agilityBonus +
        candidate.intellectBonus +
        candidate.spellPowerBonus +
        candidate.attackBonus;
    final powerDelta = newScore - curScore;
    return (
      powerDelta: powerDelta,
      atkDelta: newAtk - curAtk,
      defDelta: candidate.resolvedArmor - curDef,
      vitDelta: candidate.resolvedStamina - curVit,
      isUpgrade: isMeaningfulEquipUpgrade(
        hero: hero,
        item: candidate,
        worn: current,
        curScore: curScore,
        newScore: newScore,
        slotEmpty: current == null,
      ),
    );
  }

  /// Role-weighted primary mass (excludes rarity / ilvl / affinity crumbs).
  static double roleRelevantStatMass(PartyHero hero, EquipmentItem item) {
    final w = EquipStatWeights.forSpec(hero.spec);
    return item.strengthBonus * w.str +
        item.agilityBonus * w.agi +
        item.resolvedStamina * w.sta +
        item.intellectBonus * w.intel +
        item.spiritBonus * w.spi +
        item.spellPowerBonus * w.sp +
        item.resolvedArmor * w.armor +
        item.critChanceBonus * w.crit +
        item.attackSpeedBonus * w.aspd +
        item.attackBonus * w.flatAtk;
  }

  /// Empty slots only fill role-plausible gear (not every wearable crumb).
  ///
  /// GEAR_BUDGET: score/mass must clear a level-scaled floor. Affinity /
  /// preferred armor alone is not enough.
  static bool emptySlotWorthFilling(
    PartyHero hero,
    EquipmentItem item,
    int score,
  ) {
    final mass = roleRelevantStatMass(hero, item);
    final minIlvl = max(6, (hero.level * 0.55).floor());
    final ilvl = item.effectiveItemLevel;
    final nearLevel = ilvl >= minIlvl - 2;

    // Primary gates: meaningful budget score or mass near hero level.
    if (score >= 90 && mass >= 12 && nearLevel) return true;
    if (mass >= 28 && nearLevel) return true;
    if (ilvl >= minIlvl && mass >= 10) return true;
    if (ilvl >= minIlvl + 4 && mass >= 6) return true;

    final spec = hero.spec;
    final preferred = StarterGear.preferredArmorForSpec(spec, hero.level);
    final armorOk = preferred != null && item.armorType == preferred;
    if (armorOk && nearLevel && mass >= 16) return true;
    return false;
  }

  /// Clear upgrade bar shared by Auto Equip, UI badges, and keep/sell helpers.
  ///
  /// Empty slots use [emptySlotWorthFilling]. Worn slots need a meaningful
  /// budget-score delta (see docs/GEAR_BUDGET.md). Lower-iLvl swaps need a
  /// clearly real jump so tiny noise does not thrash gear.
  static bool isMeaningfulEquipUpgrade({
    required PartyHero hero,
    required EquipmentItem item,
    required int curScore,
    required int newScore,
    required bool slotEmpty,
    EquipmentItem? worn,
  }) {
    final delta = newScore - curScore;
    if (delta <= 0) return false;
    if (slotEmpty) {
      return emptySlotWorthFilling(hero, item, newScore);
    }
    final wornItem = worn;
    if (wornItem != null) {
      final ilvlGap = wornItem.effectiveItemLevel - item.effectiveItemLevel;
      if (ilvlGap > 2) {
        final minDelta = max(20, (curScore * 0.10).ceil() + ilvlGap);
        return delta >= minDelta;
      }
    }
    final minDelta = max(6, (curScore * 0.03).ceil());
    return delta >= minDelta;
  }

  /// Planned stash→slot upgrades from BiS assignment (shared by Auto Equip / Sell Junk).
  ///
  /// Memoized on [gearPlanSignature]: the walk is heavy (six rounds over every
  /// hero, slot and bag item) and it used to run up to eight times per Auto
  /// Equip, once per loot drop in the offline catch-up, and again for every
  /// menu badge repaint.
  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
  planBiSAssignments(GameState state) {
    final signature = gearPlanSignature(state);
    final cached = _bisPlan;
    if (cached != null && signature == _bisPlanSignature) return cached;
    final plan =
        List<
          ({int heroIndex, EquipmentSlot slot, String itemId, int delta})
        >.unmodifiable(_computeBiSAssignments(state));
    _bisPlanSignature = signature;
    _bisPlan = plan;
    return plan;
  }

  static int _bisPlanSignature = 0;

  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>?
  _bisPlan;

  /// Cheap hash of everything the BiS plan depends on: bag contents, worn
  /// gear, and hero spec/level. Anything else can change without redoing it.
  static int gearPlanSignature(GameState state) {
    var h = state.gearStash.length * 31 + state.heroes.length;
    for (final item in state.gearStash) {
      h = (h * 33) ^ item.id.hashCode ^ item.effectiveItemLevel;
    }
    for (final hero in state.heroes) {
      h = (h * 33) ^ hero.specId.index ^ (hero.level * 7);
      for (final entry in hero.equipped.entries) {
        h = (h * 33) ^ entry.key.index ^ entry.value.id.hashCode;
      }
    }
    return h & 0x3FFFFFFF;
  }

  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
  _computeBiSAssignments(GameState state) {
    final stashById = <String, EquipmentItem>{
      for (final item in state.gearStash) item.id: item,
    };
    if (stashById.isEmpty) return const [];

    final reserved = <String>{};
    final plan =
        <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];
    final filledSlots = <String>{};

    String slotKey(int heroIndex, EquipmentSlot slot) =>
        '$heroIndex:${slot.name}';

    for (var round = 0; round < 6; round++) {
      final proposals =
          <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];

      for (var hi = 0; hi < state.heroes.length; hi++) {
        final hero = state.heroes[hi];
        String? plannedWeaponId;
        for (final p in plan) {
          if (p.heroIndex == hi && p.slot == EquipmentSlot.weapon) {
            plannedWeaponId = p.itemId;
            break;
          }
        }
        final plannedWeapon = plannedWeaponId == null
            ? hero.itemIn(EquipmentSlot.weapon)
            : stashById[plannedWeaponId] ?? hero.itemIn(EquipmentSlot.weapon);
        final blocksOffHand = ClassProficiency.weaponBlocksOffHand(
          plannedWeapon,
        );

        for (final group in equipSlotGroups()) {
          if (blocksOffHand &&
              group.length == 1 &&
              group.first == EquipmentSlot.offHand) {
            continue;
          }

          final available = <EquipmentItem>[
            for (final item in state.gearStash)
              if (!reserved.contains(item.id)) item,
          ];
          final pairing = state.gearStash;

          final scored = <({EquipmentItem item, int score})>[];
          for (final item in available) {
            if (!equipTargetsFor(item).any(group.contains)) continue;
            var best = -999999;
            for (final slot in group) {
              if (filledSlots.contains(slotKey(hi, slot))) continue;
              if (!canHeroReceive(hero, item, slot: slot)) continue;
              best = max(
                best,
                slotEquipScore(hero, item, slot: slot, pairingStash: pairing),
              );
            }
            if (best > -999999) {
              scored.add((item: item, score: best));
            }
          }
          scored.sort((a, b) => b.score.compareTo(a.score));

          final slots = [...group]
            ..sort((a, b) {
              final sa = filledSlots.contains(slotKey(hi, a))
                  ? 999999
                  : slotEquipScore(
                      hero,
                      hero.itemIn(a),
                      slot: a,
                      pairingStash: pairing,
                    );
              final sb = filledSlots.contains(slotKey(hi, b))
                  ? 999999
                  : slotEquipScore(
                      hero,
                      hero.itemIn(b),
                      slot: b,
                      pairingStash: pairing,
                    );
              return sa.compareTo(sb);
            });

          final usedLocal = <String>{};
          for (final slot in slots) {
            if (filledSlots.contains(slotKey(hi, slot))) continue;
            final cur = hero.itemIn(slot);
            final curScore = slotEquipScore(
              hero,
              cur,
              slot: slot,
              pairingStash: pairing,
            );
            for (final entry in scored) {
              if (usedLocal.contains(entry.item.id)) continue;
              if (reserved.contains(entry.item.id)) continue;
              if (!canHeroReceive(hero, entry.item, slot: slot)) continue;
              final sc = slotEquipScore(
                hero,
                entry.item,
                slot: slot,
                pairingStash: pairing,
              );
              if (isMeaningfulEquipUpgrade(
                hero: hero,
                item: entry.item,
                worn: cur,
                curScore: curScore,
                newScore: sc,
                slotEmpty: cur == null,
              )) {
                usedLocal.add(entry.item.id);
                proposals.add((
                  heroIndex: hi,
                  slot: slot,
                  itemId: entry.item.id,
                  delta: sc - curScore,
                ));
                break;
              }
            }
          }
        }
      }

      if (proposals.isEmpty) break;

      final bestByItem =
          <
            String,
            ({int heroIndex, EquipmentSlot slot, String itemId, int delta})
          >{};
      for (final p in proposals) {
        final prev = bestByItem[p.itemId];
        if (prev == null || p.delta > prev.delta) {
          bestByItem[p.itemId] = p;
        }
      }

      final bestBySlot =
          <
            String,
            ({int heroIndex, EquipmentSlot slot, String itemId, int delta})
          >{};
      for (final p in bestByItem.values) {
        final key = slotKey(p.heroIndex, p.slot);
        final prev = bestBySlot[key];
        if (prev == null || p.delta > prev.delta) {
          bestBySlot[key] = p;
        }
      }

      var added = 0;
      final winners = bestBySlot.values.toList()
        ..sort((a, b) => b.delta.compareTo(a.delta));
      final claimedThisRound = <String>{};
      for (final w in winners) {
        if (reserved.contains(w.itemId)) continue;
        if (claimedThisRound.contains(w.itemId)) continue;
        final key = slotKey(w.heroIndex, w.slot);
        if (filledSlots.contains(key)) continue;
        reserved.add(w.itemId);
        claimedThisRound.add(w.itemId);
        filledSlots.add(key);
        plan.add(w);
        added++;

        // 1H swap off a 2H: also pull the bag OH that pairing credited, so one
        // Auto Equip pass equips sword+shield instead of leaving the shield.
        if (w.slot == EquipmentSlot.weapon) {
          final heroNow = state.heroes[w.heroIndex];
          final wornW = heroNow.itemIn(EquipmentSlot.weapon);
          EquipmentItem? incoming;
          for (final g in state.gearStash) {
            if (g.id == w.itemId) {
              incoming = g;
              break;
            }
          }
          if (incoming != null &&
              ClassProficiency.weaponBlocksOffHand(wornW) &&
              !ClassProficiency.weaponBlocksOffHand(incoming)) {
            final ohKey = slotKey(w.heroIndex, EquipmentSlot.offHand);
            if (!filledSlots.contains(ohKey) &&
                heroNow.itemIn(EquipmentSlot.offHand) == null) {
              final paired = bestPairingOffHand(heroNow, [
                for (final g in state.gearStash)
                  if (!reserved.contains(g.id) &&
                      !claimedThisRound.contains(g.id))
                    g,
              ], excludeItemId: w.itemId);
              if (paired != null) {
                reserved.add(paired.item.id);
                claimedThisRound.add(paired.item.id);
                filledSlots.add(ohKey);
                plan.add((
                  heroIndex: w.heroIndex,
                  slot: EquipmentSlot.offHand,
                  itemId: paired.item.id,
                  delta: paired.score,
                ));
                added++;
              }
            }
          }
        }
      }
      if (added == 0) break;
    }

    return plan;
  }

  /// Equip every stash piece that is a class-aware upgrade for some hero.
  ///
  /// Uses per-hero BiS slot fill with party-wide conflict resolution (largest
  /// power delta wins contested items; losers re-pick next round).
  /// Multi-pass so leftovers can fill after contested items resolve.
  static GameState autoEquipBetterGear(GameState state) {
    var next = state;
    for (var pass = 0; pass < 8; pass++) {
      final beforeLen = next.gearStash.length;
      next = _autoEquipPass(next);
      if (next.gearStash.length >= beforeLen) {
        break;
      }
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState _autoEquipPass(GameState state) {
    var next = state;
    final plan = planBiSAssignments(next);
    final ordered = [...plan]
      ..sort((a, b) {
        final aw = a.slot == EquipmentSlot.weapon ? 0 : 1;
        final bw = b.slot == EquipmentSlot.weapon ? 0 : 1;
        return aw.compareTo(bw);
      });
    for (final step in ordered) {
      EquipmentItem? item;
      for (final g in next.gearStash) {
        if (g.id == step.itemId) {
          item = g;
          break;
        }
      }
      if (item == null) continue;
      final hero = next.heroes[step.heroIndex];
      if (!canHeroReceive(hero, item, slot: step.slot)) continue;
      final beforeLen = next.gearStash.length;
      next = equipFromStash(
        next,
        step.itemId,
        heroIndex: step.heroIndex,
        intoSlot: step.slot,
      );
      if (next.gearStash.length >= beforeLen) {
        continue;
      }
    }
    return next;
  }

  static String formatDelta(int value) {
    if (value > 0) return '+$value';
    if (value < 0) return '$value';
    return '0';
  }

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
    return _mergedEquipment(
      primary,
      secondary,
      id: 'combined_${primary.slot.name}_${GameLogic.random.nextInt(1000000)}',
    );
  }

  /// Shows a combination result without changing state or consuming randomness.
  static EquipmentItem previewCombine(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    return _mergedEquipment(
      primary,
      secondary,
      id: 'preview_${primary.id}_${secondary.id}',
    );
  }

  static EquipmentItem _mergedEquipment(
    EquipmentItem primary,
    EquipmentItem secondary, {
    required String id,
  }) {
    final rarity = mergedRarity(primary.rarity, secondary.rarity);
    // Primary drives slot + pattern; secondary can upgrade pattern if rarer.
    final pattern = secondary.rarity.index > primary.rarity.index
        ? secondary.pattern
        : primary.pattern;
    final effectId = primary.effectId != GearEffectId.none
        ? primary.effectId
        : secondary.effectId;
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
      // GEAR_BUDGET: do not inherit Move from fuel into new merges.
      moveSpeedBonus: 0,
      pattern: pattern,
      effectId: effectId,
      effectValue: effectValue,
      // Affinity / setId from primary only (identity), not score crumbs.
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

  /// Combines two same-slot **bag** pieces. Equipped gear is ignored —
  /// unequip to stash first. Primary keeps slot/pattern identity;
  /// secondary contributes half its stats. Result always returns to bag.
  static GameState combineGear(
    GameState state, {
    required String primaryId,
    required String secondaryId,
  }) {
    final primary = findStashGear(state, primaryId);
    final secondary = findStashGear(state, secondaryId);
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
    next = removeGear(next, primaryId);
    next = removeGear(next, secondaryId);

    final result = mergeEquipment(primary, secondary);
    // Always stash result — player equips manually.
    next = stashEquipment(next, result);

    return next.copyWith(lastUpdated: DateTime.now());
  }

  /// Gear always goes to stash (manual equip). Non-gear → essence.
  /// Weak junk is auto-sold for **gold** or auto-disassembled for **essence**
  /// on pickup when filters match (sell checked first).
  static ({GameState state, List<LootDrop> resolved}) applyLootDrops(
    GameState state,
    List<LootDrop> drops,
  ) {
    var next = state;
    final resolved = <LootDrop>[];

    for (final drop in drops) {
      final item = drop.equipment;
      if (item == null) {
        if (LootPipeline.isWalletGoldDrop(drop)) {
          final gained = GameLogic.applyGoldGain(next, drop.amount);
          if (gained > 0) {
            next = next.copyWith(
              gold: next.gold + gained,
              lifetimeGoldEarned: next.lifetimeGoldEarned + gained,
            );
          }
          resolved.add(
            drop.copyWith(outcome: LootOutcome.gold, essenceGained: 0),
          );
          continue;
        }
        final essence = LootPipeline.lootEssenceValue(drop);
        next = next.copyWith(essence: next.essence + essence);
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: essence),
        );
        continue;
      }

      if (_shouldAutoSellOnPickup(next, item)) {
        final value = LootPipeline.equipmentGoldValue(item);
        next = next.copyWith(
          gold: next.gold + value,
          lifetimeGoldEarned: next.lifetimeGoldEarned + value,
        );
        resolved.add(
          drop.copyWith(outcome: LootOutcome.gold, essenceGained: 0),
        );
        continue;
      }

      if (_shouldAutoDisassembleOnPickup(next, item)) {
        final value = LootPipeline.equipmentEssenceValue(item);
        next = next.copyWith(essence: next.essence + value);
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: value),
        );
        continue;
      }

      final stashed = stashEquipmentDetailed(next, item);
      next = stashed.state;
      resolved.add(
        drop.copyWith(
          outcome: LootOutcome.stashed,
          essenceGained: stashed.overflowEssence,
        ),
      );
    }

    // Live spatial loot never goes through completeCurrentRoom meta progress.
    next = MetaSystems.registerItemDrops(next, drops);
    // Near-full bag: merge → sell gold → disassemble essence.
    next = unstickBagIfNeeded(next);
    return (state: next, resolved: resolved);
  }

  /// Run merge + auto-sell + auto-disassemble when stash is ≥90% full.
  static GameState unstickBagIfNeeded(GameState state) {
    final cap = maxGearStashFor(state);
    if (state.gearStash.length < (cap * 0.9).ceil()) {
      return state;
    }
    return cleanBagJunk(state, unstickBag: true);
  }

  /// Merge junk (optional), then auto-sell for gold, then auto-disassemble
  /// for essence. [unstickBag] keeps only BiS/soulbound/best-per-slot.
  static GameState cleanBagJunk(
    GameState state, {
    bool unstickBag = false,
    bool mergeFirst = true,
  }) {
    var next = state;
    if (mergeFirst) {
      next = autoMergeJunk(next).state;
    }
    next = autoSellJunk(next, unstickBag: unstickBag);
    next = autoDisassembleJunk(next, unstickBag: unstickBag);
    return next;
  }

  static bool _matchesIlvlRarityFilter(
    EquipmentItem item, {
    required int maxIlvl,
    required int maxRarity,
  }) {
    if (maxIlvl <= 0) return false;
    if (item.effectiveItemLevel > maxIlvl) return false;
    if (item.rarity.index > maxRarity.clamp(0, 4)) return false;
    return true;
  }

  static bool _shouldAutoSellOnPickup(GameState state, EquipmentItem item) {
    if (!_matchesIlvlRarityFilter(
      item,
      maxIlvl: state.autoSellMaxPower,
      maxRarity: state.autoSellMaxRarity,
    )) {
      return false;
    }
    return !_shouldKeepInBag(state, item);
  }

  static bool _shouldAutoDisassembleOnPickup(
    GameState state,
    EquipmentItem item,
  ) {
    if (!_matchesIlvlRarityFilter(
      item,
      maxIlvl: state.autoDisassembleMaxIlvl,
      maxRarity: state.autoDisassembleMaxRarity,
    )) {
      return false;
    }
    return !_shouldKeepInBag(state, item);
  }

  /// Keep bag piece if BiS planning would equip it, or it upgrades a worn slot.
  /// Empty slots alone do not keep forever — BiS plan covers meaningful fills.
  static bool _shouldKeepInBag(GameState state, EquipmentItem item) {
    if (item.isApex) return true;
    // Pickup path: candidate is not in stash yet — probe as if stashed so BiS
    // planning can claim it before auto-sell.
    final probe = state.gearStash.any((g) => g.id == item.id)
        ? state
        : state.copyWith(gearStash: [...state.gearStash, item]);
    final plan = planBiSAssignments(probe);
    if (plan.any((p) => p.itemId == item.id)) {
      return true;
    }
    for (final hero in state.heroes) {
      for (final slot in equipTargetsFor(item)) {
        if (!canHeroReceive(hero, item, slot: slot)) {
          continue;
        }
        if (hero.itemIn(slot) == null) {
          continue;
        }
        if (_compareForHeroSlot(
          hero,
          item,
          slot,
          pairingStash: state.gearStash,
        ).isUpgrade) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether [item] should stay when cleaning the bag.
  ///
  /// [mode] `sell` uses gold filters; `disassemble` uses essence filters.
  /// [unstickBag]: keep BiS/soulbound/apex and the strongest piece per slot.
  static bool _shouldKeepWhenCleaning(
    GameState state,
    EquipmentItem item, {
    required bool forSell,
    bool unstickBag = false,
  }) {
    if (unstickBag) {
      if (item.isApex ||
          item.id.contains('soulbound') ||
          item.name.toLowerCase().startsWith('soulbound')) {
        return true;
      }
      final plan = planBiSAssignments(state);
      if (plan.any((p) => p.itemId == item.id)) {
        return true;
      }
      EquipmentItem? best;
      var bestScore = -999999;
      var bestIlvl = -1;
      for (final other in state.gearStash) {
        if (other.slot != item.slot) continue;
        final score = _partySlotScore(state, other);
        final ilvl = other.effectiveItemLevel;
        if (score > bestScore || (score == bestScore && ilvl > bestIlvl)) {
          best = other;
          bestScore = score;
          bestIlvl = ilvl;
        }
      }
      if (best?.id == item.id) return true;
      // Still honor FILTERS — near-full unstick must not dump epics above cap.
      final matches = forSell
          ? _matchesIlvlRarityFilter(
              item,
              maxIlvl: state.autoSellMaxPower,
              maxRarity: state.autoSellMaxRarity,
            )
          : _matchesIlvlRarityFilter(
              item,
              maxIlvl: state.autoDisassembleMaxIlvl,
              maxRarity: state.autoDisassembleMaxRarity,
            );
      if (!matches) return true;
      return false;
    }
    if (_shouldKeepInBag(state, item)) {
      return true;
    }
    final matches = forSell
        ? _matchesIlvlRarityFilter(
            item,
            maxIlvl: state.autoSellMaxPower,
            maxRarity: state.autoSellMaxRarity,
          )
        : _matchesIlvlRarityFilter(
            item,
            maxIlvl: state.autoDisassembleMaxIlvl,
            maxRarity: state.autoDisassembleMaxRarity,
          );
    // Matching filter → eligible to clean (do not keep).
    if (matches) return false;
    // Outside filter: keep rare+ while bag has room; commons may still go in
    // unstick-only passes.
    if (item.rarity.index >= LootRarity.rare.index) {
      return true;
    }
    // Non-matching common/uncommon: keep unless filters are off entirely
    // (manual clean with filters off should not dump everything).
    return true;
  }

  /// Best slotEquipScore for [item] across heroes who can wear it.
  static int _partySlotScore(GameState state, EquipmentItem item) {
    var best = 0;
    for (final hero in state.heroes) {
      for (final slot in equipTargetsFor(item)) {
        if (!canHeroReceive(hero, item, slot: slot)) continue;
        best = max(
          best,
          slotEquipScore(hero, item, slot: slot, pairingStash: state.gearStash),
        );
      }
    }
    return best;
  }

  /// Auto-merge junk pairs in the bag: same slot, neither is a BiS/upgrade keep,
  /// while gold covers [combineCost]. Stronger piece is base; weaker is fuel.
  ///
  /// Returns the updated state and how many merges ran (0 if none possible).
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
        if (_shouldKeepInBag(next, a)) {
          continue;
        }
        for (var j = i + 1; j < next.gearStash.length; j++) {
          final b = next.gearStash[j];
          if (a.slot != b.slot || _shouldKeepInBag(next, b)) {
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

  /// Sell stash junk for **gold** (iLvl + rarity filters; BiS kept).
  static GameState autoSellJunk(GameState state, {bool unstickBag = false}) {
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
        if (!_shouldKeepWhenCleaning(
          probe,
          item,
          forSell: true,
          unstickBag: unstickBag,
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

  /// Disassemble stash junk for **essence** (iLvl + rarity filters; BiS kept).
  static GameState autoDisassembleJunk(
    GameState state, {
    bool unstickBag = false,
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
        if (!_shouldKeepWhenCleaning(
          probe,
          item,
          forSell: false,
          unstickBag: unstickBag,
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

  static GameState sellGearForGold(GameState state, String itemId) {
    final inStash = state.gearStash.any((g) => g.id == itemId);
    if (!inStash) return state;
    final item = findGear(state, itemId);
    if (item == null) return state;
    final value = LootPipeline.equipmentGoldValue(item);
    final next = removeGear(state, itemId);
    return next.copyWith(gold: next.gold + value, lastUpdated: DateTime.now());
  }

  static const int maxLoadouts = 3;

  /// Captures each hero's currently-equipped gear as a named preset.
  /// Replaces an existing loadout with the same [id], otherwise appends
  /// (capped at [maxLoadouts] — oldest is dropped to make room).
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
    if (existingIndex >= 0) {
      next[existingIndex] = loadout;
    } else {
      if (next.length >= maxLoadouts) {
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

  /// Locates [itemId] anywhere it might currently live (any roster hero's
  /// equipped gear, or the stash) and removes it from there.
  static (EquipmentItem?, GameState) _extractItemById(
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

  /// Re-equips a saved [GearLoadout] by id. Items sold/lost since the
  /// loadout was saved are skipped (counted in [skipped]); items that fail a
  /// class proficiency check are returned to the stash.
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
        final extracted = _extractItemById(next, itemId);
        final item = extracted.$1;
        next = extracted.$2;
        // Re-resolve index after roster mutation.
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
          next = stashEquipment(next, item);
          skipped++;
          continue;
        }
        final current = hero.itemIn(slot);
        if (current != null) {
          next = stashEquipment(next, current);
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
