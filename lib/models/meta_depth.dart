/// Prestige shop offerings (AL-gated essence sinks).
class PrestigeShopItem {
  const PrestigeShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.minAl,
    this.listedInShop = true,
  });

  final String id;
  final String name;
  final String description;
  final int cost;
  final int minAl;

  /// False = keep save math / old purchases, hide from POWER → SHOP.
  final bool listedInShop;
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
      description: 'Cheaper MERGE gold (−3g per luck, max 5).',
      cost: 55,
      minAl: 3,
    ),
    PrestigeShopItem(
      id: 'torch_keep',
      name: 'Keep Torch',
      description: '+8% hub AFK gold per level (sanctuary idle).',
      cost: 35,
      minAl: 3,
    ),
    PrestigeShopItem(
      id: 'gh_cdr',
      name: 'God Hand Cadence',
      description: 'Same cooldown as Forge → KEEP. One CD level (max 8).',
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
      id: 'loadout_slot',
      name: 'Loadout Folio',
      description: '+1 gear loadout slot (max 5 total).',
      cost: 45,
      minAl: 4,
      listedInShop: false,
    ),
    PrestigeShopItem(
      id: 'flask_discount',
      name: 'Apothecary Writ',
      description: '−5% market flask & bandage gold (max 25%).',
      cost: 40,
      minAl: 4,
    ),
    PrestigeShopItem(
      id: 'filter_span',
      name: 'Junk Magnifier',
      description: '+8 auto-sell/scrap iLvl ceiling in Settings (max +40).',
      cost: 45,
      minAl: 6,
    ),
    PrestigeShopItem(
      id: 'offline_ledger',
      name: 'Away Ledger',
      description: '+1 Welcome Back highlight row (max 6).',
      cost: 35,
      minAl: 6,
    ),
    PrestigeShopItem(
      id: 'legacy_spark',
      name: 'Legacy Spark',
      description: '+1 Legacy Point (tiny permanent ATK).',
      cost: 60,
      minAl: 10,
    ),
    PrestigeShopItem(
      id: 'daily_essence',
      name: 'Dawn Tithe',
      description: '+5e per level on Daily vault and Daily Run claims.',
      cost: 50,
      minAl: 8,
    ),
    PrestigeShopItem(
      id: 'gauntlet_gold',
      name: 'Spire Purse',
      description: '+4% Gauntlet gold per level.',
      cost: 55,
      minAl: 10,
    ),
  ];

  static List<PrestigeShopItem> get offered =>
      all.where((i) => i.listedInShop).toList(growable: false);

  static PrestigeShopItem? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
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

  /// Thresholds that grant a one-time essence claim (excludes Wandering).
  static List<int> get claimableThresholds => [
    for (final t in thresholds)
      if (t.$1 > 0) t.$1,
  ];

  /// Essence for crossing a Will threshold (claimed once via metaDepth).
  static int essenceForThreshold(int score) => 6 + (score ~/ 25);

  static String titleForScore(int score) {
    var title = thresholds.first.$2;
    for (final t in thresholds) {
      if (score >= t.$1) title = t.$2;
    }
    return title;
  }
}

/// Infinity Gauntlet floor milestones (one-time essence + achievements).
abstract final class GauntletMilestones {
  static const floors = <int>[25, 50, 100];

  static int essenceForFloor(int floor) => switch (floor) {
    25 => 22,
    50 => 45,
    100 => 90,
    _ => 10,
  };

  static String claimId(int floor) => 'f$floor';
}

/// Ascend titles unlocked at AL milestones.
abstract final class AscendTitles {
  static const Map<int, String> byAl = <int, String>{
    1: 'Reborn',
    5: 'Warden',
    10: 'Spireborn',
    15: 'Deep Will',
    20: 'Mythic Echo',
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
    this.ascendBlessings = 0,
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
    this.weeklyBestTimedKey = 0,
    this.dailyVaultDate = '',
    this.dailyVaultClears = 0,
    this.dailyBestTimedKey = 0,
    this.dailyVaultClaimed = false,
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
    this.highestHardmodeCleared = 0,
    this.gauntletBestFloor = 0,
    this.lifetimeGauntletFloors = 0,
    this.codexClaims = const <String>[],
    this.soulboundRefine = 0,
    this.soulboundIsArmor = false,
    this.heirloomAlBonus = 0,
    this.noWipeAscendReady = true,
    this.relicRespecs = 0,
    this.partySlot5Unlocked = false,
    this.unlockedSpecs = const <String>[],
    this.pendingHeroReveals = const <String>[],
    this.claimedWillRanks = const <String>[],
    this.claimedGauntletMilestones = const <String>[],
    this.riftBestTier = 0,
    this.riftPreferredTier = 1,
    this.lifetimeRiftClears = 0,
    this.claimedRiftMilestones = const <String>[],
    this.godHandStyle = 0,
    this.dailyEssenceBonusLevel = 0,
    this.gauntletGoldBonusLevel = 0,
    this.loadoutBonusSlots = 0,
    this.marketDiscountLevel = 0,
    this.filterSpanLevel = 0,
    this.offlineHighlightBonus = 0,
    this.seasonKey = '',
    this.claimedSeasonRewards = const <String>[],
    this.claimedWeekGoals = const <String>[],
    this.leaderboardSeasonKey = '',
    this.seasonBestTimedKey = 0,
    this.seasonBestTimedClearMs = 0,
    this.seasonBestGauntletFloor = 0,
    this.cloudSaveUpdatedMs = 0,
    this.playGamesOptIn = false,
    this.dismissedPlayUpdateVersionCode = 0,
    this.hubIdleSubSec = 0,
    this.hubAfkSec = 0,
    this.apexCraftClassId = '',
    this.apexCraftRoleTag = '',
    this.apexCraftSlot = '',
    this.apexTargetMatId = '',
    this.apexTargetProgress = 0,
    this.adBoostUntilMs = 0,
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

  /// Stacking Ascend Blessing packs (ATK/DEF/VIT/gold). Survives Ascend.
  final int ascendBlessings;
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

  /// Legacy weekly vault score (kept for save compat; unused by daily vault).
  final int weeklyBestTimedKey;

  /// UTC date key (`yyyy-mm-dd`) for the daily keystone vault.
  final String dailyVaultDate;

  /// Push clears counted toward today's vault.
  final int dailyVaultClears;

  /// Best timed keystone level today (vault score).
  final int dailyBestTimedKey;

  /// Whether today's vault was claimed.
  final bool dailyVaultClaimed;

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

  /// Highest keystone level at which a floor was cleared (not dial-only).
  final int highestHardmodeCleared;

  /// Best Infinity Gauntlet floor cleared (meta — survives Ascend).
  final int gauntletBestFloor;

  /// Lifetime gauntlet floor clears.
  final int lifetimeGauntletFloors;

  /// Highest Rift tier cleared (meta — survives Ascend).
  final int riftBestTier;

  /// Preferred Rift tier dial on hub (1…best+1).
  final int riftPreferredTier;

  /// Lifetime successful Rift clears.
  final int lifetimeRiftClears;

  /// Claimed Rift milestone ids (`r5`, `r10`, `r20`).
  final List<String> claimedRiftMilestones;

  final List<String> codexClaims;
  final int soulboundRefine;
  final bool soulboundIsArmor;
  final int heirloomAlBonus;
  final bool noWipeAscendReady;
  final int relicRespecs;

  /// Fifth active party slot (essence + AL gated).
  final bool partySlot5Unlocked;

  /// Unlocked [HeroSpecId.name] strings (roster eligibility).
  final List<String> unlockedSpecs;

  /// Newly unlocked specs waiting for hub “Meet …” reveal ([HeroSpecId.name]).
  /// Survives Ascend until the player opens PARTY / acknowledges.
  final List<String> pendingHeroReveals;

  /// Will-rank score thresholds already claimed for essence (e.g. `"25"`).
  final List<String> claimedWillRanks;

  /// Gauntlet milestone claim ids (`f25` / `f50` / `f100`).
  final List<String> claimedGauntletMilestones;

  /// God Hand expression: 0 balanced, 1 focus (dmg), 2 wide (radius).
  final int godHandStyle;

  /// Prestige: extra essence on Daily Run claim (+5e per level).
  final int dailyEssenceBonusLevel;

  /// Prestige: extra Gauntlet gold (+4% per level).
  final int gauntletGoldBonusLevel;

  /// Prestige: extra LOADOUTS slots beyond the base 3 (max +2 → 5).
  final int loadoutBonusSlots;

  /// Prestige: market flask/bandage gold discount (−5% per level, max 5).
  final int marketDiscountLevel;

  /// Prestige: raise Settings auto-sell/scrap iLvl ceiling (+8 per level).
  final int filterSpanLevel;

  /// Prestige: extra Welcome Back highlight rows (+1 per level, max 3).
  final int offlineHighlightBonus;

  /// Local season key (ISO week + month); shown on weekly UI.
  final String seasonKey;

  /// Calendar months (`yyyy-MM`) that already paid the season weekly bonus.
  final List<String> claimedSeasonRewards;

  /// Local week goals already claimed (`yyyy-Www:goalId`).
  final List<String> claimedWeekGoals;

  /// Calendar month (`yyyy-MM`) for Play Games seasonal PBs.
  final String leaderboardSeasonKey;

  /// Best TIMED keystone level this [leaderboardSeasonKey].
  final int seasonBestTimedKey;

  /// Clear time (ms) for [seasonBestTimedKey] (lower is better).
  final int seasonBestTimedClearMs;

  /// Best Infinity Gauntlet floor this [leaderboardSeasonKey].
  final int seasonBestGauntletFloor;

  /// UTC millis when this save was last written for cloud conflict checks.
  final int cloudSaveUpdatedMs;

  /// Player opted into Play Games (sign-in succeeded at least once).
  final bool playGamesOptIn;

  /// Play versionCode the player tapped LATER on (hub update notice).
  final int dismissedPlayUpdateVersionCode;

  /// Seconds banked toward the next hub gold tick (live 1s AFK).
  final int hubIdleSubSec;

  /// Cumulative hub AFK seconds for essence (same 10min gate as offline).
  final int hubAfkSec;

  /// Active Apex craft goal ([HeroClassId.name] / [SpecRoleTag.name] / slot).
  final String apexCraftClassId;
  final String apexCraftRoleTag;
  final String apexCraftSlot;

  /// Manual target mat override; empty = auto from craft goal shortages.
  final String apexTargetMatId;

  /// Boss-clear progress toward guaranteed target mat (resets on grant).
  final int apexTargetProgress;

  /// UTC millis when optional POWERUPS (ad boost) ends. 0 = none. Survives Ascend.
  final int adBoostUntilMs;

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
    int? ascendBlessings,
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
    int? weeklyBestTimedKey,
    String? dailyVaultDate,
    int? dailyVaultClears,
    int? dailyBestTimedKey,
    bool? dailyVaultClaimed,
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
    int? highestHardmodeCleared,
    int? gauntletBestFloor,
    int? lifetimeGauntletFloors,
    int? riftBestTier,
    int? riftPreferredTier,
    int? lifetimeRiftClears,
    List<String>? claimedRiftMilestones,
    List<String>? codexClaims,
    int? soulboundRefine,
    bool? soulboundIsArmor,
    int? heirloomAlBonus,
    bool? noWipeAscendReady,
    int? relicRespecs,
    bool? partySlot5Unlocked,
    List<String>? unlockedSpecs,
    List<String>? pendingHeroReveals,
    List<String>? claimedWillRanks,
    List<String>? claimedGauntletMilestones,
    int? godHandStyle,
    int? dailyEssenceBonusLevel,
    int? gauntletGoldBonusLevel,
    int? loadoutBonusSlots,
    int? marketDiscountLevel,
    int? filterSpanLevel,
    int? offlineHighlightBonus,
    String? seasonKey,
    List<String>? claimedSeasonRewards,
    List<String>? claimedWeekGoals,
    String? leaderboardSeasonKey,
    int? seasonBestTimedKey,
    int? seasonBestTimedClearMs,
    int? seasonBestGauntletFloor,
    int? cloudSaveUpdatedMs,
    bool? playGamesOptIn,
    int? dismissedPlayUpdateVersionCode,
    int? hubIdleSubSec,
    int? hubAfkSec,
    String? apexCraftClassId,
    String? apexCraftRoleTag,
    String? apexCraftSlot,
    String? apexTargetMatId,
    int? apexTargetProgress,
    int? adBoostUntilMs,
  }) {
    return MetaDepthState(
      sanctuaryXpLevel: sanctuaryXpLevel ?? this.sanctuaryXpLevel,
      sanctuaryGoldPrestige:
          sanctuaryGoldPrestige ?? this.sanctuaryGoldPrestige,
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
      ascendBlessings: ascendBlessings ?? this.ascendBlessings,
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
      weeklyBestTimedKey: weeklyBestTimedKey ?? this.weeklyBestTimedKey,
      dailyVaultDate: dailyVaultDate ?? this.dailyVaultDate,
      dailyVaultClears: dailyVaultClears ?? this.dailyVaultClears,
      dailyBestTimedKey: dailyBestTimedKey ?? this.dailyBestTimedKey,
      dailyVaultClaimed: dailyVaultClaimed ?? this.dailyVaultClaimed,
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
      highestHardmodeCleared:
          highestHardmodeCleared ?? this.highestHardmodeCleared,
      gauntletBestFloor: gauntletBestFloor ?? this.gauntletBestFloor,
      lifetimeGauntletFloors:
          lifetimeGauntletFloors ?? this.lifetimeGauntletFloors,
      riftBestTier: riftBestTier ?? this.riftBestTier,
      riftPreferredTier: riftPreferredTier ?? this.riftPreferredTier,
      lifetimeRiftClears: lifetimeRiftClears ?? this.lifetimeRiftClears,
      claimedRiftMilestones:
          claimedRiftMilestones ?? this.claimedRiftMilestones,
      codexClaims: codexClaims ?? this.codexClaims,
      soulboundRefine: soulboundRefine ?? this.soulboundRefine,
      soulboundIsArmor: soulboundIsArmor ?? this.soulboundIsArmor,
      heirloomAlBonus: heirloomAlBonus ?? this.heirloomAlBonus,
      noWipeAscendReady: noWipeAscendReady ?? this.noWipeAscendReady,
      relicRespecs: relicRespecs ?? this.relicRespecs,
      partySlot5Unlocked: partySlot5Unlocked ?? this.partySlot5Unlocked,
      unlockedSpecs: unlockedSpecs ?? this.unlockedSpecs,
      pendingHeroReveals: pendingHeroReveals ?? this.pendingHeroReveals,
      claimedWillRanks: claimedWillRanks ?? this.claimedWillRanks,
      claimedGauntletMilestones:
          claimedGauntletMilestones ?? this.claimedGauntletMilestones,
      godHandStyle: godHandStyle ?? this.godHandStyle,
      dailyEssenceBonusLevel:
          dailyEssenceBonusLevel ?? this.dailyEssenceBonusLevel,
      gauntletGoldBonusLevel:
          gauntletGoldBonusLevel ?? this.gauntletGoldBonusLevel,
      loadoutBonusSlots: loadoutBonusSlots ?? this.loadoutBonusSlots,
      marketDiscountLevel: marketDiscountLevel ?? this.marketDiscountLevel,
      filterSpanLevel: filterSpanLevel ?? this.filterSpanLevel,
      offlineHighlightBonus:
          offlineHighlightBonus ?? this.offlineHighlightBonus,
      seasonKey: seasonKey ?? this.seasonKey,
      claimedSeasonRewards: claimedSeasonRewards ?? this.claimedSeasonRewards,
      claimedWeekGoals: claimedWeekGoals ?? this.claimedWeekGoals,
      leaderboardSeasonKey: leaderboardSeasonKey ?? this.leaderboardSeasonKey,
      seasonBestTimedKey: seasonBestTimedKey ?? this.seasonBestTimedKey,
      seasonBestTimedClearMs:
          seasonBestTimedClearMs ?? this.seasonBestTimedClearMs,
      seasonBestGauntletFloor:
          seasonBestGauntletFloor ?? this.seasonBestGauntletFloor,
      cloudSaveUpdatedMs: cloudSaveUpdatedMs ?? this.cloudSaveUpdatedMs,
      playGamesOptIn: playGamesOptIn ?? this.playGamesOptIn,
      dismissedPlayUpdateVersionCode:
          dismissedPlayUpdateVersionCode ?? this.dismissedPlayUpdateVersionCode,
      hubIdleSubSec: hubIdleSubSec ?? this.hubIdleSubSec,
      hubAfkSec: hubAfkSec ?? this.hubAfkSec,
      apexCraftClassId: apexCraftClassId ?? this.apexCraftClassId,
      apexCraftRoleTag: apexCraftRoleTag ?? this.apexCraftRoleTag,
      apexCraftSlot: apexCraftSlot ?? this.apexCraftSlot,
      apexTargetMatId: apexTargetMatId ?? this.apexTargetMatId,
      apexTargetProgress: apexTargetProgress ?? this.apexTargetProgress,
      adBoostUntilMs: adBoostUntilMs ?? this.adBoostUntilMs,
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
    'ascendBlessings': ascendBlessings,
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
    'weeklyBestTimedKey': weeklyBestTimedKey,
    'dailyVaultDate': dailyVaultDate,
    'dailyVaultClears': dailyVaultClears,
    'dailyBestTimedKey': dailyBestTimedKey,
    'dailyVaultClaimed': dailyVaultClaimed,
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
    'highestHardmodeCleared': highestHardmodeCleared,
    'gauntletBestFloor': gauntletBestFloor,
    'lifetimeGauntletFloors': lifetimeGauntletFloors,
    'riftBestTier': riftBestTier,
    'riftPreferredTier': riftPreferredTier,
    'lifetimeRiftClears': lifetimeRiftClears,
    'claimedRiftMilestones': claimedRiftMilestones,
    'codexClaims': codexClaims,
    'soulboundRefine': soulboundRefine,
    'soulboundIsArmor': soulboundIsArmor,
    'heirloomAlBonus': heirloomAlBonus,
    'noWipeAscendReady': noWipeAscendReady,
    'relicRespecs': relicRespecs,
    'partySlot5Unlocked': partySlot5Unlocked,
    'unlockedSpecs': unlockedSpecs,
    'pendingHeroReveals': pendingHeroReveals,
    'claimedWillRanks': claimedWillRanks,
    'claimedGauntletMilestones': claimedGauntletMilestones,
    'godHandStyle': godHandStyle,
    'dailyEssenceBonusLevel': dailyEssenceBonusLevel,
    'gauntletGoldBonusLevel': gauntletGoldBonusLevel,
    'loadoutBonusSlots': loadoutBonusSlots,
    'marketDiscountLevel': marketDiscountLevel,
    'filterSpanLevel': filterSpanLevel,
    'offlineHighlightBonus': offlineHighlightBonus,
    'seasonKey': seasonKey,
    'claimedSeasonRewards': claimedSeasonRewards,
    'claimedWeekGoals': claimedWeekGoals,
    'leaderboardSeasonKey': leaderboardSeasonKey,
    'seasonBestTimedKey': seasonBestTimedKey,
    'seasonBestTimedClearMs': seasonBestTimedClearMs,
    'seasonBestGauntletFloor': seasonBestGauntletFloor,
    'cloudSaveUpdatedMs': cloudSaveUpdatedMs,
    'playGamesOptIn': playGamesOptIn,
    'dismissedPlayUpdateVersionCode': dismissedPlayUpdateVersionCode,
    'hubIdleSubSec': hubIdleSubSec,
    'hubAfkSec': hubAfkSec,
    'apexCraftClassId': apexCraftClassId,
    'apexCraftRoleTag': apexCraftRoleTag,
    'apexCraftSlot': apexCraftSlot,
    'apexTargetMatId': apexTargetMatId,
    'apexTargetProgress': apexTargetProgress,
    'adBoostUntilMs': adBoostUntilMs,
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
      sanctuaryXpLevel: (json['sanctuaryXpLevel'] as num?)?.toInt() ?? 0,
      sanctuaryGoldPrestige:
          (json['sanctuaryGoldPrestige'] as num?)?.toInt() ?? 0,
      sanctuaryPowerPrestige:
          (json['sanctuaryPowerPrestige'] as num?)?.toInt() ?? 0,
      sanctuaryVitalityPrestige:
          (json['sanctuaryVitalityPrestige'] as num?)?.toInt() ?? 0,
      sanctuaryXpPrestige: (json['sanctuaryXpPrestige'] as num?)?.toInt() ?? 0,
      stashBonusSlots: (json['stashBonusSlots'] as num?)?.toInt() ?? 0,
      combinatorLuck: (json['combinatorLuck'] as num?)?.toInt() ?? 0,
      godHandCdLevel: (json['godHandCdLevel'] as num?)?.toInt() ?? 0,
      torchKeepLevel: (json['torchKeepLevel'] as num?)?.toInt() ?? 0,
      legacyPoints: (json['legacyPoints'] as num?)?.toInt() ?? 0,
      ascendBlessings: (json['ascendBlessings'] as num?)?.toInt() ?? 0,
      ascendStreak: (json['ascendStreak'] as num?)?.toInt() ?? 0,
      bestAscendStreak: (json['bestAscendStreak'] as num?)?.toInt() ?? 0,
      titles: (json['titles'] as List<dynamic>?)?.cast<String>() ?? const [],
      activeTitle: (json['activeTitle'] as String?) ?? '',
      relicTiers: tiers,
      prestigePurchases:
          (json['prestigePurchases'] as List<dynamic>?)?.cast<String>() ??
          const [],
      weeklyKey: (json['weeklyKey'] as String?) ?? '',
      weeklyProgress: (json['weeklyProgress'] as num?)?.toInt() ?? 0,
      weeklyClaimed: (json['weeklyClaimed'] as bool?) ?? false,
      weeklyModifier: (json['weeklyModifier'] as String?) ?? '',
      weeklyBestTimedKey: ((json['weeklyBestTimedKey'] as num?)?.toInt() ?? 0)
          .clamp(0, 20),
      dailyVaultDate: (json['dailyVaultDate'] as String?) ?? '',
      dailyVaultClears: ((json['dailyVaultClears'] as num?)?.toInt() ?? 0)
          .clamp(0, 999),
      dailyBestTimedKey: ((json['dailyBestTimedKey'] as num?)?.toInt() ?? 0)
          .clamp(0, 20),
      dailyVaultClaimed: (json['dailyVaultClaimed'] as bool?) ?? false,
      favoritePetSpecies: (json['favoritePetSpecies'] as String?) ?? '',
      petRosterCapBonus: (json['petRosterCapBonus'] as num?)?.toInt() ?? 0,
      zoneTrophies:
          (json['zoneTrophies'] as List<dynamic>?)?.cast<String>() ?? const [],
      jobChainCount: (json['jobChainCount'] as num?)?.toInt() ?? 0,
      lifetimeFloorClears: (json['lifetimeFloorClears'] as num?)?.toInt() ?? 0,
      lifetimeBossKills: (json['lifetimeBossKills'] as num?)?.toInt() ?? 0,
      lifetimeAbilityCasts:
          (json['lifetimeAbilityCasts'] as num?)?.toInt() ?? 0,
      lifetimePetHatches: (json['lifetimePetHatches'] as num?)?.toInt() ?? 0,
      lifetimePetMerges: (json['lifetimePetMerges'] as num?)?.toInt() ?? 0,
      lifetimeAscends: (json['lifetimeAscends'] as num?)?.toInt() ?? 0,
      highestHardmodeCleared:
          ((json['highestHardmodeCleared'] as num?)?.toInt() ?? 0).clamp(0, 20),
      gauntletBestFloor: (json['gauntletBestFloor'] as num?)?.toInt() ?? 0,
      lifetimeGauntletFloors:
          (json['lifetimeGauntletFloors'] as num?)?.toInt() ?? 0,
      riftBestTier: ((json['riftBestTier'] as num?)?.toInt() ?? 0).clamp(0, 20),
      riftPreferredTier: ((json['riftPreferredTier'] as num?)?.toInt() ?? 1)
          .clamp(1, 20),
      lifetimeRiftClears: (json['lifetimeRiftClears'] as num?)?.toInt() ?? 0,
      claimedRiftMilestones:
          (json['claimedRiftMilestones'] as List<dynamic>?)?.cast<String>() ??
          const [],
      codexClaims:
          (json['codexClaims'] as List<dynamic>?)?.cast<String>() ?? const [],
      soulboundRefine: (json['soulboundRefine'] as num?)?.toInt() ?? 0,
      soulboundIsArmor: (json['soulboundIsArmor'] as bool?) ?? false,
      heirloomAlBonus: (json['heirloomAlBonus'] as num?)?.toInt() ?? 0,
      noWipeAscendReady: (json['noWipeAscendReady'] as bool?) ?? true,
      relicRespecs: (json['relicRespecs'] as num?)?.toInt() ?? 0,
      partySlot5Unlocked: (json['partySlot5Unlocked'] as bool?) ?? false,
      unlockedSpecs:
          (json['unlockedSpecs'] as List<dynamic>?)?.cast<String>() ?? const [],
      pendingHeroReveals:
          (json['pendingHeroReveals'] as List<dynamic>?)?.cast<String>() ??
          const [],
      claimedWillRanks:
          (json['claimedWillRanks'] as List<dynamic>?)?.cast<String>() ??
          const [],
      claimedGauntletMilestones:
          (json['claimedGauntletMilestones'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
      godHandStyle: ((json['godHandStyle'] as num?)?.toInt() ?? 0).clamp(0, 2),
      dailyEssenceBonusLevel:
          (json['dailyEssenceBonusLevel'] as num?)?.toInt() ?? 0,
      gauntletGoldBonusLevel:
          (json['gauntletGoldBonusLevel'] as num?)?.toInt() ?? 0,
      loadoutBonusSlots: ((json['loadoutBonusSlots'] as num?)?.toInt() ?? 0)
          .clamp(0, 2),
      marketDiscountLevel: ((json['marketDiscountLevel'] as num?)?.toInt() ?? 0)
          .clamp(0, 5),
      filterSpanLevel: ((json['filterSpanLevel'] as num?)?.toInt() ?? 0)
          .clamp(0, 5),
      offlineHighlightBonus:
          ((json['offlineHighlightBonus'] as num?)?.toInt() ?? 0).clamp(0, 3),
      seasonKey: (json['seasonKey'] as String?) ?? '',
      claimedSeasonRewards:
          (json['claimedSeasonRewards'] as List<dynamic>?)?.cast<String>() ??
          const [],
      claimedWeekGoals:
          (json['claimedWeekGoals'] as List<dynamic>?)?.cast<String>() ??
          const [],
      leaderboardSeasonKey: (json['leaderboardSeasonKey'] as String?) ?? '',
      seasonBestTimedKey: ((json['seasonBestTimedKey'] as num?)?.toInt() ?? 0)
          .clamp(0, 20),
      seasonBestTimedClearMs:
          (json['seasonBestTimedClearMs'] as num?)?.toInt() ?? 0,
      seasonBestGauntletFloor:
          (json['seasonBestGauntletFloor'] as num?)?.toInt() ?? 0,
      cloudSaveUpdatedMs: (json['cloudSaveUpdatedMs'] as num?)?.toInt() ?? 0,
      playGamesOptIn: (json['playGamesOptIn'] as bool?) ?? false,
      dismissedPlayUpdateVersionCode:
          (json['dismissedPlayUpdateVersionCode'] as num?)?.toInt() ?? 0,
      hubIdleSubSec: (json['hubIdleSubSec'] as num?)?.toInt() ?? 0,
      hubAfkSec: (json['hubAfkSec'] as num?)?.toInt() ?? 0,
      apexCraftClassId: (json['apexCraftClassId'] as String?) ?? '',
      apexCraftRoleTag: (json['apexCraftRoleTag'] as String?) ?? '',
      apexCraftSlot: (json['apexCraftSlot'] as String?) ?? '',
      apexTargetMatId: (json['apexTargetMatId'] as String?) ?? '',
      apexTargetProgress: (json['apexTargetProgress'] as num?)?.toInt() ?? 0,
      adBoostUntilMs: (json['adBoostUntilMs'] as num?)?.toInt() ?? 0,
    );
  }
}
