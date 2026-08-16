import 'hero.dart';
import 'hero_spec.dart';

/// Combat-aligned stat weights for BiS scoring and loot budget distribution.
///
/// Derived from [CombatRatings]:
/// - Warrior ATK ≈ (2×Str)/4 → Str is the DPS primary
/// - Rogue ATK ≈ (Str+Agi)/4 → Agi also feeds crit/DEF
/// - Caster/healer ATK = Int + SP/2 → Int full, SP half
/// - Spirit / Mp5 → mana regen only (not throughput)
/// - Sta → HP; gear Armor is sheet DEF; Agi is a small dodge crumb
///   ([CombatRatings.agilityToDefense]) so plate tanks stay ahead of leather DPS.
class EquipStatWeights {
  const EquipStatWeights({
    required this.str,
    required this.agi,
    required this.sta,
    required this.intel,
    required this.spi,
    required this.sp,
    required this.armor,
    required this.crit,
    required this.aspd,
    required this.move,
    required this.mp5,
    required this.flatAtk,
  });

  final double str;
  final double agi;
  final double sta;
  final double intel;
  final double spi;
  final double sp;
  final double armor;
  final double crit;
  final double aspd;
  final double move;
  final double mp5;
  final double flatAtk;

  /// Weights used by Auto Equip / BiS (`roleEquipScore`).
  static EquipStatWeights forSpec(HeroSpecDef spec) {
    // Spec overrides first — same affinity buckets still share most DNA.
    switch (spec.id) {
      case HeroSpecId.enhancement:
        return _enhancement;
      case HeroSpecId.beastMastery:
      case HeroSpecId.marksmanship:
      case HeroSpecId.survival:
        return _hunter;
      case HeroSpecId.shadow:
        return _shadow;
      case HeroSpecId.affliction:
        return _affliction;
      case HeroSpecId.blood:
        return _bloodTank;
      case HeroSpecId.discipline:
        return _disc;
      case HeroSpecId.feral:
        return _feral;
      default:
        break;
    }
    return switch (spec.roleTag) {
      SpecRoleTag.tank => _tank,
      SpecRoleTag.healer => _healer,
      SpecRoleTag.caster => _caster,
      SpecRoleTag.meleeDps ||
      SpecRoleTag.rangedDps => _meleeLike(spec.gearAffinity),
    };
  }

  /// Fallback when only a [HeroRole] loot bias is known (no talent tree).
  static EquipStatWeights forRole(HeroRole role) => switch (role) {
    HeroRole.warrior => _warriorDps, // Str-first; tanks pass roleTag
    HeroRole.rogue => _agiDps,
    HeroRole.healer => _healer,
    HeroRole.mage => _caster,
  };

  /// Top primary/secondary labels for tooltips (highest weights first).
  static List<String> priorityLabels(HeroSpecDef spec, {int max = 3}) {
    final w = forSpec(spec);
    final ranked = <({String name, double w})>[
      (name: 'Strength', w: w.str),
      (name: 'Agility', w: w.agi),
      (name: 'Stamina', w: w.sta),
      (name: 'Intellect', w: w.intel),
      (name: 'Spirit', w: w.spi),
      (name: 'Spell Power', w: w.sp),
      (name: 'Armor', w: w.armor),
      (name: 'Crit', w: w.crit),
      (name: 'Haste', w: w.aspd),
      (name: 'Mp5', w: w.mp5),
    ]..sort((a, b) => b.w.compareTo(a.w));
    return [
      for (final e in ranked)
        if (e.w >= 3.0) e.name,
    ].take(max).toList(growable: false);
  }

  /// One-line player pitch for tooltips.
  static String priorityBlurb(HeroSpecDef spec) {
    final labels = priorityLabels(spec);
    if (labels.isEmpty) return 'For ${spec.shortLabel}: balanced stats';
    return 'For ${spec.shortLabel}: ${labels.join(' · ')}';
  }

  /// Loot **primary** budget shares: [str, agi, sta, intel, spi, sp].
  ///
  /// WotLK-shaped and phone-readable (docs/GEAR_BUDGET.md): one power primary
  /// + Stamina (casters also Spell Power; healers also Spirit). No crumb stats.
  /// Affinity on rolled items is drop bias / tooltip flavour — not BiS score.
  static List<double> lootShares({
    required HeroRole bias,
    SpecRoleTag? roleTag,
    HeroSpecId? specId,
  }) {
    if (specId != null) {
      switch (specId) {
        case HeroSpecId.enhancement:
          // Hybrid mail: Agi lead + Str + Sta.
          return const [0.38, 0.40, 0.22, 0.0, 0.0, 0.0];
        case HeroSpecId.beastMastery:
        case HeroSpecId.marksmanship:
        case HeroSpecId.survival:
          return const [0.14, 0.60, 0.26, 0.0, 0.0, 0.0];
        case HeroSpecId.shadow:
        case HeroSpecId.affliction:
          return const [0.0, 0.0, 0.26, 0.48, 0.08, 0.18];
        case HeroSpecId.blood:
          return const [0.30, 0.0, 0.70, 0.0, 0.0, 0.0];
        default:
          break;
      }
    }
    if (roleTag != null) {
      return switch (roleTag) {
        SpecRoleTag.tank => const [0.34, 0.0, 0.66, 0.0, 0.0, 0.0],
        SpecRoleTag.healer => const [0.0, 0.0, 0.26, 0.40, 0.18, 0.16],
        SpecRoleTag.caster => const [0.0, 0.0, 0.28, 0.50, 0.0, 0.22],
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
          bias == HeroRole.warrior
              ? const [0.72, 0.0, 0.28, 0.0, 0.0, 0.0]
              : const [0.18, 0.58, 0.24, 0.0, 0.0, 0.0],
      };
    }
    return switch (bias) {
      HeroRole.warrior => const [0.68, 0.0, 0.32, 0.0, 0.0, 0.0],
      HeroRole.rogue => const [0.18, 0.58, 0.24, 0.0, 0.0, 0.0],
      HeroRole.healer => const [0.0, 0.0, 0.26, 0.40, 0.18, 0.16],
      HeroRole.mage => const [0.0, 0.0, 0.28, 0.50, 0.0, 0.22],
    };
  }

  static EquipStatWeights _meleeLike(HeroRole affinity) {
    if (affinity == HeroRole.mage || affinity == HeroRole.healer) {
      return _caster;
    }
    if (affinity == HeroRole.warrior) return _warriorDps;
    return _agiDps;
  }

  /// Survives packs: Sta / Armor first, then Str for threat / chip.
  static const _tank = EquipStatWeights(
    str: 6.5,
    agi: 1.5,
    sta: 10.0,
    intel: 0.5,
    spi: 1.0,
    sp: 0.5,
    armor: 9.5,
    crit: 2.0,
    aspd: 1.5,
    move: 1.0,
    mp5: 0.5,
    flatAtk: 2.0,
  );

  /// Blood leans self-heal threat — a touch more Str than generic tank.
  static const _bloodTank = EquipStatWeights(
    str: 7.5,
    agi: 1.5,
    sta: 10.0,
    intel: 0.5,
    spi: 1.0,
    sp: 0.5,
    armor: 9.0,
    crit: 2.5,
    aspd: 1.5,
    move: 1.0,
    mp5: 0.5,
    flatAtk: 2.5,
  );

  /// Plate/mail Str melee (Arms, Fury, Ret, Frost/Unholy DK).
  static const _warriorDps = EquipStatWeights(
    str: 10.0,
    agi: 4.0,
    sta: 3.5,
    intel: 0,
    spi: 0.5,
    sp: 0,
    armor: 2.5,
    crit: 5.0,
    aspd: 4.5,
    move: 2.0,
    mp5: 0,
    flatAtk: 2.5,
  );

  /// Agi melee / feral baseline.
  static const _agiDps = EquipStatWeights(
    str: 7.0,
    agi: 10.0,
    sta: 3.5,
    intel: 0.5,
    spi: 0.5,
    sp: 0.5,
    armor: 2.0,
    crit: 7.0,
    aspd: 5.5,
    move: 3.0,
    mp5: 0,
    flatAtk: 2.0,
  );

  /// Enh: dual-wield hybrid — Agi lead but Str still matters.
  static const _enhancement = EquipStatWeights(
    str: 8.5,
    agi: 9.5,
    sta: 3.5,
    intel: 0.5,
    spi: 0.5,
    sp: 0.5,
    armor: 2.5,
    crit: 6.5,
    aspd: 5.5,
    move: 2.5,
    mp5: 0,
    flatAtk: 2.0,
  );

  /// Hunters: pure ranged Agi — Str is filler.
  static const _hunter = EquipStatWeights(
    str: 4.0,
    agi: 11.0,
    sta: 3.5,
    intel: 0,
    spi: 0.5,
    sp: 0,
    armor: 1.5,
    crit: 7.5,
    aspd: 5.0,
    move: 2.5,
    mp5: 0,
    flatAtk: 1.5,
  );

  /// Cat: crit window fantasy.
  static const _feral = EquipStatWeights(
    str: 6.5,
    agi: 10.5,
    sta: 3.5,
    intel: 0.5,
    spi: 0.5,
    sp: 0.5,
    armor: 2.0,
    crit: 8.0,
    aspd: 5.5,
    move: 3.5,
    mp5: 0,
    flatAtk: 2.0,
  );

  /// Int full ATK, SP half — score matches CombatRatings caster path.
  static const _caster = EquipStatWeights(
    str: 0,
    agi: 1.0,
    sta: 3.0,
    intel: 10.0,
    spi: 3.0,
    sp: 5.0,
    armor: 0.5,
    crit: 8.0,
    aspd: 4.0,
    move: 1.0,
    mp5: 2.5,
    flatAtk: 0,
  );

  /// Shadow: crit/haste lean; Spirit helps DoT mana more than pure Fire.
  static const _shadow = EquipStatWeights(
    str: 0,
    agi: 1.0,
    sta: 3.0,
    intel: 10.0,
    spi: 4.0,
    sp: 4.5,
    armor: 0.5,
    crit: 8.5,
    aspd: 5.0,
    move: 1.0,
    mp5: 3.0,
    flatAtk: 0,
  );

  /// Affliction: sustain DoTs — Spi/Mp5 a bit above nuke casters.
  static const _affliction = EquipStatWeights(
    str: 0,
    agi: 1.0,
    sta: 3.0,
    intel: 10.0,
    spi: 4.5,
    sp: 4.5,
    armor: 0.5,
    crit: 7.5,
    aspd: 4.5,
    move: 1.0,
    mp5: 3.5,
    flatAtk: 0,
  );

  /// Heal throughput uses same ATK pool as casters; Spi/Mp5 are regen only.
  static const _healer = EquipStatWeights(
    str: 0,
    agi: 1.0,
    sta: 3.5,
    intel: 10.0,
    spi: 3.5,
    sp: 5.5,
    armor: 1.0,
    crit: 4.0,
    aspd: 3.5,
    move: 1.0,
    mp5: 5.0,
    flatAtk: 0,
  );

  /// Disc: slight crit for absorb/penance fantasy; still Mp5-heavy.
  static const _disc = EquipStatWeights(
    str: 0,
    agi: 1.0,
    sta: 3.5,
    intel: 10.0,
    spi: 3.0,
    sp: 5.5,
    armor: 1.0,
    crit: 5.5,
    aspd: 3.5,
    move: 1.0,
    mp5: 5.0,
    flatAtk: 0,
  );
}
