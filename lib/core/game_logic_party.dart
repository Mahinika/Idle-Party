part of 'game_logic.dart';

GameState _gameLogicEnsureRogueHero(GameState state) {
  if (!state.rogueUnlocked) {
    return GameLogic.fillMissingStarterGear(state);
  }
  var next = state;
  final combatName = HeroSpecs.ascendUnlockSpec.name;
  final unlocked = List<String>.from(next.metaDepth.unlockedSpecs);
  var pending = List<String>.from(next.metaDepth.pendingHeroReveals);
  final wasMissing =
      !unlocked.contains(combatName) ||
      !next.heroRoster.any((h) => h.specId == HeroSpecs.ascendUnlockSpec);
  if (!unlocked.contains(combatName)) {
    unlocked.add(combatName);
    next = next.copyWith(
      metaDepth: next.metaDepth.copyWith(unlockedSpecs: unlocked),
    );
  }
  if (!next.heroRoster.any((h) => h.specId == HeroSpecs.ascendUnlockSpec)) {
    final rogue = PartyHero.starting(
      name: HeroSpecs.def(HeroSpecs.ascendUnlockSpec).defaultName,
      specId: HeroSpecs.ascendUnlockSpec,
      stats: PartyHero.startingStatsForSpec(HeroSpecs.ascendUnlockSpec),
      equipped: StarterGear.forSpec(HeroSpecs.ascendUnlockSpec),
      level: GameLogic.rosterSeedLevel(next),
      race: GameLogic._rosterRace(next),
    );
    final roster = [...next.heroRoster, rogue];
    var active = List<String>.from(next.activeHeroIds);
    if (active.length < next.maxActivePartySize &&
        !active.contains(rogue.id)) {
      active = [...active, rogue.id];
    }
    next = next.copyWith(heroRoster: roster, activeHeroIds: active);
  } else {
    final combat = next.heroRoster.firstWhere(
      (h) => h.specId == HeroSpecs.ascendUnlockSpec,
    );
    if (!next.activeHeroIds.contains(combat.id) &&
        next.activeHeroIds.length < next.maxActivePartySize) {
      next = next.copyWith(activeHeroIds: [...next.activeHeroIds, combat.id]);
    }
  }
  if (wasMissing && !pending.contains(combatName)) {
    pending = [...pending, combatName];
    next = next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        unlockedSpecs: unlocked,
        pendingHeroReveals: pending,
      ),
    );
  }
  return GameLogic.fillMissingStarterGear(next);
}


GameState _gameLogicUnlockPartySlot5(GameState state) {
  if (state.metaDepth.partySlot5Unlocked) return state;
  if (state.ascensionLevel < GameLogic.partySlot5MinAscension) return state;
  if (state.essence < GameLogic.partySlot5EssenceCost) return state;
  return state.copyWith(
    essence: state.essence - GameLogic.partySlot5EssenceCost,
    metaDepth: state.metaDepth.copyWith(partySlot5Unlocked: true),
    lastUpdated: DateTime.now(),
  );
}


GameState _gameLogicSetActiveParty(GameState state, List<String> heroIds) {
  if (state.inDungeon) return state;
  final maxSize = state.maxActivePartySize;
  final seen = <String>{};
  final next = <String>[];
  for (final id in heroIds) {
    if (!seen.add(id)) continue;
    if (state.rosterHero(id) == null) continue;
    next.add(id);
    if (next.length >= maxSize) break;
  }
  if (next.isEmpty) return state;
  return state.copyWith(activeHeroIds: next, lastUpdated: DateTime.now());
}


bool _gameLogicCanUnlockSpec(GameState state, HeroSpecId specId) {
  if (HeroSpecs.starterUnlocked.contains(specId)) return true;
  if (specId == HeroSpecs.ascendUnlockSpec) {
    return state.rogueUnlocked || state.ascensionLevel > 0;
  }
  final al = state.ascensionLevel;
  final cleared = state.highestDungeonCleared;
  return switch (specId) {
    HeroSpecId.arms => cleared >= 1 || al >= 1,
    HeroSpecId.fury => cleared >= 0 || al >= 2,
    HeroSpecId.holyPaladin => al >= 1 || state.essence >= 25,
    HeroSpecId.protPaladin => al >= 3,
    HeroSpecId.retribution => cleared >= 2,
    HeroSpecId.beastMastery => al >= 2,
    HeroSpecId.marksmanship => cleared >= 3,
    HeroSpecId.survival => al >= 4,
    HeroSpecId.assassination => al >= 3,
    HeroSpecId.subtlety => cleared >= 4,
    HeroSpecId.holyPriest => al >= 2,
    HeroSpecId.shadow => cleared >= 5,
    HeroSpecId.blood || HeroSpecId.frostDk => al >= 5,
    HeroSpecId.unholy => cleared >= 6,
    HeroSpecId.elemental || HeroSpecId.enhancement => al >= 4,
    HeroSpecId.restorationShaman => al >= 3,
    HeroSpecId.arcane => al >= 2,
    HeroSpecId.frostMage => al >= 3,
    HeroSpecId.affliction || HeroSpecId.demonology => al >= 6,
    HeroSpecId.destruction => cleared >= 5,
    HeroSpecId.balance || HeroSpecId.feral => al >= 4,
    HeroSpecId.guardian => al >= 5,
    HeroSpecId.restorationDruid => al >= 3,
    _ => false,
  };
}


GameState _gameLogicSyncSpecUnlocks(GameState state) {
  var next = state;
  for (final def in HeroSpecs.all) {
    if (_gameLogicCanUnlockSpec(next, def.id) && !next.isSpecUnlocked(def.id)) {
      next = _gameLogicUnlockSpec(next, def.id);
    } else if (_gameLogicCanUnlockSpec(next, def.id) &&
        !next.heroRoster.any((h) => h.specId == def.id)) {
      next = _gameLogicUnlockSpec(next, def.id);
    }
  }
  return next;
}


GameState _gameLogicUnlockSpec(GameState state, HeroSpecId specId) {
  if (!_gameLogicCanUnlockSpec(state, specId) &&
      !HeroSpecs.starterUnlocked.contains(specId)) {
    return state;
  }
  if (state.isSpecUnlocked(specId) &&
      state.heroRoster.any((h) => h.specId == specId)) {
    return state;
  }
  final wasNew =
      !state.isSpecUnlocked(specId) ||
      !state.heroRoster.any((h) => h.specId == specId);
  final unlocked = <String>{
    ...state.metaDepth.unlockedSpecs,
    specId.name,
  }.toList();
  var pending = List<String>.from(state.metaDepth.pendingHeroReveals);
  if (wasNew && !pending.contains(specId.name)) {
    pending = [...pending, specId.name];
  }
  var next = state.copyWith(
    metaDepth: state.metaDepth.copyWith(
      unlockedSpecs: unlocked,
      pendingHeroReveals: pending,
    ),
    lastUpdated: DateTime.now(),
  );
  if (next.heroRoster.any((h) => h.specId == specId)) {
    return next;
  }
  final def = HeroSpecs.def(specId);
  final hero = PartyHero.starting(
    name: def.defaultName,
    specId: specId,
    stats: PartyHero.startingStatsForSpec(specId),
    equipped: StarterGear.forSpec(def.id),
    level: GameLogic.rosterSeedLevel(next),
    race: GameLogic._rosterRace(next),
  );
  return next.copyWith(
    heroRoster: [...next.heroRoster, hero],
    lastUpdated: DateTime.now(),
  );
}


GameState _gameLogicAckPendingHeroReveals(GameState state) {
  if (state.metaDepth.pendingHeroReveals.isEmpty) return state;
  return state.copyWith(
    metaDepth: state.metaDepth.copyWith(pendingHeroReveals: const <String>[]),
    lastUpdated: DateTime.now(),
  );
}


