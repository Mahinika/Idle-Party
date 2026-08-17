import 'dart:math';

import 'hero.dart';
import 'stats.dart';

/// Idle-tuned Classic conversion: AP → ATK uses kAp = 4 (Classic uses 14).
///
/// Gear primary ROI must stay aligned with equip BiS weights
/// ([EquipStatWeights] / docs/GEAR_BUDGET.md):
/// - Plate melee: 2 AP per Strength.
/// - Rogue-family (leather/mail AGI): 1 AP per Strength + 2 AP per Agility.
/// - Casters: level Intellect is full ATK; gear Int and Spell Power both
///   contribute ~/3 so they match Str/Agi→ATK ROI. Int still adds spell crit.
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

  /// Dodge-like crumb into sheet DEF.
  ///
  /// Classic's 2 armor per Agi made leather DPS out-armor plate: idle gear
  /// Armor is budget-carved (tens–hundreds) while Agi stacks from every
  /// leather piece plus 2 Agi/level on rogues.
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
    final casterAtk = (intellect + spellPower) ~/ 3;
    return flatAttack + max(meleeAtk, casterAtk);
  }

  /// Percent armor: `taken = raw * K / (def + K)`, K ≈ 1.2× attacker ATK.
  /// High DEF always helps; mitigation caps at 75% (at least 25% of the hit).
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
    // Casters: base Int full; gear Int+SP at ~1/3 — matches Str/Agi→ATK ROI.
    final spPool = intel + gearSpellPower;
    final casterAtk = max(
      1,
      grown.intel + ((gearIntellect + gearSpellPower) ~/ 3),
    );
    final sp = spPool;

    final isCaster =
        hero.gearAffinity == HeroRole.mage ||
        hero.gearAffinity == HeroRole.healer;

    final defense =
        roleBaseArmor(hero.gearAffinity) +
        agilityToDefense(agi) +
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
    final casterWithMeta = casterAtk + metaAttack + auraBonus;
    final spWithMeta = sp + (isCaster ? metaAttack + auraBonus : 0);

    return CombatRatings(
      strength: str,
      agility: agi,
      stamina: sta,
      intellect: intel,
      spirit: spi,
      attackPower: ap,
      physicalAttack: isCaster ? casterWithMeta : physicalWithMeta,
      spellPower: spWithMeta,
      maxHp: maxHpFinal,
      defense: defense,
      critChance: crit,
    );
  }

  int get effectiveAttack => physicalAttack;
}

/// Spirit → mana regen (idle, no 5SR). kSpirit ≈ 0.2.
double spiritManaRegenPerSec(int spirit, {double kSpirit = 0.2}) {
  return ((spirit / 4) + 12.5) / 2 * kSpirit;
}

/// Mp5 gear → mana/s.
double mp5ManaRegenPerSec(int mp5) => mp5 / 5.0;
