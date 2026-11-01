part of 'game_logic.dart';

GameState _gameLogicEnterDungeon(GameState state, {String dungeonId = 'sandy'}) {
  final def = DungeonCatalog.byId(dungeonId);
  final unlocked = DungeonCatalog.isUnlocked(
    dungeonId,
    GameLogic.partyMeanLevel(state),
    state.highestDungeonCleared,
  );
  if (!unlocked && def.number > 0) {
    return state;
  }
  final baseSeed = GameLogic.newLayoutSeed();
  final mirrorSalt = LocalSeasonCatalog.mirrorLayoutSeed(state);
  final layoutSeed = mirrorSalt == 0 ? baseSeed : baseSeed ^ mirrorSalt;
  final primed = _beginKeystoneRun(GameLogic.ensureWeeklyContract(state));
  final bossAt = GameLogic.bossFloorFor(primed);
  final resume =
      primed.dungeonMode != DungeonMode.farm &&
      GameLogic.firstBossPending(primed) &&
      primed.highestFloorCleared > 0 &&
      primed.highestFloorCleared < bossAt;
  final startFloor = resume ? primed.highestFloorCleared + 1 : 1;
  final floor = DungeonGenerator.generateFloor(
    startFloor,
    ascensionLevel: primed.ascensionLevel,
    dungeonId: dungeonId,
    layoutSeed: layoutSeed,
    keyLevel: GameLogic.layoutKeyLevel(primed),
    crowded: GameLogic.layoutCrowded(primed),
    bossFloor: bossAt,
  );
  final room = floor.first;
  return primed.copyWith(
    inDungeon: true,
    inGauntlet: false,
    dungeonId: dungeonId,
    dungeonMode: primed.dungeonMode,
    highestFloorCleared: resume ? primed.highestFloorCleared : 0,
    currentRoom: room,
    dungeonFloor: floor,
    enemies: GameLogic.createEnemyGroup(room, dungeonId: dungeonId, fromState: primed),
    layoutSeed: layoutSeed,
    wipeReviveUsed: false,
    heroes: primed.heroes
        .map(
          (hero) => hero.copyWith(currentHp: primed.effectiveHeroMaxHp(hero)),
        )
        .toList(),
    lastUpdated: DateTime.now(),
  );
}


GameState _beginKeystoneRun(GameState state) {
  if (!GameLogic.endgameUnlocked(state)) {
    return _clearKeystoneRun(state.copyWith(hardmodeLevel: 0));
  }
  final key = state.hardmodeLevel.clamp(0, state.effectiveMaxHardmode);
  if (key <= 0) {
    return _clearKeystoneRun(state);
  }
  final affixes = Keystone.affixesFor(
    key: key,
    weeklyModifier: state.metaDepth.weeklyModifier,
    weeklyKey: state.metaDepth.weeklyKey,
    personalBossRush: state.challengeBossRush,
    personalNoFlask: state.challengeNoFlask,
  );
  final par =
      (Keystone.parTimeMs(bossFloor: GameLogic.bossFloorFor(state), key: key) *
              BlessingConstellation.keyParMul(state))
          .round();
  return state.copyWith(
    keystoneRunActive: true,
    keystoneRunLevel: key,
    keystoneTimerMs: 0,
    keystoneParMs: par,
    keystoneRunAffixes: affixes,
    keystoneOutcome: '',
  );
}


GameState _clearKeystoneRun(GameState state) {
  if (!state.keystoneRunActive &&
      state.keystoneRunLevel == 0 &&
      state.keystoneTimerMs == 0 &&
      state.keystoneParMs == 0 &&
      state.keystoneRunAffixes.isEmpty &&
      state.keystoneOutcome.isEmpty) {
    return state;
  }
  return state.copyWith(
    keystoneRunActive: false,
    keystoneRunLevel: 0,
    keystoneTimerMs: 0,
    keystoneParMs: 0,
    keystoneRunAffixes: const <String>[],
    keystoneOutcome: '',
  );
}


GameState _gameLogicAdvanceKeystoneTimer(GameState state, int deltaMs) {
  if (!state.keystoneRunActive || deltaMs <= 0) return state;
  if (state.keystoneOutcome.isNotEmpty) return state;
  return state.copyWith(keystoneTimerMs: state.keystoneTimerMs + deltaMs);
}


GameState _gameLogicLeaveDungeon(GameState state) {
  var working = state;
  if (state.inRift && state.riftOutcome.isEmpty) {
    final essence = Rift.failEssence(state.riftTier);
    working = working.copyWith(
      essence: working.essence + essence,
      riftOutcome: 'depleted',
    );
    LogicNotices.addMetaPayoffs([
      'Rift R${Rift.clampTier(state.riftTier)} ended · +${essence}e',
    ]);
  }
  if (state.inGreaterRift && state.grOutcome.isEmpty) {
    final essence = GreaterRift.failEssence(state.grTier);
    final tier = GreaterRift.clampTier(state.grTier);
    final wiped = state.aliveHeroes == 0;
    working = working.copyWith(
      essence: working.essence + essence,
      grOutcome: 'depleted',
    );
    LogicNotices.addMetaPayoffs([
      wiped
          ? 'Ranked GR$tier wipe'
          : 'Greater Rift GR$tier ended · +${essence}e',
    ]);
  }
  // Ticket spent on enter — refund if leave/wipe before a paid clear.
  if (state.inWorldBoss &&
      !state.worldBossPractice &&
      !state.metaDepth.worldBossClearedWeek) {
    final tickets = (working.metaDepth.worldBossTickets + 1).clamp(
      0,
      AshenCrown.ticketsPerWeek,
    );
    working = working.copyWith(
      metaDepth: working.metaDepth.copyWith(worldBossTickets: tickets),
    );
  }
  final heroes = [
    for (final h in working.heroes)
      h.copyWith(
        currentHp: h.currentHp.clamp(0, working.effectiveHeroMaxHp(h)),
      ),
  ];
  var next = _clearGreaterRiftRun(
    _clearRiftRun(
      _clearKeystoneRun(
        working.copyWith(
          inDungeon: false,
          inGauntlet: false,
          inRift: false,
          inGreaterRift: false,
          inWorldBoss: false,
          worldBossPractice: false,
          apexTrialActive: false,
          pushResumeFloor: 0,
          wipeReviveUsed: false,
          heroes: heroes,
          lastUpdated: DateTime.now(),
        ),
      ),
    ),
  );
  if (state.inGauntlet) {
    next = GameLogic.recordGauntletRun(
      next,
      reachedFloor: state.currentRoom.floorNumber,
    );
  }
  return next;
}


GameState _gameLogicExitToHubHealed(GameState state) {
  final left = _gameLogicLeaveDungeon(state);
  return left.copyWith(
    heroes: [
      for (final h in left.heroes)
        h.copyWith(currentHp: left.effectiveHeroMaxHp(h)),
    ],
    lastUpdated: DateTime.now(),
  );
}


GameState _gameLogicSetDungeonMode(GameState state, DungeonMode mode) {
  if (state.inGauntlet || state.inAnyRiftMode) {
    // Gauntlet / Rift / Greater Rift are endless PUSH only.
    return state.copyWith(
      dungeonMode: DungeonMode.push,
      lastUpdated: DateTime.now(),
    );
  }
  if (state.dungeonMode == mode) {
    return state;
  }
  return state.copyWith(dungeonMode: mode, lastUpdated: DateTime.now());
}


bool _gameLogicCanTravelToFloor(GameState state, int floorNumber) {
  if (state.inGauntlet || state.inAnyRiftMode) return false;
  if (floorNumber < 1) {
    return false;
  }
  return floorNumber <= state.maxReachableFloor;
}


GameState _gameLogicTravelToFloor(GameState state, int floorNumber) {
  if (!_gameLogicCanTravelToFloor(state, floorNumber)) {
    return state;
  }
  if (floorNumber == state.currentRoom.floorNumber &&
      !state.isPartyDefeated) {
    return state;
  }
  final layoutSeed = GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    floorNumber,
    ascensionLevel: state.ascensionLevel,
    dungeonId: state.dungeonId,
    layoutSeed: layoutSeed,
    keyLevel: GameLogic.layoutKeyLevel(state),
    crowded: GameLogic.layoutCrowded(state),
    bossFloor: GameLogic.pushBossFloor(state),
  );
  final firstRoom = floor.first;
  return state.copyWith(
    currentRoom: firstRoom,
    dungeonFloor: floor,
    enemies: GameLogic.createEnemyGroup(
      firstRoom,
      dungeonId: state.dungeonId,
      fromState: state,
    ),
    layoutSeed: layoutSeed,
    heroes: state.heroes
        .map(
          (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
        )
        .toList(),
    lastUpdated: DateTime.now(),
  );
}


GameState _gameLogicRetreatFromFailedPush(GameState state) {
  final safeFloor = max(1, state.highestFloorCleared);
  return _gameLogicTravelToFloor(
    state.copyWith(
      metaDepth: state.metaDepth.copyWith(noWipeAscendReady: false),
    ),
    safeFloor,
  );
}


GameState _gameLogicNoteOfflineWipe(GameState state) {
  final key = GameLogic.wipeFloorKey(state);
  final count = state.wipeStreakKey == key ? state.wipeStreakCount + 1 : 1;
  return state.copyWith(wipeStreakKey: key, wipeStreakCount: count);
}


GameState _gameLogicContinueAfterWipe(GameState state) {
  if (state.inGauntlet || state.inAnyRiftMode) {
    return _gameLogicExitToHubHealed(state);
  }
  if (MetaSystems.isActiveDailyRun(state)) {
    return _gameLogicRestartFloor(state);
  }
  final cur = state.currentRoom.floorNumber;
  final pushingNew =
      state.dungeonMode == DungeonMode.push &&
      cur > state.highestFloorCleared;
  if (pushingNew && state.wipeStreakCount >= GameLogic.pushWipesBeforeFarm) {
    final safe = max(1, state.highestFloorCleared);
    return _gameLogicTravelToFloor(
      state.copyWith(
        dungeonMode: DungeonMode.farm,
        pushResumeFloor: cur,
        metaDepth: state.metaDepth.copyWith(noWipeAscendReady: false),
      ),
      safe,
    );
  }
  return _gameLogicRestartFloor(state);
}


GameState _gameLogicRestartFloor(GameState state) {
  final keepDailySeed = MetaSystems.isActiveDailyRun(state);
  final layoutSeed = keepDailySeed ? state.layoutSeed : GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    state.currentRoom.floorNumber,
    ascensionLevel: state.ascensionLevel,
    dungeonId: state.dungeonId,
    layoutSeed: layoutSeed,
    keyLevel: GameLogic.layoutKeyLevel(state),
    crowded: GameLogic.layoutCrowded(state),
    bossFloor: GameLogic.pushBossFloor(state),
  );
  final firstRoom = floor.first;
  return state.copyWith(
    heroes: state.heroes
        .map(
          (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
        )
        .toList(),
    enemies: GameLogic.createEnemyGroup(
      firstRoom,
      dungeonId: state.dungeonId,
      fromState: state,
    ),
    currentRoom: firstRoom,
    dungeonFloor: floor,
    layoutSeed: layoutSeed,
    metaDepth: state.metaDepth.copyWith(noWipeAscendReady: false),
  );
}


GameState _gameLogicReturnToClearableFloor(GameState state) {
  if (!state.inDungeon ||
      state.inGauntlet ||
      state.inAnyRiftMode ||
      state.inWorldBoss) {
    return state;
  }
  if (state.dungeonMode == DungeonMode.farm) return state;
  final cur = state.currentRoom.floorNumber;
  if (cur <= state.highestFloorCleared) return state;
  final hurt =
      state.heroes.isNotEmpty &&
      state.heroes.every(
        (h) => h.currentHp <= state.effectiveHeroMaxHp(h) * 0.4,
      );
  if (state.wipeStreakCount < 1 && !hurt) return state;
  final safe = max(1, state.highestFloorCleared);
  return _gameLogicTravelToFloor(
    state.copyWith(dungeonMode: DungeonMode.farm, pushResumeFloor: cur),
    safe,
  );
}


