import 'dart:math';

import '../../models/combat_ratings.dart';
import '../../models/equip_stat_weights.dart';
import '../../models/hero.dart';
import '../../models/hero_spec.dart';
import '../../models/loot.dart';
import '../../models/proficiency.dart';
import '../starter_gear.dart';
import 'gear_equip.dart';

/// Budget-honest equip scoring and upgrade predicates (GEAR_BUDGET).
abstract final class GearScorer {
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

  static int slotEquipScore(
    PartyHero hero,
    EquipmentItem? item, {
    required EquipmentSlot slot,
    List<EquipmentItem>? pairingStash,
  }) {
    if (item == null) return 0;
    if (!GearEquip.canHeroReceive(hero, item, slot: slot)) {
      return -999999;
    }
    if (slot == EquipmentSlot.weapon &&
        ClassProficiency.prefersOneHandAndShield(hero.spec) &&
        ClassProficiency.weaponBlocksOffHand(item)) {
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
    } else if (slot == EquipmentSlot.offHand &&
        ClassProficiency.weaponBlocksOffHand(
          hero.itemIn(EquipmentSlot.weapon),
        ) &&
        !ClassProficiency.prefersOneHandAndShield(hero.spec)) {
      score -= specEquipScore(hero, hero.itemIn(EquipmentSlot.weapon)!);
    }
    return score;
  }

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

  static ({EquipmentItem item, int score})? bestPairingOffHand(
    PartyHero hero,
    List<EquipmentItem> stash, {
    String? excludeItemId,
  }) {
    EquipmentItem? bestItem;
    var best = 0;
    for (final raw in stash) {
      if (excludeItemId != null && raw.id == excludeItemId) continue;
      if (!GearEquip.equipTargetsFor(raw).contains(EquipmentSlot.offHand)) {
        continue;
      }
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

  static int specEquipScore(PartyHero hero, EquipmentItem item) {
    return itemBudgetScore(hero, item);
  }

  static int itemBudgetScore(PartyHero hero, EquipmentItem item) {
    final role = _equipScoreRole(hero.spec);
    var score = roleEquipScore(
      role,
      item,
      specId: hero.specId,
      level: hero.level,
      critMul: critScoreMul(hero),
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

  static int roleEquipScore(
    HeroRole role,
    EquipmentItem item, {
    HeroSpecId? specId,
    int level = 60,
    double critMul = 1.0,
  }) {
    final spec = specId != null ? HeroSpecs.def(specId) : null;
    final w = spec != null
        ? EquipStatWeights.forSpec(spec)
        : EquipStatWeights.forRole(role);
    final roleTag = spec?.roleTag;
    assert(level >= 1);
    final critW = critMul.clamp(0.0, 1.0);
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
      GearEffectId.crit =>
        (switch (roleTag ?? _tagForRole(role)) {
                  SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
                    item.effectValue * 4,
                  SpecRoleTag.caster => item.effectValue * 3,
                  SpecRoleTag.healer => item.effectValue * 2,
                  _ => item.effectValue,
                } *
                critW)
            .round(),
      GearEffectId.haste => switch (roleTag ?? _tagForRole(role)) {
        SpecRoleTag.caster => item.effectValue * 3,
        SpecRoleTag.healer => item.effectValue,
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps => item.effectValue * 2,
        _ => item.effectValue,
      },
      GearEffectId.goldFind => item.effectValue,
      GearEffectId.none => 0,
    };
    final core =
        (item.strengthBonus * w.str +
                item.agilityBonus * w.agi +
                item.resolvedStamina * w.sta +
                item.intellectBonus * w.intel +
                item.spiritBonus * w.spi +
                item.spellPowerBonus * w.sp +
                item.resolvedArmor * w.armor +
                item.critChanceBonus * w.crit * critW +
                item.attackSpeedBonus * w.aspd +
                item.moveSpeedBonus * w.move +
                item.mp5Bonus * w.mp5)
            .round() +
        (item.attackBonus * w.flatAtk).round();
    return core + effect;
  }

  static const int critScoreSoftSheet = 70;
  static const int critScoreHardSheet = 75;

  static int sheetCritForEquip(PartyHero hero) {
    return CombatRatings.fromHeroSheet(
      hero: hero,
      gearStrength: hero.gearStrengthBonus,
      gearAgility: hero.gearAgilityBonus,
      gearStamina: hero.gearStaminaBonus,
      gearIntellect: hero.gearIntellectBonus,
      gearSpirit: hero.gearSpiritBonus,
      gearSpellPower: hero.gearSpellPowerBonus,
      gearArmor: hero.gearArmorBonus,
      gearCrit: hero.gearCritChance,
      gearFlatAttack: hero.gearAttackBonus,
    ).critChance;
  }

  static double critScoreMul(PartyHero hero) {
    final sheet = sheetCritForEquip(hero);
    if (sheet < critScoreSoftSheet) return 1;
    if (sheet >= critScoreHardSheet) return 0;
    return (critScoreHardSheet - sheet) /
        (critScoreHardSheet - critScoreSoftSheet);
  }

  static SpecRoleTag _tagForRole(HeroRole role) => switch (role) {
    HeroRole.warrior => SpecRoleTag.meleeDps,
    HeroRole.rogue => SpecRoleTag.meleeDps,
    HeroRole.healer => SpecRoleTag.healer,
    HeroRole.mage => SpecRoleTag.caster,
  };

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
        : GearEquip.equipTargetsFor(candidate);

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
      final cmp = compareForHeroSlot(
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
  compareForHeroSlot(
    PartyHero hero,
    EquipmentItem candidate,
    EquipmentSlot slot, {
    List<EquipmentItem>? pairingStash,
  }) {
    if (!GearEquip.canHeroReceive(hero, candidate, slot: slot)) {
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
    final curAtk = hero.gearSheetAttack;
    final nextEquipped = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
    nextEquipped[slot] = candidate;
    final newAtk = hero.copyWith(equipped: nextEquipped).gearSheetAttack;
    final curDef = current?.resolvedArmor ?? 0;
    final curVit = current?.resolvedStamina ?? 0;
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

  static double roleRelevantStatMass(PartyHero hero, EquipmentItem item) {
    final w = EquipStatWeights.forSpec(hero.spec);
    final critW = critScoreMul(hero);
    return item.strengthBonus * w.str +
        item.agilityBonus * w.agi +
        item.resolvedStamina * w.sta +
        item.intellectBonus * w.intel +
        item.spiritBonus * w.spi +
        item.spellPowerBonus * w.sp +
        item.resolvedArmor * w.armor +
        item.critChanceBonus * w.crit * critW +
        item.attackSpeedBonus * w.aspd +
        item.attackBonus * w.flatAtk;
  }

  static bool emptySlotWorthFilling(
    PartyHero hero,
    EquipmentItem item,
    int score,
  ) {
    final mass = roleRelevantStatMass(hero, item);
    final minIlvl = max(6, (hero.level * 0.55).floor());
    final ilvl = item.effectiveItemLevel;
    final nearLevel = ilvl >= minIlvl - 2;

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

  static bool isMeaningfulEquipUpgrade({
    required PartyHero hero,
    required EquipmentItem item,
    required int curScore,
    required int newScore,
    required bool slotEmpty,
    EquipmentItem? worn,
  }) {
    if (worn != null && worn.isApex && !item.isApex) {
      return false;
    }
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
    final pct = hero.level >= 50 ? 0.04 : 0.03;
    final floor = hero.level >= 50 ? 8 : 6;
    final minDelta = max(floor, (curScore * pct).ceil());
    return delta >= minDelta;
  }
}
