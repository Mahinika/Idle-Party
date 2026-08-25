part of 'game_logic.dart';

/// Ascend claim: raise AL, stack Blessing, unlock kits — **no soft-reset**.
///
/// Keeps wallet gold, forge, gear, floors, loadouts, and market. Only clears
/// bossVictories (work toward the next AL) and leaves any active dungeon run.
GameState _ascendGameState(GameState state, {DateTime? now}) {
  if (!GameLogic.canAscend(state)) {
    return state;
  }

  final clock = (now ?? DateTime.now()).toUtc();
  final nextLevel = state.ascensionLevel + 1;
  final milestoneBonus = MetaSystems.ascendMilestoneReward(
    state.ascensionLevel,
    nextLevel,
  );

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
    dailyQuestDate: MetaSystems.dailyDateKey(clock),
  );

  // Leave any active dungeon/KEY/rift without wiping hub power.
  var base = GameLogic.leaveDungeon(state);

  // Keep full gear — Ascend is a power unlock, not a wipe.
  var preservedRoster = List<PartyHero>.from(base.heroRoster);
  if (!preservedRoster.any((h) => h.specId == HeroSpecs.ascendUnlockSpec)) {
    final seedPool =
        preservedRoster.isNotEmpty ? preservedRoster : base.heroes;
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
  final maxActive = base.metaDepth.partySlot5Unlocked ? 5 : 4;
  var preservedActive = [
    for (final id in base.activeHeroIds)
      if (preservedRoster.any((h) => h.id == id)) id,
  ];
  if (preservedActive.isEmpty) {
    preservedActive = [for (final h in preservedRoster.take(maxActive)) h.id];
  } else {
    for (final h in preservedRoster) {
      if (preservedActive.length >= maxActive) break;
      if (!preservedActive.contains(h.id)) {
        preservedActive = [...preservedActive, h.id];
      }
    }
  }

  final hmCap = Keystone.maxForState(
    base.copyWith(ascensionLevel: nextLevel, heroRoster: preservedRoster),
  );

  var withMeta = base.copyWith(
    heroRoster: preservedRoster,
    activeHeroIds: preservedActive,
    essence: preservedEssence,
    ascensionLevel: nextLevel,
    bossVictories: 0,
    rogueUnlocked: true,
    missions: GameLogic.createMissionBoardFor(
      base.copyWith(
        ascensionLevel: nextLevel,
        heroRoster: preservedRoster,
        activeHeroIds: preservedActive,
      ),
    ),
    metaDepth: nextMeta,
    soulboundItem: base.soulboundItem == null
        ? null
        : GameLogic.scaleSoulboundForAl(base.soulboundItem!, nextLevel),
    seenTips: [
      for (final t in base.seenTips)
        if (t != 'post_ascend') t,
    ],
    hardmodeLevel: base.hardmodeLevel.clamp(0, hmCap),
    wipeStreakKey: '',
    wipeStreakCount: 0,
    wipeAdviceLine: '',
    lastUpdated: now ?? DateTime.now(),
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
