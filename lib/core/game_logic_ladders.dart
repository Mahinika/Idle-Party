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
    keyLevel: 0,
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
  final t = Rift.clampTier(preferred);
  final layoutSeed = GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    1,
    ascensionLevel: state.ascensionLevel,
    dungeonId: Rift.dungeonId,
    layoutSeed: layoutSeed,
    keyLevel: t.clamp(0, 20),
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
      riftProgress01: 0,
      riftGuardianActive: false,
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
      state.riftProgress01 == 0 &&
      !state.riftGuardianActive &&
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
    riftProgress01: 0,
    riftGuardianActive: false,
    riftOutcome: '',
  );
}

GameState _setRiftPreferredTier(GameState state, int tier) {
  if (!GameLogic.endgameUnlocked(state)) return state;
  final t = Rift.clampTier(tier);
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
  if (state.riftGuardianActive) return state;
  final nextKills = state.riftKills + kills;
  final progress = RiftProgress.add(
    current: state.riftProgress01,
    killTarget: max(1, state.riftKillTarget),
    normalKills: kills,
    farm: true,
  );
  return state.copyWith(riftKills: nextKills, riftProgress01: progress);
}

EnemyUnit _buildRiftGuardian(GameState state, {required bool farm}) {
  final dungeonId = farm ? Rift.dungeonId : GreaterRift.dungeonId;
  final tier = farm ? state.riftTier : state.grTier;
  final level = max(
    1,
    state.currentRoom.globalBattleNumber + clampTierBoost(tier),
  );
  final bossRoom = DungeonRoom(
    floorNumber: max(1, state.currentRoom.floorNumber),
    roomIndex: 0,
    type: RoomType.boss,
    enemyLevel: level,
    enemyCount: 1,
  );
  final group = GameLogic.createEnemyGroup(
    bossRoom,
    dungeonId: dungeonId,
    fromState: farm
        ? state.copyWith(inRift: true, riftTier: tier)
        : state.copyWith(inGreaterRift: true, grTier: tier),
  );
  if (group.isEmpty) {
    return EnemyUnit(
      name: 'Rift Guardian',
      level: level,
      currentHp: 800 + tier * 120,
      stats: Stats.enemy(
        attack: 20 + tier * 4,
        defense: 8 + tier,
        maxHp: 800 + tier * 120,
      ),
      rewardGold: farm ? 40 + tier * 8 : 0,
      role: EnemyRole.boss,
      archetype: EnemyArchetype.tank,
    );
  }
  final boss = group.first;
  return boss.copyWith(
    name: 'Rift Guardian',
    role: EnemyRole.boss,
  );
}

int clampTierBoost(int tier) => max(0, tier);

GameState _maybeActivateRiftGuardian(GameState state) {
  if (!state.inRift || state.riftOutcome.isNotEmpty) return state;
  if (state.riftGuardianActive || state.riftProgress01 < 1.0) return state;
  final boss = _buildRiftGuardian(state, farm: true);
  return state.copyWith(
    riftGuardianActive: true,
    riftProgress01: 1.0,
    enemies: <EnemyUnit>[boss],
    currentRoom: state.currentRoom.copyWith(type: RoomType.boss, enemyCount: 1),
  );
}

bool _isRiftGuardian(EnemyUnit e) =>
    e.role == EnemyRole.boss || e.name == 'Rift Guardian';

bool _riftGuardianDown(GameState state) {
  // Leftover trash must not block a dead Guardian (old all-enemies-dead check).
  return !state.enemies.any((e) => _isRiftGuardian(e) && !e.isDefeated);
}

GameState? _tryResolveRift(GameState state) {
  if (!state.inRift || state.riftOutcome.isNotEmpty) return null;
  if (state.riftGuardianActive && _riftGuardianDown(state)) {
    return _resolveRiftSuccess(state);
  }
  return null;
}

GameState _resolveRiftSuccess(GameState state) {
  if (!state.inRift) return state;
  final tier = Rift.clampTier(state.riftTier);
  final unlock = Rift.unlockTierAfterSuccess(clearedTier: tier);
  final best = max(state.metaDepth.riftBestTier, tier);
  final essence = Rift.successEssence(tier);
  final gold = Rift.successGold(tier);
  var next = state.copyWith(
    gold: state.gold + gold,
    essence: state.essence + essence,
    lifetimeGoldEarned: state.lifetimeGoldEarned + gold,
    riftOutcome: 'timed',
    metaDepth: state.metaDepth.copyWith(
      riftBestTier: best,
      riftPreferredTier: Rift.clampTier(state.metaDepth.riftPreferredTier),
      lifetimeRiftClears: state.metaDepth.lifetimeRiftClears + 1,
    ),
  );
  next = GameLogic.syncMetaPayoffs(next);
  LogicNotices.addMetaPayoffs([
    'Rift R$tier cleared · +${essence}e · +${gold}g'
        '${unlock > tier ? ' · next best R$unlock' : ''}',
  ]);
  return GameLogic.exitToHubHealed(
    GameLogic.applyMissionProgress(next, riftClears: 1),
  );
}

GameState _enterGreaterRift(GameState state, {int? tier}) {
  if (!GameLogic.canEnterGreaterRift(state)) return state;
  final preferred = tier ?? state.metaDepth.grPreferredTier;
  final t = GreaterRift.clampTier(preferred);
  final layoutSeed = GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    1,
    ascensionLevel: state.ascensionLevel,
    dungeonId: GreaterRift.dungeonId,
    layoutSeed: layoutSeed,
    keyLevel: t.clamp(0, 20),
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
      grProgress01: 0,
      grGuardianActive: false,
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
      state.grProgress01 == 0 &&
      !state.grGuardianActive &&
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
    grProgress01: 0,
    grGuardianActive: false,
    grOutcome: '',
  );
}

GameState _setGrPreferredTier(GameState state, int tier) {
  if (!GameLogic.endgameUnlocked(state)) return state;
  final t = GreaterRift.clampTier(tier);
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
  if (state.grGuardianActive) return state;
  final nextKills = state.grKills + kills;
  final progress = RiftProgress.add(
    current: state.grProgress01,
    killTarget: max(1, state.grKillTarget),
    normalKills: kills,
    farm: false,
  );
  return state.copyWith(grKills: nextKills, grProgress01: progress);
}

GameState _maybeActivateGreaterRiftGuardian(GameState state) {
  if (!state.inGreaterRift || state.grOutcome.isNotEmpty) return state;
  if (state.grGuardianActive || state.grProgress01 < 1.0) return state;
  final boss = _buildRiftGuardian(state, farm: false);
  return state.copyWith(
    grGuardianActive: true,
    grProgress01: 1.0,
    enemies: <EnemyUnit>[boss],
    currentRoom: state.currentRoom.copyWith(type: RoomType.boss, enemyCount: 1),
  );
}

GameState? _tryResolveGreaterRift(GameState state) {
  if (!state.inGreaterRift || state.grOutcome.isNotEmpty) return null;
  // Last hit on the Guardian counts even if the clock ticked over this frame.
  if (state.grGuardianActive && _riftGuardianDown(state)) {
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
  // grBestTier = highest cleared (fast skip gifts the extra rank as cleared).
  // the extra rank as if it were cleared).
  final best = max(next.metaDepth.grBestTier, max(tier, unlock - 1));
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
      grPreferredTier: GreaterRift.clampTier(md.grPreferredTier),
      lifetimeGrClears: md.lifetimeGrClears + 1,
      seasonBestGrTier: seasonTier,
      seasonBestGrClearMs: seasonMs,
    ),
  );
  next = GameLogic.syncMetaPayoffs(next);
  LogicNotices.addMetaPayoffs([
    'Greater Rift GR$tier timed · +${essence}e · +${gold}g'
        '${unlock > tier + 1 ? ' · skip to GR$unlock' : ''}',
  ]);
  return GameLogic.exitToHubHealed(
    GameLogic.applyMissionProgress(next, greaterRiftClears: 1),
  );
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
