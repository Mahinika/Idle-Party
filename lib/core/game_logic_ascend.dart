part of 'game_logic.dart';

/// Prestige wipe shared by Ascend and AL20 Reborn: gold, forge, drops, floors.
/// Keeps hero levels, zone clears, Apex, relics, and other meta.
GameState _applyPrestigeRunWipe(GameState state) {
  var apexVault = List<EquipmentItem>.from(state.apexVault);
  for (final item in state.gearStash) {
    if (item.isApex) apexVault.add(item);
  }
  return state.copyWith(
    gold: 0,
    attackBonus: 0,
    defenseBonus: 0,
    vitalityBonus: 0,
    moveSpeedBonus: 0,
    attackSpeedBonus: 0,
    critBonus: 0,
    gearStash: const <EquipmentItem>[],
    marketListings: const <MarketListing>[],
    loadouts: const <GearLoadout>[],
    recentLoot: const <LootDrop>[],
    highestFloorCleared: 0,
    heroRoster: [
      for (final hero in state.heroRoster)
        hero.copyWith(equipped: _starterKeepingApex(hero)),
    ],
    apexVault: apexVault,
    clearEquipped: true,
  );
}

Map<EquipmentSlot, EquipmentItem> _starterKeepingApex(PartyHero hero) {
  final next = <EquipmentSlot, EquipmentItem>{};
  for (final e in hero.equipped.entries) {
    if (e.value.isApex) next[e.key] = e.value;
  }
  final starter = StarterGear.forSpec(hero.specId);
  final weapon = next[EquipmentSlot.weapon] ?? starter[EquipmentSlot.weapon];
  final blocksOh = weapon?.handed == WeaponHanded.twoHand;
  for (final e in starter.entries) {
    if (next.containsKey(e.key)) continue;
    if (blocksOh && e.key == EquipmentSlot.offHand) continue;
    next[e.key] = e.value;
  }
  return next;
}

/// Ascend prestige: raise AL, stack Blessing, unlock kits, reset the run bag.
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
    freshPrestige: true,
  );

  var base = _applyPrestigeRunWipe(GameLogic.leaveDungeon(state));

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

  return _finishPrestigeState(withMeta, now: now);
}

/// AL20 optional Reborn: same bag wipe, AL and Blessing unchanged.
GameState _rebornAtCapGameState(GameState state, {DateTime? now}) {
  if (!GameLogic.canRebornAtCap(state)) {
    return state;
  }

  final clock = (now ?? DateTime.now()).toUtc();
  final essence =
      state.essence + GameLogic.rebornEssenceReward();
  var base = _applyPrestigeRunWipe(GameLogic.leaveDungeon(state));
  var nextMeta = base.metaDepth.copyWith(
    lifetimeAscends: base.metaDepth.lifetimeAscends + 1,
    freshPrestige: true,
    dailyQuestDate: MetaSystems.dailyDateKey(clock),
    noWipeAscendReady: true,
  );

  var withMeta = base.copyWith(
    essence: essence,
    bossVictories: 0,
    missions: GameLogic.createMissionBoardFor(base),
    metaDepth: nextMeta,
    seenTips: [
      for (final t in base.seenTips)
        if (t != 'post_ascend') t,
    ],
    wipeStreakKey: '',
    wipeStreakCount: 0,
    wipeAdviceLine: '',
    lastUpdated: now ?? DateTime.now(),
  );
  withMeta = BlessingConstellation.grantPoints(withMeta, 1);
  return _finishPrestigeState(withMeta, now: now);
}

GameState _finishPrestigeState(GameState withMeta, {DateTime? now}) {
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
