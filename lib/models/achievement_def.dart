/// Static definition of a local (offline) achievement.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    this.essenceReward = 3,
  });

  final String id;
  final String title;
  final String description;

  /// Small free essence ping on unlock (offline, no monetization).
  final int essenceReward;
}

/// Catalog of every achievement players can unlock. Offline-only; unlocked
/// ids are stashed in `GameState.achievements` and survive Ascend.
abstract final class AchievementCatalog {
  static const List<AchievementDef> all = <AchievementDef>[
    AchievementDef(
      id: 'first_floor',
      title: 'First Steps',
      description: 'Clear your first dungeon floor.',
      essenceReward: 3,
    ),
    AchievementDef(
      id: 'first_boss',
      title: 'Giant Slayer',
      description: 'Defeat your first dungeon boss.',
      essenceReward: 5,
    ),
    AchievementDef(
      id: 'first_ascend',
      title: 'Reborn',
      description: 'Ascend for the first time.',
      essenceReward: 8,
    ),
    AchievementDef(
      id: 'clear_goblin',
      title: 'Hideout Cleared',
      description: "Clear the Goblin's Hideout.",
      essenceReward: 6,
    ),
    AchievementDef(
      id: 'hatch_pet',
      title: 'New Friend',
      description: 'Hatch your first companion.',
      essenceReward: 4,
    ),
    AchievementDef(
      id: 'daily_clear',
      title: 'Creature of Habit',
      description: 'Claim a Daily Run reward.',
      essenceReward: 4,
    ),
    AchievementDef(
      id: 'full_party',
      title: 'Full House',
      description: 'Assemble a party of four heroes.',
      essenceReward: 5,
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final def in all) {
      if (def.id == id) return def;
    }
    return null;
  }
}
