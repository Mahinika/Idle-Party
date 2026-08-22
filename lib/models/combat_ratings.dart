import 'dart:math';

import '../spatial/combat_avoidance.dart';
import 'hero.dart';
import 'spec_mastery.dart';
import 'stats.dart';

/// Idle-tuned Classic conversion: AP → ATK uses kAp = 4 (Classic uses 14).
///
/// Cataclysm v2: separate physicalAttack / spellPower; mastery + dodge/parry on
/// sheet. Gear primary ROI stays aligned with equip BiS weights
/// ([EquipStatWeights] / docs/GEAR_BUDGET.md).
class CombatRatings {
  const CombatRatings({
    required this.strength,
    required this.agility,
    required this.stamina,
    required this.intellect,
    required this.spirit,
    required this.attackPower,
    required this.physicalAttack,
    required this.spellPower,
    required this.maxHp,
    required this.defense,
    required this.critChance,
    this.masteryRating = 0,
    this.masteryPoints = 0,
    this.dodgePercent = 0,
    this.parryPercent = 0,
  });

  final int strength;
  final int agility;
  final int stamina;
  final int intellect;
  final int spirit;
  final int attackPower;
  final int physicalAttack;
  final int spellPower;
  final int maxHp;
  final int defense;
  final int critChance;
  final int masteryRating;
  final double masteryPoints;
  final double dodgePercent;
  final double parryPercent;

  static const int kAp = 4;

  static int roleHpBase(HeroRole role) => switch (role) {
    HeroRole.warrior => 28,
    HeroRole.healer => 16,
    HeroRole.mage => 12,
    HeroRole.rogue => 14,
  };

  static int roleBaseArmor(HeroRole role) => switch (role) {
    HeroRole.warrior => 6,
    HeroRole.rogue => 3,
    HeroRole.healer => 1,
    HeroRole.mage => 1,
  };

  static int roleBaseCrit(HeroRole role) => role == HeroRole.rogue ? 12 : 5;

  /// Dodge-like crumb into sheet DEF (non-tanks only — tanks use dodge %).
  static int agilityToDefense(int agility) => max(0, agility) ~/ 8;

  /// Per-level primary gains (on top of base [Stats]).
  static ({int str, int agi, int sta, int intel, int spi}) levelGains(
    HeroRole role,
  ) => switch (role) {
    HeroRole.warrior => (str: 2, agi: 1, sta: 2, intel: 0, spi: 0),
    HeroRole.healer => (str: 0, agi: 0, sta: 1, intel: 2, spi: 2),
    HeroRole.mage => (str: 0, agi: 0, sta: 1, intel: 2, spi: 1),
    HeroRole.rogue => (str: 1, agi: 2, sta: 1, intel: 0, spi: 0),
  };

  static double critDivisor(HeroRole role, int level) {
    final base = switch (role) {
      HeroRole.warrior => 20.0,
      HeroRole.rogue => 29.0,
      HeroRole.healer => 59.2,
      HeroRole.mage => 59.5,
    };
    final lvl = level.clamp(1, 60);
    return base * (0.5 + 0.5 * lvl / 60);
  }

  static double spellCritDivisor(HeroRole role, int level) {
    final base = switch (role) {
      HeroRole.healer => 59.2,
      HeroRole.mage => 59.5,
      _ => 60.0,
    };
    final lvl = level.clamp(1, 60);
    return base * (0.5 + 0.5 * lvl / 60);
  }

  /// Totals from base sheet + level growth (no gear/meta).
  static ({int str, int agi, int sta, int intel, int spi}) grownPrimaries({
    required Stats base,
    required HeroRole role,
    required int level,
  }) {
    final g = levelGains(role);
    final levels = max(0, level - 1);
    return (
      str: base.strength + g.str * levels,
      agi: base.agility + g.agi * levels,
      sta: base.stamina + g.sta * levels,
      intel: base.intellect + g.intel * levels,
      spi: base.spirit + g.spi * levels,
    );
  }

  static int meleeAttackPower({
    required HeroRole role,
    required int strength,
    required int agility,
    required int level,
  }) {
    return switch (role) {
      HeroRole.warrior => 2 * strength + 3 * level,
      HeroRole.rogue => strength + 2 * agility + 2 * level,
      HeroRole.healer || HeroRole.mage => strength,
    };
  }

  /// Item → party ATK (soulbound / compare). Best of plate, AGI-family, caster.
  static int itemAttackContribution({
    required int strength,
    required int agility,
    required int intellect,
    required int spellPower,
    int flatAttack = 0,
  }) {
    final warriorAp = 2 * strength;
    final rogueAp = strength + 2 * agility;
    final meleeAtk = max(0, (max(warriorAp, rogueAp) / kAp).round());
    final casterAtk = intellect + spellPower;
    return flatAttack + max(meleeAtk, casterAtk);
  }

  /// Percent armor: `taken = raw * K / (def + K)`, K ≈ 1.2× attacker ATK.
  static int mitigateByArmor({
    required int rawDamage,
    required int defense,
    required int attackerAttack,
  }) {
    final hit = max(1, rawDamage);
    final def = max(0, defense);
    final k = max(8, (max(1, attackerAttack) * 12 + 5) ~/ 10);
    final taken = (hit * k / (def + k)).round();
    final floor = max(1, (hit * 25 + 99) ~/ 100);
    return max(floor, taken);
  }

  factory CombatRatings.fromHeroSheet({
    required PartyHero hero,
    int gearStrength = 0,
    int gearAgility = 0,
    int gearStamina = 0,
    int gearIntellect = 0,
    int gearSpirit = 0,
    int gearSpellPower = 0,
    int gearMasteryRating = 0,
    int gearArmor = 0,
    int gearCrit = 0,
    int gearFlatAttack = 0,
    int metaAttack = 0,
    int metaDefense = 0,
    int metaVitality = 0,
    int guardBonus = 0,
    int auraBonus = 0,
  }) {
    final grown = grownPrimaries(
      base: hero.stats,
      role: hero.gearAffinity,
      level: hero.level,
    );
    final str = grown.str + gearStrength;
    final agi = grown.agi + gearAgility;
    final sta = grown.sta + gearStamina;
    final intel = grown.intel + gearIntellect;
    final spi = grown.spi + gearSpirit;

    final ap = meleeAttackPower(
      role: hero.gearAffinity,
      strength: str,
      agility: agi,
      level: hero.level,
    );
    final physical = max(1, (ap / kAp).round()) + gearFlatAttack;

    final isCaster =
        hero.gearAffinity == HeroRole.mage ||
        hero.gearAffinity == HeroRole.healer;
    final isTank = hero.spec.isTank;

    // Cata direction: level Int is full SP; gear Int+SP use ~/3 ROI (GEAR_BUDGET fairness).
    final sp = isCaster
        ? max(1, grown.intel + ((gearIntellect + gearSpellPower) ~/ 3))
        : intel + gearSpellPower;

    final defense =
        roleBaseArmor(hero.gearAffinity) +
        (isTank ? 0 : agilityToDefense(agi)) +
        gearArmor +
        metaDefense +
        guardBonus;

    final maxHpFinal = roleHpBase(hero.gearAffinity) + 10 * sta + metaVitality;

    final crit = isCaster
        ? (5 +
                  intel / spellCritDivisor(hero.gearAffinity, hero.level) +
                  gearCrit)
              .round()
        : (roleBaseCrit(hero.gearAffinity) +
                  agi / critDivisor(hero.gearAffinity, hero.level) +
                  gearCrit)
              .round();

    final physicalWithMeta = physical + metaAttack + auraBonus;
    final spWithMeta = isCaster ? sp + metaAttack + auraBonus : sp;

    final masteryRating = max(0, gearMasteryRating);
    final masteryPoints = SpecMastery.masteryPointsFrom(
      masteryRating,
      hero.level,
    );
    final avoid = CombatAvoidance.sheetAvoidance(
      agility: agi,
      masteryRating: masteryRating,
      level: hero.level,
      isTank: isTank,
    );

    return CombatRatings(
      strength: str,
      agility: agi,
      stamina: sta,
      intellect: intel,
      spirit: spi,
      attackPower: ap,
      physicalAttack: physicalWithMeta,
      spellPower: spWithMeta,
      maxHp: maxHpFinal,
      defense: defense,
      critChance: crit,
      masteryRating: masteryRating,
      masteryPoints: masteryPoints,
      dodgePercent: avoid.dodgePercent,
      parryPercent: avoid.parryPercent,
    );
  }

  /// Role-appropriate primary attack (melee AP or caster SP).
  int get effectiveAttack => max(physicalAttack, spellPower);

  /// Optional timed POWERUPS (+ATK%). HP/DEF/crit stay the same.
  CombatRatings withAttackPercent(int percent) {
    if (percent <= 0) return this;
    return CombatRatings(
      strength: strength,
      agility: agility,
      stamina: stamina,
      intellect: intellect,
      spirit: spirit,
      attackPower: attackPower,
      physicalAttack: physicalAttack + (physicalAttack * percent) ~/ 100,
      spellPower: spellPower + (spellPower * percent) ~/ 100,
      maxHp: maxHp,
      defense: defense,
      critChance: critChance,
      masteryRating: masteryRating,
      masteryPoints: masteryPoints,
      dodgePercent: dodgePercent,
      parryPercent: parryPercent,
    );
  }
}

/// Spirit → mana regen. Optional 5-second rule when [inCombat] and recently damaged.
double spiritManaRegenPerSec(
  int spirit, {
  double perSpirit = 0.06,
  bool inCombat = false,
  bool recentlyDamaged = false,
}) {
  var regen = 1.25 + max(0, spirit) * perSpirit;
  if (inCombat && recentlyDamaged) {
    regen *= 0.15;
  } else if (inCombat) {
    regen *= 0.55;
  }
  return regen;
}

/// Mp5 gear → mana/s.
double mp5ManaRegenPerSec(int mp5) => mp5 / 5.0;
