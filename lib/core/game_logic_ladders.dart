part of 'game_logic.dart';

/// Gauntlet + Farm Rift + Greater Rift orchestration (enter / timer / resolve).
/// Payout rules live in [Rift] / [GreaterRift]; this is GameState wiring only.

double _gauntletThreatMul(int floor) => 1.0 + max(0, floor - 1) * 0.10;

double _gauntletGoldMul(int floor, {int prestigeBonusLevel = 0}) =>
    (1.0 + max(0, floor - 1) * 0.08) * (1.0 + prestigeBonusLevel * 0.04);

int _gauntletEssenceForFloor(int floor, {required bool boss}) =>
    1 + (floor ~/ 2) + (boss ? 4 : 0);

GameState _recordGauntletRun(
  GameState state, {
  required int reachedFloor,
}) {
  final cleared = max(0, reachedFloor - 1);
  var next = GameLogic.ensureLeaderboardSeason(state);
  final best = max(next.metaDepth.gauntletBestFloor, cleared);
  final seasonBest = max(next.metaDepth.seasonBestGauntletFloor, cleared);
  if (best == next.metaDepth.gauntletBestFloor &&
      seasonBest == next.metaDepth.seasonBestGauntletFloor) {
    return GameLogic.syncMetaPayoffs(next);
  }
  if (seasonBest > next.metaDepth.seasonBestGauntletFloor) {
    PlayGamesBridge.noteGauntletPb(
      monthKey: next.metaDepth.leaderboardSeasonKey,
      floor: seasonBest,
    );
  }
  return GameLogic.syncMetaPayoffs(
    next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        gauntletBestFloor: best,
        seasonBestGauntletFloor: seasonBest,
      ),
    ),
  );
}

GameState _enterGauntlet(GameState state) {
  if (!GameLogic.canEnterGauntlet(state)) return state;
  const dungeonId = 'crystal';
  final layoutSeed = GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    1,
    ascensionLevel: state.ascensionLevel,
    dungeonId: dungeonId,
    layoutSeed: layoutSeed,
    bossEvery: GameLogic.gauntletBossEvery,
  );
  final room = floor.first;
  final cleared = GameLogic._clearKeystoneRun(state);
  return MetaSystems.evaluateAchievements(
    cleared.copyWith(
      inDungeon: true,
      inGauntlet: true,
      dungeonId: dungeonId,
      dungeonMode: DungeonMode.push,
      // Keep zone highestFloorCleared — Ascend fragments + softcaps use it.
      // Gauntlet climb progress lives on metaDepth.gauntletBestFloor.
      currentRoom: room,
      dungeonFloor: floor,
      enemies: GameLogic.createEnemyGroup(
        room,
        dungeonId: dungeonId,
        fromState: cleared.copyWith(inGauntlet: true),
      ),
      layoutSeed: layoutSeed,
      heroes: cleared.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: cleared.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    ),
  );
}

GameState _enterRift(GameState state, {int? tier}) {
  if (!GameLogic.canEnterRift(state)) return state;
  final preferred = tier ?? state.metaDepth.riftPreferredTier;
  final maxSel = Rift.maxSelectableTier(state.metaDepth.riftBestTier);
  final t = Rift.clampTier(preferred.clamp(Rift.minTier, maxSel));
  final layoutSeed = GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    1,
    ascensionLevel: state.ascensionLevel,
    dungeonId: Rift.dungeonId,
    layoutSeed: layoutSeed,
  );
  final room = floor.first;
  final cleared = GameLogic._clearKeystoneRun(
    _clearGreaterRiftRun(_clearRiftRun(state)),
  );
  return MetaSystems.evaluateAchievements(
    cleared.copyWith(
      inDungeon: true,
      inGauntlet: false,
      inRift: true,
      inGreaterRift: false,
      dungeonId: Rift.dungeonId,
      dungeonMode: DungeonMode.push,
      currentRoom: room,
      dungeonFloor: floor,
      enemies: GameLogic.createEnemyGroup(
        room,
        dungeonId: Rift.dungeonId,
        fromState: cleared.copyWith(inRift: true, riftTier: t),
      ),
      layoutSeed: layoutSeed,
      riftTier: t,
      riftTimerMs: 0,
      riftParMs: Rift.parTimeMs(t),
      riftKillTarget: Rift.killTarget(t),
      riftKills: 0,
      riftOutcome: '',
      metaDepth: cleared.metaDepth.copyWith(riftPreferredTier: t),
      heroes: cleared.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: cleared.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    ),
  );
}

GameState _clearRiftRun(GameState state) {
  if (!state.inRift &&
      state.riftTier == 0 &&
      state.riftTimerMs == 0 &&
      state.riftParMs == 0 &&
      state.riftKillTarget == 0 &&
      state.riftKills == 0 &&
      state.riftOutcome.isEmpty) {
    return state;
  }
  return state.copyWith(
    inRift: false,
    riftTier: 0,
    riftTimerMs: 0,
    riftParMs: 0,
    riftKillTarget: 0,
    riftKills: 0,
    riftOutcome: '',
  );
}

GameState _setRiftPreferredTier(GameState state, int tier) {
  if (!GameLogic.endgameUnlocked(state)) return state;
  final maxSel = Rift.maxSelectableTier(state.metaDepth.riftBestTier);
  final t = Rift.clampTier(tier.clamp(Rift.minTier, maxSel));
  return state.copyWith(
    metaDepth: state.metaDepth.copyWith(riftPreferredTier: t),
    lastUpdated: DateTime.now(),
  );
}

GameState _advanceRiftTimer(GameState state, int deltaMs) {
  if (!state.inRift || deltaMs <= 0) return state;
  if (state.riftOutcome.isNotEmpty) return state;
  return state.copyWith(riftTimerMs: state.riftTimerMs + deltaMs);
}

GameState _noteRiftKills(GameState state, int kills) {
  if (!state.inRift || kills <= 0) return state;
  if (state.riftOutcome.isNotEmpty) return state;
  return state.copyWith(riftKills: state.riftKills + kills);
}

GameState? _tryResolveRift(GameState state) {
  if (!state.inRift || state.riftOutcome.isNotEmpty) return null;
  if (state.riftKills >= state.riftKillTarget &&
      state.riftTimerMs <= state.riftParMs) {
    return _resolveRiftSuccess(state);
  }
  if (state.riftTimerMs > state.riftParMs) {
    return _resolveRiftFail(state);
  }
  return null;
}

GameState _resolveRiftSuccess(GameState state) {
  if (!state.inRift) return state;
  final tier = Rift.clampTier(state.riftTier);
  final unlock = Rift.unlockTierAfterSuccess(
    clearedTier: tier,
    timerMs: state.riftTimerMs,
    parMs: state.riftParMs,
  );
  final best = max(state.metaDepth.riftBestTier, unlock);
  final essence = Rift.successEssence(tier);
  final gold = Rift.successGold(tier);
  var next = state.copyWith(
    gold: state.gold + gold,
    essence: state.essence + essence,
    lifetimeGoldEarned: state.lifetimeGoldEarned + gold,
    riftOutcome: 'timed',
    metaDepth: state.metaDepth.copyWith(
      riftBestTier: best,
      riftPreferredTier: Rift.maxSelectableTier(best),
      lifetimeRiftClears: state.metaDepth.lifetimeRiftClears + 1,
    ),
  );
  next = GameLogic.syncMetaPayoffs(next);
  LogicNotices.addMetaPayoffs([
    'Rift R$tier timed · +${essence}e · +${gold}g'
        '${unlock > tier + 1 ? ' · unlock R$unlock' : ''}',
  ]);
  return GameLogic.exitToHubHealed(next);
}

GameState _resolveRiftFail(GameState state) {
  if (!state.inRift) return state;
  if (state.riftOutcome.isNotEmpty) return GameLogic.exitToHubHealed(state);
  final tier = Rift.clampTier(state.riftTier);
  final essence = Rift.failEssence(tier);
  final next = state.copyWith(
    essence: state.essence + essence,
    riftOutcome: 'depleted',
  );
  LogicNotices.addMetaPayoffs([
    'Rift R$tier failed · +${essence}e consolation',
  ]);
  return GameLogic.exitToHubHealed(next);
}

GameState _enterGreaterRift(GameState state, {int? tier}) {
  if (!GameLogic.canEnterGreaterRift(state)) return state;
  final preferred = tier ?? state.metaDepth.grPreferredTier;
  final maxSel = GreaterRift.maxSelectableTier(state.metaDepth.grBestTier);
  final t = GreaterRift.clampTier(
    preferred.clamp(GreaterRift.minTier, maxSel),
  );
  final layoutSeed = GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    1,
    ascensionLevel: state.ascensionLevel,
    dungeonId: GreaterRift.dungeonId,
    layoutSeed: layoutSeed,
  );
  final room = floor.first;
  final cleared = GameLogic._clearKeystoneRun(
    _clearRiftRun(_clearGreaterRiftRun(state)),
  );
  return MetaSystems.evaluateAchievements(
    cleared.copyWith(
      inDungeon: true,
      inGauntlet: false,
      inRift: false,
      inGreaterRift: true,
      dungeonId: GreaterRift.dungeonId,
      dungeonMode: DungeonMode.push,
      currentRoom: room,
      dungeonFloor: floor,
      enemies: GameLogic.createEnemyGroup(
        room,
        dungeonId: GreaterRift.dungeonId,
        fromState: cleared.copyWith(inGreaterRift: true, grTier: t),
      ),
      layoutSeed: layoutSeed,
      grTier: t,
      grTimerMs: 0,
      grParMs: GreaterRift.parTimeMs(t),
      grKillTarget: GreaterRift.killTarget(t),
      grKills: 0,
      grOutcome: '',
      metaDepth: cleared.metaDepth.copyWith(grPreferredTier: t),
      heroes: cleared.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: cleared.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    ),
  );
}

GameState _clearGreaterRiftRun(GameState state) {
  if (!state.inGreaterRift &&
      state.grTier == 0 &&
      state.grTimerMs == 0 &&
      state.grParMs == 0 &&
      state.grKillTarget == 0 &&
      state.grKills == 0 &&
      state.grOutcome.isEmpty) {
    return state;
  }
  return state.copyWith(
    inGreaterRift: false,
    grTier: 0,
    grTimerMs: 0,
    grParMs: 0,
    grKillTarget: 0,
    grKills: 0,
    grOutcome: '',
  );
}

GameState _setGrPreferredTier(GameState state, int tier) {
  if (!GameLogic.endgameUnlocked(state)) return state;
  final maxSel = GreaterRift.maxSelectableTier(state.metaDepth.grBestTier);
  final t = GreaterRift.clampTier(
    tier.clamp(GreaterRift.minTier, maxSel),
  );
  return state.copyWith(
    metaDepth: state.metaDepth.copyWith(grPreferredTier: t),
    lastUpdated: DateTime.now(),
  );
}

GameState _advanceGreaterRiftTimer(GameState state, int deltaMs) {
  if (!state.inGreaterRift || deltaMs <= 0) return state;
  if (state.grOutcome.isNotEmpty) return state;
  return state.copyWith(grTimerMs: state.grTimerMs + deltaMs);
}

GameState _noteGreaterRiftKills(GameState state, int kills) {
  if (!state.inGreaterRift || kills <= 0) return state;
  if (state.grOutcome.isNotEmpty) return state;
  return state.copyWith(grKills: state.grKills + kills);
}

GameState? _tryResolveGreaterRift(GameState state) {
  if (!state.inGreaterRift || state.grOutcome.isNotEmpty) return null;
  if (state.grKills >= state.grKillTarget &&
      state.grTimerMs <= state.grParMs) {
    return _resolveGreaterRiftSuccess(state);
  }
  if (state.grTimerMs > state.grParMs) {
    return _resolveGreaterRiftFail(state);
  }
  return null;
}

GameState _resolveGreaterRiftSuccess(GameState state) {
  if (!state.inGreaterRift) return state;
  var next = GameLogic.ensureLeaderboardSeason(state);
  final tier = GreaterRift.clampTier(next.grTier);
  final unlock = GreaterRift.unlockTierAfterSuccess(
    clearedTier: tier,
    timerMs: next.grTimerMs,
    parMs: next.grParMs,
  );
  final best = max(next.metaDepth.grBestTier, unlock);
  final essence = GreaterRift.successEssence(tier);
  final gold = GreaterRift.successGold(tier);
  final clearMs = next.grTimerMs;
  final md = next.metaDepth;
  final betterSeason = PlayGamesScores.isBetterTimed(
    newKey: tier,
    newClearMs: clearMs,
    bestKey: md.seasonBestGrTier,
    bestClearMs: md.seasonBestGrClearMs,
  );
  var seasonTier = md.seasonBestGrTier;
  var seasonMs = md.seasonBestGrClearMs;
  if (betterSeason) {
    seasonTier = tier;
    seasonMs = clearMs;
    PlayGamesBridge.noteGreaterRiftPb(
      monthKey: md.leaderboardSeasonKey.isNotEmpty
          ? md.leaderboardSeasonKey
          : GameLogic.isoMonthKey(DateTime.now().toUtc()),
      tier: tier,
      clearMs: clearMs,
    );
  }
  next = next.copyWith(
    gold: next.gold + gold,
    essence: next.essence + essence,
    lifetimeGoldEarned: next.lifetimeGoldEarned + gold,
    grOutcome: 'timed',
    metaDepth: md.copyWith(
      grBestTier: best,
      monthlyBestGrTier: max(md.monthlyBestGrTier, best),
      grPreferredTier: GreaterRift.maxSelectableTier(best),
      lifetimeGrClears: md.lifetimeGrClears + 1,
      seasonBestGrTier: seasonTier,
      seasonBestGrClearMs: seasonMs,
    ),
  );
  next = GameLogic.syncMetaPayoffs(next);
  LogicNotices.addMetaPayoffs([
    'Greater Rift GR$tier timed · +${essence}e · +${gold}g'
        '${unlock > tier + 1 ? ' · unlock GR$unlock' : ''}',
  ]);
  return GameLogic.exitToHubHealed(next);
}

GameState _resolveGreaterRiftFail(GameState state) {
  if (!state.inGreaterRift) return state;
  if (state.grOutcome.isNotEmpty) return GameLogic.exitToHubHealed(state);
  final tier = GreaterRift.clampTier(state.grTier);
  final essence = GreaterRift.failEssence(tier);
  final next = state.copyWith(
    essence: state.essence + essence,
    grOutcome: 'depleted',
  );
  LogicNotices.addMetaPayoffs([
    'Greater Rift GR$tier failed · +${essence}e consolation',
  ]);
  return GameLogic.exitToHubHealed(next);
}
