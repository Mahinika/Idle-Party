part of 'game_logic.dart';

/// Month pass claim (READY on TODAY) — essence + title, no gold stamp.
GameState _claimMonthPass(GameState state, {DateTime? now}) {
  final t = (now ?? DateTime.now()).toUtc();
  var next = GameLogic.ensureWeeklyContract(state, now: t);
  final monthKey = next.metaDepth.monthPassKey.isNotEmpty
      ? next.metaDepth.monthPassKey
      : GameLogic.isoMonthKey(t);
  final month = LocalSeasonCatalog.forMonthKey(monthKey);
  if (!LocalSeasonCatalog.monthPassReady(next, month)) return next;
  final claimId = month.claimIdForMonth(monthKey);
  final claims = List<String>.from(next.metaDepth.claimedMonthGoals);
  if (claims.contains(claimId)) return next;
  claims.add(claimId);
  final titles = List<String>.from(next.metaDepth.titles);
  final title = month.titleReward;
  if (title != null && title.isNotEmpty && !titles.contains(title)) {
    titles.add(title);
  }
  return next.copyWith(
    essence: next.essence + month.essenceReward,
    metaDepth: next.metaDepth.copyWith(
      claimedMonthGoals: claims,
      titles: titles,
    ),
  );
}

GameState _enterWorldBoss(GameState state, {required bool practice}) {
  var next = WorldBoss.ensureWeek(state);
  if (!WorldBoss.canEnter(next)) return state;
  if (!practice) {
    if (next.metaDepth.worldBossTickets <= 0) return state;
    next = next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        worldBossTickets: next.metaDepth.worldBossTickets - 1,
      ),
    );
  }
  final layoutSeed = GameLogic.newLayoutSeed();
  final floor = DungeonGenerator.generateFloor(
    1,
    ascensionLevel: next.ascensionLevel,
    dungeonId: WorldBoss.dungeonId,
    layoutSeed: layoutSeed,
    bossEvery: 1,
  );
  final room = floor.first.copyWith(type: RoomType.boss);
  final cleared = next.copyWith(
    keystoneRunActive: false,
    keystoneRunLevel: 0,
    keystoneTimerMs: 0,
    keystoneParMs: 0,
    keystoneRunAffixes: const <String>[],
    keystoneOutcome: '',
  );
  return MetaSystems.evaluateAchievements(
    cleared.copyWith(
      inDungeon: true,
      inWorldBoss: true,
      inGauntlet: false,
      inRift: false,
      inGreaterRift: false,
      worldBossPractice: practice,
      apexTrialActive: false,
      dungeonId: WorldBoss.dungeonId,
      dungeonMode: DungeonMode.push,
      currentRoom: room,
      dungeonFloor: [room],
      enemies: GameLogic.createEnemyGroup(
        room,
        dungeonId: WorldBoss.dungeonId,
        fromState: cleared.copyWith(inWorldBoss: true),
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

GameState _applyRosterExhibition(GameState state) {
  if (state.metaDepth.rosterExhibition) return state;
  if (state.heroRoster.isEmpty) return state;
  for (final h in state.heroRoster) {
    if (h.level < GameLogic.maxHeroLevel) return state;
  }
  final titles = List<String>.from(state.metaDepth.titles);
  if (!titles.contains('Full Bench')) titles.add('Full Bench');
  return state.copyWith(
    metaDepth: state.metaDepth.copyWith(
      rosterExhibition: true,
      titles: titles,
    ),
  );
}

GameState _startApexTrial(GameState state) {
  if (!GameLogic.endgameUnlocked(state) || state.inDungeon) return state;
  final month = GameLogic.isoMonthKey(DateTime.now().toUtc());
  var next = state;
  if (next.metaDepth.apexTrialMonthKey != month) {
    next = next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        apexTrialMonthKey: month,
        apexTrialCleared: false,
      ),
    );
  }
  if (next.metaDepth.apexTrialCleared) return next;
  final dungeonId = GameLogic.recommendedDungeonId(next);
  return GameLogic.enterDungeon(
    next.copyWith(apexTrialActive: true),
    dungeonId: dungeonId,
  );
}
