part of 'game_logic.dart';

/// Prestige: reset the run, keep essence/relics/sanctuary/pets/Apex, bump AL.
GameState _ascendGameState(GameState state, {DateTime? now}) {
  if (!GameLogic.canAscend(state)) {
    return state;
  }

  final nextLevel = state.ascensionLevel + 1;
  final milestoneBonus = MetaSystems.ascendMilestoneReward(
    state.ascensionLevel,
    nextLevel,
  );
  final preservedRelics = List<String>.from(state.unlockedRelics);

  final streak = state.metaDepth.noWipeAscendReady
      ? state.metaDepth.ascendStreak + 1
      : 0;
  final bestStreak = max(state.metaDepth.bestAscendStreak, streak);
  final streakEssence = streak > 0 && streak % 3 == 0 ? (10 + streak * 2) : 0;
  final preservedEssence =
      state.essence +
      GameLogic.ascendEssenceReward(nextLevel) +
      milestoneBonus +
      streakEssence;
  final legacyGain = (nextLevel ~/ 5) - (state.ascensionLevel ~/ 5);
  final titles = List<String>.from(state.metaDepth.titles);
  for (final entry in AscendTitles.byAl.entries) {
    if (nextLevel >= entry.key && !titles.contains(entry.value)) {
      titles.add(entry.value);
    }
  }
  final trophies = List<String>.from(state.metaDepth.zoneTrophies);
  for (final d in DungeonCatalog.all) {
    if (d.number <= state.highestDungeonCleared && !trophies.contains(d.id)) {
      trophies.add(d.id);
    }
  }
  final unlockedSpecs = <String>{
    ...state.metaDepth.unlockedSpecs,
    for (final s in HeroSpecs.starterUnlocked) s.name,
    HeroSpecs.ascendUnlockSpec.name,
  }.toList();
  final nextMeta = state.metaDepth.copyWith(
    ascendStreak: streak,
    bestAscendStreak: bestStreak,
    lifetimeAscends: state.metaDepth.lifetimeAscends + 1,
    titles: titles,
    legacyPoints: state.metaDepth.legacyPoints + legacyGain,
    heirloomAlBonus: nextLevel ~/ 5,
    zoneTrophies: trophies,
    noWipeAscendReady: true,
    unlockedSpecs: unlockedSpecs,
    ascendBlessings: state.metaDepth.ascendBlessings + 1,
  );

  final fresh = GameLogic.createInitialState(now: now);
  final hmCap = Keystone.maxForAl(nextLevel);

  final stashApex = [
    for (final g in state.gearStash)
      if (g.isApex) g,
  ];
  final preservedVault = [...state.apexVault, ...stashApex];
  var preservedRoster = [
    for (final h in state.heroRoster) h.copyWith(equipped: GameLogic.keepApexOnly(h)),
  ];
  if (!preservedRoster.any((h) => h.specId == HeroSpecs.ascendUnlockSpec)) {
    final seedPool = preservedRoster.isNotEmpty ? preservedRoster : state.heroes;
    final seedLevel = seedPool.isEmpty
        ? 1
        : max(
            1,
            seedPool.fold<int>(0, (s, h) => s + h.level) ~/ seedPool.length,
          );
    preservedRoster = [
      ...preservedRoster,
      PartyHero.starting(
        name: HeroSpecs.def(HeroSpecs.ascendUnlockSpec).defaultName,
        specId: HeroSpecs.ascendUnlockSpec,
        stats: PartyHero.startingStatsForSpec(HeroSpecs.ascendUnlockSpec),
        equipped: StarterGear.forSpec(HeroSpecs.ascendUnlockSpec),
        level: seedLevel,
      ),
    ];
  }
  final maxActive = state.metaDepth.partySlot5Unlocked ? 5 : 4;
  var preservedActive = [
    for (final id in state.activeHeroIds)
      if (preservedRoster.any((h) => h.id == id)) id,
  ];
  if (preservedActive.isEmpty) {
    preservedActive = [for (final h in preservedRoster.take(maxActive)) h.id];
  }

  var withMeta = fresh.copyWith(
    heroRoster: preservedRoster,
    activeHeroIds: preservedActive,
    partyName: state.partyName,
    essence: preservedEssence,
    lifetimeGoldEarned: state.lifetimeGoldEarned,
    unlockedRelics: preservedRelics,
    ascensionLevel: nextLevel,
    missions: GameLogic.createMissionBoardFor(
      state.copyWith(ascensionLevel: nextLevel, highestFloorCleared: 0),
    ),
    activePet: state.activePet,
    ownedPets: List<Pet>.from(state.ownedPets),
    sanctuaryGoldLevel: state.sanctuaryGoldLevel,
    sanctuaryPowerLevel: state.sanctuaryPowerLevel,
    sanctuaryVitalityLevel: state.sanctuaryVitalityLevel,
    metaDepth: nextMeta,
    dungeonMode: state.dungeonMode,
    highestFloorCleared: 0,
    highestDungeonCleared: state.highestDungeonCleared,
    inDungeon: false,
    soulboundFragments: state.soulboundFragments,
    soulboundItem: state.soulboundItem == null
        ? null
        : GameLogic.scaleSoulboundForAl(state.soulboundItem!, nextLevel),
    craftMaterials: Map<String, int>.from(state.craftMaterials),
    craftPity: Map<String, int>.from(state.craftPity),
    apexVault: preservedVault,
    godHandLevel: state.godHandLevel,
    soundMuted: state.soundMuted,
    vfxQuality: state.vfxQuality,
    autoSellMaxPower: state.autoSellMaxPower,
    autoSellMaxRarity: state.autoSellMaxRarity,
    autoDisassembleMaxIlvl: state.autoDisassembleMaxIlvl,
    autoDisassembleMaxRarity: state.autoDisassembleMaxRarity,
    rogueUnlocked: true,
    seenTips: [
      for (final t in state.seenTips)
        if (t != 'post_ascend') t,
    ],
    loadouts: const <GearLoadout>[],
    achievements: List<String>.from(state.achievements),
    codexEnemies: List<String>.from(state.codexEnemies),
    codexItems: List<String>.from(state.codexItems),
    challengeBossRush: state.challengeBossRush,
    challengeNoFlask: state.challengeNoFlask,
    hardmodeLevel: state.hardmodeLevel.clamp(0, hmCap),
    keystoneRunActive: false,
    keystoneRunLevel: 0,
    keystoneTimerMs: 0,
    keystoneParMs: 0,
    keystoneRunAffixes: const <String>[],
    keystoneOutcome: '',
    inRift: false,
    riftTier: 0,
    riftTimerMs: 0,
    riftParMs: 0,
    riftKillTarget: 0,
    riftKills: 0,
    riftOutcome: '',
    inGreaterRift: false,
    grTier: 0,
    grTimerMs: 0,
    grParMs: 0,
    grKillTarget: 0,
    grKills: 0,
    grOutcome: '',
    colorblindMode: state.colorblindMode,
    uiTextScale: state.uiTextScale,
    dungeonZoom: state.dungeonZoom,
    hapticsEnabled: state.hapticsEnabled,
    keepScreenAwake: state.keepScreenAwake,
    lastDailyDate: state.lastDailyDate,
    dailyClaimed: state.dailyClaimed,
    seenChangelogVersion: state.seenChangelogVersion,
    sessionTelemetryOptIn: state.sessionTelemetryOptIn,
    sessionTelemetryLog: state.sessionTelemetryLog,
    lastUpdated: now ?? DateTime.now(),
    clearEquipped: true,
    marketListings: const <MarketListing>[],
    marketListingsRefreshMs: 0,
    wipeStreakKey: '',
    wipeStreakCount: 0,
    wipeAdviceLine: '',
  );
  withMeta = GameLogic.ensureRogueHero(withMeta);
  withMeta = GameLogic.syncSpecUnlocks(withMeta);
  withMeta = withMeta.copyWith(
    heroes: withMeta.heroes
        .map(
          (hero) => hero.copyWith(currentHp: withMeta.effectiveHeroMaxHp(hero)),
        )
        .toList(),
  );
  withMeta = GameLogic.ensureWeeklyContract(withMeta, now: now);
  withMeta = MetaSystems.evaluateAchievements(withMeta);
  withMeta = GameLogic.syncMetaPayoffs(withMeta);
  final recommend = GameLogic.recommendedDungeonId(withMeta);
  if (recommend != withMeta.dungeonId) {
    withMeta = withMeta.copyWith(dungeonId: recommend);
  }
  return withMeta;
}
