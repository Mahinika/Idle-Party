import 'class_ability.dart';
import 'combat_ratings.dart';
import 'gear_set.dart';
import 'hero_spec.dart';
import 'loot.dart';
import 'stats.dart';

/// Gear / combat-ratings affinity bucket (NOT party role).
///
/// Use [SpecRoleTag] / [HeroSpecDef.isTank] / [HeroSpecDef.isHealer] for
/// tank/healer/DPS identity. These four values are leftover “family” buckets
/// for ratings, paper-doll, and ability tickers:
/// `warrior` ≈ plate/melee, `rogue` ≈ phys DPS, `mage` ≈ caster, `healer` ≈ heal.
enum HeroRole { warrior, healer, mage, rogue }

class PartyHero {
  const PartyHero({
    required this.id,
    required this.name,
    required this.level,
    required this.currentHp,
    required this.stats,
    required this.specId,
    this.equipped = const <EquipmentSlot, EquipmentItem>{},
    this.xp = 0,
  });

  factory PartyHero.starting({
    required String name,
    required HeroSpecId specId,
    String? id,
    Stats? stats,
    Map<EquipmentSlot, EquipmentItem>? equipped,
    int level = 1,
  }) {
    final startLevel = level < 1 ? 1 : level;
    final def = HeroSpecs.def(specId);
    final sheetStats = stats ?? def.startingStats;
    final affinity = def.gearAffinity;
    final sheet = CombatRatings.grownPrimaries(
      base: sheetStats,
      role: affinity,
      level: startLevel,
    );
    final hp = CombatRatings.roleHpBase(affinity) + 10 * sheet.sta;
    return PartyHero(
      id: id ?? _stableIdFor(specId, name),
      name: name,
      level: startLevel,
      currentHp: hp,
      stats: sheetStats,
      specId: specId,
      equipped: equipped ?? const <EquipmentSlot, EquipmentItem>{},
      xp: 0,
    );
  }

  static String _stableIdFor(HeroSpecId specId, String name) =>
      '${specId.name}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

  static HeroRole roleForName(String name) => switch (name) {
    'Aegis' => HeroRole.warrior,
    'Vale' => HeroRole.healer,
    'Ember' => HeroRole.mage,
    _ => HeroRole.rogue,
  };

  static HeroSpecId specForName(String name) => switch (name) {
    'Aegis' => HeroSpecId.protection,
    'Vale' => HeroSpecId.discipline,
    'Ember' => HeroSpecId.fire,
    'Shade' => HeroSpecId.combat,
    _ => HeroSpecId.combat,
  };

  /// Locked starting primary sheets from the Classic stats plan.
  static Stats startingStatsFor(HeroRole role) =>
      HeroSpecs.def(HeroSpecs.fromGearAffinity(role)).startingStats;

  static Stats startingStatsForSpec(HeroSpecId specId) =>
      HeroSpecs.def(specId).startingStats;

  final String id;
  final String name;
  final int level;
  final int currentHp;
  final Stats stats;
  final HeroSpecId specId;
  final Map<EquipmentSlot, EquipmentItem> equipped;
  final int xp;

  HeroSpecDef get spec => HeroSpecs.def(specId);

  /// Gear/ratings affinity bucket — not tank/healer/DPS. Prefer [spec.roleTag].
  HeroRole get gearAffinity => spec.gearAffinity;

  /// Deprecated alias for [gearAffinity]. Do not use for tank checks.
  @Deprecated('Use gearAffinity, or spec.roleTag / isTank / isHealer')
  HeroRole get role => gearAffinity;

  ({int str, int agi, int sta, int intel, int spi}) get grownPrimaries =>
      CombatRatings.grownPrimaries(
        base: stats,
        role: gearAffinity,
        level: level,
      );

  /// Base attack without gear/meta (AP/4 or Int for casters).
  int get attack {
    final g = grownPrimaries;
    if (gearAffinity == HeroRole.mage || gearAffinity == HeroRole.healer) {
      return g.intel;
    }
    final ap = CombatRatings.meleeAttackPower(
      role: gearAffinity,
      strength: g.str,
      agility: g.agi,
      level: level,
    );
    return (ap / CombatRatings.kAp).round().clamp(1, 99999);
  }

  int get defense {
    final g = grownPrimaries;
    return CombatRatings.roleBaseArmor(gearAffinity) +
        CombatRatings.agilityToDefense(g.agi);
  }

  int get maxHp {
    final g = grownPrimaries;
    return CombatRatings.roleHpBase(gearAffinity) + 10 * g.sta;
  }

  bool get isAlive => currentHp > 0;

  int get gearStrengthBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.strengthBonus);
  int get gearAgilityBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.agilityBonus);
  int get gearStaminaBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.resolvedStamina) +
      GearSets.setStaminaBonus(equipped);
  int get gearIntellectBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.intellectBonus);
  int get gearSpiritBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.spiritBonus) +
      GearSets.setSpiritBonus(equipped) +
      GearSets.setRoleSpiritBonus(equipped, gearAffinity);
  int get gearSpellPowerBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.spellPowerBonus) +
      GearSets.setSpellPowerBonus(equipped) +
      GearSets.setRoleSpellPowerBonus(equipped, gearAffinity);
  int get gearArmorBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.resolvedArmor) +
      GearSets.setRoleArmorBonus(equipped, gearAffinity);
  int get gearMp5Bonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.mp5Bonus);

  int get gearAttackBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.attackBonus);

  /// Sheet ATK from this hero's gear only (no party Forge/AL/soulbound).
  int get gearSheetAttack => CombatRatings.fromHeroSheet(
    hero: this,
    gearStrength: gearStrengthBonus,
    gearAgility: gearAgilityBonus,
    gearStamina: gearStaminaBonus,
    gearIntellect: gearIntellectBonus,
    gearSpirit: gearSpiritBonus,
    gearSpellPower: gearSpellPowerBonus,
    gearArmor: gearArmorBonus,
    gearCrit: gearCritChance,
    gearFlatAttack: gearAttackBonus,
  ).effectiveAttack;

  int get gearDefenseBonus => gearArmorBonus;

  int get gearVitalityBonus => gearStaminaBonus * 10;

  int get gearCritChance {
    final raw =
        equipped.values.fold<int>(
          0,
          (s, i) =>
              s +
              i.critChanceBonus +
              (i.effectId == GearEffectId.crit ? i.effectValue : 0),
        ) +
        GearSets.setCritBonus(equipped);
    return _softCapStat(raw, soft: 18, hard: 40);
  }

  int get gearAttackSpeedBonus {
    final raw =
        equipped.values.fold<int>(
          0,
          (s, i) =>
              s +
              i.attackSpeedBonus +
              (i.effectId == GearEffectId.haste ? i.effectValue : 0),
        ) +
        GearSets.setRoleHasteBonus(equipped, gearAffinity);
    return _softCapStat(raw, soft: 22, hard: 50);
  }

  int get gearMoveSpeedBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.moveSpeedBonus);

  int get gearLifestealPercent {
    final raw = equipped.values.fold<int>(0, (s, i) {
      if (i.effectId == GearEffectId.lifesteal) return s + i.effectValue;
      return s;
    });
    return _softCapStat(raw, soft: 10, hard: 22);
  }

  static int _softCapStat(int value, {required int soft, required int hard}) {
    if (value <= soft) return value;
    final compressed = soft + ((value - soft) * 0.45).round();
    return compressed > hard ? hard : compressed;
  }

  bool get gearHasPierce =>
      equipped.values.any((i) => i.effectId == GearEffectId.pierce) ||
      equipped[EquipmentSlot.weapon]?.pattern == ProjectilePattern.pierce;

  int get gearGoldFindPercent => equipped.values.fold<int>(0, (s, i) {
    if (i.effectId == GearEffectId.goldFind) return s + i.effectValue;
    return s;
  });

  ProjectilePattern get weaponPattern =>
      equipped[EquipmentSlot.weapon]?.pattern ?? ProjectilePattern.single;

  EquipmentItem? itemIn(EquipmentSlot slot) => equipped[slot];

  String get roleLabel => spec.shortLabel;

  String get passiveLabel => ClassKits.kitSummaryForSpec(specId, level);

  PartyHero takeDamage(int damage) {
    final nextHp = currentHp - damage;
    return copyWith(currentHp: nextHp.clamp(0, maxHp));
  }

  PartyHero healToFull() => copyWith(currentHp: maxHp);

  PartyHero levelUp() =>
      copyWith(level: level + 1, xp: 0, currentHp: maxHp + 5);

  PartyHero train() => levelUp();

  PartyHero copyWith({
    String? id,
    String? name,
    int? level,
    int? currentHp,
    Stats? stats,
    HeroSpecId? specId,
    Map<EquipmentSlot, EquipmentItem>? equipped,
    int? xp,
    bool clearEquipped = false,
    @Deprecated('Use specId') HeroRole? role,
  }) {
    final nextSpec =
        specId ??
        (role != null ? HeroSpecs.fromGearAffinity(role) : this.specId);
    return PartyHero(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      stats: stats ?? this.stats,
      specId: nextSpec,
      equipped: clearEquipped
          ? const <EquipmentSlot, EquipmentItem>{}
          : (equipped ?? this.equipped),
      xp: xp ?? this.xp,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'level': level,
    'currentHp': currentHp,
    'stats': stats.toJson(),
    'specId': specId.name,
    // Legacy save key (gear affinity name); prefer specId for identity.
    'role': gearAffinity.name,
    'xp': xp,
    'equipped': equipped.map(
      (slot, item) => MapEntry(slot.name, item.toJson()),
    ),
  };

  factory PartyHero.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    final name = json['name'] as String;
    final specRaw = json['specId'] as String?;
    final roleRaw = json['role'] as String?;
    final specId =
        HeroSpecs.tryParse(specRaw) ??
        (roleRaw != null
            ? HeroSpecs.fromGearAffinityName(roleRaw)
            : specForName(name));
    final affinity = HeroSpecs.def(specId).gearAffinity;

    final equipped = <EquipmentSlot, EquipmentItem>{};
    final equippedJson = json['equipped'] as Map<String, dynamic>?;
    if (equippedJson != null) {
      for (final entry in equippedJson.entries) {
        final slot = EquipmentSlotX.parse(entry.key);
        equipped[slot] = EquipmentItem.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    final statsJson = json['stats'] as Map<String, dynamic>;
    Stats stats;
    if (statsJson.containsKey('strength')) {
      stats = Stats.fromJson(statsJson);
      if (stats.isEnemySheet) {
        stats = Stats(
          strength: stats.strength,
          agility: stats.agility,
          stamina: stats.stamina,
          intellect: stats.intellect,
          spirit: stats.spirit,
        );
      }
    } else {
      final atk = asInt(statsJson['attack'], 1);
      final def = asInt(statsJson['defense'], 1);
      final hp = asInt(statsJson['maxHp'], 10);
      final sta = (hp / 10).ceil().clamp(1, 999);
      stats = switch (affinity) {
        HeroRole.warrior => Stats(
          strength: atk.clamp(1, 999),
          agility: def.clamp(1, 999),
          stamina: sta,
          intellect: 1,
          spirit: 2,
        ),
        HeroRole.rogue => Stats(
          strength: (atk / 2).ceil().clamp(1, 999),
          agility: (atk - (atk / 2).ceil()).clamp(1, 999),
          stamina: sta,
          intellect: 1,
          spirit: 2,
        ),
        HeroRole.healer || HeroRole.mage => Stats(
          strength: 1,
          agility: 1,
          stamina: sta,
          intellect: atk.clamp(1, 999),
          spirit: def.clamp(1, 999),
        ),
      };
    }

    final id = (json['id'] as String?) ?? PartyHero._stableIdFor(specId, name);

    return PartyHero(
      id: id,
      name: name,
      level: asInt(json['level'], 1),
      currentHp: asInt(json['currentHp']),
      stats: stats,
      specId: specId,
      equipped: equipped,
      xp: asInt(json['xp']),
    );
  }
}
