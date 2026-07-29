import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/hero.dart';
import '../models/loot.dart';
import '../models/proficiency.dart';

/// Typed Classic-style equipment rolls (stat budgets by armor/weapon type).
class EquipmentFactory {
  EquipmentFactory._();

  static Random get random => _random;
  static Random _random = Random();
  static set random(Random value) => _random = value;

  /// Hardcoded fallback used until (or unless) `assets/data/item_affixes.json`
  /// loads successfully — keeps loot naming working offline / in tests.
  static const List<String> _fallbackAffixes = <String>[
    'Ancient',
    'Cursed',
    'Gleaming',
    'Feral',
    'Sacred',
    'Ashen',
    'Frozen',
    'Runed',
    'Savage',
    'Blessed',
  ];

  static List<String> _affixPrefixes = _fallbackAffixes;

  /// Currently active affix prefix pool (data-driven when the load succeeds).
  static List<String> get affixPrefixes => _affixPrefixes;

  /// Loads `assets/data/item_affixes.json` into the affix prefix pool.
  /// Safe to call multiple times; falls back silently to the hardcoded
  /// list on any parse/asset error (offline-first, no crash risk).
  static Future<void> loadAffixes({AssetBundle? bundle}) async {
    try {
      final raw =
          await (bundle ?? rootBundle).loadString('assets/data/item_affixes.json');
      final decoded = jsonDecode(raw);
      final list = decoded is Map<String, dynamic>
          ? decoded['prefixes'] as List<dynamic>?
          : (decoded is List<dynamic> ? decoded : null);
      if (list != null && list.isNotEmpty) {
        _affixPrefixes = List<String>.unmodifiable(
          list.map((e) => e.toString()),
        );
      }
    } catch (_) {
      _affixPrefixes = _fallbackAffixes;
    }
  }

  static int itemLevelFor({
    required int battleNumber,
    required LootRarity rarity,
  }) =>
      max(1, battleNumber * 2 + rarity.index * 4 + 3);

  static int _budget({
    required LootRarity rarity,
    required int battleNumber,
    EquipmentSlot? slot,
  }) {
    final floorBonus = (battleNumber - 1) ~/ 8;
    final base = switch (rarity) {
      LootRarity.common => 6 + floorBonus * 2,
      LootRarity.uncommon => 10 + floorBonus * 2,
      LootRarity.rare => 16 + floorBonus * 3,
      LootRarity.epic => 24 + floorBonus * 4,
      LootRarity.legendary => 36 + floorBonus * 5,
    };
    // Jewelry / cloak used to be empty→full power spikes; keep them weaker.
    if (slot == EquipmentSlot.cloak ||
        slot == EquipmentSlot.neck ||
        slot == EquipmentSlot.ring ||
        slot == EquipmentSlot.ring2 ||
        slot == EquipmentSlot.trinket ||
        slot == EquipmentSlot.trinket2) {
      return max(3, (base * 0.62).round());
    }
    return base;
  }

  static ArmorType armorTypeFor(HeroRole bias, int level) {
    return switch (bias) {
      HeroRole.warrior =>
        level >= 40 && _random.nextDouble() < 0.55
            ? ArmorType.plate
            : (_random.nextDouble() < 0.7 ? ArmorType.mail : ArmorType.leather),
      HeroRole.rogue =>
        _random.nextDouble() < 0.85 ? ArmorType.leather : ArmorType.cloth,
      HeroRole.healer || HeroRole.mage => ArmorType.cloth,
    };
  }

  static (WeaponType, WeaponHanded) mainHandFor(HeroRole bias) {
    return switch (bias) {
      HeroRole.warrior => () {
          final roll = _random.nextDouble();
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
          final roll = _random.nextDouble();
          if (roll < 0.45) {
            return (WeaponType.dagger, WeaponHanded.oneHand);
          }
          if (roll < 0.7) {
            return (WeaponType.sword, WeaponHanded.oneHand);
          }
          if (roll < 0.85) {
            return (WeaponType.fist, WeaponHanded.oneHand);
          }
          return (WeaponType.mace, WeaponHanded.oneHand);
        }(),
      HeroRole.healer => () {
          final roll = _random.nextDouble();
          if (roll < 0.55) return (WeaponType.staff, WeaponHanded.twoHand);
          if (roll < 0.8) {
            return (WeaponType.mace, WeaponHanded.oneHand);
          }
          return (WeaponType.dagger, WeaponHanded.oneHand);
        }(),
      HeroRole.mage => () {
          final roll = _random.nextDouble();
          if (roll < 0.55) return (WeaponType.staff, WeaponHanded.twoHand);
          if (roll < 0.8) {
            return (WeaponType.sword, WeaponHanded.oneHand);
          }
          return (WeaponType.dagger, WeaponHanded.oneHand);
        }(),
    };
  }

  static WeaponType rangedFor(HeroRole bias) {
    return switch (bias) {
      HeroRole.healer || HeroRole.mage => WeaponType.wand,
      HeroRole.warrior || HeroRole.rogue => () {
          final opts = [
            WeaponType.bow,
            WeaponType.crossbow,
            WeaponType.gun,
            WeaponType.thrown,
          ];
          return opts[_random.nextInt(opts.length)];
        }(),
    };
  }

  /// Weights: Str, Agi, Sta, Int, Spi, SP (sum ≈ 1).
  static List<double> _armorWeights(ArmorType type) => switch (type) {
        ArmorType.cloth => [0, 0, 0.15, 0.40, 0.30, 0.25],
        ArmorType.leather => [0.15, 0.45, 0.25, 0, 0, 0],
        ArmorType.mail => [0.35, 0.10, 0.40, 0, 0, 0],
        ArmorType.plate => [0.30, 0.05, 0.45, 0, 0, 0],
      };

  static List<double> _weaponWeights(WeaponType type, HeroRole bias) {
    return switch (type) {
      WeaponType.axe ||
      WeaponType.sword ||
      WeaponType.mace ||
      WeaponType.polearm ||
      WeaponType.fist =>
        [0.45, 0.10, 0.35, 0, 0, 0],
      WeaponType.dagger => bias == HeroRole.healer || bias == HeroRole.mage
          ? [0, 0, 0.15, 0.35, 0.20, 0.30]
          : [0.15, 0.50, 0.25, 0, 0, 0],
      WeaponType.staff => [0, 0, 0.15, 0.35, 0.25, 0.25],
      WeaponType.wand => [0, 0, 0.10, 0.25, 0.15, 0.50],
      WeaponType.bow ||
      WeaponType.crossbow ||
      WeaponType.gun ||
      WeaponType.thrown =>
        [0.05, 0.50, 0.25, 0, 0, 0],
    };
  }

  static List<double> _offHandWeights(OffHandKind kind) => switch (kind) {
        OffHandKind.shield => [0.25, 0, 0.50, 0, 0, 0],
        OffHandKind.frill => [0, 0, 0.15, 0.35, 0.25, 0.25],
        OffHandKind.weapon => [0.15, 0.50, 0.20, 0, 0, 0],
      };

  static List<double> _jewelryWeights(HeroRole bias) => switch (bias) {
        HeroRole.warrior => [0.35, 0.10, 0.40, 0, 0, 0],
        HeroRole.rogue => [0.15, 0.50, 0.25, 0, 0, 0],
        HeroRole.healer => [0, 0, 0.15, 0.30, 0.35, 0.30],
        HeroRole.mage => [0, 0, 0.10, 0.40, 0.20, 0.35],
      };

  static ({
    int str,
    int agi,
    int sta,
    int intel,
    int spi,
    int sp,
  }) _distribute(int budget, List<double> w) {
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

  static String equipmentNameFor({
    required EquipmentSlot slot,
    required LootRarity rarity,
    HeroRole? bias,
    ArmorType? armorType,
    WeaponType? weaponType,
    OffHandKind? offHandKind,
    WeaponHanded? handed,
    String? affixWord,
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
    return affixWord == null ? base : '$affixWord $base';
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
  }) {
    final classBias = bias ?? HeroRole.values[_random.nextInt(4)];
    final budget = _budget(
      rarity: rarity,
      battleNumber: battleNumber,
      slot: slot,
    );
    final iLvl = itemLevelFor(battleNumber: battleNumber, rarity: rarity);

    ArmorType? armorType;
    WeaponType? weaponType;
    WeaponHanded? handed;
    OffHandKind? offHandKind;
    List<double> weights;

    if (slot.isArmorSlot) {
      armorType = armorTypeFor(classBias, max(1, battleNumber));
      weights = _armorWeights(armorType);
    } else if (slot == EquipmentSlot.weapon) {
      final mh = mainHandFor(classBias);
      weaponType = mh.$1;
      handed = mh.$2;
      weights = _weaponWeights(weaponType, classBias);
    } else if (slot == EquipmentSlot.ranged) {
      weaponType = rangedFor(classBias);
      handed = ClassProficiency.defaultHanded(weaponType);
      weights = _weaponWeights(weaponType, classBias);
    } else if (slot == EquipmentSlot.offHand) {
      if (classBias == HeroRole.warrior) {
        offHandKind = OffHandKind.shield;
        weights = _offHandWeights(OffHandKind.shield);
      } else if (classBias == HeroRole.rogue) {
        offHandKind = OffHandKind.weapon;
        final opts = [
          WeaponType.dagger,
          WeaponType.sword,
          WeaponType.fist,
          WeaponType.mace,
        ];
        weaponType = opts[_random.nextInt(opts.length)];
        handed = WeaponHanded.oneHand;
        weights = _offHandWeights(OffHandKind.weapon);
      } else {
        offHandKind = OffHandKind.frill;
        weights = _offHandWeights(OffHandKind.frill);
      }
    } else if (slot == EquipmentSlot.cloak ||
        slot == EquipmentSlot.neck ||
        slot == EquipmentSlot.ring ||
        slot == EquipmentSlot.ring2 ||
        slot == EquipmentSlot.trinket ||
        slot == EquipmentSlot.trinket2) {
      weights = _jewelryWeights(classBias);
    } else {
      // consumable
      weights = _jewelryWeights(classBias);
    }

    if (slot == EquipmentSlot.offHand && classBias == HeroRole.warrior) {
      offHandKind = OffHandKind.shield;
      weaponType = null;
      handed = null;
      weights = _offHandWeights(OffHandKind.shield);
    }
    if (slot == EquipmentSlot.offHand &&
        (classBias == HeroRole.healer || classBias == HeroRole.mage)) {
      offHandKind = OffHandKind.frill;
      weaponType = null;
      handed = null;
      weights = _offHandWeights(OffHandKind.frill);
    }

    final dist = _distribute(budget, weights);
    final armorPts = slot.isArmorSlot ||
            (slot == EquipmentSlot.offHand && offHandKind == OffHandKind.shield)
        ? _armorPoints(
            armorType ??
                (offHandKind == OffHandKind.shield ? ArmorType.plate : null),
            budget,
          )
        : 0;

    var crit = 0;
    var aspd = 0;
    var move = 0;
    var mp5 = 0;

    if (armorType == ArmorType.leather ||
        weaponType == WeaponType.dagger ||
        weaponType == WeaponType.bow ||
        weaponType == WeaponType.crossbow ||
        weaponType == WeaponType.gun ||
        weaponType == WeaponType.thrown ||
        classBias == HeroRole.rogue) {
      crit = rarity.index + (_random.nextDouble() < 0.5 ? 1 : 0);
    }
    if (armorType == ArmorType.cloth ||
        weaponType == WeaponType.staff ||
        weaponType == WeaponType.wand ||
        offHandKind == OffHandKind.frill) {
      mp5 = rarity.index >= 1 ? 1 + rarity.index : 0;
      if (_random.nextDouble() < 0.4) crit = max(crit, rarity.index);
    }
    if (slot == EquipmentSlot.boots) {
      move = 3 + rarity.index * 2;
      aspd = 1 + rarity.index;
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
    if (_random.nextDouble() < effectChance) {
      effectId = switch (classBias) {
        HeroRole.warrior => _random.nextDouble() < 0.55
            ? GearEffectId.lifesteal
            : (_random.nextBool() ? GearEffectId.goldFind : GearEffectId.haste),
        HeroRole.healer => _random.nextDouble() < 0.55
            ? GearEffectId.haste
            : (_random.nextBool()
                ? GearEffectId.lifesteal
                : GearEffectId.goldFind),
        HeroRole.mage => _random.nextDouble() < 0.5
            ? GearEffectId.pierce
            : (_random.nextBool() ? GearEffectId.haste : GearEffectId.crit),
        HeroRole.rogue => _random.nextDouble() < 0.55
            ? GearEffectId.crit
            : (_random.nextBool() ? GearEffectId.haste : GearEffectId.lifesteal),
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

    String? affixWord;
    final affixChance = switch (rarity) {
      LootRarity.rare => 0.3,
      LootRarity.epic => 0.65,
      LootRarity.legendary => 0.9,
      _ => 0.0,
    };
    if (affixChance > 0 && _random.nextDouble() < affixChance) {
      affixWord = _affixPrefixes[_random.nextInt(_affixPrefixes.length)];
    }

    final name = equipmentNameFor(
      slot: slot,
      rarity: rarity,
      bias: classBias,
      armorType: armorType,
      weaponType: weaponType,
      offHandKind: offHandKind,
      handed: handed,
      affixWord: affixWord,
    );

    return EquipmentItem(
      id: '${slot.name}_${rarity.name}_${battleNumber}_${_random.nextInt(100000)}',
      name: name,
      slot: slot,
      rarity: rarity,
      strengthBonus: dist.str,
      agilityBonus: dist.agi,
      staminaBonus: dist.sta,
      intellectBonus: dist.intel,
      spiritBonus: dist.spi,
      spellPowerBonus: dist.sp,
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
    );
  }
}
