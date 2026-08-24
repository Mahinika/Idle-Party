import 'class_ability.dart';
import 'hero_spec.dart';

/// Cataclysm-style specialization mastery (31 specs, conservative magnitudes).
enum SpecMasteryKind {
  strikesOfOpportunity,
  unshackledFury,
  criticalBlock,
  illuminatedHealing,
  divineBulwark,
  handOfLight,
  masterOfBeasts,
  wildQuiver,
  hunterVsWild,
  masterPoisoner,
  mainGauche,
  executioner,
  shieldDiscipline,
  echoOfLight,
  empoweredShadow,
  bloodShield,
  frozenPower,
  dreadblade,
  elementalOverload,
  enhancedElements,
  deepHealing,
  manaAdept,
  ignite,
  frostburn,
  potentAfflictions,
  masterDemonologist,
  flashburn,
  eclipse,
  razorClaws,
  savageDefense,
  harmony,
}

/// Lightweight combat view for mastery hooks (no spatial import).
class MasteryCombatant {
  const MasteryCombatant({
    this.specId,
    this.masteryPoints = 0,
    this.rage = 0,
    this.hp = 1,
    this.maxHp = 1,
    this.rooted = false,
    this.eclipseArcane = false,
    this.eclipseNature = false,
  });

  final HeroSpecId? specId;
  final double masteryPoints;
  final double rage;
  final int hp;
  final int maxHp;
  final bool rooted;
  final bool eclipseArcane;
  final bool eclipseNature;

  double get hpFrac => maxHp <= 0 ? 1.0 : hp / maxHp;

  double get missingHpFrac => (1.0 - hpFrac).clamp(0.0, 1.0);

  double get manaFrac => (rage / 100).clamp(0.0, 1.0);
}

class SpecMastery {
  SpecMastery._();

  static SpecMasteryKind? kindFor(HeroSpecId? id) {
    if (id == null) return null;
    return switch (id) {
      HeroSpecId.arms => SpecMasteryKind.strikesOfOpportunity,
      HeroSpecId.fury => SpecMasteryKind.unshackledFury,
      HeroSpecId.protection => SpecMasteryKind.criticalBlock,
      HeroSpecId.holyPaladin => SpecMasteryKind.illuminatedHealing,
      HeroSpecId.protPaladin => SpecMasteryKind.divineBulwark,
      HeroSpecId.retribution => SpecMasteryKind.handOfLight,
      HeroSpecId.beastMastery => SpecMasteryKind.masterOfBeasts,
      HeroSpecId.marksmanship => SpecMasteryKind.wildQuiver,
      HeroSpecId.survival => SpecMasteryKind.hunterVsWild,
      HeroSpecId.assassination => SpecMasteryKind.masterPoisoner,
      HeroSpecId.combat => SpecMasteryKind.mainGauche,
      HeroSpecId.subtlety => SpecMasteryKind.executioner,
      HeroSpecId.discipline => SpecMasteryKind.shieldDiscipline,
      HeroSpecId.holyPriest => SpecMasteryKind.echoOfLight,
      HeroSpecId.shadow => SpecMasteryKind.empoweredShadow,
      HeroSpecId.blood => SpecMasteryKind.bloodShield,
      HeroSpecId.frostDk => SpecMasteryKind.frozenPower,
      HeroSpecId.unholy => SpecMasteryKind.dreadblade,
      HeroSpecId.elemental => SpecMasteryKind.elementalOverload,
      HeroSpecId.enhancement => SpecMasteryKind.enhancedElements,
      HeroSpecId.restorationShaman => SpecMasteryKind.deepHealing,
      HeroSpecId.arcane => SpecMasteryKind.manaAdept,
      HeroSpecId.fire => SpecMasteryKind.ignite,
      HeroSpecId.frostMage => SpecMasteryKind.frostburn,
      HeroSpecId.affliction => SpecMasteryKind.potentAfflictions,
      HeroSpecId.demonology => SpecMasteryKind.masterDemonologist,
      HeroSpecId.destruction => SpecMasteryKind.flashburn,
      HeroSpecId.balance => SpecMasteryKind.eclipse,
      HeroSpecId.feral => SpecMasteryKind.razorClaws,
      HeroSpecId.guardian => SpecMasteryKind.savageDefense,
      HeroSpecId.restorationDruid => SpecMasteryKind.harmony,
    };
  }

  /// Rating → mastery points (Cata-like curve, idle-tuned).
  static double masteryPointsFrom(int rating, int level) {
    if (rating <= 0) return 0;
    final lvl = level.clamp(1, 100);
    return rating / (90.0 + lvl * 4.0);
  }

  static double _pt(MasteryCombatant hero) => hero.masteryPoints;

  /// Passive block chance for Prot Warr / Prot Pala (before Shield Block CD).
  static double blockChance(MasteryCombatant hero) {
    final kind = kindFor(hero.specId);
    return switch (kind) {
      SpecMasteryKind.criticalBlock =>
        (0.06 + _pt(hero) * 0.008).clamp(0.0, 0.32),
      SpecMasteryKind.divineBulwark =>
        (0.05 + _pt(hero) * 0.007).clamp(0.0, 0.28),
      _ => 0.0,
    };
  }

  /// Outgoing damage multiplier from mastery (shape, not raw ATK inflation).
  static double damageMul(
    MasteryCombatant hero,
    ClassAbilityDef def,
    MasteryCombatant target,
  ) {
    final kind = kindFor(hero.specId);
    final p = _pt(hero);
    if (kind == null || p <= 0) return 1.0;

    var mul = 1.0 + p * 0.002;

    switch (kind) {
      case SpecMasteryKind.handOfLight:
        if (_isHolyStrike(def)) mul += p * 0.006;
      case SpecMasteryKind.frozenPower:
      case SpecMasteryKind.frostburn:
        if (target.rooted) mul += 0.08 + p * 0.004;
      case SpecMasteryKind.executioner:
        if (target.hpFrac < 0.35) mul += 0.06 + p * 0.005;
      case SpecMasteryKind.manaAdept:
        mul += hero.manaFrac * (0.04 + p * 0.003);
      case SpecMasteryKind.flashburn:
        if (!_isDotAbility(def)) mul += 0.04 + p * 0.004;
      case SpecMasteryKind.enhancedElements:
        if (_isElementalAbility(def)) mul += 0.05 + p * 0.004;
      case SpecMasteryKind.eclipse:
        if (hero.eclipseArcane && _isArcaneAbility(def)) {
          mul += 0.06 + p * 0.004;
        } else if (hero.eclipseNature && _isNatureAbility(def)) {
          mul += 0.06 + p * 0.004;
        }
      case SpecMasteryKind.masterOfBeasts:
        if (def.id == AbilityId.killCommand) mul += 0.05 + p * 0.004;
      case SpecMasteryKind.masterDemonologist:
        if (def.id == AbilityId.handOfGuldan || def.id == AbilityId.shadowBolt) {
          mul += 0.04 + p * 0.004;
        }
      case SpecMasteryKind.unshackledFury:
        if (hero.rage >= 80) mul += 0.04 + p * 0.003;
      default:
        break;
    }
    return mul.clamp(0.85, 1.35);
  }

  /// Direct heal multiplier; Deep Healing scales with target missing HP.
  static double healMul(MasteryCombatant hero, double targetMissingPct) {
    final kind = kindFor(hero.specId);
    final p = _pt(hero);
    if (kind == null) return 1.0;

    var mul = 1.0 + p * 0.004;
    switch (kind) {
      case SpecMasteryKind.deepHealing:
        mul += targetMissingPct.clamp(0.0, 1.0) * (0.12 + p * 0.006);
      case SpecMasteryKind.harmony:
        mul += 0.03 + p * 0.003;
      case SpecMasteryKind.illuminatedHealing:
      case SpecMasteryKind.echoOfLight:
        mul += 0.02 + p * 0.003;
      default:
        break;
    }
    return mul.clamp(0.9, 1.4);
  }

  /// Periodic damage tick amplifier (Fire / Shadow / Affliction / Feral bleeds).
  static double dotTickMul(MasteryCombatant hero) {
    final kind = kindFor(hero.specId);
    final p = _pt(hero);
    if (kind == null) return 1.0;

    return switch (kind) {
      SpecMasteryKind.ignite ||
      SpecMasteryKind.empoweredShadow ||
      SpecMasteryKind.potentAfflictions ||
      SpecMasteryKind.dreadblade ||
      SpecMasteryKind.masterPoisoner ||
      SpecMasteryKind.razorClaws =>
        (1.0 + 0.02 + p * 0.004).clamp(1.0, 1.22),
      _ => (1.0 + p * 0.002).clamp(1.0, 1.12),
    };
  }

  /// Arms Strikes of Opportunity — extra white swing proc chance.
  static double extraSwingProcChance(MasteryCombatant hero) {
    if (hero.specId != HeroSpecId.arms) return 0;
    return (0.04 + _pt(hero) * 0.006).clamp(0.0, 0.18);
  }

  /// Marksmanship Wild Quiver — bonus auto shot proc.
  static double extraAutoShotProcChance(MasteryCombatant hero) {
    if (hero.specId != HeroSpecId.marksmanship) return 0;
    return (0.05 + _pt(hero) * 0.006).clamp(0.0, 0.2);
  }

  /// Combat Main Gauche — off-hand strike proc on main-hand.
  static double mainGaucheProcChance(MasteryCombatant hero) {
    if (hero.specId != HeroSpecId.combat) return 0;
    return (0.04 + _pt(hero) * 0.005).clamp(0.0, 0.16);
  }

  /// Absorb strength from Disc / Blood mastery (fraction of heal/absorb).
  static double absorbStrengthMul(MasteryCombatant hero) {
    final kind = kindFor(hero.specId);
    final p = _pt(hero);
    return switch (kind) {
      SpecMasteryKind.shieldDiscipline => 1.0 + 0.06 + p * 0.005,
      SpecMasteryKind.bloodShield => 1.0 + 0.05 + p * 0.004,
      SpecMasteryKind.savageDefense => 1.0 + 0.04 + p * 0.004,
      _ => 1.0,
    };
  }

  static bool _isHolyStrike(ClassAbilityDef def) {
    final k = _abilityKey(def);
    return k.contains('crusader') ||
        k.contains('divine storm') ||
        k.contains('templar') ||
        def.id == AbilityId.divineStorm ||
        def.id == AbilityId.crusaderStrike;
  }

  static bool _isDotAbility(ClassAbilityDef def) {
    return def.gate.maintainDot ||
        def.id == AbilityId.livingBomb ||
        def.id == AbilityId.immolateDemo ||
        def.id == AbilityId.immolateDestro ||
        def.id == AbilityId.corruption ||
        def.id == AbilityId.garrote ||
        def.id == AbilityId.rip ||
        def.id == AbilityId.rake;
  }

  static bool _isElementalAbility(ClassAbilityDef def) {
    final style = def.boltStyle;
    return style != null &&
        (style.name.contains('fire') ||
            style.name.contains('frost') ||
            style.name.contains('lightning') ||
            style.name.contains('nature'));
  }

  static bool _isArcaneAbility(ClassAbilityDef def) {
    return def.id == AbilityId.arcaneBlast ||
        def.id == AbilityId.arcaneMissiles ||
        def.boltStyle?.name.contains('arcane') == true;
  }

  static bool _isNatureAbility(ClassAbilityDef def) {
    return def.boltStyle?.name.contains('nature') == true ||
        def.id == AbilityId.wrath ||
        def.id == AbilityId.starfire;
  }

  static String _abilityKey(ClassAbilityDef def) =>
      '${def.id.name} ${def.shortLabel} ${def.name}'.toLowerCase();
}
