import 'game_state.dart';
import 'keystone.dart';

/// One offline week beat — reuses keystone / Gauntlet loops (no servers).
class LocalSeasonWeek {
  const LocalSeasonWeek({
    required this.id,
    required this.name,
    required this.blurb,
    this.weekKey,
    this.affixOverride,
    this.timedKeyTarget = 0,
    this.gauntletFloorTarget = 0,
    this.essenceReward = 8,
    this.titleReward,
  });

  /// Stable id inside a week (`weekKey:id` claim key).
  final String id;
  final String name;
  final String blurb;

  /// Exact ISO week `yyyy-Www`, or null for rotating pool.
  final String? weekKey;

  /// Optional primary affix override for the week.
  final String? affixOverride;

  /// Claim when [MetaDepthState.weeklyBestTimedKey] ≥ this (0 = ignore).
  final int timedKeyTarget;

  /// Claim when [MetaDepthState.gauntletBestFloor] ≥ this (0 = ignore).
  final int gauntletFloorTarget;

  final int essenceReward;
  final String? titleReward;

  String claimIdForWeek(String weekKey) => '$weekKey:$id';

  bool get hasGoal => timedKeyTarget > 0 || gauntletFloorTarget > 0;
}

/// Calendar-month cosmetic / copy overlay (first vault still pays essence).
class LocalSeasonMonth {
  const LocalSeasonMonth({
    required this.id,
    required this.name,
    this.monthKey,
    this.titleReward,
  });

  final String id;
  final String name;
  final String? monthKey;
  final String? titleReward;
}

/// Table-driven local seasons keyed by ISO week / month.
abstract final class LocalSeasonCatalog {
  /// Explicit week rows (optional exact [LocalSeasonWeek.weekKey]).
  static const List<LocalSeasonWeek> weeks = <LocalSeasonWeek>[
    LocalSeasonWeek(
      id: 'glass_tempo',
      name: 'Glass Tempo',
      blurb: 'Fragile packs — time a KEY +2 this week.',
      affixOverride: 'glass',
      timedKeyTarget: 2,
      essenceReward: 10,
      titleReward: 'Glass Runner',
    ),
    LocalSeasonWeek(
      id: 'swarm_surge',
      name: 'Swarm Surge',
      blurb: 'More foes — fill the vault under Swarm pressure.',
      affixOverride: 'swarm',
      timedKeyTarget: 2,
      essenceReward: 10,
      titleReward: 'Swarm Breaker',
    ),
    LocalSeasonWeek(
      id: 'spire_push',
      name: 'Spire Push',
      blurb: 'Climb Infinity Gauntlet to floor 15 this season of climbs.',
      affixOverride: 'elite',
      gauntletFloorTarget: 15,
      essenceReward: 12,
      titleReward: 'Spire Scout',
    ),
    LocalSeasonWeek(
      id: 'fortune_rush',
      name: 'Fortune Rush',
      blurb: 'Gold-heavy packs — bank a timed KEY +2.',
      affixOverride: 'fortune',
      timedKeyTarget: 2,
      essenceReward: 10,
      titleReward: 'Fortune Timed',
    ),
    LocalSeasonWeek(
      id: 'iron_week',
      name: 'Iron Week',
      blurb: 'Harder, richer packs — time a KEY +2 under Iron.',
      affixOverride: 'iron',
      timedKeyTarget: 2,
      essenceReward: 12,
      titleReward: 'Iron Timer',
    ),
    LocalSeasonWeek(
      id: 'elite_tempo',
      name: 'Elite Tempo',
      blurb: 'Tougher packs — clear a timed KEY +2 while Elite rules.',
      affixOverride: 'elite',
      timedKeyTarget: 2,
      essenceReward: 12,
      titleReward: 'Elite Tempo',
    ),
  ];

  static const List<LocalSeasonMonth> months = <LocalSeasonMonth>[
    LocalSeasonMonth(
      id: 'ember_month',
      name: 'Ember Month',
      titleReward: 'Ember Season',
    ),
    LocalSeasonMonth(
      id: 'tide_month',
      name: 'Tide Month',
      titleReward: 'Tide Season',
    ),
    LocalSeasonMonth(
      id: 'crystal_month',
      name: 'Crystal Month',
      titleReward: 'Crystal Season',
    ),
  ];

  static const Map<int, String> gauntletTitles = <int, String>{
    25: 'Spire Climber',
    50: 'Crystal Warden',
    100: 'Infinity Bound',
  };

  static LocalSeasonWeek forWeekKey(String weekKey) {
    for (final w in weeks) {
      if (w.weekKey == weekKey) return w;
    }
    final hash = weekKey.hashCode & 0x7fffffff;
    return weeks[hash % weeks.length];
  }

  static LocalSeasonMonth forMonthKey(String monthKey) {
    for (final m in months) {
      if (m.monthKey == monthKey) return m;
    }
    final hash = monthKey.hashCode & 0x7fffffff;
    return months[hash % months.length];
  }

  /// Resolve week affix: catalog override, else existing modifier / pool.
  static String resolveAffix({
    required String weekKey,
    required String currentModifier,
  }) {
    final week = forWeekKey(weekKey);
    if (week.affixOverride != null && week.affixOverride!.isNotEmpty) {
      return week.affixOverride!;
    }
    if (currentModifier.isNotEmpty) return currentModifier;
    return Keystone.weeklyPool[
        (weekKey.hashCode & 0x7fffffff) % Keystone.weeklyPool.length];
  }

  static bool weekGoalClaimed(GameState state, LocalSeasonWeek week) {
    final key = week.claimIdForWeek(state.metaDepth.weeklyKey);
    return state.metaDepth.claimedWeekGoals.contains(key);
  }

  static bool weekGoalReady(GameState state, LocalSeasonWeek week) {
    if (!week.hasGoal) return false;
    if (weekGoalClaimed(state, week)) return false;
    if (week.timedKeyTarget > 0 &&
        state.metaDepth.weeklyBestTimedKey < week.timedKeyTarget) {
      return false;
    }
    if (week.gauntletFloorTarget > 0 &&
        state.metaDepth.gauntletBestFloor < week.gauntletFloorTarget) {
      return false;
    }
    return true;
  }

  static bool weekGoalAlmost(GameState state, LocalSeasonWeek week) {
    if (!week.hasGoal || weekGoalClaimed(state, week) || weekGoalReady(state, week)) {
      return false;
    }
    if (week.timedKeyTarget > 0) {
      final best = state.metaDepth.weeklyBestTimedKey;
      if (best > 0 && best + 1 >= week.timedKeyTarget) return true;
    }
    if (week.gauntletFloorTarget > 0) {
      final best = state.metaDepth.gauntletBestFloor;
      final need = week.gauntletFloorTarget - best;
      if (best > 0 && need > 0 && need <= 5) return true;
    }
    return false;
  }

  static String weekProgressLabel(GameState state, LocalSeasonWeek week) {
    if (week.timedKeyTarget > 0) {
      return 'KEY +${state.metaDepth.weeklyBestTimedKey}/+${week.timedKeyTarget}';
    }
    if (week.gauntletFloorTarget > 0) {
      return 'F${state.metaDepth.gauntletBestFloor} → F${week.gauntletFloorTarget}';
    }
    return week.name;
  }
}
