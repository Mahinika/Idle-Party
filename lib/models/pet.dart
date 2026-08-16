/// Pet combat/meta passive kinds.
enum PetPassive { attack, goldFind, lootFind, xpFind, mitigate, healBoost }

enum PetRarity { common, uncommon, rare, epic, legendary }

/// Portrait frame cosmetic (CC0-friendly labels only).
enum PetFrame { none, bronze, silver, gold, crystal }

/// Static pet species definition (templates for hatch).
class PetSpecies {
  const PetSpecies({
    required this.id,
    required this.name,
    required this.baseAttack,
    required this.passive,
    required this.affinityDungeonId,
    this.passivePerLevel = 1,
  });

  final String id;
  final String name;
  final int baseAttack;
  final PetPassive passive;
  final String affinityDungeonId;
  final int passivePerLevel;
}

abstract final class PetCatalog {
  static const List<PetSpecies> all = <PetSpecies>[
    PetSpecies(
      id: 'ember_pup',
      name: 'Ember Pup',
      baseAttack: 2,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    ),
    PetSpecies(
      id: 'cave_bat',
      name: 'Cave Bat',
      baseAttack: 3,
      passive: PetPassive.attack,
      affinityDungeonId: 'sandy',
    ),
    PetSpecies(
      id: 'loot_sprite',
      name: 'Loot Sprite',
      baseAttack: 1,
      passive: PetPassive.lootFind,
      affinityDungeonId: 'goblin',
      passivePerLevel: 2,
    ),
    PetSpecies(
      id: 'warden_cub',
      name: 'Warden Cub',
      baseAttack: 4,
      passive: PetPassive.mitigate,
      affinityDungeonId: 'king',
    ),
    PetSpecies(
      id: 'gold_grub',
      name: 'Gold Grub',
      baseAttack: 1,
      passive: PetPassive.goldFind,
      affinityDungeonId: 'dead',
      passivePerLevel: 2,
    ),
    PetSpecies(
      id: 'spirit_moth',
      name: 'Spirit Moth',
      baseAttack: 2,
      passive: PetPassive.healBoost,
      affinityDungeonId: 'underworld',
    ),
    PetSpecies(
      id: 'xp_wisp',
      name: 'XP Wisp',
      baseAttack: 1,
      passive: PetPassive.xpFind,
      affinityDungeonId: 'crystal',
      passivePerLevel: 2,
    ),
    PetSpecies(
      id: 'ash_fox',
      name: 'Ash Fox',
      baseAttack: 3,
      passive: PetPassive.attack,
      affinityDungeonId: 'hell',
    ),
    PetSpecies(
      id: 'mire_toad',
      name: 'Mire Toad',
      baseAttack: 2,
      passive: PetPassive.mitigate,
      affinityDungeonId: 'sandy',
    ),
    PetSpecies(
      id: 'shrine_owl',
      name: 'Shrine Owl',
      baseAttack: 2,
      passive: PetPassive.healBoost,
      affinityDungeonId: 'crystal',
    ),
    PetSpecies(
      id: 'coin_imp',
      name: 'Coin Imp',
      baseAttack: 1,
      passive: PetPassive.goldFind,
      affinityDungeonId: 'goblin',
    ),
    PetSpecies(
      id: 'vault_beetle',
      name: 'Vault Beetle',
      baseAttack: 2,
      passive: PetPassive.lootFind,
      affinityDungeonId: 'king',
    ),
  ];

  static PetSpecies? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static int rarityWeight(PetRarity r) => switch (r) {
    PetRarity.common => 50,
    PetRarity.uncommon => 28,
    PetRarity.rare => 14,
    PetRarity.epic => 6,
    PetRarity.legendary => 2,
  };

  static int rarityAtkBonus(PetRarity r) => switch (r) {
    PetRarity.common => 0,
    PetRarity.uncommon => 1,
    PetRarity.rare => 2,
    PetRarity.epic => 4,
    PetRarity.legendary => 7,
  };

  static double rarityPassiveMult(PetRarity r) => switch (r) {
    PetRarity.common => 1.0,
    PetRarity.uncommon => 1.15,
    PetRarity.rare => 1.3,
    PetRarity.epic => 1.5,
    PetRarity.legendary => 1.8,
  };
}

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.attackBonus,
    this.level = 1,
    this.speciesId = '',
    this.rarity = PetRarity.common,
    this.passive = PetPassive.attack,
    this.affinityDungeonId = 'sandy',
    this.bondLevel = 0,
    this.frame = PetFrame.none,
    this.passivePerLevel = 1,
  });

  final String id;
  final String name;
  final int attackBonus;
  final int level;
  final String speciesId;
  final PetRarity rarity;
  final PetPassive passive;
  final String affinityDungeonId;
  final int bondLevel;
  final PetFrame frame;
  final int passivePerLevel;

  String get resolvedSpecies {
    if (speciesId.isNotEmpty) return speciesId;
    for (final s in PetCatalog.all) {
      if (id == s.id || id.startsWith('${s.id}_')) return s.id;
    }
    return id;
  }

  int get totalAttackBonus {
    final rarityBonus = PetCatalog.rarityAtkBonus(rarity);
    final bond = bondLevel ~/ 5;
    return attackBonus + (level - 1) + rarityBonus + bond;
  }

  int passiveValue({required String dungeonId}) {
    final base = switch (passive) {
      PetPassive.attack => 0,
      PetPassive.goldFind => 6 + level * passivePerLevel,
      PetPassive.lootFind => 5 + level * passivePerLevel,
      PetPassive.xpFind => 4 + level * passivePerLevel,
      PetPassive.mitigate => 2 + (level ~/ 2),
      PetPassive.healBoost => 3 + (level ~/ 2),
    };
    final mult = PetCatalog.rarityPassiveMult(rarity);
    final affinity = dungeonId == affinityDungeonId ? 1.25 : 1.0;
    return (base * mult * affinity).round();
  }

  Pet copyWith({
    String? id,
    String? name,
    int? attackBonus,
    int? level,
    String? speciesId,
    PetRarity? rarity,
    PetPassive? passive,
    String? affinityDungeonId,
    int? bondLevel,
    PetFrame? frame,
    int? passivePerLevel,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      attackBonus: attackBonus ?? this.attackBonus,
      level: level ?? this.level,
      speciesId: speciesId ?? this.speciesId,
      rarity: rarity ?? this.rarity,
      passive: passive ?? this.passive,
      affinityDungeonId: affinityDungeonId ?? this.affinityDungeonId,
      bondLevel: bondLevel ?? this.bondLevel,
      frame: frame ?? this.frame,
      passivePerLevel: passivePerLevel ?? this.passivePerLevel,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'attackBonus': attackBonus,
    'level': level,
    'speciesId': speciesId,
    'rarity': rarity.name,
    'passive': passive.name,
    'affinityDungeonId': affinityDungeonId,
    'bondLevel': bondLevel,
    'frame': frame.name,
    'passivePerLevel': passivePerLevel,
  };

  factory Pet.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    PetSpecies? species;
    for (final s in PetCatalog.all) {
      if (id == s.id || id.startsWith('${s.id}_')) {
        species = s;
        break;
      }
    }
    var rarity = PetRarity.common;
    final rarityRaw = json['rarity'] as String?;
    if (rarityRaw != null) {
      rarity = PetRarity.values.firstWhere(
        (r) => r.name == rarityRaw,
        orElse: () => PetRarity.common,
      );
    }
    var passive = species?.passive ?? PetPassive.attack;
    final passiveRaw = json['passive'] as String?;
    if (passiveRaw != null) {
      passive = PetPassive.values.firstWhere(
        (p) => p.name == passiveRaw,
        orElse: () => passive,
      );
    }
    var frame = PetFrame.none;
    final frameRaw = json['frame'] as String?;
    if (frameRaw != null) {
      frame = PetFrame.values.firstWhere(
        (f) => f.name == frameRaw,
        orElse: () => PetFrame.none,
      );
    }
    return Pet(
      id: id,
      name: json['name'] as String,
      attackBonus: (json['attackBonus'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      speciesId: (json['speciesId'] as String?) ?? species?.id ?? '',
      rarity: rarity,
      passive: passive,
      affinityDungeonId:
          (json['affinityDungeonId'] as String?) ??
          species?.affinityDungeonId ??
          'sandy',
      bondLevel: (json['bondLevel'] as num?)?.toInt() ?? 0,
      frame: frame,
      passivePerLevel:
          (json['passivePerLevel'] as num?)?.toInt() ??
          species?.passivePerLevel ??
          1,
    );
  }
}
