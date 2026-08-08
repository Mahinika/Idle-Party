import 'hero.dart';
import 'hero_spec.dart';

/// Combat-aligned stat weights for BiS scoring and loot budget distribution.
///
/// Derived from [CombatRatings]:
/// - Warrior ATK ≈ (2×Str)/4 → Str is the DPS primary
/// - Rogue ATK ≈ (Str+Agi)/4 → Agi also feeds crit/DEF
/// - Caster/healer ATK = Int + SP/2 → Int full, SP half
/// - Spirit / Mp5 → mana regen only (not throughput)
/// - Sta → HP; Armor / Agi → DEF
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
    return switch (spec.roleTag) {
      SpecRoleTag.tank => _tank,
      SpecRoleTag.healer => _healer,
      SpecRoleTag.caster => _caster,
      SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
        _meleeLike(spec.gearAffinity),
    };
  }

  /// Fallback when only a [HeroRole] loot bias is known (no talent tree).
  static EquipStatWeights forRole(HeroRole role) => switch (role) {
        HeroRole.warrior => _warriorDps, // Str-first; tanks pass roleTag
        HeroRole.rogue => _agiDps,
        HeroRole.healer => _healer,
        HeroRole.mage => _caster,
      };

  /// Loot primary budget shares: [str, agi, sta, intel, spi, sp].
  static List<double> lootShares({
    required HeroRole bias,
    SpecRoleTag? roleTag,
  }) {
    if (roleTag != null) {
      return switch (roleTag) {
        SpecRoleTag.tank => const [0.28, 0.12, 0.50, 0.0, 0.05, 0.05],
        SpecRoleTag.healer => const [0.0, 0.04, 0.16, 0.34, 0.12, 0.34],
        SpecRoleTag.caster => const [0.0, 0.04, 0.12, 0.44, 0.08, 0.32],
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
          bias == HeroRole.warrior
              ? const [0.48, 0.12, 0.28, 0.0, 0.06, 0.06]
              : const [0.22, 0.44, 0.22, 0.04, 0.04, 0.04],
      };
    }
    return switch (bias) {
      HeroRole.warrior => const [0.42, 0.12, 0.36, 0.0, 0.05, 0.05],
      HeroRole.rogue => const [0.22, 0.44, 0.22, 0.04, 0.04, 0.04],
      HeroRole.healer => const [0.0, 0.04, 0.16, 0.34, 0.12, 0.34],
      HeroRole.mage => const [0.0, 0.04, 0.12, 0.44, 0.08, 0.32],
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
    agi: 5.0,
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

  /// Agi melee / hunters / feral / enh.
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
}
