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

/// Calendar-month pass — KEY or Greater Rift PB (no permanent gold stamps).
class LocalSeasonMonth {
  const LocalSeasonMonth({
    required this.id,
    required this.name,
    this.monthKey,
    this.titleReward,
    this.timedKeyTarget = 0,
    this.grTierTarget = 0,
    this.essenceReward = 20,
    this.mirrorZoneId,
    this.mirrorSeedSalt = 0,
  });

  final String id;
  final String name;
  final String? monthKey;
  final String? titleReward;

  /// Claim when monthly best timed KEY ≥ this (0 = ignore).
  final int timedKeyTarget;

  /// Claim when [MetaDepthState.grBestTier] ≥ this (0 = ignore).
  final int grTierTarget;

  final int essenceReward;

  /// Optional zone for weekly mirror layout seed (catalog id).
  final String? mirrorZoneId;

  /// Extra salt mixed into floor RNG for mirror weeks.
  final int mirrorSeedSalt;

  String claimIdForMonth(String monthKey) => '$monthKey:$id';

  bool get hasPassGoal => timedKeyTarget > 0 || grTierTarget > 0;
}

/// Table-driven local seasons keyed by ISO week / month.
abstract final class LocalSeasonCatalog {
  /// Explicit week rows (optional exact [LocalSeasonWeek.weekKey]).
  static const List<LocalSeasonWeek> weeks = <LocalSeasonWeek>[
    // Pinned late-summer 2026 weeks (ISO) so hub TODAY names a real season beat.
    LocalSeasonWeek(
      id: 'fen_tide',
      name: 'Fen Tide Week',
      blurb: 'Mire pressure — time a KEY +2 under Swarm.',
      weekKey: '2026-W32',
      affixOverride: 'swarm',
      timedKeyTarget: 2,
      essenceReward: 12,
      titleReward: 'Fen Timer',
    ),
    LocalSeasonWeek(
      id: 'moth_dust',
      name: 'Moth Dust Week',
      blurb: 'Silk week — time a KEY +2 while the veil drifts.',
      weekKey: '2026-W33',
      affixOverride: 'glass',
      timedKeyTarget: 2,
      essenceReward: 12,
      titleReward: 'Moth Timer',
    ),
    LocalSeasonWeek(
      id: 'brass_tempo',
      name: 'Brass Tempo',
      blurb: 'Cog packs — bank a timed KEY +2 under Elite.',
      weekKey: '2026-W34',
      affixOverride: 'elite',
      timedKeyTarget: 2,
      essenceReward: 12,
      titleReward: 'Brass Timer',
    ),
    LocalSeasonWeek(
      id: 'spire_late',
      name: 'Late Spire Push',
      blurb: 'Climb Infinity Gauntlet to floor 20 this week.',
      weekKey: '2026-W35',
      affixOverride: 'iron',
      gauntletFloorTarget: 20,
      essenceReward: 14,
      titleReward: 'Late Spire',
    ),
    LocalSeasonWeek(
      id: 'veil_tempo',
      name: 'Veil Tempo',
      blurb: 'Silk packs — bank a timed KEY +2 under Swarm.',
      weekKey: '2026-W36',
      affixOverride: 'swarm',
      timedKeyTarget: 2,
      essenceReward: 12,
      titleReward: 'Veil Timer',
    ),
    LocalSeasonWeek(
      id: 'ember_climb',
      name: 'Ember Climb',
      blurb: 'Climb Infinity Gauntlet to floor 25 this week.',
      weekKey: '2026-W37',
      affixOverride: 'fortune',
      gauntletFloorTarget: 25,
      essenceReward: 14,
      titleReward: 'Ember Climber',
    ),
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
      id: 'veil_month',
      name: 'Veil Month',
      monthKey: '2026-08',
      titleReward: 'Veil Season',
      timedKeyTarget: 8,
      essenceReward: 24,
      mirrorZoneId: 'veil',
      mirrorSeedSalt: 8,
    ),
    LocalSeasonMonth(
      id: 'ember_month',
      name: 'Ember Month',
      titleReward: 'Ember Season',
      timedKeyTarget: 10,
      essenceReward: 24,
      mirrorZoneId: 'ember',
      mirrorSeedSalt: 9,
    ),
    LocalSeasonMonth(
      id: 'tide_month',
      name: 'Tide Month',
      titleReward: 'Tide Season',
      grTierTarget: 5,
      essenceReward: 26,
      mirrorZoneId: 'tide',
      mirrorSeedSalt: 10,
    ),
    LocalSeasonMonth(
      id: 'crystal_month',
      name: 'Crystal Month',
      titleReward: 'Crystal Season',
      timedKeyTarget: 12,
      essenceReward: 28,
      mirrorZoneId: 'crystal',
      mirrorSeedSalt: 11,
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
    return Keystone.weeklyPool[(weekKey.hashCode & 0x7fffffff) %
        Keystone.weeklyPool.length];
  }

  static bool weekGoalClaimed(GameState state, LocalSeasonWeek week) {
    final key = week.claimIdForWeek(state.metaDepth.weeklyKey);
    return state.metaDepth.claimedWeekGoals.contains(key);
  }

  static bool weekGoalReady(GameState state, LocalSeasonWeek week) {
    if (!week.hasGoal) return false;
    if (weekGoalClaimed(state, week)) return false;
    // KEY week goals need party-max-level KEY unlock.
    if (week.timedKeyTarget > 0 && Keystone.maxForState(state) <= 0) {
      return false;
    }
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
    if (!week.hasGoal ||
        weekGoalClaimed(state, week) ||
        weekGoalReady(state, week)) {
      return false;
    }
    if (week.timedKeyTarget > 0) {
      if (Keystone.maxForState(state) <= 0) return false;
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
      final best = state.metaDepth.weeklyBestTimedKey;
      final need = week.timedKeyTarget;
      if (best >= need) return 'Done · KEY +$best';
      return 'KEY +$best/+$need';
    }
    if (week.gauntletFloorTarget > 0) {
      final best = state.metaDepth.gauntletBestFloor;
      final need = week.gauntletFloorTarget;
      if (best >= need) return 'Done · best F$best';
      return 'F$best → F$need';
    }
    return week.name;
  }

  static bool monthPassClaimed(GameState state, LocalSeasonMonth month) {
    final key = month.claimIdForMonth(state.metaDepth.monthPassKey);
    return state.metaDepth.claimedMonthGoals.contains(key);
  }

  static bool monthPassReady(GameState state, LocalSeasonMonth month) {
    if (!month.hasPassGoal) return false;
    if (monthPassClaimed(state, month)) return false;
    if (Keystone.maxForState(state) <= 0) return false;
    if (month.timedKeyTarget > 0 &&
        state.metaDepth.monthlyBestTimedKey < month.timedKeyTarget) {
      return false;
    }
    if (month.grTierTarget > 0 &&
        state.metaDepth.monthlyBestGrTier < month.grTierTarget) {
      return false;
    }
    return true;
  }

  static bool monthPassAlmost(GameState state, LocalSeasonMonth month) {
    if (!month.hasPassGoal ||
        monthPassClaimed(state, month) ||
        monthPassReady(state, month) ||
        Keystone.maxForState(state) <= 0) {
      return false;
    }
    if (month.timedKeyTarget > 0) {
      final best = state.metaDepth.monthlyBestTimedKey;
      if (best > 0 && best + 1 >= month.timedKeyTarget) return true;
    }
    if (month.grTierTarget > 0) {
      final best = state.metaDepth.monthlyBestGrTier;
      final need = month.grTierTarget - best;
      if (best > 0 && need > 0 && need <= 1) return true;
    }
    return false;
  }

  static String monthProgressLabel(GameState state, LocalSeasonMonth month) {
    if (month.timedKeyTarget > 0) {
      return 'KEY +${state.metaDepth.monthlyBestTimedKey}/+${month.timedKeyTarget}';
    }
    if (month.grTierTarget > 0) {
      return 'GR${state.metaDepth.monthlyBestGrTier} → GR${month.grTierTarget}';
    }
    return month.name;
  }

  /// Mirror layout seed for the current week (0 = no mirror salt).
  static int mirrorLayoutSeed(GameState state) {
    final weekKey = state.metaDepth.weeklyKey;
    if (weekKey.isEmpty) return 0;
    final mk = state.metaDepth.monthPassKey.isNotEmpty
        ? state.metaDepth.monthPassKey
        : '2026-08';
    final month = forMonthKey(mk);
    if (month.mirrorZoneId == null) return weekKey.hashCode;
    return weekKey.hashCode ^
        month.mirrorSeedSalt ^
        month.mirrorZoneId.hashCode;
  }

  static String? mirrorZoneId(GameState state) {
    final mk = state.metaDepth.monthPassKey;
    if (mk.isEmpty) return null;
    return forMonthKey(mk).mirrorZoneId;
  }
}
