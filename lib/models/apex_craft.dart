import 'dart:math';

import '../core/equipment_factory.dart';
import '../visual/equipment_visual_resolver.dart';
import 'equip_stat_weights.dart';
import 'hero.dart';
import 'hero_spec.dart';
import 'loot.dart';
import 'proficiency.dart';

/// Apex crafting materials, pity, and class/role recipe templates.
abstract final class ApexCraft {
  /// Highest rank the forge can ever reach (AL20).
  static const int absoluteMaxRank = 7;

  /// Highest craft rank at [ascensionLevel].
  ///
  /// AL0–4 stays at 3. Each 5 Ascend levels opens one more rank:
  /// AL5 → 4, AL10 → 5, AL15 → 6, AL20+ → 7.
  static int maxRank(int ascensionLevel) {
    final al = ascensionLevel < 0 ? 0 : ascensionLevel;
    final unlocked = 3 + al ~/ 5;
    return unlocked > absoluteMaxRank ? absoluteMaxRank : unlocked;
  }

  /// "Max rank 4" for the CRAFT sheet.
  static String maxRankLabel(int ascensionLevel) =>
      'Max rank ${maxRank(ascensionLevel)}';

  /// When the next rank opens, or null once the piece can reach rank 7.
  static String? rankUnlockHint(int ascensionLevel) {
    final cap = maxRank(ascensionLevel);
    if (cap >= absoluteMaxRank) return null;
    final next = cap + 1;
    return 'Rank $next unlocks at Ascend ${5 * (next - 3)}';
  }

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

  /// Boss clears (PUSH) to fill the target-material meter (100 units).
  static const int targetMeterRequired = 100;

  /// Progress per boss clear toward [targetMeterRequired].
  static const int targetMeterPushTick = 20;

  /// FARM boss clears tick slower (same meter cap).
  static const int targetMeterFarmTick = 5;

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

  /// Recipe unit: any named zone shard in the bag pays this cost.
  static const String shardAnyId = 'shard_any';

  static const String slagId = 'apex_slag';

  static const List<CraftMatDef> materials = <CraftMatDef>[
    CraftMatDef(
      id: shardAnyId,
      name: 'Zone Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Any dungeon boss',
    ),
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
      bossSources: "Goblin's Hideout boss",
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
      bossSources: 'City of Dead boss',
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
      id: 'shard_veil',
      name: 'Mothveil Shard',
      family: CraftMatFamily.shard,
      bossSources: 'Mothveil Hollow boss',
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
      name: 'Bladeward Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Bladeward in party)',
    ),
    CraftMatDef(
      id: 'catalyst_paladin',
      name: 'Oathguard Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Oathguard in party)',
    ),
    CraftMatDef(
      id: 'catalyst_hunter',
      name: 'Trailbow Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Trailbow in party)',
    ),
    CraftMatDef(
      id: 'catalyst_rogue',
      name: 'Cutpurse Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Cutpurse in party)',
    ),
    CraftMatDef(
      id: 'catalyst_priest',
      name: 'Lightkeeper Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Lightkeeper in party)',
    ),
    CraftMatDef(
      id: 'catalyst_deathKnight',
      name: 'Graveknight Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Graveknight in party)',
    ),
    CraftMatDef(
      id: 'catalyst_shaman',
      name: 'Stormcaller Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Stormcaller in party)',
    ),
    CraftMatDef(
      id: 'catalyst_mage',
      name: 'Arcanist Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Arcanist in party)',
    ),
    CraftMatDef(
      id: 'catalyst_warlock',
      name: 'Hexbinder Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Hexbinder in party)',
    ),
    CraftMatDef(
      id: 'catalyst_druid',
      name: 'Wildheart Catalyst',
      family: CraftMatFamily.catalyst,
      bossSources: 'Any boss (Wildheart in party)',
    ),
    CraftMatDef(
      id: slagId,
      name: 'Apex Slag',
      family: CraftMatFamily.slag,
      bossSources: 'Gauntlet bosses · Crystal Spire boss',
    ),
  ];

  static final Map<String, CraftMatDef> materialsById = {
    for (final m in materials) m.id: m,
  };

  /// One loot-log line for a boss drop. Empty when nothing was granted.
  static String lootLineForGrants(Iterable<String> ids) {
    final counts = <String, int>{};
    final order = <String>[];
    for (final id in ids) {
      if (id.isEmpty) continue;
      if (!counts.containsKey(id)) order.add(id);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (order.isEmpty) return '';
    return '+${[for (final id in order) _countName(id, counts[id]!)].join(' · ')}';
  }

  /// Welcome Back line. Empty when [gained] is empty.
  static String gainedLine(Map<String, int> gained) {
    if (gained.isEmpty) return '';
    final ids = gained.keys.toList()..sort();
    return 'Craft materials · ${[for (final id in ids)
      if ((gained[id] ?? 0) > 0) _countName(id, gained[id]!)].join(' · ')}';
  }

  static String _countName(String id, int count) {
    final name = materialsById[id]?.name ?? id;
    return count == 1 ? name : '$count $name';
  }

  static String shardIdForDungeon(String dungeonId) => 'shard_$dungeonId';

  static bool isZoneShardId(String matId) {
    if (matId == shardAnyId) return false;
    return materialsById[matId]?.family == CraftMatFamily.shard;
  }

  static int ownedShardCount(Map<String, int> bag) {
    var n = 0;
    for (final e in bag.entries) {
      if (isZoneShardId(e.key)) n += e.value;
    }
    return n;
  }

  /// Prefer the fattest piles so leftover named shards stay readable.
  static Map<String, int> spendZoneShards(Map<String, int> bag, int qty) {
    if (qty <= 0) return bag;
    final next = Map<String, int>.from(bag);
    final piles =
        next.entries.where((e) => isZoneShardId(e.key) && e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    var left = qty;
    for (final e in piles) {
      if (left <= 0) break;
      final take = e.value < left ? e.value : left;
      final remain = e.value - take;
      if (remain <= 0) {
        next.remove(e.key);
      } else {
        next[e.key] = remain;
      }
      left -= take;
    }
    return next;
  }

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

  /// Apex recipes skip off-hand when specs in the pair disagree or all use 2H
  /// (Blood DK, Arms vs Fury, Hunter bow, Ret 2H, …).
  static List<EquipmentSlot> craftSlotsFor(
    HeroClassId classId,
    SpecRoleTag role,
  ) {
    final kind = apexOffHandKind(classId, role);
    return [
      for (final s in craftSlots)
        if (s != EquipmentSlot.offHand || kind != null) s,
    ];
  }

  /// Shared off-hand kind for a class×role Apex recipe, or null if none.
  ///
  /// Uses each spec's Apex off-hand (DW / frill / shield) — not a class-wide
  /// "can use shield" dump — so Enhancement gets a weapon, Mage/Priest a tome,
  /// and Ret/Arms (2H melee) get no off-hand even though they *can* wear shields.
  static OffHandKind? apexOffHandKind(HeroClassId classId, SpecRoleTag role) {
    final specs = [
      for (final d in HeroSpecs.all)
        if (d.classId == classId && d.roleTag == role) d,
    ];
    if (specs.isEmpty) return null;
    final preferred = [for (final s in specs) _apexPreferredOh(s)];
    // Any spec that does not use an off-hand → no shared OH recipe.
    if (preferred.any((k) => k == null)) return null;
    final first = preferred.first;
    if (preferred.every((k) => k == first)) return first;
    return null;
  }

  /// Per-spec Apex off-hand. Frill/DW always count; shields skip pure 2H melee
  /// fantasy (Ret, Arms). Casters like Elemental keep shield + forced 1H MH.
  static OffHandKind? _apexPreferredOh(HeroSpecDef spec) {
    final pref = ClassProficiency.preferredOffHandKind(spec);
    if (pref == null) return null;
    if (pref == OffHandKind.frill || pref == OffHandKind.weapon) return pref;
    if (pref == OffHandKind.shield &&
        _apexMainHandRaw(spec).$2 == WeaponHanded.twoHand &&
        spec.roleTag == SpecRoleTag.meleeDps) {
      return null;
    }
    return pref;
  }

  static double slotCostMult(EquipmentSlot slot) => switch (slot) {
    EquipmentSlot.weapon => 2.0,
    EquipmentSlot.offHand => 1.4,
    EquipmentSlot.chest || EquipmentSlot.legs => 1.3,
    EquipmentSlot.head || EquipmentSlot.shoulder => 1.1,
    _ => 1.0,
  };

  static bool _heavySlot(EquipmentSlot slot) => slotCostMult(slot) >= 1.3;

  /// Absolute mat cost to reach [rank] from nothing (for R1 craft).
  ///
  /// Zone shards are a pool ([shardAnyId]) — Mothveil/KEY/Rift shards pay
  /// the same as Sandy. Each rank adds a short, same-shaped tax so upgrades
  /// do not invent a new shopping list of early-zone mats.
  ///
  /// Ranks 1–3 are the original table. Ranks 4–7 keep that step (catalyst
  /// equals the rank) so a higher rank always costs more than rank 3.
  /// The AL cap in [maxRank] decides whether the forge will spend it.
  static Map<String, int> absoluteCost({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
    required int rank,
  }) {
    final r = rank.clamp(1, absoluteMaxRank);
    final heavy = _heavySlot(slot);
    // Heavy shards: 2, 4, 6, … Light: 1, then 2, 4, 6, …
    final shards = heavy ? r * 2 : (r == 1 ? 1 : (r - 1) * 2);
    // Heavy cores: 2, 3, 4, … Light: 1, 2, 3, …
    final cores = heavy ? r + 1 : r;
    final costs = <String, int>{
      shardAnyId: shards,
      coreIdForRole(role): cores,
      catalystIdForClass(classId): r,
    };
    if (r >= 2 || slot == EquipmentSlot.weapon) {
      // Weapon slag: 1, 2, 3, … Other slots start at rank 2: 1, 2, 3, …
      costs[slagId] = slot == EquipmentSlot.weapon ? r : r - 1;
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
  }) => 'apex_${classId.name}_${role.name}_${slot.name}';

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
      EquipmentSlot.weapon => classId == HeroClassId.hunter ? 'Bow' : 'Edge',
      EquipmentSlot.offHand => switch (apexOffHandKind(classId, role)) {
        OffHandKind.shield => 'Bulwark',
        OffHandKind.frill => 'Tome',
        OffHandKind.weapon => 'Fang',
        null => 'Ward',
      },
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

  /// Shown item level baked at craft time: 40 + AL×2 + rank×8 (+6 weapons).
  static int itemLevelFor({
    required int rank,
    required int ascensionLevel,
    required EquipmentSlot slot,
  }) {
    final r = rank.clamp(1, absoluteMaxRank);
    return 40 +
        ascensionLevel * 2 +
        r * 8 +
        (slot == EquipmentSlot.weapon ? 6 : 0);
  }

  /// Rank power on the drop budget. Ranks 1–3 step +0.08 from 1.06.
  /// Ranks 4–7 step +0.005 so an AL20 rank-7 weapon stays about
  /// 1.3–1.4× the best boss legendary (see the band test).
  static double powerMulFor(int rank) {
    final r = rank.clamp(1, absoluteMaxRank);
    if (r <= 3) return (106 + (r - 1) * 8) / 100;
    return (1220 + (r - 3) * 5) / 1000;
  }

  /// Primary+armor budget after the rank multiplier (before the stat split).
  static int powerBudget({
    required int itemLevel,
    required int rank,
    required EquipmentSlot slot,
    WeaponHanded? handed,
  }) {
    final base = EquipmentFactory.budgetForItemLevel(
      itemLevel: itemLevel,
      rarity: LootRarity.legendary,
      slot: slot,
      handed: handed,
    );
    return max(8, (base * powerMulFor(rank)).round());
  }

  /// Rebuild [item] at [ascensionLevel] and the same rank.
  ///
  /// Affixes and on-item effects stay. A piece with no class or role is
  /// left as it was saved.
  static EquipmentItem rebakeForAscend(EquipmentItem item, int ascensionLevel) {
    if (!item.isApex || item.apexRank < 1) return item;
    final className = item.apexClassId;
    final roleName = item.apexRoleTag;
    if (className == null || roleName == null) return item;
    final classId = _enumByName(HeroClassId.values, className);
    final role = _enumByName(SpecRoleTag.values, roleName);
    if (classId == null || role == null) return item;
    final fresh = buildItem(
      classId: classId,
      role: role,
      slot: item.slot,
      rank: item.apexRank,
      ascensionLevel: ascensionLevel,
    );
    return withKeptAffixes(fresh, item);
  }

  /// Keep id, affixes, effects, and a saved look when a piece is rebuilt.
  static EquipmentItem withKeptAffixes(
    EquipmentItem fresh,
    EquipmentItem prior,
  ) {
    return fresh.copyWith(
      id: prior.id,
      effectId: prior.effectId,
      effectValue: prior.effectValue,
      affixPrefixId: prior.affixPrefixId,
      affixSuffixId: prior.affixSuffixId,
      iconId: prior.iconId,
      visualSetId: prior.visualSetId,
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
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
    final preferredArmor = spec != null
        ? ClassProficiency.preferredArmor(spec, 80)
        : null;

    final ranked = rank.clamp(1, absoluteMaxRank);
    final baseIlvl = itemLevelFor(
      rank: ranked,
      ascensionLevel: ascensionLevel,
      slot: slot,
    );

    ArmorType? armorType;
    WeaponType? weaponType;
    WeaponHanded? handed;
    OffHandKind? offHandKind;
    ProjectilePattern pattern = ProjectilePattern.single;

    if (slot.isArmorSlot || slot == EquipmentSlot.cloak) {
      armorType = preferredArmor ?? ArmorType.mail;
    } else if (slot == EquipmentSlot.weapon) {
      // If this recipe also crafts an off-hand, keep MH one-handed so the
      // Apex set is actually wearable together (no 2H staff + tome).
      var mh = spec != null
          ? _apexMainHandRaw(spec)
          : _mainHandFor(affinity, role);
      final ohKind = apexOffHandKind(classId, role);
      if (ohKind != null && mh.$2 == WeaponHanded.twoHand && spec != null) {
        mh = _apexOneHandFor(spec);
      }
      weaponType = mh.$1;
      handed = mh.$2;
      pattern = switch (role) {
        SpecRoleTag.caster || SpecRoleTag.healer => ProjectilePattern.arc,
        SpecRoleTag.rangedDps => ProjectilePattern.pierce,
        _ => ProjectilePattern.single,
      };
    } else if (slot == EquipmentSlot.offHand) {
      final kind = apexOffHandKind(classId, role);
      if (kind == OffHandKind.shield) {
        offHandKind = OffHandKind.shield;
      } else if (kind == OffHandKind.frill) {
        offHandKind = OffHandKind.frill;
      } else if (kind == OffHandKind.weapon) {
        offHandKind = OffHandKind.weapon;
        weaponType = spec != null ? _apexOneHandFor(spec).$1 : WeaponType.sword;
        handed = WeaponHanded.oneHand;
      } else {
        // Caller should not request OH when kind is null.
        offHandKind = OffHandKind.frill;
      }
    }

    // Same ilvl→budget curve as dungeon drops (legendary quality + rank mul).
    // Armor is carved from the pool (not stacked on top) — matches EquipmentFactory.create.
    final budget = powerBudget(
      itemLevel: baseIlvl,
      rank: ranked,
      slot: slot,
      handed: handed,
    );

    final needsArmor =
        slot.isArmorSlot ||
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

    // Same primary split as dungeon drops (CombatRatings ROI). Never dump
    // leftover budget into attackBonus — that field is flat ATK (1 = 1 sheet
    // ATK) while 1 Str/Agi is only ~0.5 ATK.
    final dist = EquipmentFactory.distributePrimaries(
      pool,
      EquipStatWeights.lootShares(
        bias: affinity,
        roleTag: role,
        specId: spec?.id,
      ),
    );
    final str = dist.str;
    final agi = dist.agi;
    final sta = dist.sta;
    final intel = dist.intel;
    final spi = dist.spi;
    final sp = dist.sp;
    const ap = 0;
    var crit = 0;
    var aspd = 0;
    var mp5 = 0;
    var mastery = 0;
    final secTier = max(0, (baseIlvl - 5) ~/ 18);
    switch (role) {
      case SpecRoleTag.tank:
        crit = 2 + ranked + secTier ~/ 2;
        mastery = 1 + ranked ~/ 2;
      case SpecRoleTag.healer:
        mp5 = 2 + ranked + secTier ~/ 2;
        crit = 1 + ranked + secTier ~/ 3;
        aspd = 1 + ranked ~/ 2;
      case SpecRoleTag.meleeDps:
        crit = 3 + ranked * 2 + secTier ~/ 2;
        aspd = 2 + ranked + secTier ~/ 2;
      case SpecRoleTag.rangedDps:
        crit = 4 + ranked * 2 + secTier ~/ 2;
        aspd = 3 + ranked + secTier ~/ 2;
      case SpecRoleTag.caster:
        crit = 3 + ranked * 2 + secTier ~/ 2;
        aspd = 2 + ranked ~/ 2;
    }
    crit = EquipmentFactory.lootCritPercent(crit);

    final piece = EquipmentItem(
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
      mp5Bonus: mp5,
      masteryBonus: mastery,
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
      apexRank: ranked,
    );
    // Same look every rank — seed is the fixed piece id.
    return EquipmentVisualResolver.stampLook(
      piece,
      Random(EquipmentVisualResolver.stableSeed(piece.id)),
    );
  }

  static int max(int a, int b) => a > b ? a : b;

  /// Fantasy main-hand before off-hand pairing adjustments.
  static (WeaponType, WeaponHanded) _apexMainHandRaw(HeroSpecDef spec) {
    return switch (spec.id) {
      HeroSpecId.protection ||
      HeroSpecId.holyPaladin ||
      HeroSpecId.protPaladin ||
      HeroSpecId.restorationShaman ||
      HeroSpecId.discipline ||
      HeroSpecId.holyPriest => (WeaponType.mace, WeaponHanded.oneHand),
      HeroSpecId.arms ||
      HeroSpecId.retribution ||
      HeroSpecId.unholy => (WeaponType.sword, WeaponHanded.twoHand),
      HeroSpecId.fury ||
      HeroSpecId.frostDk ||
      HeroSpecId.enhancement => (WeaponType.axe, WeaponHanded.oneHand),
      HeroSpecId.blood => (WeaponType.mace, WeaponHanded.twoHand),
      HeroSpecId.beastMastery ||
      HeroSpecId.marksmanship ||
      HeroSpecId.survival => (WeaponType.bow, WeaponHanded.twoHand),
      HeroSpecId.feral ||
      HeroSpecId.guardian => (WeaponType.polearm, WeaponHanded.twoHand),
      HeroSpecId.assassination ||
      HeroSpecId.combat ||
      HeroSpecId.subtlety => (WeaponType.dagger, WeaponHanded.oneHand),
      HeroSpecId.shadow ||
      HeroSpecId.elemental ||
      HeroSpecId.balance ||
      HeroSpecId.restorationDruid ||
      HeroSpecId.arcane ||
      HeroSpecId.fire ||
      HeroSpecId.frostMage ||
      HeroSpecId.affliction ||
      HeroSpecId.demonology ||
      HeroSpecId.destruction => (WeaponType.staff, WeaponHanded.twoHand),
    };
  }

  /// Legal one-hand when an Apex off-hand is part of the same recipe.
  static (WeaponType, WeaponHanded) _apexOneHandFor(HeroSpecDef spec) {
    final candidates = <(WeaponType, WeaponHanded)>[
      (WeaponType.mace, WeaponHanded.oneHand),
      (WeaponType.sword, WeaponHanded.oneHand),
      (WeaponType.axe, WeaponHanded.oneHand),
      (WeaponType.dagger, WeaponHanded.oneHand),
      (WeaponType.fist, WeaponHanded.oneHand),
    ];
    for (final c in candidates) {
      if (ClassProficiency.canEquipWeaponForSpec(
        spec,
        c.$1,
        c.$2,
        rangedSlot: false,
      )) {
        return c;
      }
    }
    return (WeaponType.dagger, WeaponHanded.oneHand);
  }

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
