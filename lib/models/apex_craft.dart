import '../core/equipment_factory.dart';
import 'dungeon_def.dart';
import 'hero.dart';
import 'hero_spec.dart';
import 'loot.dart';

/// Apex crafting materials, pity, and class/role recipe templates.
abstract final class ApexCraft {
  static const int maxRank = 3;

  static const double pityPBase = 0.04;
  static const int pitySoft = 40;
  static const int pityHard = 60;
  static const double pityRamp = 0.04;

  /// FARM boss clears contribute this fraction of a full pity tick.
  static const double farmPityWeight = 0.25;

  static const double shardPBase = 0.35;
  static const double corePBase = 0.18;
  static const double catalystPBase = 0.03;
  static const double slagPBase = 0.12;

  static const List<EquipmentSlot> craftSlots = <EquipmentSlot>[
    EquipmentSlot.weapon,
    EquipmentSlot.offHand,
    EquipmentSlot.head,
    EquipmentSlot.shoulder,
    EquipmentSlot.chest,
    EquipmentSlot.waist,
    EquipmentSlot.legs,
    EquipmentSlot.boots,
    EquipmentSlot.wrist,
    EquipmentSlot.hands,
    EquipmentSlot.cloak,
  ];

  static const List<CraftMatDef> materials = <CraftMatDef>[
    CraftMatDef(
      id: 'shard_sandy',
      name: 'Sandy Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Sandy Caverns boss',
    ),
    CraftMatDef(
      id: 'shard_goblin',
      name: 'Hideout Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Goblin Hideout boss',
    ),
    CraftMatDef(
      id: 'shard_king',
      name: 'Fort Shard',
      family: CraftMatFamily.shard,
      bossSources: 'King\'s Fort boss',
    ),
    CraftMatDef(
      id: 'shard_underworld',
      name: 'Underworld Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Underworld boss',
    ),
    CraftMatDef(
      id: 'shard_dead',
      name: 'Necropolis Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Dead City boss',
    ),
    CraftMatDef(
      id: 'shard_hell',
      name: 'Hellgate Shard',
      family: CraftMatFamily.shard,
      bossSources: "Hell's Gate boss",
    ),
    CraftMatDef(
      id: 'shard_crystal',
      name: 'Spire Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Crystal Spire boss',
    ),
    CraftMatDef(
      id: 'shard_tide',
      name: 'Tidehold Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Sunken Tidehold boss',
    ),
    CraftMatDef(
      id: 'shard_ember',
      name: 'Ashen Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Ashen Vault boss',
    ),
    CraftMatDef(
      id: 'shard_grove',
      name: 'Hollow Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Hollow Grove boss',
    ),
    CraftMatDef(
      id: 'shard_storm',
      name: 'Stormwake Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Stormwake Hollow boss',
    ),
    CraftMatDef(
      id: 'shard_rime',
      name: 'Rimeglass Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Rimeglass Rift boss',
    ),
    CraftMatDef(
      id: 'shard_fen',
      name: 'Blightfen Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Blightfen Mire boss',
    ),
    CraftMatDef(
      id: 'shard_brass',
      name: 'Brassvault Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Brassvault Deep boss',
    ),
    CraftMatDef(
      id: 'core_tank',
      name: 'Aegis Core',
      family: CraftMatFamily.core,
      bossSources: 'Any boss (tank party bias)',
    ),
    CraftMatDef(
      id: 'core_healer',
      name: 'Mending Core',
      family: CraftMatFamily.core,
      bossSources: 'Any boss (healer party bias)',
    ),
    CraftMatDef(
      id: 'core_melee',
      name: 'Strike Core',
      family: CraftMatFamily.core,
      bossSources: 'Any boss (melee party bias)',
    ),
    CraftMatDef(
      id: 'core_ranged',
      name: 'Mark Core',
      family: CraftMatFamily.core,
      bossSources: 'Any boss (ranged party bias)',
    ),
    CraftMatDef(
      id: 'core_caster',
      name: 'Arcane Core',
      family: CraftMatFamily.core,
      bossSources: 'Any boss (caster party bias)',
    ),
    CraftMatDef(
      id: 'catalyst_warrior',
      name: 'Warrior Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Warrior in party)',
    ),
    CraftMatDef(
      id: 'catalyst_paladin',
      name: 'Paladin Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Paladin in party)',
    ),
    CraftMatDef(
      id: 'catalyst_hunter',
      name: 'Hunter Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Hunter in party)',
    ),
    CraftMatDef(
      id: 'catalyst_rogue',
      name: 'Rogue Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Rogue in party)',
    ),
    CraftMatDef(
      id: 'catalyst_priest',
      name: 'Priest Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Priest in party)',
    ),
    CraftMatDef(
      id: 'catalyst_deathKnight',
      name: 'Death Knight Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Death Knight in party)',
    ),
    CraftMatDef(
      id: 'catalyst_shaman',
      name: 'Shaman Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Shaman in party)',
    ),
    CraftMatDef(
      id: 'catalyst_mage',
      name: 'Mage Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Mage in party)',
    ),
    CraftMatDef(
      id: 'catalyst_warlock',
      name: 'Warlock Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Warlock in party)',
    ),
    CraftMatDef(
      id: 'catalyst_druid',
      name: 'Druid Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Druid in party)',
    ),
    CraftMatDef(
      id: 'apex_slag',
      name: 'Apex Slag',
      family: CraftMatFamily.slag,
      bossSources: 'Gauntlet bosses · Crystal Spire boss',
    ),
  ];

  static final Map<String, CraftMatDef> materialsById = {
    for (final m in materials) m.id: m,
  };

  static String shardIdForDungeon(String dungeonId) => 'shard_$dungeonId';

  static String coreIdForRole(SpecRoleTag role) => switch (role) {
        SpecRoleTag.tank => 'core_tank',
        SpecRoleTag.healer => 'core_healer',
        SpecRoleTag.meleeDps => 'core_melee',
        SpecRoleTag.rangedDps => 'core_ranged',
        SpecRoleTag.caster => 'core_caster',
      };

  static String catalystIdForClass(HeroClassId classId) =>
      'catalyst_${classId.name}';

  static Set<SpecRoleTag> validRolesFor(HeroClassId classId) => {
        for (final d in HeroSpecs.all)
          if (d.classId == classId) d.roleTag,
      };

  static bool isValidPair(HeroClassId classId, SpecRoleTag role) =>
      validRolesFor(classId).contains(role);

  static HeroSpecDef? representativeSpec(
    HeroClassId classId,
    SpecRoleTag role,
  ) {
    for (final d in HeroSpecs.all) {
      if (d.classId == classId && d.roleTag == role) return d;
    }
    return null;
  }

  static double slotCostMult(EquipmentSlot slot) => switch (slot) {
        EquipmentSlot.weapon => 2.0,
        EquipmentSlot.offHand => 1.4,
        EquipmentSlot.chest || EquipmentSlot.legs => 1.3,
        EquipmentSlot.head || EquipmentSlot.shoulder => 1.1,
        _ => 1.0,
      };

  static int rankCostMult(int rank) => switch (rank) {
        1 => 1,
        2 => 2,
        3 => 4,
        _ => 1,
      };

  /// Absolute mat cost to reach [rank] from nothing (for R1 craft).
  static Map<String, int> absoluteCost({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
    required int rank,
  }) {
    final mult = (slotCostMult(slot) * rankCostMult(rank)).ceil();
    final shardsNeeded = max(1, (2 * mult) ~/ 2);
    final dungeonIds = DungeonCatalog.all.map((d) => d.id).toList();
    final costs = <String, int>{};
    // Spread shards across early → late zones by rank/slot weight.
    for (var i = 0; i < shardsNeeded && i < dungeonIds.length; i++) {
      final id = shardIdForDungeon(dungeonIds[i]);
      costs[id] = (costs[id] ?? 0) + 1 + (mult ~/ 3);
    }
    if (shardsNeeded > dungeonIds.length) {
      final crystal = shardIdForDungeon('crystal');
      costs[crystal] = (costs[crystal] ?? 0) + (shardsNeeded - dungeonIds.length);
    }
    costs[coreIdForRole(role)] = max(1, mult);
    costs[catalystIdForClass(classId)] = max(1, (mult + 1) ~/ 2);
    if (rank >= 2 || slot == EquipmentSlot.weapon) {
      // R1 weapons: 1 slag (was heavier); upgrades stay steeper.
      costs['apex_slag'] = rank == 1
          ? 1
          : max(1, mult ~/ (rank == 2 ? 2 : 1));
    }
    return costs;
  }

  /// Delta cost to go from [fromRank] to [toRank] (upgrade-in-place).
  static Map<String, int> upgradeDeltaCost({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
    required int fromRank,
    required int toRank,
  }) {
    assert(toRank > fromRank);
    final high = absoluteCost(
      classId: classId,
      role: role,
      slot: slot,
      rank: toRank,
    );
    final low = fromRank <= 0
        ? <String, int>{}
        : absoluteCost(
            classId: classId,
            role: role,
            slot: slot,
            rank: fromRank,
          );
    final delta = <String, int>{};
    for (final e in high.entries) {
      final need = e.value - (low[e.key] ?? 0);
      if (need > 0) delta[e.key] = need;
    }
    return delta;
  }

  static ApexRecipe recipe({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
    int rank = 1,
  }) {
    final abs = absoluteCost(
      classId: classId,
      role: role,
      slot: slot,
      rank: rank,
    );
    final sources = <String>{
      for (final id in abs.keys)
        if (materialsById[id] != null) materialsById[id]!.bossSources,
    };
    return ApexRecipe(
      classId: classId,
      role: role,
      slot: slot,
      rank: rank,
      costs: abs,
      bossSources: sources.toList()..sort(),
    );
  }

  static double pityChance(int dryStreak, {double pBase = pityPBase}) {
    if (dryStreak >= pityHard) return 1.0;
    if (dryStreak < pitySoft) return pBase;
    return (pBase + pityRamp * (dryStreak - pitySoft + 1)).clamp(0.0, 1.0);
  }

  static String pieceId({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) =>
      'apex_${classId.name}_${role.name}_${slot.name}';

  static String pieceName({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    final cls = HeroSpecs.classLabel(classId);
    final roleLabel = switch (role) {
      SpecRoleTag.tank => 'Aegis',
      SpecRoleTag.healer => 'Grace',
      SpecRoleTag.meleeDps => 'Fury',
      SpecRoleTag.rangedDps => 'Mark',
      SpecRoleTag.caster => 'Arcana',
    };
    final slotLabel = switch (slot) {
      EquipmentSlot.weapon => 'Edge',
      EquipmentSlot.offHand => 'Ward',
      EquipmentSlot.head => 'Crown',
      EquipmentSlot.shoulder => 'Mantle',
      EquipmentSlot.chest => 'Cuirass',
      EquipmentSlot.waist => 'Girdle',
      EquipmentSlot.legs => 'Greaves',
      EquipmentSlot.boots => 'Treads',
      EquipmentSlot.wrist => 'Bracers',
      EquipmentSlot.hands => 'Grips',
      EquipmentSlot.cloak => 'Cloak',
      _ => slot.name,
    };
    return 'Apex $cls $roleLabel $slotLabel';
  }

  /// Build a legendary Apex piece at [rank] for AL scaling.
  static EquipmentItem buildItem({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
    required int rank,
    required int ascensionLevel,
  }) {
    final spec = representativeSpec(classId, role);
    final affinity = spec?.gearAffinity ?? HeroRole.warrior;
    final preferredArmor = spec?.armorTypes.isNotEmpty == true
        ? spec!.armorTypes.last
        : null;

    final powerMul = switch (rank.clamp(1, maxRank)) {
      1 => 1.06,
      2 => 1.14,
      _ => 1.22,
    };
    final alBonus = ascensionLevel * 2;
    final baseIlvl =
        40 + alBonus + rank * 8 + (slot == EquipmentSlot.weapon ? 6 : 0);

    ArmorType? armorType;
    WeaponType? weaponType;
    WeaponHanded? handed;
    OffHandKind? offHandKind;
    ProjectilePattern pattern = ProjectilePattern.single;

    if (slot.isArmorSlot || slot == EquipmentSlot.cloak) {
      armorType = preferredArmor ?? ArmorType.mail;
    } else if (slot == EquipmentSlot.weapon) {
      final mh = _mainHandFor(affinity, role);
      weaponType = mh.$1;
      handed = mh.$2;
      pattern = switch (role) {
        SpecRoleTag.caster || SpecRoleTag.healer => ProjectilePattern.arc,
        SpecRoleTag.rangedDps => ProjectilePattern.pierce,
        _ => ProjectilePattern.single,
      };
    } else if (slot == EquipmentSlot.offHand) {
      if (role == SpecRoleTag.tank) {
        offHandKind = OffHandKind.shield;
      } else if (role == SpecRoleTag.healer || role == SpecRoleTag.caster) {
        offHandKind = OffHandKind.frill;
      } else {
        offHandKind = OffHandKind.weapon;
        weaponType = WeaponType.sword;
        handed = WeaponHanded.oneHand;
      }
    }

    // Same ilvl→budget curve as dungeon drops (legendary quality + rank mul).
    // Armor is carved from the pool (not stacked on top) — matches EquipmentFactory.create.
    final baseBudget = EquipmentFactory.budgetForItemLevel(
      itemLevel: baseIlvl,
      rarity: LootRarity.legendary,
      slot: slot,
      handed: handed,
    );
    final budget = max(8, (baseBudget * powerMul).round());

    final needsArmor = slot.isArmorSlot ||
        slot == EquipmentSlot.cloak ||
        (slot == EquipmentSlot.offHand && offHandKind == OffHandKind.shield);
    final armor = needsArmor
        ? EquipmentFactory.armorPointsFor(
            armorType ??
                (offHandKind == OffHandKind.shield ? ArmorType.plate : null),
            budget,
          )
        : 0;
    final pool = max(1, budget - armor);

    var str = 0, agi = 0, sta = 0, intel = 0, spi = 0, sp = 0;
    var ap = 0, crit = 0, aspd = 0;
    final secTier = max(0, (baseIlvl - 5) ~/ 18);
    // Role weights sum to ~1.0 of [pool] (armor already carved).
    switch (role) {
      case SpecRoleTag.tank:
        str = (pool * 0.40).round();
        sta = (pool * 0.55).round();
        crit = 2 + rank + secTier ~/ 2;
      case SpecRoleTag.healer:
        intel = (pool * 0.30).round();
        spi = (pool * 0.25).round();
        sp = (pool * 0.30).round();
        sta = (pool * 0.15).round();
      case SpecRoleTag.meleeDps:
        str = (pool * 0.35).round();
        agi = (pool * 0.25).round();
        ap = (pool * 0.20).round();
        sta = (pool * 0.15).round();
        crit = 3 + rank * 2 + secTier ~/ 2;
        aspd = 2 + rank + secTier ~/ 2;
      case SpecRoleTag.rangedDps:
        agi = (pool * 0.50).round();
        ap = (pool * 0.30).round();
        sta = (pool * 0.15).round();
        crit = 4 + rank * 2 + secTier ~/ 2;
        aspd = 3 + rank + secTier ~/ 2;
      case SpecRoleTag.caster:
        intel = (pool * 0.42).round();
        sp = (pool * 0.42).round();
        sta = (pool * 0.15).round();
        crit = 3 + rank * 2 + secTier ~/ 2;
    }

    return EquipmentItem(
      id: pieceId(classId: classId, role: role, slot: slot),
      name: pieceName(classId: classId, role: role, slot: slot),
      slot: slot,
      rarity: LootRarity.legendary,
      strengthBonus: str,
      agilityBonus: agi,
      staminaBonus: sta,
      intellectBonus: intel,
      spiritBonus: spi,
      spellPowerBonus: sp,
      armorBonus: armor,
      attackBonus: ap,
      critChanceBonus: crit,
      attackSpeedBonus: aspd,
      itemLevel: baseIlvl,
      armorType: armorType,
      weaponType: weaponType,
      handed: handed,
      offHandKind: offHandKind,
      pattern: pattern,
      affinity: affinity.name,
      isApex: true,
      apexClassId: classId.name,
      apexRoleTag: role.name,
      apexRank: rank.clamp(1, maxRank),
    );
  }

  static int max(int a, int b) => a > b ? a : b;

  static (WeaponType, WeaponHanded) _mainHandFor(
    HeroRole affinity,
    SpecRoleTag role,
  ) {
    if (role == SpecRoleTag.tank) {
      return (WeaponType.mace, WeaponHanded.oneHand);
    }
    return switch (affinity) {
      HeroRole.warrior => (WeaponType.sword, WeaponHanded.twoHand),
      HeroRole.rogue => (WeaponType.dagger, WeaponHanded.oneHand),
      HeroRole.healer => (WeaponType.mace, WeaponHanded.oneHand),
      HeroRole.mage => (WeaponType.staff, WeaponHanded.twoHand),
    };
  }
}

enum CraftMatFamily { shard, core, catalyst, slag }

class CraftMatDef {
  const CraftMatDef({
    required this.id,
    required this.name,
    required this.family,
    required this.bossSources,
  });

  final String id;
  final String name;
  final CraftMatFamily family;
  final String bossSources;
}

class ApexRecipe {
  const ApexRecipe({
    required this.classId,
    required this.role,
    required this.slot,
    required this.rank,
    required this.costs,
    required this.bossSources,
  });

  final HeroClassId classId;
  final SpecRoleTag role;
  final EquipmentSlot slot;
  final int rank;
  final Map<String, int> costs;
  final List<String> bossSources;
}
