part of 'game_logic.dart';

/// Daily vault, week/month season keys, Will/Gauntlet/Rift milestone payoffs,
/// and the free Daily Run enter/claim helpers.

String _isoWeekKey(DateTime utc) {
  final d = DateTime.utc(utc.year, utc.month, utc.day);
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final week = (thursday.difference(yearStart).inDays ~/ 7) + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

String _isoMonthKey(DateTime utc) {
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  return '$y-$m';
}

GameState _ensureLeaderboardSeason(GameState state, {DateTime? now}) {
  final month = GameLogic.isoMonthKey((now ?? DateTime.now()).toUtc());
  final md = state.metaDepth;
  if (md.leaderboardSeasonKey == month) return state;
  return state.copyWith(
    metaDepth: md.copyWith(
      leaderboardSeasonKey: month,
      seasonBestTimedKey: 0,
      seasonBestTimedClearMs: 0,
      seasonBestGauntletFloor: 0,
      seasonBestGrTier: 0,
      seasonBestGrClearMs: 0,
    ),
  );
}

String _seasonLabel(DateTime utc) =>
    '${GameLogic.isoWeekKey(utc)} · ${GameLogic.isoMonthKey(utc)}';

GameState _ensureWeeklyContract(GameState state, {DateTime? now}) {
  final t = (now ?? DateTime.now()).toUtc();
  final key = GameLogic.isoWeekKey(t);
  final season = GameLogic.seasonLabel(t);
  var next = GameLogic.ensureLeaderboardSeason(state, now: t);
  if (next.metaDepth.weeklyKey != key || next.metaDepth.seasonKey != season) {
    final sameWeek = next.metaDepth.weeklyKey == key;
    final monthKey = GameLogic.isoMonthKey(t);
    final sameMonth = next.metaDepth.monthPassKey == monthKey;
    final mod = LocalSeasonCatalog.resolveAffix(
      weekKey: key,
      currentModifier: sameWeek ? next.metaDepth.weeklyModifier : '',
    );
    next = next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        weeklyKey: key,
        // Legacy weekly vault fields — kept for saves; vault is daily now.
        weeklyProgress: sameWeek ? next.metaDepth.weeklyProgress : 0,
        weeklyClaimed: sameWeek ? next.metaDepth.weeklyClaimed : false,
        weeklyModifier: sameWeek ? next.metaDepth.weeklyModifier : mod,
        weeklyBestTimedKey: sameWeek ? next.metaDepth.weeklyBestTimedKey : 0,
        monthPassKey: monthKey,
        monthlyBestTimedKey:
            sameMonth ? next.metaDepth.monthlyBestTimedKey : 0,
        monthlyBestGrTier: sameMonth ? next.metaDepth.monthlyBestGrTier : 0,
        apexTrialMonthKey:
            sameMonth ? next.metaDepth.apexTrialMonthKey : monthKey,
        apexTrialCleared: sameMonth ? next.metaDepth.apexTrialCleared : false,
        seasonKey: season,
      ),
    );
  }
  next = AshenCrown.ensureWeek(next, now: t);
  next = BlessingConstellation.ensure(next);
  return GameLogic.ensureDailyVault(next, now: t);
}

GameState _ensureDailyVault(GameState state, {DateTime? now}) {
  final t = (now ?? DateTime.now()).toUtc();
  final day = MetaSystems.dailyDateKey(t);
  final md = state.metaDepth;
  if (md.dailyVaultDate == day) return state;
  if (md.dailyVaultDate.isEmpty &&
      (md.weeklyProgress > 0 ||
          md.weeklyClaimed ||
          md.weeklyBestTimedKey > 0)) {
    return state.copyWith(
      metaDepth: md.copyWith(
        dailyVaultDate: day,
        dailyVaultClears: md.weeklyClaimed
            ? GameLogic.dailyVaultClearTarget
            : min(GameLogic.dailyVaultClearTarget, md.weeklyProgress),
        dailyBestTimedKey: md.weeklyBestTimedKey,
        dailyVaultClaimed: md.weeklyClaimed,
      ),
    );
  }
  return state.copyWith(
    metaDepth: md.copyWith(
      dailyVaultDate: day,
      dailyVaultClears: 0,
      dailyBestTimedKey: 0,
      dailyVaultClaimed: false,
    ),
  );
}

int _dailyVaultClaimEssence(GameState state) =>
    Keystone.dailyVaultEssence(state.metaDepth.dailyBestTimedKey) +
    state.metaDepth.dailyEssenceBonusLevel *
        GameLogic.dawnTitheEssencePerLevel;

int _dailyVaultClaimPreviewEssence(GameState state, {DateTime? now}) {
  var gain = GameLogic.dailyVaultClaimEssence(state);
  final month = GameLogic.isoMonthKey((now ?? DateTime.now()).toUtc());
  if (month.isNotEmpty &&
      !state.metaDepth.claimedSeasonRewards.contains(month)) {
    gain += GameLogic.seasonWeeklyBonusEssence;
  }
  return gain;
}

String _dungeonModeChipLabel(DungeonMode mode, GameState state) {
  if (GameLogic.plainPlayerChrome(state)) {
    return mode == DungeonMode.farm ? '↻ Repeat' : '▲ Next';
  }
  return mode == DungeonMode.farm ? '↻ FARM' : '▲ PUSH';
}

String _dungeonModeChipTip(DungeonMode mode, GameState state) {
  if (GameLogic.plainPlayerChrome(state)) {
    return mode == DungeonMode.farm
        ? 'Stay on this floor after clear for more loot'
        : 'Advance toward the boss after each clear';
  }
  return mode == DungeonMode.farm
      ? 'LOOP FARM — loop this floor after clear for loot'
      : 'CLIMB PUSH — advance floors toward the boss';
}

String _dungeonModeAfterClearHint(GameState state, DungeonMode mode) {
  if (mode == DungeonMode.farm) {
    return 'After clear: stay on this floor';
  }
  return 'After clear: go to next floor';
}

bool _canClaimDailyVault(GameState state) {
  final md = state.metaDepth;
  if (md.dailyVaultClaimed) return false;
  return md.dailyVaultClears >= GameLogic.dailyVaultClearTarget ||
      md.dailyBestTimedKey >= 2;
}

GameState _claimDailyVault(GameState state, {DateTime? now}) {
  var next = GameLogic.ensureWeeklyContract(state, now: now);
  final md = next.metaDepth;
  if (md.dailyVaultClaimed) return next;
  if (md.dailyVaultClears < GameLogic.dailyVaultClearTarget &&
      md.dailyBestTimedKey < 2) {
    return next;
  }
  var essenceGain = GameLogic.dailyVaultClaimEssence(next);
  final seasonClaims = List<String>.from(md.claimedSeasonRewards);
  final month = GameLogic.isoMonthKey((now ?? DateTime.now()).toUtc());
  final notices = <String>[];
  final titles = List<String>.from(md.titles);
  if (month.isNotEmpty && !seasonClaims.contains(month)) {
    seasonClaims.add(month);
    essenceGain += GameLogic.seasonWeeklyBonusEssence;
    notices.add('Season $month · +${GameLogic.seasonWeeklyBonusEssence}e');
    final season = LocalSeasonCatalog.forMonthKey(month);
    final title = season.titleReward;
    if (title != null && title.isNotEmpty && !titles.contains(title)) {
      titles.add(title);
      notices.add('Title unlocked · $title');
    }
  }
  LogicNotices.setMetaPayoffs(notices);
  next = next.copyWith(
    essence: next.essence + essenceGain,
    metaDepth: md.copyWith(
      dailyVaultClaimed: true,
      claimedSeasonRewards: seasonClaims,
      titles: titles,
    ),
    lastUpdated: DateTime.now(),
  );
  return MetaSystems.evaluateAchievements(next);
}

GameState _syncMetaPayoffs(GameState state) {
  var next = state;
  var essenceGain = 0;
  final notices = <String>[];
  final willClaims = List<String>.from(next.metaDepth.claimedWillRanks);
  final score = next.collectionScore;
  for (final threshold in WillRanks.claimableThresholds) {
    final id = '$threshold';
    if (score >= threshold && !willClaims.contains(id)) {
      willClaims.add(id);
      final gain = WillRanks.essenceForThreshold(threshold);
      essenceGain += gain;
      notices.add('Will · ${WillRanks.titleForScore(threshold)} +${gain}e');
    }
  }
  final gauntletClaims = List<String>.from(
    next.metaDepth.claimedGauntletMilestones,
  );
  final titles = List<String>.from(next.metaDepth.titles);
  final best = next.metaDepth.gauntletBestFloor;
  for (final floor in GauntletMilestones.floors) {
    final id = GauntletMilestones.claimId(floor);
    if (best >= floor && !gauntletClaims.contains(id)) {
      gauntletClaims.add(id);
      final gain = GauntletMilestones.essenceForFloor(floor);
      essenceGain += gain;
      notices.add('Gauntlet F$floor · +${gain}e');
      final title = LocalSeasonCatalog.gauntletTitles[floor];
      if (title != null && !titles.contains(title)) {
        titles.add(title);
        notices.add('Title unlocked · $title');
      }
    }
  }

  final riftClaims = List<String>.from(next.metaDepth.claimedRiftMilestones);
  final riftBest = next.metaDepth.riftBestTier;
  for (final tier in RiftMilestones.tiers) {
    final id = RiftMilestones.claimId(tier);
    if (riftBest >= tier && !riftClaims.contains(id)) {
      riftClaims.add(id);
      final gain = RiftMilestones.essenceForTier(tier);
      essenceGain += gain;
      notices.add('Rift R$tier · +${gain}e');
    }
  }

  final grClaims = List<String>.from(next.metaDepth.claimedGrMilestones);
  final grBest = next.metaDepth.grBestTier;
  for (final tier in GreaterRiftMilestones.tiers) {
    final id = GreaterRiftMilestones.claimId(tier);
    if (grBest >= tier && !grClaims.contains(id)) {
      grClaims.add(id);
      final gain = GreaterRiftMilestones.essenceForTier(tier);
      essenceGain += gain;
      notices.add('Greater Rift GR$tier · +${gain}e');
    }
  }

  // Local week goals (timed KEY / Gauntlet floor).
  final weekClaims = List<String>.from(next.metaDepth.claimedWeekGoals);
  final weekKey = next.metaDepth.weeklyKey;
  if (weekKey.isNotEmpty) {
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    final claimId = week.claimIdForWeek(weekKey);
    if (LocalSeasonCatalog.weekGoalReady(next, week) &&
        !weekClaims.contains(claimId)) {
      weekClaims.add(claimId);
      essenceGain += week.essenceReward;
      notices.add('${week.name} · +${week.essenceReward}e');
      final title = week.titleReward;
      if (title != null && title.isNotEmpty && !titles.contains(title)) {
        titles.add(title);
        notices.add('Title unlocked · $title');
      }
    }
  }

  if (essenceGain == 0 &&
      willClaims.length == next.metaDepth.claimedWillRanks.length &&
      gauntletClaims.length ==
          next.metaDepth.claimedGauntletMilestones.length &&
      riftClaims.length == next.metaDepth.claimedRiftMilestones.length &&
      grClaims.length == next.metaDepth.claimedGrMilestones.length &&
      weekClaims.length == next.metaDepth.claimedWeekGoals.length &&
      titles.length == next.metaDepth.titles.length) {
    LogicNotices.setMetaPayoffs(const []);
    return MetaSystems.evaluateAchievements(next);
  }
  LogicNotices.setMetaPayoffs(notices);
  next = next.copyWith(
    essence: next.essence + essenceGain,
    metaDepth: next.metaDepth.copyWith(
      claimedWillRanks: willClaims,
      claimedGauntletMilestones: gauntletClaims,
      claimedRiftMilestones: riftClaims,
      claimedGrMilestones: grClaims,
      claimedWeekGoals: weekClaims,
      titles: titles,
    ),
  );
  return MetaSystems.evaluateAchievements(next);
}

GameState _claimDailyIfEligible(
  GameState state, {
  GameState? dailyProbe,
}) {
  if (state.dailyClaimed) return state;
  final probe = dailyProbe ?? state;
  // Match the day the Daily was started (probe.lastDailyDate), not wall
  // clock — tests inject frozen dates and midnight crossover mid-run.
  final day = MetaSystems.parseDailyDateKey(probe.lastDailyDate);
  if (day == null) return state;
  if (probe.dungeonId != MetaSystems.dailyDungeonId(day)) return state;
  if (probe.layoutSeed != MetaSystems.dailySeed(day)) return state;
  final dailyEssenceReward = 25 +
      state.metaDepth.dailyEssenceBonusLevel *
          GameLogic.dawnTitheEssencePerLevel;
  return state.copyWith(
    dailyClaimed: true,
    essence: state.essence + dailyEssenceReward,
  );
}

GameState _enterDaily(GameState state, {DateTime? now}) {
  final t = now ?? DateTime.now().toUtc();
  if (MetaSystems.isDailyClaimedToday(state, now: t)) {
    return state;
  }
  final dateKey = MetaSystems.dailyDateKey(t);
  final seed = MetaSystems.dailySeed(t);
  final dungeonId = MetaSystems.dailyDungeonId(t);
  final isNewDay = state.lastDailyDate != dateKey;
  final floor = DungeonGenerator.generateFloor(
    1,
    ascensionLevel: state.ascensionLevel,
    dungeonId: dungeonId,
    layoutSeed: seed,
  );
  final room = floor.first;
  final cleared = GameLogic._clearKeystoneRun(state);
  return cleared.copyWith(
    inDungeon: true,
    inGauntlet: false,
    dungeonId: dungeonId,
    dungeonMode: DungeonMode.push,
    highestFloorCleared: 0,
    currentRoom: room,
    dungeonFloor: floor,
    enemies: GameLogic.createEnemyGroup(
      room,
      dungeonId: dungeonId,
      fromState: cleared,
    ),
    layoutSeed: seed,
    lastDailyDate: dateKey,
    dailyClaimed: isNewDay ? false : state.dailyClaimed,
    heroes: cleared.heroes
        .map(
          (hero) =>
              hero.copyWith(currentHp: cleared.effectiveHeroMaxHp(hero)),
        )
        .toList(),
    lastUpdated: DateTime.now(),
  );
}
