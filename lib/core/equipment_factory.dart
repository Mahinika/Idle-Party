import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/dungeon_def.dart';
import '../models/equip_stat_weights.dart';
import '../models/gear_set.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';

/// Affix definition loaded from `item_affixes.json`.
class ItemAffixDef {
  const ItemAffixDef({
    required this.id,
    required this.name,
    this.str = 0,
    this.agi = 0,
    this.sta = 0,
    this.intel = 0,
    this.spi = 0,
    this.sp = 0,
    this.crit = 0,
    this.aspd = 0,
  });

  final String id;
  final String name;
  final int str;
  final int agi;
  final int sta;
  final int intel;
  final int spi;
  final int sp;
  final int crit;
  final int aspd;

  double get weightSum =>
      (str + agi + sta + intel + spi + sp + crit + aspd).toDouble();

  factory ItemAffixDef.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return ItemAffixDef(
      id: (json['id'] ?? json['name'] ?? 'affix').toString(),
      name: (json['name'] ?? json['id'] ?? 'Affix').toString(),
      str: asInt(json['str']),
      agi: asInt(json['agi']),
      sta: asInt(json['sta']),
      intel: asInt(json['int'] ?? json['intel']),
      spi: asInt(json['spi']),
      sp: asInt(json['sp']),
      crit: asInt(json['crit']),
      aspd: asInt(json['aspd']),
    );
  }
}

/// Typed Classic-style equipment rolls (stat budgets by armor/weapon type).
class EquipmentFactory {
  EquipmentFactory._();

  static Random random = Random();

  static const List<ItemAffixDef> _fallbackPrefixes = <ItemAffixDef>[
    ItemAffixDef(id: 'savage', name: 'Savage', agi: 1, str: 1),
    ItemAffixDef(id: 'blessed', name: 'Blessed', spi: 1, sta: 1),
    ItemAffixDef(id: 'runed', name: 'Runed', sp: 1, intel: 1),
    ItemAffixDef(id: 'ashen', name: 'Ashen', str: 1),
    ItemAffixDef(id: 'feral', name: 'Feral', agi: 1),
  ];

  static const List<ItemAffixDef> _fallbackSuffixes = <ItemAffixDef>[
    ItemAffixDef(id: 'of_the_bear', name: 'of the Bear', sta: 1),
    ItemAffixDef(id: 'of_the_tiger', name: 'of the Tiger', agi: 1),
    ItemAffixDef(id: 'of_power', name: 'of Power', sp: 1),
    ItemAffixDef(id: 'of_the_owl', name: 'of the Owl', intel: 1),
  ];

  static List<ItemAffixDef> _prefixes = _fallbackPrefixes;
  static List<ItemAffixDef> _suffixes = _fallbackSuffixes;

  /// Legacy string list for tests that inspect prefix names.
  static List<String> get affixPrefixes =>
      List<String>.unmodifiable(_prefixes.map((a) => a.name));

  static List<ItemAffixDef> get affixPrefixDefs => _prefixes;
  static List<ItemAffixDef> get affixSuffixDefs => _suffixes;

  static String? affixNameById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in _prefixes) {
      if (a.id == id) return a.name;
    }
    for (final a in _suffixes) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  /// Loads `assets/data/item_affixes.json`. Falls back silently on error.
  static Future<void> loadAffixes({AssetBundle? bundle}) async {
    try {
      final raw =
          await (bundle ?? rootBundle).loadString('assets/data/item_affixes.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _prefixes = _fallbackPrefixes;
        _suffixes = _fallbackSuffixes;
        return;
      }
      final prefixRaw = decoded['prefixes'];
      final suffixRaw = decoded['suffixes'];
      final parsedPrefixes = _parseAffixList(prefixRaw);
      final parsedSuffixes = _parseAffixList(suffixRaw);
      if (parsedPrefixes.isNotEmpty) {
        _prefixes = List<ItemAffixDef>.unmodifiable(parsedPrefixes);
      }
      if (parsedSuffixes.isNotEmpty) {
        _suffixes = List<ItemAffixDef>.unmodifiable(parsedSuffixes);
      }
    } catch (_) {
      _prefixes = _fallbackPrefixes;
      _suffixes = _fallbackSuffixes;
    }
  }

  static List<ItemAffixDef> _parseAffixList(dynamic raw) {
    if (raw is! List) return const <ItemAffixDef>[];
    final out = <ItemAffixDef>[];
    for (final e in raw) {
      if (e is String) {
        final id = e.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        out.add(ItemAffixDef(id: id, name: e, sta: 1));
      } else if (e is Map) {
        out.add(ItemAffixDef.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  /// Zone mult matching [GameLogic.roomCombatBudget] enemy scaling.
  static double zoneMultFor(String? dungeonId) {
    final zone = DungeonCatalog.byId(dungeonId ?? 'sandy').number;
    return 1.0 + zone * 0.28;
  }

  /// Soft AL loot mult (half of enemy AL threat; AL already has drop skip).
  static double alLootMult(int ascensionLevel) =>
      1.0 + ascensionLevel.clamp(0, 40) * 0.05;

  static int itemLevelFor({
    required int battleNumber,
    required LootRarity rarity,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) {
    final zone = DungeonCatalog.byId(dungeonId ?? 'sandy').number;
    final base = max(1, battleNumber * 2 + rarity.index * 4 + 3);
    var ilvl = max(
      1,
      base +
          zone * 4 +
          ascensionLevel.clamp(0, 40) * 2 +
          hardmodeLevel.clamp(0, 20) ~/ 4,
    );
    // Soft-cap endless Crystal/Gauntlet display so auto-sell stays usable.
    if (ilvl > 100) {
      ilvl = 100 + ((ilvl - 100) * 0.35).round();
    }
    return ilvl;
  }

  /// Classic-style slot budget multipliers (MH full; jewelry/wrist softer).
  static double slotMult(EquipmentSlot slot, {WeaponHanded? handed}) {
    if (slot == EquipmentSlot.weapon && handed == WeaponHanded.twoHand) {
      return 1.15;
    }
    return switch (slot) {
      EquipmentSlot.head ||
      EquipmentSlot.chest ||
      EquipmentSlot.legs ||
      EquipmentSlot.weapon =>
        1.0,
      EquipmentSlot.shoulder ||
      EquipmentSlot.hands ||
      EquipmentSlot.waist ||
      EquipmentSlot.boots =>
        0.75,
      EquipmentSlot.offHand => 0.55,
      EquipmentSlot.ranged => 0.50,
      EquipmentSlot.wrist ||
      EquipmentSlot.cloak ||
      EquipmentSlot.neck ||
      EquipmentSlot.ring ||
      EquipmentSlot.ring2 ||
      EquipmentSlot.trinket ||
      EquipmentSlot.trinket2 =>
        0.55,
      EquipmentSlot.consumable => 0.40,
    };
  }

  static int _budget({
    required LootRarity rarity,
    required int battleNumber,
    EquipmentSlot? slot,
    WeaponHanded? handed,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) {
    // Continuous floor growth (aligned with ilvl +2/floor pacing).
    // Old band was ~/8; per-floor rates keep the same milestone averages.
    final floorProgress = max(0, battleNumber - 1);
    final perFloor = switch (rarity) {
      LootRarity.common => 0.25,
      LootRarity.uncommon => 0.25,
      LootRarity.rare => 0.375,
      LootRarity.epic => 0.5,
      LootRarity.legendary => 0.625,
    };
    final base = switch (rarity) {
          LootRarity.common => 6.0,
          LootRarity.uncommon => 10.0,
          LootRarity.rare => 16.0,
          LootRarity.epic => 24.0,
          LootRarity.legendary => 36.0,
        } +
        floorProgress * perFloor;
    final slotM = slot == null ? 1.0 : slotMult(slot, handed: handed);
    final hmMult = 1.0 + hardmodeLevel.clamp(0, 20) * 0.0125;
    final scaled = base *
        slotM *
        zoneMultFor(dungeonId) *
        alLootMult(ascensionLevel) *
        hmMult;
    return max(3, scaled.round());
  }

  static ArmorType armorTypeFor(
    HeroRole bias,
    int level, {
    ArmorType? preferred,
  }) {
    if (preferred != null && random.nextDouble() < 0.82) {
      return preferred;
    }
    return switch (bias) {
      HeroRole.warrior =>
        level >= 40 && random.nextDouble() < 0.55
            ? ArmorType.plate
            : (random.nextDouble() < 0.7 ? ArmorType.mail : ArmorType.leather),
      HeroRole.rogue => preferred == ArmorType.mail && random.nextDouble() < 0.8
          ? ArmorType.mail
          : (random.nextDouble() < 0.85 ? ArmorType.leather : ArmorType.cloth),
      HeroRole.healer || HeroRole.mage =>
        (preferred == ArmorType.mail ||
                preferred == ArmorType.plate ||
                preferred == ArmorType.leather) &&
            random.nextDouble() < 0.8
        ? preferred!
        : ArmorType.cloth,
    };
  }

  static (WeaponType, WeaponHanded) mainHandFor(HeroRole bias) {
    return switch (bias) {
      HeroRole.warrior => () {
          final roll = random.nextDouble();
          if (roll < 0.35) {
            return (WeaponType.mace, WeaponHanded.oneHand);
          }
          if (roll < 0.55) {
            return (WeaponType.sword, WeaponHanded.oneHand);
          }
          if (roll < 0.7) {
            return (WeaponType.axe, WeaponHanded.oneHand);
          }
          if (roll < 0.82) {
            return (WeaponType.sword, WeaponHanded.twoHand);
          }
          if (roll < 0.9) return (WeaponType.polearm, WeaponHanded.twoHand);
          if (roll < 0.95) return (WeaponType.axe, WeaponHanded.twoHand);
          return (WeaponType.fist, WeaponHanded.oneHand);
        }(),
      HeroRole.rogue => () {
          final roll = random.nextDouble();
          if (roll < 0.45) {
            return (WeaponType.dagger, WeaponHanded.oneHand);
          }
          if (roll < 0.7) {
            return (WeaponType.sword, WeaponHanded.oneHand);
          }
          if (roll < 0.88) {
            return (WeaponType.fist, WeaponHanded.oneHand);
          }
          return (WeaponType.mace, WeaponHanded.oneHand);
        }(),
      HeroRole.healer => () {
          final roll = random.nextDouble();
          if (roll < 0.55) return (WeaponType.staff, WeaponHanded.twoHand);
          if (roll < 0.85) {
            return (WeaponType.mace, WeaponHanded.oneHand);
          }
          return (WeaponType.dagger, WeaponHanded.oneHand);
        }(),
      HeroRole.mage => () {
          final roll = random.nextDouble();
          if (roll < 0.55) return (WeaponType.staff, WeaponHanded.twoHand);
          if (roll < 0.85) {
            return (WeaponType.sword, WeaponHanded.oneHand);
          }
          return (WeaponType.dagger, WeaponHanded.oneHand);
        }(),
    };
  }

  static WeaponType rangedFor(HeroRole bias) {
    return switch (bias) {
      HeroRole.healer || HeroRole.mage => WeaponType.wand,
      _ => [
          WeaponType.bow,
          WeaponType.crossbow,
          WeaponType.gun,
          WeaponType.thrown,
        ][random.nextInt(4)],
    };
  }

  static List<double> _armorWeights(
    ArmorType type,
    HeroRole bias, {
    SpecRoleTag? roleTag,
  }) {
    // Plate tanks get a touch more Sta; cloth casters keep Int/SP from shares.
    if (type == ArmorType.plate && roleTag == SpecRoleTag.tank) {
      return const [0.25, 0.10, 0.55, 0.0, 0.05, 0.05];
    }
    return EquipStatWeights.lootShares(bias: bias, roleTag: roleTag);
  }

  static List<double> _weaponWeights(
    WeaponType type,
    HeroRole bias, {
    SpecRoleTag? roleTag,
  }) {
    if (type == WeaponType.staff || type == WeaponType.wand) {
      return EquipStatWeights.lootShares(
        bias: HeroRole.mage,
        roleTag: roleTag ?? SpecRoleTag.caster,
      );
    }
    if (type == WeaponType.bow ||
        type == WeaponType.crossbow ||
        type == WeaponType.gun ||
        type == WeaponType.thrown) {
      return EquipStatWeights.lootShares(
        bias: HeroRole.rogue,
        roleTag: roleTag ?? SpecRoleTag.rangedDps,
      );
    }
    return EquipStatWeights.lootShares(bias: bias, roleTag: roleTag);
  }

  static List<double> _offHandWeights(
    OffHandKind kind, {
    HeroRole bias = HeroRole.warrior,
    SpecRoleTag? roleTag,
  }) =>
      switch (kind) {
        OffHandKind.shield => const [0.25, 0.10, 0.55, 0.0, 0.05, 0.05],
        OffHandKind.weapon => EquipStatWeights.lootShares(
            bias: bias,
            roleTag: roleTag ?? SpecRoleTag.meleeDps,
          ),
        OffHandKind.frill => EquipStatWeights.lootShares(
            bias: bias == HeroRole.rogue ? HeroRole.healer : bias,
            roleTag: roleTag ??
                (bias == HeroRole.mage
                    ? SpecRoleTag.caster
                    : SpecRoleTag.healer),
          ),
      };

  static List<double> _jewelryWeights(
    HeroRole bias, {
    SpecRoleTag? roleTag,
  }) =>
      EquipStatWeights.lootShares(bias: bias, roleTag: roleTag);

  static ({int str, int agi, int sta, int intel, int spi, int sp}) _distribute(
    int budget,
    List<double> w,
  ) {
    final sum = w.fold<double>(0, (a, b) => a + b);
    if (sum <= 0 || budget <= 0) {
      return (str: 0, agi: 0, sta: 0, intel: 0, spi: 0, sp: 0);
    }
    int alloc(int i) => max(0, (budget * w[i] / sum).round());
    return (
      str: alloc(0),
      agi: alloc(1),
      sta: alloc(2),
      intel: alloc(3),
      spi: alloc(4),
      sp: alloc(5),
    );
  }

  static int _armorPoints(ArmorType? type, int budget) {
    if (type == null) return max(1, budget ~/ 4);
    return switch (type) {
      ArmorType.cloth => max(0, budget ~/ 8),
      ArmorType.leather => max(1, budget ~/ 5),
      ArmorType.mail => max(2, budget ~/ 3),
      ArmorType.plate => max(3, budget ~/ 2),
    };
  }

  static List<ItemAffixDef> _affixesForBias(
    List<ItemAffixDef> pool,
    HeroRole bias, {
    SpecRoleTag? roleTag,
  }) {
    bool matches(ItemAffixDef a) {
      final melee = a.str + a.agi + a.sta + a.crit + a.aspd;
      final caster = a.intel + a.sp; // Spirit is regen — don't require it
      final spiHeavy = a.spi > a.intel + a.sp;
      return switch (roleTag ?? _fallbackTag(bias)) {
        SpecRoleTag.tank => melee >= caster && a.sta + a.str >= a.agi,
        SpecRoleTag.healer =>
          (a.intel + a.sp + a.spi) >= melee || caster > 0,
        SpecRoleTag.caster => caster >= melee || a.intel + a.sp > 0,
        SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
          bias == HeroRole.warrior
              ? a.str + a.sta + a.crit >= caster
              : a.agi + a.str + a.crit + a.aspd >= caster,
      } &&
          // Prefer throughput affixes over pure Spirit for casters/healers.
          !(spiHeavy &&
              (roleTag == SpecRoleTag.caster || roleTag == SpecRoleTag.healer));
    }

    final filtered = [for (final a in pool) if (matches(a)) a];
    return filtered.isNotEmpty ? filtered : pool;
  }

  static SpecRoleTag _fallbackTag(HeroRole bias) => switch (bias) {
        HeroRole.warrior => SpecRoleTag.meleeDps,
        HeroRole.rogue => SpecRoleTag.meleeDps,
        HeroRole.healer => SpecRoleTag.healer,
        HeroRole.mage => SpecRoleTag.caster,
      };

  /// Apply affix weights as a slice of [affixBudget] (stat points).
  static ({
    int str,
    int agi,
    int sta,
    int intel,
    int spi,
    int sp,
    int crit,
    int aspd,
  }) _affixStats(ItemAffixDef affix, int affixBudget) {
    final w = affix.weightSum;
    if (w <= 0 || affixBudget <= 0) {
      return (str: 0, agi: 0, sta: 0, intel: 0, spi: 0, sp: 0, crit: 0, aspd: 0);
    }
    int part(int weight) =>
        weight <= 0 ? 0 : max(1, (affixBudget * weight / w).round());
    return (
      str: part(affix.str),
      agi: part(affix.agi),
      sta: part(affix.sta),
      intel: part(affix.intel),
      spi: part(affix.spi),
      sp: part(affix.sp),
      crit: part(affix.crit),
      aspd: part(affix.aspd),
    );
  }

  static String equipmentNameFor({
    required EquipmentSlot slot,
    required LootRarity rarity,
    HeroRole? bias,
    ArmorType? armorType,
    WeaponType? weaponType,
    OffHandKind? offHandKind,
    WeaponHanded? handed,
    String? affixPrefix,
    String? affixSuffix,
  }) {
    final rolePrefix = switch (bias) {
      HeroRole.warrior => switch (rarity) {
          LootRarity.common => 'Guard',
          LootRarity.uncommon => 'Bulwark',
          LootRarity.rare => 'Aegis',
          LootRarity.epic => 'Titan',
          LootRarity.legendary => 'Eternal',
        },
      HeroRole.healer => switch (rarity) {
          LootRarity.common => 'Soft',
          LootRarity.uncommon => 'Mending',
          LootRarity.rare => 'Sanctum',
          LootRarity.epic => 'Aurora',
          LootRarity.legendary => 'Celestial',
        },
      HeroRole.mage => switch (rarity) {
          LootRarity.common => 'Spark',
          LootRarity.uncommon => 'Arcane',
          LootRarity.rare => 'Runic',
          LootRarity.epic => 'Astral',
          LootRarity.legendary => 'Voidforged',
        },
      HeroRole.rogue => switch (rarity) {
          LootRarity.common => 'Swift',
          LootRarity.uncommon => 'Shadow',
          LootRarity.rare => 'Viper',
          LootRarity.epic => 'Night',
          LootRarity.legendary => 'Assassin',
        },
      null => switch (rarity) {
          LootRarity.common => 'Iron',
          LootRarity.uncommon => 'Hunter',
          LootRarity.rare => 'Rune',
          LootRarity.epic => 'Mythic',
          LootRarity.legendary => 'Legendary',
        },
    };

    final material = switch (armorType) {
      ArmorType.cloth => 'Cloth',
      ArmorType.leather => 'Leather',
      ArmorType.mail => 'Mail',
      ArmorType.plate => 'Plate',
      null => null,
    };

    final noun = () {
      if (offHandKind == OffHandKind.shield) return 'Tower Shield';
      if (offHandKind == OffHandKind.frill) return 'Tome';
      if (offHandKind == OffHandKind.weapon && weaponType != null) {
        return 'Off-hand ${_weaponNoun(weaponType)}';
      }
      if (weaponType != null) {
        final hand = handed == WeaponHanded.twoHand ? '2H ' : '';
        return '$hand${_weaponNoun(weaponType)}';
      }
      return switch (slot) {
        EquipmentSlot.head => material == null ? 'Helm' : '$material Helm',
        EquipmentSlot.shoulder =>
          material == null ? 'Pauldrons' : '$material Pauldrons',
        EquipmentSlot.chest =>
          material == null ? 'Chestguard' : '$material Chestguard',
        EquipmentSlot.waist => material == null ? 'Belt' : '$material Belt',
        EquipmentSlot.legs =>
          material == null ? 'Legguards' : '$material Legguards',
        EquipmentSlot.boots => material == null ? 'Boots' : '$material Boots',
        EquipmentSlot.wrist =>
          material == null ? 'Bracers' : '$material Bracers',
        EquipmentSlot.hands =>
          material == null ? 'Gloves' : '$material Gloves',
        EquipmentSlot.cloak => 'Cloak',
        EquipmentSlot.neck => 'Amulet',
        EquipmentSlot.ring || EquipmentSlot.ring2 => 'Ring',
        EquipmentSlot.trinket || EquipmentSlot.trinket2 => 'Trinket',
        EquipmentSlot.consumable => 'Flask',
        EquipmentSlot.weapon => 'Weapon',
        EquipmentSlot.ranged => 'Ranged',
        EquipmentSlot.offHand => 'Off-hand',
      };
    }();

    final base = (material != null && !noun.contains(material) && slot.isArmorSlot)
        ? '$rolePrefix $material $noun'
        : '$rolePrefix $noun';
    final withPrefix = affixPrefix == null ? base : '$affixPrefix $base';
    return affixSuffix == null ? withPrefix : '$withPrefix $affixSuffix';
  }

  static String _weaponNoun(WeaponType t) => switch (t) {
        WeaponType.axe => 'Axe',
        WeaponType.sword => 'Sword',
        WeaponType.mace => 'Mace',
        WeaponType.dagger => 'Dagger',
        WeaponType.fist => 'Fist',
        WeaponType.staff => 'Staff',
        WeaponType.polearm => 'Polearm',
        WeaponType.bow => 'Bow',
        WeaponType.crossbow => 'Crossbow',
        WeaponType.gun => 'Gun',
        WeaponType.thrown => 'Thrown',
        WeaponType.wand => 'Wand',
      };

  static EquipmentItem create({
    required EquipmentSlot slot,
    required LootRarity rarity,
    required int battleNumber,
    HeroRole? bias,
    ArmorType? preferredArmor,
    SpecRoleTag? roleTag,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) {
    final classBias = bias ?? HeroRole.values[random.nextInt(4)];
    final dungeon = dungeonId ?? 'sandy';

    ArmorType? armorType;
    WeaponType? weaponType;
    WeaponHanded? handed;
    OffHandKind? offHandKind;
    List<double> weights;

    if (slot.isArmorSlot) {
      armorType = armorTypeFor(
        classBias,
        max(1, battleNumber),
        preferred: preferredArmor,
      );
      weights = _armorWeights(armorType, classBias, roleTag: roleTag);
    } else if (slot == EquipmentSlot.weapon) {
      final mh = mainHandFor(classBias);
      weaponType = mh.$1;
      handed = mh.$2;
      weights = _weaponWeights(weaponType, classBias, roleTag: roleTag);
    } else if (slot == EquipmentSlot.ranged) {
      weaponType = rangedFor(classBias);
      handed = ClassProficiency.defaultHanded(weaponType);
      weights = _weaponWeights(weaponType, classBias, roleTag: roleTag);
    } else if (slot == EquipmentSlot.offHand) {
      if (classBias == HeroRole.warrior) {
        offHandKind = OffHandKind.shield;
        weights = _offHandWeights(
          OffHandKind.shield,
          bias: classBias,
          roleTag: roleTag,
        );
      } else if (classBias == HeroRole.rogue) {
        offHandKind = OffHandKind.weapon;
        final opts = [
          WeaponType.dagger,
          WeaponType.sword,
          WeaponType.fist,
          WeaponType.mace,
        ];
        weaponType = opts[random.nextInt(opts.length)];
        handed = WeaponHanded.oneHand;
        weights = _offHandWeights(
          OffHandKind.weapon,
          bias: classBias,
          roleTag: roleTag,
        );
      } else {
        offHandKind = OffHandKind.frill;
        weights = _offHandWeights(
          OffHandKind.frill,
          bias: classBias,
          roleTag: roleTag,
        );
      }
    } else if (slot == EquipmentSlot.cloak ||
        slot == EquipmentSlot.neck ||
        slot == EquipmentSlot.ring ||
        slot == EquipmentSlot.ring2 ||
        slot == EquipmentSlot.trinket ||
        slot == EquipmentSlot.trinket2) {
      weights = _jewelryWeights(classBias, roleTag: roleTag);
    } else {
      weights = _jewelryWeights(classBias, roleTag: roleTag);
    }

    if (slot == EquipmentSlot.offHand && classBias == HeroRole.warrior) {
      offHandKind = OffHandKind.shield;
      weaponType = null;
      handed = null;
      weights = _offHandWeights(
        OffHandKind.shield,
        bias: classBias,
        roleTag: roleTag,
      );
    }
    if (slot == EquipmentSlot.offHand &&
        (classBias == HeroRole.healer || classBias == HeroRole.mage)) {
      offHandKind = OffHandKind.frill;
      weaponType = null;
      handed = null;
      weights = _offHandWeights(
        OffHandKind.frill,
        bias: classBias,
        roleTag: roleTag,
      );
    }

    // Pick affixes first so their budget slice can be reserved.
    ItemAffixDef? prefix;
    ItemAffixDef? suffix;
    final prefixChance = switch (rarity) {
      LootRarity.rare => 0.40,
      LootRarity.epic => 0.70,
      LootRarity.legendary => 0.92,
      _ => 0.0,
    };
    final suffixChance = switch (rarity) {
      LootRarity.rare => 0.35,
      LootRarity.epic => 0.60,
      LootRarity.legendary => 0.85,
      _ => 0.0,
    };
    final prefixPool = _affixesForBias(_prefixes, classBias, roleTag: roleTag);
    final suffixPool = _affixesForBias(_suffixes, classBias, roleTag: roleTag);
    if (prefixChance > 0 &&
        prefixPool.isNotEmpty &&
        random.nextDouble() < prefixChance) {
      prefix = prefixPool[random.nextInt(prefixPool.length)];
    }
    if (suffixChance > 0 &&
        suffixPool.isNotEmpty &&
        random.nextDouble() < suffixChance) {
      suffix = suffixPool[random.nextInt(suffixPool.length)];
    }

    final rawBudget = _budget(
      rarity: rarity,
      battleNumber: battleNumber,
      slot: slot,
      handed: handed,
      dungeonId: dungeon,
      ascensionLevel: ascensionLevel,
      hardmodeLevel: hardmodeLevel,
    );
    final affixCount = (prefix != null ? 1 : 0) + (suffix != null ? 1 : 0);
    final affixFrac = affixCount == 0
        ? 0.0
        : (0.15 + rarity.index * 0.02).clamp(0.15, 0.25);
    final affixPool = (rawBudget * affixFrac).round();
    final primaryBudget = max(1, rawBudget - affixPool);
    final perAffix = affixCount == 0 ? 0 : max(1, affixPool ~/ affixCount);

    final iLvl = itemLevelFor(
      battleNumber: battleNumber,
      rarity: rarity,
      dungeonId: dungeon,
      ascensionLevel: ascensionLevel,
      hardmodeLevel: hardmodeLevel,
    );

    // Armor density reserved from primary budget (not stacked on top).
    final armorPts = slot.isArmorSlot ||
            (slot == EquipmentSlot.offHand && offHandKind == OffHandKind.shield)
        ? _armorPoints(
            armorType ??
                (offHandKind == OffHandKind.shield ? ArmorType.plate : null),
            primaryBudget,
          )
        : 0;
    final distributeBudget = max(1, primaryBudget - armorPts);

    final dist = _distribute(distributeBudget, weights);
    var str = dist.str;
    var agi = dist.agi;
    var sta = dist.sta;
    var intel = dist.intel;
    var spi = dist.spi;
    var sp = dist.sp;
    var crit = 0;
    var aspd = 0;
    var move = 0;
    var mp5 = 0;

    void applyAffix(ItemAffixDef a) {
      final s = _affixStats(a, perAffix);
      str += s.str;
      agi += s.agi;
      sta += s.sta;
      intel += s.intel;
      spi += s.spi;
      sp += s.sp;
      crit += s.crit;
      aspd += s.aspd;
    }

    if (prefix != null) applyAffix(prefix);
    if (suffix != null) applyAffix(suffix);

    if (armorType == ArmorType.leather ||
        weaponType == WeaponType.dagger ||
        weaponType == WeaponType.bow ||
        weaponType == WeaponType.crossbow ||
        weaponType == WeaponType.gun ||
        weaponType == WeaponType.thrown ||
        classBias == HeroRole.rogue) {
      crit = max(crit, rarity.index + (random.nextDouble() < 0.5 ? 1 : 0));
    }
    if (armorType == ArmorType.cloth ||
        weaponType == WeaponType.staff ||
        weaponType == WeaponType.wand ||
        offHandKind == OffHandKind.frill) {
      mp5 = rarity.index >= 1 ? 1 + rarity.index : 0;
      if (random.nextDouble() < 0.4) crit = max(crit, rarity.index);
    }
    if (slot == EquipmentSlot.boots) {
      move = 3 + rarity.index * 2;
      aspd = max(aspd, 1 + rarity.index);
    }
    if (slot == EquipmentSlot.weapon || slot == EquipmentSlot.hands) {
      aspd = max(aspd, 1 + rarity.index);
    }

    var effectId = GearEffectId.none;
    var effectValue = 0;
    final effectChance = switch (rarity) {
      LootRarity.common => 0.28,
      LootRarity.uncommon => 0.55,
      LootRarity.rare => 0.78,
      LootRarity.epic => 0.92,
      LootRarity.legendary => 1.0,
    };
    if (random.nextDouble() < effectChance) {
      effectId = switch (classBias) {
        HeroRole.warrior => random.nextDouble() < 0.55
            ? GearEffectId.lifesteal
            : (random.nextBool() ? GearEffectId.goldFind : GearEffectId.haste),
        HeroRole.healer => random.nextDouble() < 0.55
            ? GearEffectId.haste
            : (random.nextBool()
                ? GearEffectId.lifesteal
                : GearEffectId.goldFind),
        HeroRole.mage => random.nextDouble() < 0.5
            ? GearEffectId.pierce
            : (random.nextBool() ? GearEffectId.haste : GearEffectId.crit),
        HeroRole.rogue => random.nextDouble() < 0.55
            ? GearEffectId.crit
            : (random.nextBool() ? GearEffectId.haste : GearEffectId.lifesteal),
      };
      effectValue = switch (effectId) {
        GearEffectId.lifesteal => 3 + rarity.index * 2,
        GearEffectId.pierce => 1,
        GearEffectId.goldFind => 6 + rarity.index * 4,
        GearEffectId.crit => 3 + rarity.index * 2,
        GearEffectId.haste => 3 + rarity.index * 2,
        GearEffectId.none => 0,
      };
    }

    final pattern = slot == EquipmentSlot.weapon
        ? switch (classBias) {
            HeroRole.mage => rarity.index >= 2
                ? ProjectilePattern.pierce
                : ProjectilePattern.arc,
            HeroRole.rogue => rarity.index >= 1
                ? ProjectilePattern.spread
                : ProjectilePattern.single,
            HeroRole.warrior => ProjectilePattern.single,
            HeroRole.healer => rarity.index >= 2
                ? ProjectilePattern.arc
                : ProjectilePattern.single,
          }
        : ProjectilePattern.single;

    final name = equipmentNameFor(
      slot: slot,
      rarity: rarity,
      bias: classBias,
      armorType: armorType,
      weaponType: weaponType,
      offHandKind: offHandKind,
      handed: handed,
      affixPrefix: prefix?.name,
      affixSuffix: suffix?.name,
    );

    final setId = armorType == null
        ? null
        : GearSets.setIdFor(
            dungeonId: dungeon,
            armorType: armorType,
            rarity: rarity,
            slot: slot,
          );

    return EquipmentItem(
      id: '${slot.name}_${rarity.name}_${battleNumber}_${random.nextInt(100000)}',
      name: name,
      slot: slot,
      rarity: rarity,
      strengthBonus: str,
      agilityBonus: agi,
      staminaBonus: sta,
      intellectBonus: intel,
      spiritBonus: spi,
      spellPowerBonus: sp,
      armorBonus: armorPts,
      mp5Bonus: mp5,
      critChanceBonus: crit,
      attackSpeedBonus: aspd,
      moveSpeedBonus: move,
      pattern: pattern,
      effectId: effectId,
      effectValue: effectValue,
      affinity: classBias.name,
      itemLevel: iLvl,
      armorType: armorType,
      weaponType: weaponType,
      handed: handed,
      offHandKind: offHandKind,
      affixPrefixId: prefix?.id,
      affixSuffixId: suffix?.id,
      setId: setId,
    );
  }
}
