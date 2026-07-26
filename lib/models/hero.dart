import 'class_ability.dart';
import 'combat_ratings.dart';
import 'loot.dart';
import 'stats.dart';

enum HeroRole { warrior, healer, mage, rogue }

class PartyHero {
  const PartyHero({
    required this.name,
    required this.level,
    required this.currentHp,
    required this.stats,
    this.role = HeroRole.rogue,
    this.equipped = const <EquipmentSlot, EquipmentItem>{},
    this.xp = 0,
  });

  factory PartyHero.starting({
    required String name,
    required Stats stats,
    HeroRole? role,
    Map<EquipmentSlot, EquipmentItem>? equipped,
  }) {
    final r = role ?? roleForName(name);
    final sheet = CombatRatings.grownPrimaries(
      base: stats,
      role: r,
      level: 1,
    );
    final hp = CombatRatings.roleHpBase(r) + 10 * sheet.sta;
    return PartyHero(
      name: name,
      level: 1,
      currentHp: hp,
      stats: stats,
      role: r,
      equipped: equipped ?? const <EquipmentSlot, EquipmentItem>{},
      xp: 0,
    );
  }

  static HeroRole roleForName(String name) => switch (name) {
        'Aegis' => HeroRole.warrior,
        'Vale' => HeroRole.healer,
        'Ember' => HeroRole.mage,
        _ => HeroRole.rogue,
      };

  /// Locked starting primary sheets from the Classic stats plan.
  static Stats startingStatsFor(HeroRole role) => switch (role) {
        HeroRole.warrior => const Stats(
            strength: 14,
            agility: 6,
            stamina: 4,
            intellect: 1,
            spirit: 2,
          ),
        HeroRole.healer => const Stats(
            strength: 2,
            agility: 3,
            stamina: 3,
            intellect: 6,
            spirit: 6,
          ),
        HeroRole.mage => const Stats(
            strength: 1,
            agility: 2,
            stamina: 3,
            intellect: 5,
            spirit: 4,
          ),
        HeroRole.rogue => const Stats(
            strength: 8,
            agility: 16,
            stamina: 3,
            intellect: 1,
            spirit: 2,
          ),
      };

  final String name;
  final int level;
  final int currentHp;
  final Stats stats;
  final HeroRole role;
  final Map<EquipmentSlot, EquipmentItem> equipped;
  final int xp;

  ({int str, int agi, int sta, int intel, int spi}) get grownPrimaries =>
      CombatRatings.grownPrimaries(base: stats, role: role, level: level);

  /// Base attack without gear/meta (AP/4 or Int for casters).
  int get attack {
    final g = grownPrimaries;
    if (role == HeroRole.mage || role == HeroRole.healer) {
      return g.intel;
    }
    final ap = CombatRatings.meleeAttackPower(
      role: role,
      strength: g.str,
      agility: g.agi,
      level: level,
    );
    return (ap / CombatRatings.kAp).round().clamp(1, 99999);
  }

  int get defense {
    final g = grownPrimaries;
    return CombatRatings.roleBaseArmor(role) + 2 * g.agi;
  }

  int get maxHp {
    final g = grownPrimaries;
    return CombatRatings.roleHpBase(role) + 10 * g.sta;
  }

  bool get isAlive => currentHp > 0;

  int get gearStrengthBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.strengthBonus);
  int get gearAgilityBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.agilityBonus);
  int get gearStaminaBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.resolvedStamina);
  int get gearIntellectBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.intellectBonus);
  int get gearSpiritBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.spiritBonus);
  int get gearSpellPowerBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.spellPowerBonus);
  int get gearArmorBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.resolvedArmor);
  int get gearMp5Bonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.mp5Bonus);

  /// Flat AP from legacy attackBonus on melee gear.
  int get gearAttackBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.attackBonus);

  int get gearDefenseBonus => gearArmorBonus;

  int get gearVitalityBonus => gearStaminaBonus * 10;

  int get gearCritChance => equipped.values.fold<int>(
        0,
        (s, i) =>
            s +
            i.critChanceBonus +
            (i.effectId == GearEffectId.crit ? i.effectValue : 0),
      );

  int get gearAttackSpeedBonus => equipped.values.fold<int>(
        0,
        (s, i) =>
            s +
            i.attackSpeedBonus +
            (i.effectId == GearEffectId.haste ? i.effectValue : 0),
      );

  int get gearMoveSpeedBonus =>
      equipped.values.fold<int>(0, (s, i) => s + i.moveSpeedBonus);

  int get gearLifestealPercent => equipped.values.fold<int>(0, (s, i) {
        if (i.effectId == GearEffectId.lifesteal) return s + i.effectValue;
        return s;
      });

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

  String get roleLabel => switch (role) {
        HeroRole.warrior => 'WARRIOR',
        HeroRole.healer => 'DISC PRIEST',
        HeroRole.mage => 'MAGE',
        HeroRole.rogue => 'ROGUE',
      };

  String get passiveLabel => ClassKits.kitSummary(role, level);

  PartyHero takeDamage(int damage) {
    final nextHp = currentHp - damage;
    return copyWith(currentHp: nextHp.clamp(0, maxHp));
  }

  PartyHero healToFull() => copyWith(currentHp: maxHp);

  PartyHero levelUp() => copyWith(level: level + 1, xp: 0, currentHp: maxHp + 5);

  PartyHero train() => levelUp();

  PartyHero copyWith({
    int? level,
    int? currentHp,
    Stats? stats,
    HeroRole? role,
    Map<EquipmentSlot, EquipmentItem>? equipped,
    int? xp,
    bool clearEquipped = false,
  }) {
    return PartyHero(
      name: name,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      stats: stats ?? this.stats,
      role: role ?? this.role,
      equipped: clearEquipped
          ? const <EquipmentSlot, EquipmentItem>{}
          : (equipped ?? this.equipped),
      xp: xp ?? this.xp,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'level': level,
        'currentHp': currentHp,
        'stats': stats.toJson(),
        'role': role.name,
        'xp': xp,
        'equipped': equipped.map(
          (slot, item) => MapEntry(slot.name, item.toJson()),
        ),
      };

  factory PartyHero.fromJson(Map<String, dynamic> json) {
    final roleRaw = json['role'] as String?;
    final name = json['name'] as String;
    final role = roleRaw == null
        ? roleForName(name)
        : HeroRole.values.byName(roleRaw);

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
      // Drop enemy flat overrides if present on a hero sheet.
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
      final atk = (statsJson['attack'] as int?) ?? 1;
      final def = (statsJson['defense'] as int?) ?? 1;
      final hp = (statsJson['maxHp'] as int?) ?? 10;
      final sta = (hp / 10).ceil().clamp(1, 999);
      stats = switch (role) {
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

    return PartyHero(
      name: name,
      level: json['level'] as int,
      currentHp: json['currentHp'] as int,
      stats: stats,
      role: role,
      equipped: equipped,
      xp: (json['xp'] as int?) ?? 0,
    );
  }
}
