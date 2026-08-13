/// Static definition of a local (offline) achievement.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    this.essenceReward = 3,
    this.category = AchievementCategory.meta,
    this.hidden = false,
  });

  final String id;
  final String title;
  final String description;
  final int essenceReward;
  final AchievementCategory category;
  final bool hidden;
}

enum AchievementCategory { combat, meta, explorer, collector }

/// Catalog of every achievement players can unlock. Offline-only; unlocked
/// ids are stashed in `GameState.achievements` and survive Ascend.
abstract final class AchievementCatalog {
  static const List<AchievementDef> all = <AchievementDef>[
    // —— Core ——
    AchievementDef(
      id: 'first_floor',
      title: 'First Steps',
      description: 'Clear your first dungeon floor.',
      essenceReward: 3,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'first_boss',
      title: 'Giant Slayer',
      description: 'Defeat your first dungeon boss.',
      essenceReward: 5,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'first_ascend',
      title: 'Reborn',
      description: 'Ascend for the first time.',
      essenceReward: 8,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'clear_goblin',
      title: 'Hideout Cleared',
      description: "Clear the Goblin's Hideout.",
      essenceReward: 6,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'hatch_pet',
      title: 'New Friend',
      description: 'Hatch your first companion.',
      essenceReward: 4,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'daily_clear',
      title: 'Creature of Habit',
      description: 'Claim a Daily Run reward.',
      essenceReward: 4,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'full_party',
      title: 'Full House',
      description: 'Assemble a party of four heroes.',
      essenceReward: 5,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'party_five',
      title: 'Five Strong',
      description: 'Unlock and field a 5-hero party.',
      essenceReward: 12,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'specs_10',
      title: 'Spec Collector',
      description: 'Unlock 10 different hero specs.',
      essenceReward: 15,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'specs_all',
      title: 'Full Grimoire',
      description: 'Unlock every hero spec.',
      essenceReward: 40,
      category: AchievementCategory.collector,
    ),
    // —— Zone clears ——
    AchievementDef(
      id: 'clear_sandy',
      title: 'Sandwalker',
      description: 'Clear Sandy Caverns.',
      essenceReward: 4,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_king',
      title: 'Regicide',
      description: "Clear King's Fort.",
      essenceReward: 8,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_underworld',
      title: 'Eye Opener',
      description: 'Clear Underworld.',
      essenceReward: 10,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_dead',
      title: 'City Silence',
      description: 'Clear City of Dead.',
      essenceReward: 12,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_hell',
      title: 'Ashwalker',
      description: "Clear Hell's Gate.",
      essenceReward: 14,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_crystal',
      title: 'Spire Climber',
      description: 'Clear Crystal Spire.',
      essenceReward: 18,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_tide',
      title: 'Tidebreaker',
      description: 'Clear Sunken Tidehold.',
      essenceReward: 22,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_ember',
      title: 'Vault Breaker',
      description: 'Clear Ashen Vault.',
      essenceReward: 26,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_grove',
      title: 'Root Severed',
      description: 'Clear Hollow Grove.',
      essenceReward: 30,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_storm',
      title: 'Stormbreaker',
      description: 'Clear Stormwake Hollow.',
      essenceReward: 34,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_rime',
      title: 'Rimebreaker',
      description: 'Clear Rimeglass Rift.',
      essenceReward: 38,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_fen',
      title: 'Fenwalker',
      description: 'Clear Blightfen Mire.',
      essenceReward: 42,
      category: AchievementCategory.explorer,
    ),
    AchievementDef(
      id: 'clear_brass',
      title: 'Clockbound',
      description: 'Clear Brassvault Deep.',
      essenceReward: 46,
      category: AchievementCategory.explorer,
    ),
    // —— Hardmode ——
    AchievementDef(
      id: 'hm_1',
      title: 'Hardmode Initiate',
      description: 'Clear a floor at Hardmode +1 or higher.',
      essenceReward: 4,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'hm_5',
      title: 'Hardmode Adept',
      description: 'Clear a floor at Hardmode +5 or higher.',
      essenceReward: 10,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'hm_10',
      title: 'Hardmode Master',
      description: 'Clear a floor at Hardmode +10.',
      essenceReward: 20,
      category: AchievementCategory.combat,
    ),
    // —— Lifetime gold ——
    AchievementDef(
      id: 'gold_10k',
      title: 'Pocket Change',
      description: 'Earn 10,000 lifetime gold.',
      essenceReward: 5,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'gold_100k',
      title: 'Deep Pockets',
      description: 'Earn 100,000 lifetime gold.',
      essenceReward: 12,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'gold_1m',
      title: 'Gold Tide',
      description: 'Earn 1,000,000 lifetime gold.',
      essenceReward: 25,
      category: AchievementCategory.meta,
    ),
    // —— Codex ——
    AchievementDef(
      id: 'codex_10',
      title: 'Field Notes',
      description: 'Discover 10 codex entries.',
      essenceReward: 5,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'codex_25',
      title: 'Archivist',
      description: 'Discover 25 codex entries.',
      essenceReward: 10,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'codex_50',
      title: 'Lore Keeper',
      description: 'Discover 50 codex entries.',
      essenceReward: 18,
      category: AchievementCategory.collector,
    ),
    // —— Pets / collector ——
    AchievementDef(
      id: 'pets_3',
      title: 'Kennel Starter',
      description: 'Own 3 pets at once.',
      essenceReward: 6,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'pet_merge',
      title: 'Beast Fusion',
      description: 'Merge duplicate pets once.',
      essenceReward: 8,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'pet_legendary',
      title: 'Mythic Bond',
      description: 'Own a legendary pet.',
      essenceReward: 15,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'favorite_pet',
      title: 'Chosen Companion',
      description: 'Mark a favorite pet species.',
      essenceReward: 4,
      category: AchievementCategory.collector,
    ),
    // —— Ascend / combat meta ——
    AchievementDef(
      id: 'ascend_streak_3',
      title: 'Unbroken Will',
      description: 'Ascend 3 times in a row without a wipe.',
      essenceReward: 12,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'al_5',
      title: 'Warden',
      description: 'Reach Ascension Level 5.',
      essenceReward: 10,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'al_10',
      title: 'Spireborn',
      description: 'Reach Ascension Level 10.',
      essenceReward: 16,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'gauntlet_enter',
      title: 'Endless Threshold',
      description: 'Enter the Infinity Gauntlet.',
      essenceReward: 8,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'gauntlet_10',
      title: 'Tenfold Spire',
      description: 'Clear floor 10 of the Infinity Gauntlet.',
      essenceReward: 14,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'gauntlet_25',
      title: 'Quarter Spire',
      description: 'Clear floor 25 of the Infinity Gauntlet.',
      essenceReward: 18,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'gauntlet_50',
      title: 'Halfway Spire',
      description: 'Clear floor 50 of the Infinity Gauntlet.',
      essenceReward: 28,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'gauntlet_100',
      title: 'Century Spire',
      description: 'Clear floor 100 of the Infinity Gauntlet.',
      essenceReward: 50,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'casts_100',
      title: 'Spellweaver',
      description: 'Cast 100 class abilities (lifetime).',
      essenceReward: 8,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'floors_50',
      title: 'Corridor Runner',
      description: 'Clear 50 floors (lifetime).',
      essenceReward: 10,
      category: AchievementCategory.combat,
    ),
    AchievementDef(
      id: 'relic_all',
      title: 'Reliquary',
      description: 'Unlock all Forge relics.',
      essenceReward: 18,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'sanctuary_12',
      title: 'Temple Keeper',
      description: 'Raise any sanctuary track to 12.',
      essenceReward: 10,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'god_hand_5',
      title: 'Distant Fist',
      description: 'Upgrade God Hand to level 5.',
      essenceReward: 8,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'weekly_clear',
      title: 'Weekender',
      description: 'Claim a daily vault reward.',
      essenceReward: 10,
      category: AchievementCategory.meta,
    ),
    AchievementDef(
      id: 'apex_first',
      title: 'Apex Ignition',
      description: 'Craft your first Apex piece.',
      essenceReward: 12,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'apex_set_r1',
      title: 'Forged Ensemble',
      description: 'Craft a full Apex set (R1) for one class and role.',
      essenceReward: 30,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'apex_r3',
      title: 'Peak Temper',
      description: 'Upgrade any Apex piece to Rank 3.',
      essenceReward: 24,
      category: AchievementCategory.collector,
    ),
    AchievementDef(
      id: 'hidden_egg',
      title: 'Shell Surprise',
      description: 'Hatch 10 pets lifetime.',
      essenceReward: 6,
      category: AchievementCategory.collector,
      hidden: true,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final def in all) {
      if (def.id == id) return def;
    }
    return null;
  }

  static List<AchievementDef> forCategory(AchievementCategory c) =>
      all.where((d) => d.category == c).toList();
}
