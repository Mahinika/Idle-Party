/// Prestige shop offerings (AL-gated essence sinks).
class PrestigeShopItem {
  const PrestigeShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.minAl,
  });

  final String id;
  final String name;
  final String description;
  final int cost;
  final int minAl;
}

abstract final class PrestigeShopCatalog {
  static const List<PrestigeShopItem> all = <PrestigeShopItem>[
    PrestigeShopItem(
      id: 'stash_slot',
      name: 'Stash Pocket',
      description: '+2 permanent stash slots.',
      cost: 40,
      minAl: 3,
    ),
    PrestigeShopItem(
      id: 'combine_luck',
      name: 'Combinator Charm',
      description: '+1 combinator luck (better merge odds).',
      cost: 55,
      minAl: 3,
    ),
    PrestigeShopItem(
      id: 'torch_keep',
      name: 'Keep Torch',
      description: '+8% hub offline gold.',
      cost: 35,
      minAl: 3,
    ),
    PrestigeShopItem(
      id: 'gh_cdr',
      name: 'God Hand Focus',
      description: 'Faster God Hand cooldown.',
      cost: 45,
      minAl: 5,
    ),
    PrestigeShopItem(
      id: 'roster_cap',
      name: 'Beast Kennel',
      description: '+2 pet roster capacity.',
      cost: 50,
      minAl: 5,
    ),
    PrestigeShopItem(
      id: 'legacy_spark',
      name: 'Legacy Spark',
      description: '+1 Legacy Point (tiny permanent ATK).',
      cost: 60,
      minAl: 10,
    ),
  ];
}

/// Will-rank titles from collection score.
abstract final class WillRanks {
  static const thresholds = <(int score, String title)>[
    (0, 'Wandering Will'),
    (25, 'Kindled Will'),
    (60, 'Bound Will'),
    (120, 'Ascendant Will'),
    (200, 'Spireborn Will'),
    (320, 'Eternal Will'),
  ];

  static String titleForScore(int score) {
    var title = thresholds.first.$2;
    for (final t in thresholds) {
      if (score >= t.$1) title = t.$2;
    }
    return title;
  }
}

/// Ascend titles unlocked at AL milestones.
abstract final class AscendTitles {
  static const Map<int, String> byAl = <int, String>{
    1: 'Reborn',
    5: 'Warden',
    10: 'Spireborn',
    15: 'Deep Will',
    20: 'Mythic Echo',
    25: 'Worldwalker',
    30: 'Crownless',
    40: 'Idle Sovereign',
  };
}

/// Survives Ascend. Bundles most of the meta-depth feature flags/progress.
class MetaDepthState {
  const MetaDepthState({
    this.sanctuaryXpLevel = 0,
    this.sanctuaryGoldPrestige = 0,
    this.sanctuaryPowerPrestige = 0,
    this.sanctuaryVitalityPrestige = 0,
    this.sanctuaryXpPrestige = 0,
    this.stashBonusSlots = 0,
    this.combinatorLuck = 0,
    this.godHandCdLevel = 0,
    this.torchKeepLevel = 0,
    this.legacyPoints = 0,
    this.ascendStreak = 0,
    this.bestAscendStreak = 0,
    this.titles = const <String>[],
    this.activeTitle = '',
    this.relicTiers = const <String, int>{},
    this.prestigePurchases = const <String>[],
    this.weeklyKey = '',
    this.weeklyProgress = 0,
    this.weeklyClaimed = false,
    this.weeklyModifier = '',
    this.favoritePetSpecies = '',
    this.petRosterCapBonus = 0,
    this.zoneTrophies = const <String>[],
    this.jobChainCount = 0,
    this.lifetimeFloorClears = 0,
    this.lifetimeBossKills = 0,
    this.lifetimeAbilityCasts = 0,
    this.lifetimePetHatches = 0,
    this.lifetimePetMerges = 0,
    this.lifetimeAscends = 0,
    this.codexClaims = const <String>[],
    this.soulboundRefine = 0,
    this.soulboundIsArmor = false,
    this.heirloomAlBonus = 0,
    this.noWipeAscendReady = true,
    this.relicRespecs = 0,
  });

  final int sanctuaryXpLevel;
  final int sanctuaryGoldPrestige;
  final int sanctuaryPowerPrestige;
  final int sanctuaryVitalityPrestige;
  final int sanctuaryXpPrestige;
  final int stashBonusSlots;
  final int combinatorLuck;
  final int godHandCdLevel;
  final int torchKeepLevel;
  final int legacyPoints;
  final int ascendStreak;
  final int bestAscendStreak;
  final List<String> titles;
  final String activeTitle;
  final Map<String, int> relicTiers;
  final List<String> prestigePurchases;
  final String weeklyKey;
  final int weeklyProgress;
  final bool weeklyClaimed;
  final String weeklyModifier;
  final String favoritePetSpecies;
  final int petRosterCapBonus;
  final List<String> zoneTrophies;
  final int jobChainCount;
  final int lifetimeFloorClears;
  final int lifetimeBossKills;
  final int lifetimeAbilityCasts;
  final int lifetimePetHatches;
  final int lifetimePetMerges;
  final int lifetimeAscends;
  final List<String> codexClaims;
  final int soulboundRefine;
  final bool soulboundIsArmor;
  final int heirloomAlBonus;
  final bool noWipeAscendReady;
  final int relicRespecs;

  static const empty = MetaDepthState();

  int get basePetRosterCap => 6 + petRosterCapBonus;

  int relicTierOf(String id) => relicTiers[id] ?? 0;

  bool hasPrestige(String id) => prestigePurchases.contains(id);

  MetaDepthState copyWith({
    int? sanctuaryXpLevel,
    int? sanctuaryGoldPrestige,
    int? sanctuaryPowerPrestige,
    int? sanctuaryVitalityPrestige,
    int? sanctuaryXpPrestige,
    int? stashBonusSlots,
    int? combinatorLuck,
    int? godHandCdLevel,
    int? torchKeepLevel,
    int? legacyPoints,
    int? ascendStreak,
    int? bestAscendStreak,
    List<String>? titles,
    String? activeTitle,
    Map<String, int>? relicTiers,
    List<String>? prestigePurchases,
    String? weeklyKey,
    int? weeklyProgress,
    bool? weeklyClaimed,
    String? weeklyModifier,
    String? favoritePetSpecies,
    int? petRosterCapBonus,
    List<String>? zoneTrophies,
    int? jobChainCount,
    int? lifetimeFloorClears,
    int? lifetimeBossKills,
    int? lifetimeAbilityCasts,
    int? lifetimePetHatches,
    int? lifetimePetMerges,
    int? lifetimeAscends,
    List<String>? codexClaims,
    int? soulboundRefine,
    bool? soulboundIsArmor,
    int? heirloomAlBonus,
    bool? noWipeAscendReady,
    int? relicRespecs,
  }) {
    return MetaDepthState(
      sanctuaryXpLevel: sanctuaryXpLevel ?? this.sanctuaryXpLevel,
      sanctuaryGoldPrestige: sanctuaryGoldPrestige ?? this.sanctuaryGoldPrestige,
      sanctuaryPowerPrestige:
          sanctuaryPowerPrestige ?? this.sanctuaryPowerPrestige,
      sanctuaryVitalityPrestige:
          sanctuaryVitalityPrestige ?? this.sanctuaryVitalityPrestige,
      sanctuaryXpPrestige: sanctuaryXpPrestige ?? this.sanctuaryXpPrestige,
      stashBonusSlots: stashBonusSlots ?? this.stashBonusSlots,
      combinatorLuck: combinatorLuck ?? this.combinatorLuck,
      godHandCdLevel: godHandCdLevel ?? this.godHandCdLevel,
      torchKeepLevel: torchKeepLevel ?? this.torchKeepLevel,
      legacyPoints: legacyPoints ?? this.legacyPoints,
      ascendStreak: ascendStreak ?? this.ascendStreak,
      bestAscendStreak: bestAscendStreak ?? this.bestAscendStreak,
      titles: titles ?? this.titles,
      activeTitle: activeTitle ?? this.activeTitle,
      relicTiers: relicTiers ?? this.relicTiers,
      prestigePurchases: prestigePurchases ?? this.prestigePurchases,
      weeklyKey: weeklyKey ?? this.weeklyKey,
      weeklyProgress: weeklyProgress ?? this.weeklyProgress,
      weeklyClaimed: weeklyClaimed ?? this.weeklyClaimed,
      weeklyModifier: weeklyModifier ?? this.weeklyModifier,
      favoritePetSpecies: favoritePetSpecies ?? this.favoritePetSpecies,
      petRosterCapBonus: petRosterCapBonus ?? this.petRosterCapBonus,
      zoneTrophies: zoneTrophies ?? this.zoneTrophies,
      jobChainCount: jobChainCount ?? this.jobChainCount,
      lifetimeFloorClears: lifetimeFloorClears ?? this.lifetimeFloorClears,
      lifetimeBossKills: lifetimeBossKills ?? this.lifetimeBossKills,
      lifetimeAbilityCasts: lifetimeAbilityCasts ?? this.lifetimeAbilityCasts,
      lifetimePetHatches: lifetimePetHatches ?? this.lifetimePetHatches,
      lifetimePetMerges: lifetimePetMerges ?? this.lifetimePetMerges,
      lifetimeAscends: lifetimeAscends ?? this.lifetimeAscends,
      codexClaims: codexClaims ?? this.codexClaims,
      soulboundRefine: soulboundRefine ?? this.soulboundRefine,
      soulboundIsArmor: soulboundIsArmor ?? this.soulboundIsArmor,
      heirloomAlBonus: heirloomAlBonus ?? this.heirloomAlBonus,
      noWipeAscendReady: noWipeAscendReady ?? this.noWipeAscendReady,
      relicRespecs: relicRespecs ?? this.relicRespecs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sanctuaryXpLevel': sanctuaryXpLevel,
        'sanctuaryGoldPrestige': sanctuaryGoldPrestige,
        'sanctuaryPowerPrestige': sanctuaryPowerPrestige,
        'sanctuaryVitalityPrestige': sanctuaryVitalityPrestige,
        'sanctuaryXpPrestige': sanctuaryXpPrestige,
        'stashBonusSlots': stashBonusSlots,
        'combinatorLuck': combinatorLuck,
        'godHandCdLevel': godHandCdLevel,
        'torchKeepLevel': torchKeepLevel,
        'legacyPoints': legacyPoints,
        'ascendStreak': ascendStreak,
        'bestAscendStreak': bestAscendStreak,
        'titles': titles,
        'activeTitle': activeTitle,
        'relicTiers': relicTiers,
        'prestigePurchases': prestigePurchases,
        'weeklyKey': weeklyKey,
        'weeklyProgress': weeklyProgress,
        'weeklyClaimed': weeklyClaimed,
        'weeklyModifier': weeklyModifier,
        'favoritePetSpecies': favoritePetSpecies,
        'petRosterCapBonus': petRosterCapBonus,
        'zoneTrophies': zoneTrophies,
        'jobChainCount': jobChainCount,
        'lifetimeFloorClears': lifetimeFloorClears,
        'lifetimeBossKills': lifetimeBossKills,
        'lifetimeAbilityCasts': lifetimeAbilityCasts,
        'lifetimePetHatches': lifetimePetHatches,
        'lifetimePetMerges': lifetimePetMerges,
        'lifetimeAscends': lifetimeAscends,
        'codexClaims': codexClaims,
        'soulboundRefine': soulboundRefine,
        'soulboundIsArmor': soulboundIsArmor,
        'heirloomAlBonus': heirloomAlBonus,
        'noWipeAscendReady': noWipeAscendReady,
        'relicRespecs': relicRespecs,
      };

  factory MetaDepthState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    final tiersRaw = json['relicTiers'];
    final tiers = <String, int>{};
    if (tiersRaw is Map) {
      for (final e in tiersRaw.entries) {
        tiers['${e.key}'] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return MetaDepthState(
      sanctuaryXpLevel: (json['sanctuaryXpLevel'] as int?) ?? 0,
      sanctuaryGoldPrestige: (json['sanctuaryGoldPrestige'] as int?) ?? 0,
      sanctuaryPowerPrestige: (json['sanctuaryPowerPrestige'] as int?) ?? 0,
      sanctuaryVitalityPrestige:
          (json['sanctuaryVitalityPrestige'] as int?) ?? 0,
      sanctuaryXpPrestige: (json['sanctuaryXpPrestige'] as int?) ?? 0,
      stashBonusSlots: (json['stashBonusSlots'] as int?) ?? 0,
      combinatorLuck: (json['combinatorLuck'] as int?) ?? 0,
      godHandCdLevel: (json['godHandCdLevel'] as int?) ?? 0,
      torchKeepLevel: (json['torchKeepLevel'] as int?) ?? 0,
      legacyPoints: (json['legacyPoints'] as int?) ?? 0,
      ascendStreak: (json['ascendStreak'] as int?) ?? 0,
      bestAscendStreak: (json['bestAscendStreak'] as int?) ?? 0,
      titles: (json['titles'] as List<dynamic>?)?.cast<String>() ?? const [],
      activeTitle: (json['activeTitle'] as String?) ?? '',
      relicTiers: tiers,
      prestigePurchases:
          (json['prestigePurchases'] as List<dynamic>?)?.cast<String>() ??
              const [],
      weeklyKey: (json['weeklyKey'] as String?) ?? '',
      weeklyProgress: (json['weeklyProgress'] as int?) ?? 0,
      weeklyClaimed: (json['weeklyClaimed'] as bool?) ?? false,
      weeklyModifier: (json['weeklyModifier'] as String?) ?? '',
      favoritePetSpecies: (json['favoritePetSpecies'] as String?) ?? '',
      petRosterCapBonus: (json['petRosterCapBonus'] as int?) ?? 0,
      zoneTrophies:
          (json['zoneTrophies'] as List<dynamic>?)?.cast<String>() ?? const [],
      jobChainCount: (json['jobChainCount'] as int?) ?? 0,
      lifetimeFloorClears: (json['lifetimeFloorClears'] as int?) ?? 0,
      lifetimeBossKills: (json['lifetimeBossKills'] as int?) ?? 0,
      lifetimeAbilityCasts: (json['lifetimeAbilityCasts'] as int?) ?? 0,
      lifetimePetHatches: (json['lifetimePetHatches'] as int?) ?? 0,
      lifetimePetMerges: (json['lifetimePetMerges'] as int?) ?? 0,
      lifetimeAscends: (json['lifetimeAscends'] as int?) ?? 0,
      codexClaims:
          (json['codexClaims'] as List<dynamic>?)?.cast<String>() ?? const [],
      soulboundRefine: (json['soulboundRefine'] as int?) ?? 0,
      soulboundIsArmor: (json['soulboundIsArmor'] as bool?) ?? false,
      heirloomAlBonus: (json['heirloomAlBonus'] as int?) ?? 0,
      noWipeAscendReady: (json['noWipeAscendReady'] as bool?) ?? true,
      relicRespecs: (json['relicRespecs'] as int?) ?? 0,
    );
  }
}
