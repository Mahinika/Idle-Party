import 'dart:convert';
import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/gear_loadout.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/market_listing.dart';
import '../models/meta_depth.dart';
import '../models/mission.dart';
import '../models/pet.dart';
import 'ad_boost.dart';
import 'relic_ids.dart';
import 'dungeon_generator.dart';
import 'economy_service.dart';
import 'blessing_constellation.dart';
import 'game_state.dart';
import 'keystone.dart';
import 'logic_notices.dart';
import 'rift.dart';
import 'greater_rift.dart';
import 'apex_forge.dart';
import 'encounter_factory.dart';
import 'market_service.dart';
import 'market_listings_service.dart';
import 'gear_service.dart';
import 'mission_board.dart';
import 'loot_pipeline.dart';
import 'offline_progress.dart';
import 'pet_service.dart';
import 'starter_gear.dart';
import 'local_season.dart';
import 'meta_systems.dart';
import 'play_games_bridge.dart';
import 'play_games_scores.dart';
import 'wipe_advice.dart';
import 'party_name_filter.dart';
import 'world_boss.dart';
import 'party_power.dart';

part 'game_logic_ascend.dart';
part 'game_logic_endgame.dart';

class GameLogic {
  /// Injectable randomness for enemy targeting (seed in tests).
  static Random random = Random();

  static const String warBannerRelic = RelicIds.warBanner;
  static const String ironWardRelic = RelicIds.ironWard;
  static const String phoenixEmberRelic = RelicIds.phoenixEmber;
  static const String godHandFocusRelic = RelicIds.godHandFocus;
  static const String chamberLuckRelic = RelicIds.chamberLuck;
  static const String ironWillRelic = RelicIds.ironWill;
  static const List<String> relicOrder = <String>[
    warBannerRelic,
    ironWardRelic,
    phoenixEmberRelic,
    godHandFocusRelic,
    chamberLuckRelic,
    ironWillRelic,
  ];
  static const Map<LootRarity, String> rarityNames = <LootRarity, String>{
    LootRarity.common: 'Common',
    LootRarity.uncommon: 'Uncommon',
    LootRarity.rare: 'Rare',
    LootRarity.epic: 'Epic',
    LootRarity.legendary: 'Legendary',
  };
  static const Map<String, String> relicNames = <String, String>{
    warBannerRelic: 'War Banner',
    ironWardRelic: 'Iron Ward',
    phoenixEmberRelic: 'Phoenix Ember',
    godHandFocusRelic: 'God Hand Focus',
    chamberLuckRelic: 'Chamber Luck',
    ironWillRelic: 'Iron Will',
  };
  static const Map<String, String> relicDescriptions = <String, String>{
    warBannerRelic: 'Permanent +4 team attack aura.',
    ironWardRelic: 'Permanent +16 team defense aura.',
    phoenixEmberRelic: 'Permanent +48 max HP for every hero.',
    godHandFocusRelic: '+3 God Hand damage per tier.',
    chamberLuckRelic: '+5% loot find per tier.',
    ironWillRelic: '+8 flat damage mitigate per tier.',
  };
  static const Map<String, int> relicCosts = <String, int>{
    warBannerRelic: 6,
    ironWardRelic: 14,
    phoenixEmberRelic: 28,
    godHandFocusRelic: 36,
    chamberLuckRelic: 42,
    ironWillRelic: 48,
  };

  /// Per-tier payout shown on KEEP / CAMP (English).
  static String relicPerTierPayout(String relicId) => switch (relicId) {
    warBannerRelic => '+$relicAttackPerTier ATK',
    ironWardRelic => '+$relicDefensePerTier DEF',
    phoenixEmberRelic => '+$relicVitalityPerTier HP',
    godHandFocusRelic => '+3 God Hand',
    chamberLuckRelic => '+5% loot',
    ironWillRelic => '+$relicMitigatePerTier mitigate',
    _ => '',
  };

  static String relicOwnedPayout(GameState state, String relicId) =>
      switch (relicId) {
        warBannerRelic => '+${state.relicAttackBonus} ATK',
        ironWardRelic => '+${state.relicDefenseBonus} DEF',
        phoenixEmberRelic => '+${state.relicVitalityBonus} HP',
        godHandFocusRelic => '+${state.relicGodHandDamageBonus} God Hand',
        chamberLuckRelic => '+${state.relicLootFindPercent}% loot',
        ironWillRelic => '+${state.relicMitigateFlat} mitigate',
        _ => '',
      };

  /// One CAMP/KEEP line of owned relic bonuses, or null if none.
  static String? relicKeepSummary(GameState state) {
    final bits = <String>[
      if (state.relicAttackBonus > 0) '+${state.relicAttackBonus} ATK',
      if (state.relicDefenseBonus > 0) '+${state.relicDefenseBonus} DEF',
      if (state.relicVitalityBonus > 0) '+${state.relicVitalityBonus} HP',
      if (state.relicGodHandDamageBonus > 0)
        '+${state.relicGodHandDamageBonus} God Hand',
      if (state.relicLootFindPercent > 0)
        '+${state.relicLootFindPercent}% loot',
      if (state.relicMitigateFlat > 0) '+${state.relicMitigateFlat} mitigate',
    ];
    if (bits.isEmpty) return null;
    return 'KEEP relics · ${bits.join(' · ')}';
  }

  static const int starterPartySize = 3;

  static GameState createInitialState({
    DateTime? now,
    List<HeroSpecId>? partySpecs,
    String? partyName,
  }) {
    final timestamp = now ?? DateTime.now();
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: 0,
      dungeonId: 'sandy',
      layoutSeed: layoutSeed,
    );
    final firstRoom = floor.first;
    final specs = _normalizeStarterSpecs(partySpecs);
    final roster = <PartyHero>[
      for (final specId in specs)
        PartyHero.starting(
          name: HeroSpecs.def(specId).defaultName,
          specId: specId,
          stats: PartyHero.startingStatsForSpec(specId),
          equipped: StarterGear.forSpec(specId),
        ),
    ];
    var state = GameState(
      heroRoster: roster,
      activeHeroIds: [for (final h in roster) h.id],
      partyName:
          PartyNameFilter.sanitize(partyName ?? '') ??
          PartyNameFilter.defaultName,
      enemies: createEnemyGroup(firstRoom, dungeonId: 'sandy'),
      gold: 0,
      lifetimeGoldEarned: 0,
      essence: 0,
      bossVictories: 0,
      lastUpdated: timestamp,
      offlineSecondsRecovered: 0,
      attackBonus: 0,
      defenseBonus: 0,
      vitalityBonus: 0,
      moveSpeedBonus: 0,
      attackSpeedBonus: 0,
      critBonus: 0,
      recentLoot: <LootDrop>[],
      unlockedRelics: <String>[],
      currentRoom: firstRoom,
      dungeonFloor: floor,
      ascensionLevel: 0,
      equipped: const <EquipmentSlot, EquipmentItem>{},
      missions: createMissionBoard(ascensionLevel: 0),
      gearStash: const <EquipmentItem>[],
      dungeonMode: DungeonMode.push,
      highestFloorCleared: 0,
      highestDungeonCleared: -1,
      activePet: null,
      ownedPets: const <Pet>[],
      sanctuaryGoldLevel: 0,
      sanctuaryPowerLevel: 0,
      sanctuaryVitalityLevel: 0,
      metaDepth: MetaDepthState(
        unlockedSpecs: [for (final s in specs) s.name],
        dailyQuestDate: MetaSystems.dailyDateKey(
          (now ?? DateTime.now()).toUtc(),
        ),
      ),
      inDungeon: false,
      dungeonId: 'sandy',
      soulboundFragments: 0,
      godHandLevel: 0,
      layoutSeed: layoutSeed,
    );
    return state.copyWith(
      heroes: state.heroes
          .map((h) => h.copyWith(currentHp: state.effectiveHeroMaxHp(h)))
          .toList(),
      // Fresh saves already know this build — What's New is for upgrades.
      seenChangelogVersion: MetaSystems.currentVersion,
    );
  }

  static List<HeroSpecId> _normalizeStarterSpecs(List<HeroSpecId>? partySpecs) {
    final defaults = List<HeroSpecId>.from(HeroSpecs.starterUnlocked);
    if (partySpecs == null || partySpecs.isEmpty) {
      return defaults;
    }
    final seen = <HeroSpecId>{};
    final out = <HeroSpecId>[];
    for (final id in partySpecs) {
      if (!seen.add(id)) continue;
      out.add(id);
      if (out.length >= starterPartySize) break;
    }
    for (final id in defaults) {
      if (out.length >= starterPartySize) break;
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  /// New Game path: only [HeroSpecs.starterUnlocked] may be chosen.
  static List<HeroSpecId> normalizeNewGameParty(List<HeroSpecId> partySpecs) {
    final allowed = HeroSpecs.starterUnlocked.toSet();
    final seen = <HeroSpecId>{};
    final out = <HeroSpecId>[];
    for (final id in partySpecs) {
      if (!allowed.contains(id)) continue;
      if (!seen.add(id)) continue;
      out.add(id);
      if (out.length >= starterPartySize) break;
    }
    for (final id in HeroSpecs.starterUnlocked) {
      if (out.length >= starterPartySize) break;
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  static int newLayoutSeed() => random.nextInt(0x3fffffff);

  /// AL gear skip per level — blunted by loot-find / HM / elite-boss relief.
  static const double ascensionDropPenalty = 0.10;

  static Map<String, String> get dungeonNames => {
    for (final d in DungeonCatalog.all) d.id: d.name,
  };

  static int bossFloorFor(GameState state) =>
      DungeonGenerator.bossFloorFor(state.ascensionLevel);

  static GameState enterDungeon(GameState state, {String dungeonId = 'sandy'}) {
    final def = DungeonCatalog.byId(dungeonId);
    final unlocked = DungeonCatalog.isUnlocked(
      dungeonId,
      partyMeanLevel(state),
      state.highestDungeonCleared,
    );
    if (!unlocked && def.number > 0) {
      return state;
    }
    final baseSeed = newLayoutSeed();
    final mirrorSalt = LocalSeasonCatalog.mirrorLayoutSeed(state);
    final layoutSeed = mirrorSalt == 0 ? baseSeed : baseSeed ^ mirrorSalt;
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: state.ascensionLevel,
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
    );
    final room = floor.first;
    final primed = _beginKeystoneRun(ensureWeeklyContract(state));
    return primed.copyWith(
      inDungeon: true,
      inGauntlet: false,
      dungeonId: dungeonId,
      dungeonMode: primed.dungeonMode,
      highestFloorCleared: 0,
      currentRoom: room,
      dungeonFloor: floor,
      enemies: createEnemyGroup(room, dungeonId: dungeonId, fromState: primed),
      layoutSeed: layoutSeed,
      heroes: primed.heroes
          .map(
            (hero) => hero.copyWith(currentHp: primed.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Locks preferred key + affixes + idle-friendly par timer for a dungeon run.
  static GameState _beginKeystoneRun(GameState state) {
    if (!endgameUnlocked(state)) {
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
    final par = (Keystone.parTimeMs(
              bossFloor: Keystone.bossFloorForAl(state.ascensionLevel),
              key: key,
            ) *
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

  static GameState _clearKeystoneRun(GameState state) {
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

  /// Advances keystone timer (live ticks or offline). Stops after resolve.
  static GameState advanceKeystoneTimer(GameState state, int deltaMs) {
    if (!state.keystoneRunActive || deltaMs <= 0) return state;
    if (state.keystoneOutcome.isNotEmpty) return state;
    return state.copyWith(keystoneTimerMs: state.keystoneTimerMs + deltaMs);
  }

  static GameState leaveDungeon(GameState state) {
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
      working = working.copyWith(
        essence: working.essence + essence,
        grOutcome: 'depleted',
      );
      LogicNotices.addMetaPayoffs([
        'Greater Rift GR${GreaterRift.clampTier(state.grTier)} ended · +${essence}e',
      ]);
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
            heroes: heroes,
            lastUpdated: DateTime.now(),
          ),
        ),
      ),
    );
    if (state.inGauntlet) {
      next = recordGauntletRun(
        next,
        reachedFloor: state.currentRoom.floorNumber,
      );
    }
    return next;
  }

  /// Leave dungeon/Gauntlet and restore party HP (wipe / hub exit).
  static GameState exitToHubHealed(GameState state) {
    final left = leaveDungeon(state);
    return left.copyWith(
      heroes: [
        for (final h in left.heroes)
          h.copyWith(currentHp: left.effectiveHeroMaxHp(h)),
      ],
      lastUpdated: DateTime.now(),
    );
  }

  /// Hard Ascend cap (Blessing / kit roadmap). Endgame content uses
  /// [endgameUnlocked] (party at [maxHeroLevel]), not this AL gate.
  static const int maxAscensionLevel = 20;

  /// Hero level hard cap — XP stops here; endgame unlocks when the
  /// active party is fully capped.
  static const int maxHeroLevel = 100;

  /// Legacy aliases (older copy / tests). Prefer [endgameUnlocked].
  static const int gauntletMinAscension = maxAscensionLevel;
  static const int keystoneMinAscension = maxAscensionLevel;

  static bool isMaxAscension(GameState state) =>
      state.ascensionLevel >= maxAscensionLevel;

  /// Active party every hero at [maxHeroLevel].
  static bool partyAtMaxLevel(GameState state) {
    if (state.heroes.isEmpty) return false;
    for (final h in state.heroes) {
      if (h.level < maxHeroLevel) return false;
    }
    return true;
  }

  /// Mean level of the active party (zone unlock / softcap helpers).
  static int partyMeanLevel(GameState state) {
    if (state.heroes.isEmpty) return 1;
    final sum = state.heroes.fold<int>(0, (s, h) => s + h.level);
    return max(1, sum ~/ state.heroes.length);
  }

  /// KEY / Gauntlet / Rifts / Greater Rifts / KEY jargon.
  static bool endgameUnlocked(GameState state) => partyAtMaxLevel(state);

  static bool canEnterGauntlet(GameState state) =>
      endgameUnlocked(state) && !state.inDungeon;

  static GameState claimMonthPass(GameState state, {DateTime? now}) =>
      _claimMonthPass(state, now: now);

  static GameState enterWorldBoss(GameState state, {bool practice = false}) =>
      _enterWorldBoss(state, practice: practice);

  static GameState startApexTrial(GameState state) => _startApexTrial(state);

  static GameState applyRosterExhibition(GameState state) =>
      _applyRosterExhibition(state);

  static int partyPowerScore(GameState state) => PartyPower.score(state);

  /// Escalating threat: +10% enemy stats per floor beyond 1.
  static double gauntletThreatMul(int floor) => 1.0 + max(0, floor - 1) * 0.10;

  /// Escalating gold: +8% per floor beyond 1, plus prestige Spire Purse.
  static double gauntletGoldMul(int floor, {int prestigeBonusLevel = 0}) =>
      (1.0 + max(0, floor - 1) * 0.08) * (1.0 + prestigeBonusLevel * 0.04);

  static int gauntletEssenceForFloor(int floor, {required bool boss}) =>
      1 + (floor ~/ 2) + (boss ? 4 : 0);

  /// Updates best floor after a gauntlet attempt ends (wipe / leave).
  static GameState recordGauntletRun(
    GameState state, {
    required int reachedFloor,
  }) {
    final cleared = max(0, reachedFloor - 1);
    var next = ensureLeaderboardSeason(state);
    final best = max(next.metaDepth.gauntletBestFloor, cleared);
    final seasonBest = max(next.metaDepth.seasonBestGauntletFloor, cleared);
    if (best == next.metaDepth.gauntletBestFloor &&
        seasonBest == next.metaDepth.seasonBestGauntletFloor) {
      return syncMetaPayoffs(next);
    }
    if (seasonBest > next.metaDepth.seasonBestGauntletFloor) {
      PlayGamesBridge.noteGauntletPb(
        monthKey: next.metaDepth.leaderboardSeasonKey,
        floor: seasonBest,
      );
    }
    return syncMetaPayoffs(
      next.copyWith(
        metaDepth: next.metaDepth.copyWith(
          gauntletBestFloor: best,
          seasonBestGauntletFloor: seasonBest,
        ),
      ),
    );
  }

  /// AL20 endless climb — Crystal Spire art, boss every 5 floors, no hub exit.
  static const int gauntletBossEvery = 5;

  static GameState enterGauntlet(GameState state) {
    if (!canEnterGauntlet(state)) return state;
    const dungeonId = 'crystal';
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: state.ascensionLevel,
      dungeonId: dungeonId,
      layoutSeed: layoutSeed,
      bossEvery: gauntletBossEvery,
    );
    final room = floor.first;
    final cleared = _clearKeystoneRun(state);
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
        enemies: createEnemyGroup(
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

  static bool canEnterRift(GameState state) =>
      endgameUnlocked(state) && !state.inDungeon;

  /// Timed kill-quota run — Crystal Spire art, dense packs, hub exit on resolve.
  static GameState enterRift(GameState state, {int? tier}) {
    if (!canEnterRift(state)) return state;
    final preferred = tier ?? state.metaDepth.riftPreferredTier;
    final maxSel = Rift.maxSelectableTier(state.metaDepth.riftBestTier);
    final t = Rift.clampTier(preferred.clamp(Rift.minTier, maxSel));
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: state.ascensionLevel,
      dungeonId: Rift.dungeonId,
      layoutSeed: layoutSeed,
    );
    final room = floor.first;
    final cleared = _clearKeystoneRun(
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
        enemies: createEnemyGroup(
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

  static GameState _clearRiftRun(GameState state) {
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

  static GameState setRiftPreferredTier(GameState state, int tier) {
    if (!endgameUnlocked(state)) return state;
    final maxSel = Rift.maxSelectableTier(state.metaDepth.riftBestTier);
    final t = Rift.clampTier(tier.clamp(Rift.minTier, maxSel));
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(riftPreferredTier: t),
      lastUpdated: DateTime.now(),
    );
  }

  static GameState advanceRiftTimer(GameState state, int deltaMs) {
    if (!state.inRift || deltaMs <= 0) return state;
    if (state.riftOutcome.isNotEmpty) return state;
    return state.copyWith(riftTimerMs: state.riftTimerMs + deltaMs);
  }

  static GameState noteRiftKills(GameState state, int kills) {
    if (!state.inRift || kills <= 0) return state;
    if (state.riftOutcome.isNotEmpty) return state;
    return state.copyWith(riftKills: state.riftKills + kills);
  }

  /// Success if kill quota met under par; fail if over par.
  static GameState? tryResolveRift(GameState state) {
    if (!state.inRift || state.riftOutcome.isNotEmpty) return null;
    if (state.riftKills >= state.riftKillTarget &&
        state.riftTimerMs <= state.riftParMs) {
      return resolveRiftSuccess(state);
    }
    if (state.riftTimerMs > state.riftParMs) {
      return resolveRiftFail(state);
    }
    return null;
  }

  static GameState resolveRiftSuccess(GameState state) {
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
    next = syncMetaPayoffs(next);
    LogicNotices.addMetaPayoffs([
      'Rift R$tier timed · +${essence}e · +${gold}g'
          '${unlock > tier + 1 ? ' · unlock R$unlock' : ''}',
    ]);
    return exitToHubHealed(next);
  }

  static GameState resolveRiftFail(GameState state) {
    if (!state.inRift) return state;
    if (state.riftOutcome.isNotEmpty) return exitToHubHealed(state);
    final tier = Rift.clampTier(state.riftTier);
    final essence = Rift.failEssence(tier);
    final next = state.copyWith(
      essence: state.essence + essence,
      riftOutcome: 'depleted',
    );
    LogicNotices.addMetaPayoffs([
      'Rift R$tier failed · +${essence}e consolation',
    ]);
    return exitToHubHealed(next);
  }

  static bool canEnterGreaterRift(GameState state) =>
      endgameUnlocked(state) && !state.inDungeon;

  /// Prestige timed kill ladder — harder packs, no mid-run gear, Play ranked.
  static GameState enterGreaterRift(GameState state, {int? tier}) {
    if (!canEnterGreaterRift(state)) return state;
    final preferred = tier ?? state.metaDepth.grPreferredTier;
    final maxSel = GreaterRift.maxSelectableTier(state.metaDepth.grBestTier);
    final t = GreaterRift.clampTier(
      preferred.clamp(GreaterRift.minTier, maxSel),
    );
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      1,
      ascensionLevel: state.ascensionLevel,
      dungeonId: GreaterRift.dungeonId,
      layoutSeed: layoutSeed,
    );
    final room = floor.first;
    final cleared = _clearKeystoneRun(
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
        enemies: createEnemyGroup(
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

  static GameState _clearGreaterRiftRun(GameState state) {
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

  static GameState setGrPreferredTier(GameState state, int tier) {
    if (!endgameUnlocked(state)) return state;
    final maxSel = GreaterRift.maxSelectableTier(state.metaDepth.grBestTier);
    final t = GreaterRift.clampTier(
      tier.clamp(GreaterRift.minTier, maxSel),
    );
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(grPreferredTier: t),
      lastUpdated: DateTime.now(),
    );
  }

  static GameState advanceGreaterRiftTimer(GameState state, int deltaMs) {
    if (!state.inGreaterRift || deltaMs <= 0) return state;
    if (state.grOutcome.isNotEmpty) return state;
    return state.copyWith(grTimerMs: state.grTimerMs + deltaMs);
  }

  static GameState noteGreaterRiftKills(GameState state, int kills) {
    if (!state.inGreaterRift || kills <= 0) return state;
    if (state.grOutcome.isNotEmpty) return state;
    return state.copyWith(grKills: state.grKills + kills);
  }

  static GameState? tryResolveGreaterRift(GameState state) {
    if (!state.inGreaterRift || state.grOutcome.isNotEmpty) return null;
    if (state.grKills >= state.grKillTarget &&
        state.grTimerMs <= state.grParMs) {
      return resolveGreaterRiftSuccess(state);
    }
    if (state.grTimerMs > state.grParMs) {
      return resolveGreaterRiftFail(state);
    }
    return null;
  }

  static GameState resolveGreaterRiftSuccess(GameState state) {
    if (!state.inGreaterRift) return state;
    var next = ensureLeaderboardSeason(state);
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
            : isoMonthKey(DateTime.now().toUtc()),
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
    next = syncMetaPayoffs(next);
    LogicNotices.addMetaPayoffs([
      'Greater Rift GR$tier timed · +${essence}e · +${gold}g'
          '${unlock > tier + 1 ? ' · unlock GR$unlock' : ''}',
    ]);
    return exitToHubHealed(next);
  }

  static GameState resolveGreaterRiftFail(GameState state) {
    if (!state.inGreaterRift) return state;
    if (state.grOutcome.isNotEmpty) return exitToHubHealed(state);
    final tier = GreaterRift.clampTier(state.grTier);
    final essence = GreaterRift.failEssence(tier);
    final next = state.copyWith(
      essence: state.essence + essence,
      grOutcome: 'depleted',
    );
    LogicNotices.addMetaPayoffs([
      'Greater Rift GR$tier failed · +${essence}e consolation',
    ]);
    return exitToHubHealed(next);
  }

  static int godHandUpgradeCost(int level) => 10 + level * 8;

  static GameState upgradeGodHand(GameState state) {
    final cost = godHandUpgradeCost(state.godHandLevel);
    if (state.essence < cost) {
      return state;
    }
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        godHandLevel: state.godHandLevel + 1,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static const Map<String, String> sanctuaryNames = <String, String>{
    'gold': 'Gold Find',
    'power': 'War Altar',
    'vitality': 'Life Well',
    'xp': 'Lore Font',
  };

  static int sanctuaryCost(int level) => 15 + (level * 12);

  /// Essence paid back when prestigging a track at [level] (Lv12+).
  static int sanctuaryPrestigeEssenceGain(int level) => 25 + level;

  /// Forever bonus added per prestige stack (does not soft-cap).
  static int sanctuaryPrestigeKeepAmount(String track) => switch (track) {
    'gold' => 3,
    'xp' => 2,
    'power' => sanctuaryPowerPerLevel,
    'vitality' => sanctuaryVitalityPerLevel,
    _ => 0,
  };

  /// Short keep line for CAMP buttons (English).
  static String sanctuaryPrestigeKeepShort(String track) => switch (track) {
    'gold' => '+3% gold',
    'power' => '+$sanctuaryPowerPerLevel ATK',
    'vitality' => '+$sanctuaryVitalityPerLevel HP',
    'xp' => '+2% XP',
    _ => '',
  };

  /// Softcapped track bonus only (no prestige). Used for "next level" labels.
  static int sanctuaryTrackBonusAt(String track, int level) {
    return switch (track) {
      'gold' => GameState.softForgePercent(
        level * sanctuaryGoldPctPerLevel,
        softAt: sanctuaryGoldSoftAt,
      ).round(),
      'power' => GameState.softForgePercent(
        level * sanctuaryPowerPerLevel,
        softAt: sanctuaryPowerSoftAt,
      ).round(),
      'vitality' => GameState.softForgePercent(
        level * sanctuaryVitalityPerLevel,
        softAt: sanctuaryVitalitySoftAt,
      ).round(),
      'xp' => GameState.softForgePercent(
        level * sanctuaryXpPctPerLevel,
        softAt: sanctuaryXpSoftAt,
      ).round(),
      _ => 0,
    };
  }

  static String sanctuaryBonusLabel(
    String track,
    int level, {
    int prestige = 0,
  }) {
    final soft = sanctuaryTrackBonusAt(track, level);
    final prestBonus = prestige * sanctuaryPrestigeKeepAmount(track);
    final total = soft + prestBonus;
    final unit = switch (track) {
      'gold' => '% gold find',
      'power' => ' ATK',
      'vitality' => ' HP',
      'xp' => '% XP find',
      _ => '',
    };
    if (prestige > 0) {
      return '+$total$unit (Lv$level + P$prestige)';
    }
    return '+$total$unit';
  }

  static GameState upgradeSanctuary(GameState state, String track) {
    final level = switch (track) {
      'gold' => state.sanctuaryGoldLevel,
      'power' => state.sanctuaryPowerLevel,
      'vitality' => state.sanctuaryVitalityLevel,
      'xp' => state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (level < 0) {
      return state;
    }
    final cost = sanctuaryCost(level);
    if (state.essence < cost) {
      return state;
    }
    var next = state.copyWith(essence: state.essence - cost);
    next = switch (track) {
      'gold' => next.copyWith(sanctuaryGoldLevel: level + 1),
      'power' => next.copyWith(sanctuaryPowerLevel: level + 1),
      'vitality' => next.copyWith(sanctuaryVitalityLevel: level + 1),
      'xp' => next.copyWith(
        metaDepth: next.metaDepth.copyWith(sanctuaryXpLevel: level + 1),
      ),
      _ => state,
    };
    if (track == 'vitality') {
      next = next.copyWith(
        heroes: next.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: min(
                  next.effectiveHeroMaxHp(hero),
                  hero.currentHp + sanctuaryVitalityPerLevel,
                ),
              ),
            )
            .toList(),
      );
    }
    return MetaSystems.evaluateAchievements(
      next.copyWith(lastUpdated: DateTime.now()),
    );
  }

  /// How many consecutive [track] upgrades essence can afford (cap [maxLevels]).
  static int sanctuaryBulkAffordableLevels(
    GameState state,
    String track, {
    int maxLevels = 5,
  }) {
    var essence = state.essence;
    var level = switch (track) {
      'gold' => state.sanctuaryGoldLevel,
      'power' => state.sanctuaryPowerLevel,
      'vitality' => state.sanctuaryVitalityLevel,
      'xp' => state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (level < 0) return 0;
    var count = 0;
    while (count < maxLevels) {
      final cost = sanctuaryCost(level);
      if (essence < cost) break;
      essence -= cost;
      level++;
      count++;
    }
    return count;
  }

  /// Buy up to [maxLevels] sanctuary levels on one track while essence lasts.
  static GameState upgradeSanctuaryBulk(
    GameState state,
    String track, {
    int maxLevels = 5,
  }) {
    var next = state;
    for (var i = 0; i < maxLevels; i++) {
      final before = next;
      next = upgradeSanctuary(next, track);
      if (identical(next, before)) break;
    }
    return next;
  }

  /// Optional compress: reset track to 0 for essence + lasting prestige bonus.
  /// Available from level 12+; tracks may also keep leveling infinitely.
  static GameState prestigeSanctuaryTrack(GameState state, String track) {
    final level = switch (track) {
      'gold' => state.sanctuaryGoldLevel,
      'power' => state.sanctuaryPowerLevel,
      'vitality' => state.sanctuaryVitalityLevel,
      'xp' => state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (level < 12) return state;
    final essenceGain = sanctuaryPrestigeEssenceGain(level);
    final md = state.metaDepth;
    final nextMd = switch (track) {
      'gold' => md.copyWith(
        sanctuaryGoldPrestige: md.sanctuaryGoldPrestige + 1,
      ),
      'power' => md.copyWith(
        sanctuaryPowerPrestige: md.sanctuaryPowerPrestige + 1,
      ),
      'vitality' => md.copyWith(
        sanctuaryVitalityPrestige: md.sanctuaryVitalityPrestige + 1,
      ),
      'xp' => md.copyWith(
        sanctuaryXpLevel: 0,
        sanctuaryXpPrestige: md.sanctuaryXpPrestige + 1,
      ),
      _ => md,
    };
    final next = switch (track) {
      'gold' => state.copyWith(
        sanctuaryGoldLevel: 0,
        essence: state.essence + essenceGain,
        metaDepth: nextMd,
      ),
      'power' => state.copyWith(
        sanctuaryPowerLevel: 0,
        essence: state.essence + essenceGain,
        metaDepth: nextMd,
      ),
      'vitality' => state.copyWith(
        sanctuaryVitalityLevel: 0,
        essence: state.essence + essenceGain,
        metaDepth: nextMd,
      ),
      'xp' => state.copyWith(
        essence: state.essence + essenceGain,
        metaDepth: nextMd,
      ),
      _ => state,
    };
    return MetaSystems.evaluateAchievements(
      next.copyWith(lastUpdated: DateTime.now()),
    );
  }

  static GameState setActiveTitle(GameState state, String title) {
    if (title.isEmpty) return state;
    if (!state.metaDepth.titles.contains(title)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(activeTitle: title),
      lastUpdated: DateTime.now(),
    );
  }

  static GameState setDungeonMode(GameState state, DungeonMode mode) {
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

  static bool canTravelToFloor(GameState state, int floorNumber) {
    if (state.inGauntlet || state.inAnyRiftMode) return false;
    if (floorNumber < 1) {
      return false;
    }
    return floorNumber <= state.maxReachableFloor;
  }

  /// Jump to an unlocked floor wave (farm/push zone select).
  static GameState travelToFloor(GameState state, int floorNumber) {
    if (!canTravelToFloor(state, floorNumber)) {
      return state;
    }
    if (floorNumber == state.currentRoom.floorNumber &&
        !state.isPartyDefeated) {
      return state;
    }
    final layoutSeed = newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      floorNumber,
      ascensionLevel: state.ascensionLevel,
      dungeonId: state.dungeonId,
      layoutSeed: layoutSeed,
    );
    final firstRoom = floor.first;
    return state.copyWith(
      currentRoom: firstRoom,
      dungeonFloor: floor,
      enemies: createEnemyGroup(
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

  /// Failed push: retreat to the highest cleared floor (or floor 1).
  /// Keeps PUSH mode so Retry does not silently switch to FARM.
  static GameState retreatFromFailedPush(GameState state) {
    final safeFloor = max(1, state.highestFloorCleared);
    return travelToFloor(
      state.copyWith(
        metaDepth: state.metaDepth.copyWith(noWipeAscendReady: false),
      ),
      safeFloor,
    );
  }

  /// Bosses needed this run before Ascend unlocks.
  /// AL 0 → 1 boss, AL 1 → 2 bosses, etc.
  static int bossesRequiredForAscension(int ascensionLevel) =>
      ascensionLevel + 1;

  static bool canAscend(GameState state) =>
      !isMaxAscension(state) &&
      state.bossVictories >= bossesRequiredForAscension(state.ascensionLevel);

  /// Hub / Ascend pick: NEXT frontier zone, else deepest unlocked.
  static String recommendedDungeonId(GameState state) {
    final mirror = LocalSeasonCatalog.mirrorZoneId(state);
    if (mirror != null) {
      final partyLv = partyMeanLevel(state);
      final highest = state.highestDungeonCleared;
      if (DungeonCatalog.isUnlocked(mirror, partyLv, highest)) {
        return mirror;
      }
    }
    final highest = state.highestDungeonCleared;
    final partyLv = partyMeanLevel(state);
    for (final d in DungeonCatalog.all) {
      final unlocked = DungeonCatalog.isUnlocked(d.id, partyLv, highest);
      final cleared = highest >= d.number;
      if (unlocked && !cleared && d.number == highest + 1) {
        return d.id;
      }
    }
    var bestId = DungeonCatalog.all.first.id;
    var bestNum = -1;
    for (final d in DungeonCatalog.all) {
      if (!DungeonCatalog.isUnlocked(d.id, partyLv, highest)) continue;
      if (d.number >= bestNum) {
        bestNum = d.number;
        bestId = d.id;
      }
    }
    return bestId;
  }

  /// Essence granted when ascending into [newLevel].
  static int ascendEssenceReward(int newLevel) => 4 + (newLevel * 3);

  /// Flat ATK granted per Ascend Blessing stack.
  static const int ascendBlessingAtk = 2;

  /// Flat DEF granted per Ascend Blessing stack (percent armor needs chunks).
  static const int ascendBlessingDef = 8;

  /// Flat VIT granted per Ascend Blessing stack (HP, not gear STA ×10).
  static const int ascendBlessingVit = 24;

  /// Per-AL keep flats (same 1 ATK ≈ 4 DEF ≈ 12 HP as FORGE).
  static const int alAttackPerLevel = 1;
  static const int alDefensePerLevel = 4;
  static const int alVitalityPerLevel = 12;

  static const int relicAttackPerTier = 4;
  static const int relicDefensePerTier = 16;
  static const int relicVitalityPerTier = 48;
  static const int relicMitigatePerTier = 8;

  /// Gold FORGE one-buy gains. Percent armor made +1 DEF / +6 HP a rounding
  /// error next to +2 ATK; CRIT was half of HASTE at the same gold.
  static const int forgeAttackGain = 2;
  static const int forgeDefenseGain = 8;
  static const int forgeVitalityGain = 24;
  static const int forgeMoveGain = 2;
  static const int forgeHasteGain = 2;
  static const int forgeCritGain = 2;

  /// CAMP (sanctuary) per-level gains. Same essence cost; Life Well HP must
  /// match War Altar ATK the way FORGE STA matches ATK.
  static const int sanctuaryGoldPctPerLevel = 5;
  static const int sanctuaryPowerPerLevel = 1;
  static const int sanctuaryVitalityPerLevel = 12;
  static const int sanctuaryXpPctPerLevel = 4;
  static const double sanctuaryPowerSoftAt = 40;
  static const double sanctuaryVitalitySoftAt = 480; // 40 levels × 12 HP
  static const double sanctuaryGoldSoftAt = 100;
  static const double sanctuaryXpSoftAt = 80;

  /// Gold-find percent granted per Ascend Blessing stack.
  static const int ascendBlessingGoldPct = 3;

  /// Applies Ascension + Sanctuary + Blessing + gear + pet gold bonuses.
  static int applyGoldGain(GameState state, int baseGold) =>
      EconomyService.applyGoldGain(state, baseGold);

  /// Optional POWERUPS: +[AdBoost.hoursPerAd] hours of double gold and +25% ATK.
  /// Stacks duration only (effects do not multiply).
  static GameState grantAdBoostHour(GameState state, {int? nowMs}) {
    final until = AdBoost.addHour(
      state.metaDepth.adBoostUntilMs,
      nowMs: nowMs,
    );
    if (until == state.metaDepth.adBoostUntilMs) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(adBoostUntilMs: until),
    );
  }

  /// Credit kill / God Hand gold immediately (survives wipe; matches floaters).
  /// Includes Gauntlet floor mul + [applyGoldGain] bonuses.
  static GameState creditCombatGold(GameState state, int baseGold) {
    if (baseGold <= 0) return state;
    final mul = state.inGauntlet
        ? gauntletGoldMul(
            state.currentRoom.floorNumber,
            prestigeBonusLevel: state.metaDepth.gauntletGoldBonusLevel,
          )
        : 1.0;
    final gained = applyGoldGain(state, (baseGold * mul).round());
    if (gained <= 0) return state;
    final paid = state.copyWith(
      gold: state.gold + gained,
      lifetimeGoldEarned: state.lifetimeGoldEarned + gained,
    );
    // Earn-gold missions previously tracked clear-time awards only.
    return applyMissionProgress(paid, goldEarned: gained);
  }

  /// Prestige: reset the run, keep essence/relics/sanctuary/pets/Apex, bump AL.
  static GameState ascend(GameState state, {DateTime? now}) =>
      _ascendGameState(state, now: now);

  /// Mean level used when seeding a newly unlocked roster hero.
  static int rosterSeedLevel(GameState state) {
    final pool = state.heroes.isNotEmpty ? state.heroes : state.heroRoster;
    if (pool.isEmpty) return 1;
    final sum = pool.fold<int>(0, (s, h) => s + h.level);
    return max(1, (sum / pool.length).round());
  }

  /// Unlocks Shade (Combat) on the roster when [rogueUnlocked].
  static GameState ensureRogueHero(GameState state) {
    if (!state.rogueUnlocked) {
      return fillMissingStarterGear(state);
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
        level: rosterSeedLevel(next),
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
    return fillMissingStarterGear(next);
  }

  static const int partySlot5EssenceCost = 80;
  static const int partySlot5MinAscension = 2;

  /// Unlocks the 5th active party slot (80e, AL ≥ 2).
  static GameState unlockPartySlot5(GameState state) {
    if (state.metaDepth.partySlot5Unlocked) return state;
    if (state.ascensionLevel < partySlot5MinAscension) return state;
    if (state.essence < partySlot5EssenceCost) return state;
    return state.copyWith(
      essence: state.essence - partySlot5EssenceCost,
      metaDepth: state.metaDepth.copyWith(partySlot5Unlocked: true),
      lastUpdated: DateTime.now(),
    );
  }

  /// Sets the active party lineup by roster hero ids (hub / out of dungeon).
  static GameState setActiveParty(GameState state, List<String> heroIds) {
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

  /// Whether the player has met the meta gate for [specId].
  static bool canUnlockSpec(GameState state, HeroSpecId specId) {
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

  /// Auto-unlock every eligible spec into the roster (after clear / ascend).
  static GameState syncSpecUnlocks(GameState state) {
    var next = state;
    for (final def in HeroSpecs.all) {
      if (canUnlockSpec(next, def.id) && !next.isSpecUnlocked(def.id)) {
        next = unlockSpec(next, def.id);
      } else if (canUnlockSpec(next, def.id) &&
          !next.heroRoster.any((h) => h.specId == def.id)) {
        next = unlockSpec(next, def.id);
      }
    }
    return next;
  }

  /// Unlocks [specId] into meta + adds a starting hero to the roster.
  static GameState unlockSpec(GameState state, HeroSpecId specId) {
    if (!canUnlockSpec(state, specId) &&
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
      level: rosterSeedLevel(next),
    );
    return next.copyWith(
      heroRoster: [...next.heroRoster, hero],
      lastUpdated: DateTime.now(),
    );
  }

  /// Clears hub “Meet new hero” queue (player opened PARTY / acknowledged).
  static GameState ackPendingHeroReveals(GameState state) {
    if (state.metaDepth.pendingHeroReveals.isEmpty) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(pendingHeroReveals: const <String>[]),
      lastUpdated: DateTime.now(),
    );
  }

  /// Restarts the current floor wave with a healed party.
  /// Daily echo keeps today's layout seed so claim + wipe-retry stay valid.
  static GameState restartFloor(GameState state) {
    final keepDailySeed = MetaSystems.isActiveDailyRun(state);
    final layoutSeed = keepDailySeed ? state.layoutSeed : newLayoutSeed();
    final floor = DungeonGenerator.generateFloor(
      state.currentRoom.floorNumber,
      ascensionLevel: state.ascensionLevel,
      dungeonId: state.dungeonId,
      layoutSeed: layoutSeed,
    );
    final firstRoom = floor.first;
    return state.copyWith(
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      enemies: createEnemyGroup(
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

  static int partyTrainingCostFor(GameState state) {
    final totalLevels = state.heroes.fold<int>(
      0,
      (sum, hero) => sum + hero.level,
    );
    return 16 + (totalLevels * 3) + (state.bossVictories * 6);
  }

  static int forgeTrackTier(GameState state, PartyUpgradeType type) {
    return switch (type) {
      PartyUpgradeType.attack => state.attackBonus ~/ forgeAttackGain,
      PartyUpgradeType.defense => state.defenseBonus ~/ forgeDefenseGain,
      PartyUpgradeType.vitality => state.vitalityBonus ~/ forgeVitalityGain,
      PartyUpgradeType.moveSpeed => state.moveSpeedBonus ~/ forgeMoveGain,
      PartyUpgradeType.attackSpeed => state.attackSpeedBonus ~/ forgeHasteGain,
      PartyUpgradeType.crit => state.critBonus ~/ forgeCritGain,
    };
  }

  static int upgradeCostFor(GameState state, PartyUpgradeType type) {
    return 18 +
        (forgeTrackTier(state, type) * 10) +
        (state.bossVictories * 5) +
        (state.ascensionLevel * 25);
  }

  /// Wallet gold budget for a FORGE GOLD spend mode (×1 uses next buy cost).
  static int forgeGoldBudget(GameState state, ForgeGoldSpendMode mode) {
    return switch (mode) {
      ForgeGoldSpendMode.one => 0,
      ForgeGoldSpendMode.pct5 => (state.gold * 5) ~/ 100,
      ForgeGoldSpendMode.pct25 => (state.gold * 25) ~/ 100,
      ForgeGoldSpendMode.pct50 => (state.gold * 50) ~/ 100,
      ForgeGoldSpendMode.pct100 => state.gold,
    };
  }

  static bool canForgeGoldSpend(
    GameState state,
    PartyUpgradeType type,
    ForgeGoldSpendMode mode,
  ) {
    final cost = upgradeCostFor(state, type);
    if (state.gold < cost) {
      return false;
    }
    if (mode == ForgeGoldSpendMode.one) {
      return true;
    }
    return forgeGoldBudget(state, mode) >= cost;
  }

  static bool canForgeGoldSpendEven(GameState state) {
    for (final type in PartyUpgradeType.values) {
      if (state.gold >= upgradeCostFor(state, type)) {
        return true;
      }
    }
    return false;
  }

  /// How many buys / gold a spend mode would use on [type] from [state].
  static ({int buys, int spent}) previewForgeGoldSpend(
    GameState state,
    PartyUpgradeType type,
    ForgeGoldSpendMode mode,
  ) {
    if (mode == ForgeGoldSpendMode.one) {
      final cost = upgradeCostFor(state, type);
      if (state.gold < cost) {
        return (buys: 0, spent: 0);
      }
      return (buys: 1, spent: cost);
    }
    final budget = forgeGoldBudget(state, mode);
    var remaining = min(budget, state.gold);
    var cur = state;
    var buys = 0;
    var spent = 0;
    for (var i = 0; i < 10000; i++) {
      final cost = upgradeCostFor(cur, type);
      if (cost > remaining || cost > cur.gold) {
        break;
      }
      final next = _applyUpgrade(cur, type: type);
      if (identical(next, cur)) {
        break;
      }
      remaining -= cost;
      spent += cost;
      buys += 1;
      cur = next;
    }
    return (buys: buys, spent: spent);
  }

  /// Buy one track once, or dump a % of wallet gold into that track.
  static GameState upgradeWithSpendMode(
    GameState state, {
    required PartyUpgradeType type,
    required ForgeGoldSpendMode mode,
  }) {
    if (mode == ForgeGoldSpendMode.one) {
      return _applyUpgrade(state, type: type);
    }
    final budget = forgeGoldBudget(state, mode);
    if (budget <= 0) {
      return state;
    }
    return _upgradeWithBudget(state, type: type, budget: budget);
  }

  static GameState _upgradeWithBudget(
    GameState state, {
    required PartyUpgradeType type,
    required int budget,
  }) {
    var remaining = min(budget, state.gold);
    var cur = state;
    for (var i = 0; i < 10000; i++) {
      final cost = upgradeCostFor(cur, type);
      if (cost > remaining || cost > cur.gold) {
        break;
      }
      final next = _applyUpgrade(cur, type: type);
      if (identical(next, cur)) {
        break;
      }
      remaining -= cost;
      cur = next;
    }
    return cur;
  }

  /// Spend wallet gold round-robin across ATK/DEF/STA/MOVE/HASTE/CRIT.
  static GameState upgradeSpendAllEvenly(GameState state) {
    var cur = state;
    for (var round = 0; round < 10000; round++) {
      var bought = false;
      for (final type in PartyUpgradeType.values) {
        final cost = upgradeCostFor(cur, type);
        if (cur.gold < cost) {
          continue;
        }
        final next = _applyUpgrade(cur, type: type);
        if (!identical(next, cur)) {
          cur = next;
          bought = true;
        }
      }
      if (!bought) {
        break;
      }
    }
    return cur;
  }

  /// Gold Train (+1 Lv party-wide) is retired — levels come from combat XP only.
  static GameState trainParty(GameState state) => state;

  static GameState upgradeAttack(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.attack);

  static GameState upgradeDefense(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.defense);

  static GameState upgradeVitality(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.vitality);

  static GameState upgradeMoveSpeed(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.moveSpeed);

  static GameState upgradeAttackSpeed(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.attackSpeed);

  static GameState upgradeCrit(GameState state) =>
      _applyUpgrade(state, type: PartyUpgradeType.crit);

  static GameState _applyUpgrade(
    GameState state, {
    required PartyUpgradeType type,
  }) {
    final cost = upgradeCostFor(state, type);
    if (state.gold < cost) {
      return state;
    }

    switch (type) {
      case PartyUpgradeType.attack:
        return state.copyWith(
          attackBonus: state.attackBonus + forgeAttackGain,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.defense:
        return state.copyWith(
          defenseBonus: state.defenseBonus + forgeDefenseGain,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.vitality:
        final nextVit = state.vitalityBonus + forgeVitalityGain;
        final probe = state.copyWith(vitalityBonus: nextVit);
        final healedHeroes = state.heroes
            .map(
              (hero) =>
                  hero.copyWith(currentHp: probe.effectiveHeroMaxHp(hero)),
            )
            .toList();
        return state.copyWith(
          vitalityBonus: nextVit,
          heroes: healedHeroes,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.moveSpeed:
        return state.copyWith(
          moveSpeedBonus: state.moveSpeedBonus + forgeMoveGain,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.attackSpeed:
        return state.copyWith(
          attackSpeedBonus: state.attackSpeedBonus + forgeHasteGain,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.crit:
        return state.copyWith(
          critBonus: state.critBonus + forgeCritGain,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
    }
  }

  static GameState unlockRelic(GameState state, String relicId) {
    final cost = relicCosts[relicId];
    if (cost == null || state.hasRelic(relicId) || state.essence < cost) {
      return state;
    }

    final unlockedRelics = List<String>.from(state.unlockedRelics)
      ..add(relicId);
    final tiers = Map<String, int>.from(state.metaDepth.relicTiers);
    tiers[relicId] = max(1, tiers[relicId] ?? 0);
    final healedHeroes = state.heroes
        .map(
          (hero) => hero.copyWith(
            currentHp: min(
              hero.currentHp,
              hero.maxHp +
                  state.totalVitalityBonus +
                  (relicId == phoenixEmberRelic ? relicVitalityPerTier : 0),
            ),
          ),
        )
        .toList();

    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        heroes: healedHeroes,
        unlockedRelics: unlockedRelics,
        metaDepth: state.metaDepth.copyWith(relicTiers: tiers),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static int relicTierUpgradeCost(int nextTier) => 12 + nextTier * 14;

  static GameState upgradeRelicTier(GameState state, String relicId) {
    if (!state.hasRelic(relicId) || !relicCosts.containsKey(relicId)) {
      return state;
    }
    final current = max(1, state.metaDepth.relicTierOf(relicId));
    if (current >= 3) return state;
    final nextTier = current + 1;
    final cost = relicTierUpgradeCost(nextTier);
    if (state.essence < cost) return state;
    final tiers = Map<String, int>.from(state.metaDepth.relicTiers);
    tiers[relicId] = nextTier;
    return state.copyWith(
      essence: state.essence - cost,
      metaDepth: state.metaDepth.copyWith(relicTiers: tiers),
      lastUpdated: DateTime.now(),
    );
  }

  static int respecRelicsCost(GameState state) =>
      40 + state.metaDepth.relicRespecs * 25;

  static GameState respecRelics(GameState state) {
    if (state.unlockedRelics.isEmpty && state.metaDepth.relicTiers.isEmpty) {
      return state;
    }
    final cost = respecRelicsCost(state);
    if (state.essence < cost) return state;
    return state.copyWith(
      essence: state.essence - cost,
      unlockedRelics: const <String>[],
      metaDepth: state.metaDepth.copyWith(
        relicTiers: const <String, int>{},
        relicRespecs: state.metaDepth.relicRespecs + 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static int godHandCdUpgradeCost(int level) => 12 + level * 10;

  static GameState upgradeGodHandCd(GameState state) {
    if (state.metaDepth.godHandCdLevel >= 8) return state;
    final cost = godHandCdUpgradeCost(state.metaDepth.godHandCdLevel);
    if (state.essence < cost) return state;
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        metaDepth: state.metaDepth.copyWith(
          godHandCdLevel: state.metaDepth.godHandCdLevel + 1,
        ),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static GameState buyPrestigeShopItem(GameState state, String id) {
    PrestigeShopItem? item;
    for (final candidate in PrestigeShopCatalog.all) {
      if (candidate.id == id) {
        item = candidate;
        break;
      }
    }
    if (item == null) return state;
    if (state.ascensionLevel < item.minAl) return state;
    if (state.essence < item.cost) return state;

    final md = state.metaDepth;
    final atCap = switch (id) {
      'stash_slot' => md.stashBonusSlots >= 20,
      'combine_luck' => md.combinatorLuck >= 5,
      'torch_keep' => md.torchKeepLevel >= 10,
      'gh_cdr' => md.godHandCdLevel >= 8,
      'roster_cap' => md.petRosterCapBonus >= 10,
      'loadout_slot' => md.loadoutBonusSlots >= 2,
      'flask_discount' => md.marketDiscountLevel >= 5,
      'filter_span' => md.filterSpanLevel >= 5,
      'offline_ledger' => md.offlineHighlightBonus >= 3,
      'legacy_spark' => md.legacyPoints >= 20,
      'daily_essence' => md.dailyEssenceBonusLevel >= 5,
      'gauntlet_gold' => md.gauntletGoldBonusLevel >= 5,
      _ => false,
    };
    if (atCap) return state;

    var nextMd = switch (id) {
      'stash_slot' => md.copyWith(
        stashBonusSlots: min(20, md.stashBonusSlots + 2),
      ),
      'combine_luck' => md.copyWith(
        combinatorLuck: min(5, md.combinatorLuck + 1),
      ),
      'torch_keep' => md.copyWith(
        torchKeepLevel: min(10, md.torchKeepLevel + 1),
      ),
      'gh_cdr' => md.copyWith(godHandCdLevel: min(8, md.godHandCdLevel + 1)),
      'roster_cap' => md.copyWith(
        petRosterCapBonus: min(10, md.petRosterCapBonus + 2),
      ),
      'loadout_slot' => md.copyWith(
        loadoutBonusSlots: min(2, md.loadoutBonusSlots + 1),
      ),
      'flask_discount' => md.copyWith(
        marketDiscountLevel: min(5, md.marketDiscountLevel + 1),
      ),
      'filter_span' => md.copyWith(
        filterSpanLevel: min(5, md.filterSpanLevel + 1),
      ),
      'offline_ledger' => md.copyWith(
        offlineHighlightBonus: min(3, md.offlineHighlightBonus + 1),
      ),
      'legacy_spark' => md.copyWith(legacyPoints: min(20, md.legacyPoints + 1)),
      'daily_essence' => md.copyWith(
        dailyEssenceBonusLevel: min(5, md.dailyEssenceBonusLevel + 1),
      ),
      'gauntlet_gold' => md.copyWith(
        gauntletGoldBonusLevel: min(5, md.gauntletGoldBonusLevel + 1),
      ),
      _ => md,
    };
    // Track ownership once via levels; keep a de-duplicated purchase mark.
    if (!nextMd.prestigePurchases.contains(id)) {
      nextMd = nextMd.copyWith(
        prestigePurchases: [...nextMd.prestigePurchases, id],
      );
    }
    return state.copyWith(
      essence: state.essence - item.cost,
      metaDepth: nextMd,
      lastUpdated: DateTime.now(),
    );
  }

  /// ISO week key (`yyyy-Www`) for weekly contract / local season rotation.
  static String isoWeekKey(DateTime utc) {
    final d = DateTime.utc(utc.year, utc.month, utc.day);
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final week = (thursday.difference(yearStart).inDays ~/ 7) + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Calendar-month season key (`yyyy-MM`) for local offline seasons.
  static String isoMonthKey(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Reset Play Games seasonal PBs when the calendar month rolls.
  static GameState ensureLeaderboardSeason(GameState state, {DateTime? now}) {
    final month = isoMonthKey((now ?? DateTime.now()).toUtc());
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

  /// Display season label (ISO week + month), e.g. `2026-W32 · 2026-08`.
  static String seasonLabel(DateTime utc) =>
      '${isoWeekKey(utc)} · ${isoMonthKey(utc)}';

  static GameState ensureWeeklyContract(GameState state, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    final key = isoWeekKey(t);
    final season = seasonLabel(t);
    var next = ensureLeaderboardSeason(state, now: t);
    if (next.metaDepth.weeklyKey != key || next.metaDepth.seasonKey != season) {
      final sameWeek = next.metaDepth.weeklyKey == key;
      final monthKey = isoMonthKey(t);
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
          monthlyBestGrTier:
              sameMonth ? next.metaDepth.monthlyBestGrTier : 0,
          apexTrialMonthKey:
              sameMonth ? next.metaDepth.apexTrialMonthKey : monthKey,
          apexTrialCleared:
              sameMonth ? next.metaDepth.apexTrialCleared : false,
          seasonKey: season,
        ),
      );
    }
    next = WorldBoss.ensureWeek(next, now: t);
    next = BlessingConstellation.ensure(next);
    return ensureDailyVault(next, now: t);
  }

  /// Resets daily vault progress when the UTC calendar day rolls.
  /// First touch on legacy saves (empty [dailyVaultDate]) migrates weekly
  /// vault progress into today's daily fields instead of wiping it.
  static GameState ensureDailyVault(GameState state, {DateTime? now}) {
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
              ? dailyVaultClearTarget
              : min(dailyVaultClearTarget, md.weeklyProgress),
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

  static const int dailyVaultClearTarget = 1;

  /// Extra vault / Daily Run essence per Dawn Tithe shop level.
  static const int dawnTitheEssencePerLevel = 5;

  /// Daily vault claim payout (timed-key table + Dawn Tithe).
  static int dailyVaultClaimEssence(GameState state) =>
      Keystone.dailyVaultEssence(state.metaDepth.dailyBestTimedKey) +
      state.metaDepth.dailyEssenceBonusLevel * dawnTitheEssencePerLevel;

  /// Essence shown on CLAIM VAULT — same as [claimDailyVault], including
  /// the first-of-month season bonus when it is still unclaimed.
  static int dailyVaultClaimPreviewEssence(GameState state, {DateTime? now}) {
    var gain = dailyVaultClaimEssence(state);
    final month = isoMonthKey((now ?? DateTime.now()).toUtc());
    if (month.isNotEmpty &&
        !state.metaDepth.claimedSeasonRewards.contains(month)) {
      gain += seasonWeeklyBonusEssence;
    }
    return gain;
  }

  /// Endgame players see KEY / weekly affix jargon; earlier stays vault-simple.
  ///
  /// KEY unlocks with Gauntlet / Rift when the active party hits max level.
  static bool showKeystoneJargon(GameState state) => endgameUnlocked(state);

  /// Daily / vault-start / KEY habit as TODAY after the first boss or first Ascend.
  ///
  /// New saves chase growing the party in the starter zone — not a Daily
  /// or KEY handshake they have not earned yet.
  static bool showDailyChase(GameState state) =>
      state.ascensionLevel > 0 || state.bossVictories > 0;

  /// One-time essence when claiming the first vault of a calendar month.
  static const int seasonWeeklyBonusEssence = 12;

  /// Claim when 1 push clear **or** a timed KEY ≥2 today.
  static bool canClaimDailyVault(GameState state) {
    final md = state.metaDepth;
    if (md.dailyVaultClaimed) return false;
    return md.dailyVaultClears >= dailyVaultClearTarget ||
        md.dailyBestTimedKey >= 2;
  }

  static GameState claimDailyVault(GameState state, {DateTime? now}) {
    var next = ensureWeeklyContract(state, now: now);
    final md = next.metaDepth;
    if (md.dailyVaultClaimed) return next;
    if (md.dailyVaultClears < dailyVaultClearTarget &&
        md.dailyBestTimedKey < 2) {
      return next;
    }
    var essenceGain = dailyVaultClaimEssence(next);
    final seasonClaims = List<String>.from(md.claimedSeasonRewards);
    final month = isoMonthKey((now ?? DateTime.now()).toUtc());
    final notices = <String>[];
    final titles = List<String>.from(md.titles);
    if (month.isNotEmpty && !seasonClaims.contains(month)) {
      seasonClaims.add(month);
      essenceGain += seasonWeeklyBonusEssence;
      notices.add('Season $month · +${seasonWeeklyBonusEssence}e');
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

  /// God Hand style: 0 balanced, 1 focus, 2 wide.
  static GameState setGodHandStyle(GameState state, int style) {
    final next = style.clamp(0, 2);
    if (state.metaDepth.godHandStyle == next) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(godHandStyle: next),
      lastUpdated: DateTime.now(),
    );
  }

  /// Claim Will-rank + Gauntlet milestone essence when thresholds are met.
  static GameState syncMetaPayoffs(GameState state) {
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

  /// Soft expected codex size for percentage milestone claims (soft goal).
  static const int expectedCodexEntries = 120;

  static const Map<String, ({int pct, int reward})> codexRewardTiers =
      <String, ({int pct, int reward})>{
        'codex_25pct': (pct: 25, reward: 8),
        'codex_50pct': (pct: 50, reward: 15),
        'codex_75pct': (pct: 75, reward: 22),
        'codex_100pct': (pct: 100, reward: 30),
      };

  static int codexCompletionPercent(GameState state) {
    final discovered = state.codexEnemies.length + state.codexItems.length;
    return min(100, (discovered * 100) ~/ expectedCodexEntries);
  }

  /// Discover names already worn or sitting in the bag (older saves).
  static GameState backfillCodexFromInventory(GameState state) {
    final names = <String>{};
    for (final item in state.gearStash) {
      names.add(item.name);
    }
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        names.add(item.name);
      }
    }
    if (state.soulboundItem != null) {
      names.add(state.soulboundItem!.name);
    }
    if (names.isEmpty) return state;
    return MetaSystems.registerItemNames(state, names);
  }

  static GameState claimCodexReward(GameState state, String tierId) {
    final tier = codexRewardTiers[tierId];
    if (tier == null) return state;
    if (state.metaDepth.codexClaims.contains(tierId)) return state;
    if (codexCompletionPercent(state) < tier.pct) return state;
    final claims = List<String>.from(state.metaDepth.codexClaims)..add(tierId);
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence + tier.reward,
        metaDepth: state.metaDepth.copyWith(codexClaims: claims),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Clamp preferred keystone level (hub only — ignored while a run is locked).
  static GameState setHardmodeLevel(GameState state, int level) {
    if (state.inDungeon && state.keystoneRunActive) return state;
    if (!endgameUnlocked(state)) {
      return state.copyWith(hardmodeLevel: 0, lastUpdated: DateTime.now());
    }
    final capped = level.clamp(0, state.effectiveMaxHardmode);
    return MetaSystems.evaluateAchievements(
      state.copyWith(hardmodeLevel: capped, lastUpdated: DateTime.now()),
    );
  }

  static GameState dismissTip(GameState state, String tipId) {
    if (state.seenTips.contains(tipId)) return state;
    return state.copyWith(
      seenTips: [...state.seenTips, tipId],
      lastUpdated: DateTime.now(),
    );
  }

  static GameState dismissTips(GameState state, Iterable<String> tipIds) {
    final seen = {...state.seenTips};
    var changed = false;
    for (final id in tipIds) {
      if (seen.add(id)) changed = true;
    }
    if (!changed) return state;
    return state.copyWith(seenTips: seen.toList(), lastUpdated: DateTime.now());
  }

  static String wipeFloorKey(GameState state) {
    final g = state.inGauntlet ? ':g' : '';
    return '${state.dungeonId}:${state.currentRoom.floorNumber}$g';
  }

  static GameState clearWipeStreak(GameState state) {
    if (state.wipeStreakCount == 0 &&
        state.wipeAdviceLine.isEmpty &&
        state.wipeStreakKey.isEmpty) {
      return state;
    }
    return state.copyWith(
      wipeStreakKey: '',
      wipeStreakCount: 0,
      wipeAdviceLine: '',
    );
  }

  /// Live wipe only. Stacks the same floor; writes [GameState.wipeAdviceLine]
  /// from fight numbers after [WipeAdvice.streakNeeded] wipes.
  static GameState notePartyWipe(GameState state, WipeFightSnapshot fight) {
    final key = wipeFloorKey(state);
    final count = state.wipeStreakKey == key ? state.wipeStreakCount + 1 : 1;
    var line = '';
    final advice = WipeAdvice.lineFor(state: state, fight: fight);
    if (advice != null &&
        (WipeAdvice.isImmediate(advice) || count >= WipeAdvice.streakNeeded)) {
      line = advice;
    }
    return state.copyWith(
      wipeStreakKey: key,
      wipeStreakCount: count,
      wipeAdviceLine: line,
    );
  }

  static int recommendedForgeUpgrade(GameState state) {
    // Pick the forge track most behind relative to cost (equal combat tiers).
    final scores = <(int, double)>[
      for (final type in PartyUpgradeType.values)
        (
          type.index,
          forgeTrackTier(state, type) / max(1, upgradeCostFor(state, type)),
        ),
    ];
    scores.sort((a, b) => a.$2.compareTo(b.$2));
    return scores.first.$1;
  }

  static int levelsUntilSoftcap(GameState state) {
    final mean =
        state.heroes.fold<int>(0, (s, h) => s + h.level) /
        max(1, state.heroes.length);
    final floor = state.currentRoom.floorNumber.toDouble();
    final gap = floor + 2 - mean;
    return max(0, gap.ceil());
  }

  /// Public room-clear: awards loot/gold and advances (farm loop or push).
  static GameState completeCurrentRoom(
    GameState state, {
    required int goldGain,
    bool skipLootRoll = false,
    List<LootDrop>? recentLoot,
  }) => _advanceToNextRoom(
    state,
    goldGain: goldGain,
    skipLootRoll: skipLootRoll,
    recentLoot: recentLoot,
  );

  /// Marks the current floor wave cleared, awards gold/loot and advances.
  /// Farm loops the same floor; push goes to the next floor.
  /// Clearing the boss floor (5+AL) counts a boss victory; push returns to hub.
  static GameState _advanceToNextRoom(
    GameState state, {
    required int goldGain,
    bool skipLootRoll = false,
    List<LootDrop>? recentLoot,
  }) {
    final room = state.currentRoom;
    final enemiesDefeated = state.enemies.length;
    final bossesCleared = room.type == RoomType.boss ? 1 : 0;
    final elitesDefeated = state.enemies
        .where((e) => e.role == EnemyRole.elite || e.role == EnemyRole.boss)
        .length;

    late GameState awarded;
    late List<LootDrop> drops;
    var lootReceipt = const LootGrantResult();
    // Floor fillers (sigil / pouch / relic / vial) once per clear.
    final floorDrops = rollFloorClearLoot(
      room.globalBattleNumber,
      roomType: room.type,
    );
    if (skipLootRoll) {
      // Combat: kill gear already applied on pickup; still grant floor fillers.
      final lootResult = grantLoot(state, floorDrops);
      awarded = lootResult.state;
      drops = lootResult.resolved;
      lootReceipt = lootReceipt.merge(lootResult.receipt);
    } else {
      // Treasure (and any explicit full roll): chest gear + floor fillers.
      final rawDrops = LootPipeline.finalizeLootDrops([
        ...rollKillLoot(
          room.globalBattleNumber,
          ascensionLevel: state.ascensionLevel,
          lootFindPercent: state.petLootFindPercent + BlessingConstellation.lootFindPercent(state),
          hardmodeLevel: Keystone.combatLevel(state),
          party: state.heroes,
          dungeonId: state.dungeonId,
        ),
        ...floorDrops,
      ]);
      final lootResult = grantLoot(state, rawDrops);
      awarded = lootResult.state;
      drops = lootResult.resolved;
      lootReceipt = lootReceipt.merge(lootResult.receipt);
    }
    final lootLine = lootReceipt.summaryLine();
    if (lootLine.isNotEmpty) {
      LogicNotices.recordFloorLootLine(lootLine);
    }
    // recentLoot arg kept for call-site compat; clear loot is authoritative.
    if (recentLoot != null && recentLoot.isNotEmpty && drops.isEmpty) {
      drops = recentLoot;
    }
    final goldMul = awarded.inGauntlet
        ? gauntletGoldMul(
            room.floorNumber,
            prestigeBonusLevel: awarded.metaDepth.gauntletGoldBonusLevel,
          )
        : 1.0;
    // Combat kill gold is credited live via [creditCombatGold]. Clear only
    // pays treasure/chest budgets (and any explicit leftover goldGain).
    final goldAwarded = applyGoldGain(awarded, (goldGain * goldMul).round());
    final farmLoop = awarded.dungeonMode == DungeonMode.farm;
    final clearedBoss = bossesCleared > 0;
    final gauntlet = awarded.inGauntlet;
    final rift = awarded.inAnyRiftMode;
    // Zone HFC only — Gauntlet climb lives on metaDepth.gauntletBestFloor
    // so Ascend fragments keep using real zone clears.
    final highest = (gauntlet || rift)
        ? awarded.highestFloorCleared
        : max(awarded.highestFloorCleared, room.floorNumber);
    awarded = grantBossCraftMats(awarded, clearedBoss: clearedBoss);
    // Auto-wear clear upgrades so bag loot powers the party every Ascension.
    final stashBeforeEquip = awarded.gearStash.length;
    awarded = autoEquipBetterGear(awarded);
    final equippedOnClear = stashBeforeEquip - awarded.gearStash.length;
    if (equippedOnClear > 0) {
      LogicNotices.recordFloorEquipLine(
        'Equipped $equippedOnClear · ${awarded.gearStash.length} kept in bag',
      );
    }

    // Push + boss floor clear → dungeon cleared, back to hub.
    // Gauntlet / Rift / Greater Rift never exit on boss — endless climb / kill waves.
    // Daily echo: claim on first clear, then return to hub (one floor).
    final wasDaily = MetaSystems.isActiveDailyRun(state);
    if (!farmLoop && clearedBoss && !gauntlet && !rift) {
      var preLeave = awarded;
      if (state.inWorldBoss) {
        preLeave = WorldBoss.onBossClear(preLeave);
      }
      if (state.apexTrialActive && !preLeave.metaDepth.apexTrialCleared) {
        preLeave = preLeave.copyWith(
          essence: preLeave.essence + 20,
          metaDepth: preLeave.metaDepth.copyWith(apexTrialCleared: true),
        );
        preLeave = BlessingConstellation.grantPoints(
          preLeave,
          BlessingConstellation.apexTrialPointReward,
        );
      }
      final def = DungeonCatalog.byId(preLeave.dungeonId);
      var progressed = preLeave.copyWith(
        gold: preLeave.gold + goldAwarded,
        lifetimeGoldEarned: preLeave.lifetimeGoldEarned + goldAwarded,
        bossVictories: preLeave.bossVictories + bossesCleared,
        highestFloorCleared: highest,
        highestDungeonCleared: max(preLeave.highestDungeonCleared, def.number),
        inDungeon: false,
        inWorldBoss: false,
        worldBossPractice: false,
        apexTrialActive: false,
        recentLoot: drops,
        heroes: preLeave.heroes
            .map(
              (hero) =>
                  hero.copyWith(currentHp: preLeave.effectiveHeroMaxHp(hero)),
            )
            .toList(),
      );
      progressed = _clearKeystoneRun(progressed);
      progressed = _applyMetaProgress(state, progressed, drops);
      progressed = _applyRosterExhibition(progressed);
      return applyMissionProgress(
        progressed,
        enemiesDefeated: enemiesDefeated,
        bossesCleared: bossesCleared,
        goldEarned: goldAwarded,
        floorsCleared: 1,
        elitesDefeated: elitesDefeated,
      );
    }

    final targetFloor = farmLoop ? room.floorNumber : room.floorNumber + 1;
    final layoutSeed = newLayoutSeed();
    final nextFloor = DungeonGenerator.generateFloor(
      targetFloor,
      ascensionLevel: awarded.ascensionLevel,
      dungeonId: awarded.dungeonId,
      layoutSeed: layoutSeed,
      bossEvery: gauntlet ? gauntletBossEvery : null,
    );
    final nextRoom = nextFloor.first;
    final gauntletEss = gauntlet
        ? gauntletEssenceForFloor(room.floorNumber, boss: clearedBoss)
        : 0;
    var progressed = awarded.copyWith(
      gold: awarded.gold + goldAwarded,
      lifetimeGoldEarned: awarded.lifetimeGoldEarned + goldAwarded,
      essence: awarded.essence + gauntletEss,
      // Don't inflate ascend boss count from endless gauntlet bosses.
      bossVictories: gauntlet
          ? awarded.bossVictories
          : awarded.bossVictories + bossesCleared,
      highestFloorCleared: highest,
      enemies: createEnemyGroup(
        nextRoom,
        dungeonId: awarded.dungeonId,
        fromState: awarded,
      ),
      currentRoom: nextRoom,
      dungeonFloor: nextFloor,
      layoutSeed: layoutSeed,
      heroes: awarded.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: awarded.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      recentLoot: drops,
      metaDepth: gauntlet
          ? awarded.metaDepth.copyWith(
              gauntletBestFloor: max(
                awarded.metaDepth.gauntletBestFloor,
                room.floorNumber,
              ),
              seasonBestGauntletFloor: max(
                awarded.metaDepth.seasonBestGauntletFloor,
                room.floorNumber,
              ),
              lifetimeGauntletFloors:
                  awarded.metaDepth.lifetimeGauntletFloors + 1,
            )
          : awarded.metaDepth,
    );
    if (gauntlet &&
        room.floorNumber > awarded.metaDepth.seasonBestGauntletFloor) {
      final month = awarded.metaDepth.leaderboardSeasonKey.isNotEmpty
          ? awarded.metaDepth.leaderboardSeasonKey
          : isoMonthKey(DateTime.now().toUtc());
      PlayGamesBridge.noteGauntletPb(monthKey: month, floor: room.floorNumber);
    }
    progressed = _applyMetaProgress(state, progressed, drops);

    // Daily echo ends after the first clear (reward claimed) — no PUSH climb.
    if (wasDaily && progressed.dailyClaimed) {
      progressed = _clearKeystoneRun(
        progressed.copyWith(
          inDungeon: false,
          heroes: progressed.heroes
              .map(
                (hero) => hero.copyWith(
                  currentHp: progressed.effectiveHeroMaxHp(hero),
                ),
              )
              .toList(),
        ),
      );
    }

    return applyMissionProgress(
      progressed,
      enemiesDefeated: enemiesDefeated,
      bossesCleared: gauntlet ? 0 : bossesCleared,
      goldEarned: goldAwarded,
      floorsCleared: 1,
      elitesDefeated: elitesDefeated,
    );
  }

  /// Codex discovery, local achievements, and Daily Run claim — evaluated on
  /// every floor/boss clear. [before] is the pre-clear state (still holding
  /// the defeated enemy roster); [after] is the state post gold/loot award.
  static GameState _applyMetaProgress(
    GameState before,
    GameState after,
    List<LootDrop> drops,
  ) {
    var next = MetaSystems.registerEnemyEncounters(after, before.enemies);
    next = MetaSystems.registerItemDrops(next, drops);
    // Probe [before] — after already rolled a new layoutSeed on advance.
    next = _claimDailyIfEligible(next, dailyProbe: before);
    // Only clear when they beat the floor they kept wiping on. Clearing a
    // lower floor after a PUSH retreat must keep the wall streak (else advice
    // never reaches 3 on a cliff floor).
    if (before.wipeStreakKey.isEmpty ||
        before.wipeStreakKey == wipeFloorKey(before)) {
      next = clearWipeStreak(next);
    }
    final farmLoop = before.dungeonMode == DungeonMode.farm;
    // Gauntlet is endless — same mint rules as farm (no challenge/weekly cheese).
    final suppressMetaMint = farmLoop || before.inGauntlet;
    final challengeBonus = MetaSystems.challengeClearEssenceBonus(
      before,
      farmLoop: suppressMetaMint,
    );
    if (challengeBonus > 0) {
      next = next.copyWith(essence: next.essence + challengeBonus);
    }
    final bossKill = before.currentRoom.type == RoomType.boss ? 1 : 0;
    // Zone trophies granted when a dungeon is fully cleared (push boss → hub).
    final trophies = List<String>.from(next.metaDepth.zoneTrophies);
    if (after.highestDungeonCleared > before.highestDungeonCleared) {
      if (!trophies.contains(before.dungeonId)) {
        trophies.add(before.dungeonId);
      }
    }
    // Daily vault: push clears (or any boss). Gauntlet clears count in endgame.
    // Farm loops never mint vault progress.
    final gauntletVault = before.inGauntlet && endgameUnlocked(before);
    final vaultBump =
        (!farmLoop && (!before.inGauntlet || gauntletVault)) ||
            (bossKill > 0 && !before.inGauntlet)
        ? 1
        : 0;
    final keyCleared = before.keystoneRunActive
        ? before.keystoneRunLevel
        : before.hardmodeLevel;
    final hmCleared = keyCleared.clamp(0, Keystone.maxLevel);
    next = ensureWeeklyContract(next);
    var bestTimed = next.metaDepth.dailyBestTimedKey;
    var weekBestTimed = next.metaDepth.weeklyBestTimedKey;
    var preferredKey = next.hardmodeLevel;
    var outcome = next.keystoneOutcome;
    var essence = next.essence;
    final keystoneNotices = <String>[];

    // Keystone boss clear: timed → upgrade + vault score; overtime → depleted.
    if (bossKill > 0 &&
        before.keystoneRunActive &&
        !before.inGauntlet &&
        !farmLoop &&
        before.keystoneOutcome.isEmpty) {
      final timed = before.keystoneTimerMs <= before.keystoneParMs;
      final key = before.keystoneRunLevel;
      if (timed) {
        final bonus = Keystone.timedClearBonus(key);
        essence += bonus;
        preferredKey = min(
          next.effectiveMaxHardmode,
          max(preferredKey, key + 1),
        );
        bestTimed = max(bestTimed, key);
        weekBestTimed = max(weekBestTimed, key);
        outcome = 'timed';
        keystoneNotices.add(
          'KEY +$key TIMED · next KEY +$preferredKey · +${bonus}e',
        );
        final monthBest = max(next.metaDepth.monthlyBestTimedKey, key);
        if (monthBest != next.metaDepth.monthlyBestTimedKey) {
          next = next.copyWith(
            metaDepth: next.metaDepth.copyWith(monthlyBestTimedKey: monthBest),
          );
        }
        // Challenge PBs (personal toggles).
        var mdCh = next.metaDepth;
        if (before.challengeBossRush) {
          mdCh = mdCh.copyWith(
            challengeBestBossRushKey: max(mdCh.challengeBestBossRushKey, key),
          );
        }
        if (before.challengeNoFlask) {
          mdCh = mdCh.copyWith(
            challengeBestNoFlaskKey: max(mdCh.challengeBestNoFlaskKey, key),
          );
        }
        if (before.challengeTiny) {
          mdCh = mdCh.copyWith(
            challengeBestTinyKey: max(mdCh.challengeBestTinyKey, key),
          );
        }
        if (mdCh != next.metaDepth) {
          next = next.copyWith(metaDepth: mdCh);
        }
        final md = next.metaDepth;
        final clearMs = before.keystoneTimerMs;
        if (PlayGamesScores.isBetterTimed(
          newKey: key,
          newClearMs: clearMs,
          bestKey: md.seasonBestTimedKey,
          bestClearMs: md.seasonBestTimedClearMs,
        )) {
          next = next.copyWith(
            metaDepth: md.copyWith(
              seasonBestTimedKey: key,
              seasonBestTimedClearMs: clearMs,
            ),
          );
          PlayGamesBridge.noteTimedPb(
            monthKey: next.metaDepth.leaderboardSeasonKey.isNotEmpty
                ? next.metaDepth.leaderboardSeasonKey
                : isoMonthKey(DateTime.now().toUtc()),
            keyLevel: key,
            clearMs: clearMs,
          );
        }
      } else {
        outcome = 'depleted';
        keystoneNotices.add(
          'KEY +$key depleted (${Keystone.formatTimer(before.keystoneTimerMs)} / ${Keystone.formatTimer(before.keystoneParMs)})',
        );
      }
    }

    next = next.copyWith(
      essence: essence,
      hardmodeLevel: preferredKey,
      keystoneOutcome: outcome,
      metaDepth: next.metaDepth.copyWith(
        lifetimeFloorClears: next.metaDepth.lifetimeFloorClears + 1,
        lifetimeBossKills: next.metaDepth.lifetimeBossKills + bossKill,
        highestHardmodeCleared: max(
          next.metaDepth.highestHardmodeCleared,
          hmCleared,
        ),
        zoneTrophies: trophies,
        dailyVaultClears: min(
          dailyVaultClearTarget,
          next.metaDepth.dailyVaultClears + vaultBump,
        ),
        dailyBestTimedKey: bestTimed,
        weeklyBestTimedKey: weekBestTimed,
      ),
    );
    next = MetaSystems.evaluateAchievements(next);
    next = syncMetaPayoffs(next);
    LogicNotices.addMetaPayoffs(keystoneNotices);
    return next;
  }

  static GameState _claimDailyIfEligible(
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
    final dailyEssenceReward =
        25 + state.metaDepth.dailyEssenceBonusLevel * dawnTitheEssencePerLevel;
    return state.copyWith(
      dailyClaimed: true,
      essence: state.essence + dailyEssenceReward,
    );
  }

  /// Enters the free, seeded Daily Run — a single floor echo in whichever
  /// dungeon today's UTC date rotates to. Ignores normal unlock gating.
  /// Clearing the floor claims today's reward once and returns to hub.
  static GameState enterDaily(GameState state, {DateTime? now}) {
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
    final cleared = _clearKeystoneRun(state);
    return cleared.copyWith(
      inDungeon: true,
      inGauntlet: false,
      dungeonId: dungeonId,
      dungeonMode: DungeonMode.push,
      highestFloorCleared: 0,
      currentRoom: room,
      dungeonFloor: floor,
      enemies: createEnemyGroup(room, dungeonId: dungeonId, fromState: cleared),
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

  /// Parses a save of any version, migrating legacy v1 saves
  /// (single `enemy` + stored `battleNumber`) to the room-based v2 model.
  static GameState stateFromJson(Map<String, dynamic> json) {
    final loaded = saveVersionOf(json) <= 1
        ? _migrateV1(json)
        : _backfillLifetimeGold(GameState.fromJson(json));
    final rebuildQuests = MissionBoard.needsQuestBoardRebuild(loaded.missions);
    var next = loaded.missions.isNotEmpty && !rebuildQuests
        ? loaded
        : loaded.copyWith(
            missions: createMissionBoardFor(loaded),
            metaDepth: loaded.metaDepth.copyWith(
              dailyQuestDate: MetaSystems.dailyDateKey(DateTime.now().toUtc()),
            ),
          );
    next = MissionBoard.ensureDailyQuest(next);
    if (next.ascensionLevel > 0) {
      next = next.copyWith(rogueUnlocked: true);
    }
    // KEY is party-max-level endgame — clamp preferred keys before unlock.
    if (!endgameUnlocked(next) &&
        (next.hardmodeLevel > 0 || next.keystoneRunActive)) {
      next = _clearKeystoneRun(next.copyWith(hardmodeLevel: 0));
    }
    // Legacy saves may store hero levels above the hard cap.
    next = _clampHeroLevels(next);
    // Legacy / incomplete dungeon saves: preferred KEY was set but the run
    // never locked — re-begin so combat scaling matches hub KEY preference.
    if (next.inDungeon &&
        !next.inGauntlet &&
        !next.keystoneRunActive &&
        next.hardmodeLevel > 0) {
      next = _beginKeystoneRun(next);
    }
    return MetaSystems.evaluateAchievements(
      syncSpecUnlocks(
        ensureRogueHero(
          GearService.clampStashToCap(unequipIllegalGear(next)),
        ),
      ),
    );
  }

  /// Which save format this JSON is.
  ///
  /// Saves have written `version` since v2; before that the shape is the tell
  /// (v1 stored a single `enemy`, not an `enemies` list). Reading the field
  /// means a future format change has one place to branch on.
  static int saveVersionOf(Map<String, dynamic> json) {
    final stored = (json['version'] as num?)?.toInt();
    if (stored != null && stored > 0) return stored;
    return json.containsKey('enemies') ? 2 : 1;
  }

  /// Lifetime gold is tracked for achievements / stats. Older saves may
  /// under-count it vs gold already earned; raise it to the smallest honest
  /// floor so gold-milestone achievements stay fair.
  static GameState _backfillLifetimeGold(GameState state) {
    var floor = state.gold;
    for (final d in DungeonCatalog.all) {
      if (d.number <= state.highestDungeonCleared) {
        floor = max(floor, d.unlockPrice);
      }
    }
    if (state.lifetimeGoldEarned >= floor) return state;
    return state.copyWith(lifetimeGoldEarned: floor);
  }

  /// Cap roster levels at [maxHeroLevel] (legacy / bad saves).
  static GameState _clampHeroLevels(GameState state) {
    var dirty = false;
    final roster = <PartyHero>[];
    for (final h in state.heroRoster) {
      if (h.level > maxHeroLevel) {
        dirty = true;
        roster.add(h.copyWith(level: maxHeroLevel, xp: 0));
      } else {
        roster.add(h);
      }
    }
    return dirty ? state.copyWith(heroRoster: roster) : state;
  }

  // —— Save export / import (clipboard JSON, no server) ——————————

  /// Serializes [state] to a JSON string suitable for clipboard export.
  static String exportSaveJson(GameState state) => jsonEncode(state.toJson());

  /// Parses a previously-exported save string. Returns null on any parse
  /// failure so the caller can show a friendly error instead of crashing.
  static GameState? importSaveJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return stateFromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  // —— Gear loadouts (save/apply up to 3 named presets) ——————————

  static GameState _migrateV1(Map<String, dynamic> json) {
    final battleNumber = (json['battleNumber'] as int?) ?? 1;
    final floorNumber = max(1, battleNumber);
    final floor = DungeonGenerator.generateFloor(floorNumber);
    final room = floor.first;

    final recentLootJson = json['recentLoot'] as List<dynamic>?;
    final unlockedRelicsJson = json['unlockedRelics'] as List<dynamic>?;

    final heroes = (json['heroes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PartyHero.fromJson)
        .toList();

    return GameState(
      heroRoster: heroes,
      activeHeroIds: [for (final h in heroes) h.id],
      enemies: createEnemyGroup(room),
      gold: json['gold'] as int,
      essence: (json['essence'] as int?) ?? 0,
      bossVictories: (json['bossVictories'] as int?) ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      offlineSecondsRecovered: (json['offlineSecondsRecovered'] as int?) ?? 0,
      attackBonus: (json['attackBonus'] as int?) ?? 0,
      defenseBonus: (json['defenseBonus'] as int?) ?? 0,
      vitalityBonus: (json['vitalityBonus'] as int?) ?? 0,
      recentLoot: recentLootJson == null
          ? <LootDrop>[]
          : recentLootJson
                .cast<Map<String, dynamic>>()
                .map(LootDrop.fromJson)
                .toList(),
      unlockedRelics: unlockedRelicsJson == null
          ? <String>[]
          : unlockedRelicsJson.cast<String>(),
      currentRoom: room,
      dungeonFloor: floor,
      ascensionLevel: min(
        maxAscensionLevel,
        (json['ascensionLevel'] as int?) ?? 0,
      ),
      equipped: () {
        final map = <EquipmentSlot, EquipmentItem>{};
        if (json['equippedWeapon'] != null) {
          map[EquipmentSlot.weapon] = EquipmentItem.fromJson(
            json['equippedWeapon'] as Map<String, dynamic>,
          );
        }
        if (json['equippedArmor'] != null) {
          map[EquipmentSlot.cloak] = EquipmentItem.fromJson(
            json['equippedArmor'] as Map<String, dynamic>,
          );
        }
        return map;
      }(),
      metaDepth: MetaDepthState(
        unlockedSpecs: [
          for (final s in HeroSpecs.starterUnlocked) s.name,
          for (final h in heroes) h.specId.name,
        ],
      ),
    );
  }

  // —— Starter gear: moved to starter_gear.dart ——
  static GameState fillMissingStarterGear(GameState state) =>
      StarterGear.fillMissingStarterGear(state);
  static GameState unequipIllegalGear(GameState state) =>
      GearService.unequipIllegalGear(state);
  static ArmorType? preferredArmorForSpec(HeroSpecDef spec, int level) =>
      StarterGear.preferredArmorForSpec(spec, level);
  // —— Loot pipeline: moved to loot_pipeline.dart ——
  static int goldPouchBaseGold(int battleNumber) =>
      LootPipeline.goldPouchBaseGold(battleNumber);
  static bool isWalletGoldDrop(LootDrop drop) =>
      LootPipeline.isWalletGoldDrop(drop);
  static List<LootDrop> rollKillLoot(
    int battleNumber, {
    int ascensionLevel = 0,
    int lootFindPercent = 0,
    int hardmodeLevel = 0,
    List<PartyHero>? party,
    String dungeonId = 'sandy',
    EnemyRole enemyRole = EnemyRole.normal,
  }) => LootPipeline.rollKillLoot(
    battleNumber,
    ascensionLevel: ascensionLevel,
    lootFindPercent: lootFindPercent,
    hardmodeLevel: hardmodeLevel,
    party: party,
    dungeonId: dungeonId,
    enemyRole: enemyRole,
  );
  static List<LootDrop> rollRoomChestLoot(GameState state, {Random? random}) =>
      LootPipeline.rollRoomChestLoot(state, random: random);
  static List<LootDrop> rollFloorClearLoot(
    int battleNumber, {
    required RoomType roomType,
  }) => LootPipeline.rollFloorClearLoot(battleNumber, roomType: roomType);
  static List<LootDrop> rollLoot(
    int battleNumber, {
    int ascensionLevel = 0,
    int lootFindPercent = 0,
    int hardmodeLevel = 0,
    List<PartyHero>? party,
    String dungeonId = 'sandy',
    EnemyRole enemyRole = EnemyRole.normal,
    RoomType? roomType,
  }) => LootPipeline.rollLoot(
    battleNumber,
    ascensionLevel: ascensionLevel,
    lootFindPercent: lootFindPercent,
    hardmodeLevel: hardmodeLevel,
    party: party,
    dungeonId: dungeonId,
    enemyRole: enemyRole,
    roomType: roomType,
  );
  static EquipmentItem createEquipment({
    required EquipmentSlot slot,
    required LootRarity rarity,
    required int battleNumber,
    HeroRole? bias,
    ArmorType? preferredArmor,
    SpecRoleTag? roleTag,
    HeroSpecId? lootSpecId,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) => LootPipeline.createEquipment(
    slot: slot,
    rarity: rarity,
    battleNumber: battleNumber,
    bias: bias,
    preferredArmor: preferredArmor,
    roleTag: roleTag,
    lootSpecId: lootSpecId,
    dungeonId: dungeonId,
    ascensionLevel: ascensionLevel,
    hardmodeLevel: hardmodeLevel,
  );
  static int itemLevelFor({
    required int battleNumber,
    required LootRarity rarity,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) => LootPipeline.itemLevelFor(
    battleNumber: battleNumber,
    rarity: rarity,
    dungeonId: dungeonId,
    ascensionLevel: ascensionLevel,
    hardmodeLevel: hardmodeLevel,
  );
  static int maxAutoSellIlvlCap(GameState state) =>
      LootPipeline.maxAutoSellIlvlCap(state);
  static EquipmentItem scaleSoulboundForAl(
    EquipmentItem item,
    int ascensionLevel,
  ) => LootPipeline.scaleSoulboundForAl(item, ascensionLevel);
  static int lootEssenceValue(LootDrop drop) =>
      LootPipeline.lootEssenceValue(drop);
  static int equipmentEssenceValue(EquipmentItem item) =>
      LootPipeline.equipmentEssenceValue(item);
  static int equipmentGoldValue(EquipmentItem item) =>
      LootPipeline.equipmentGoldValue(item);
  static int treasureGoldBudget(GameState state) =>
      LootPipeline.treasureGoldBudget(state);
  // —— Gear service: moved to gear_service.dart ——
  static const int maxGearStash = GearService.maxGearStash;
  static int maxGearStashFor(GameState state) =>
      GearService.maxGearStashFor(state);
  static GameState stashEquipment(GameState state, EquipmentItem item) =>
      GearService.stashEquipment(state, item);
  static ({GameState state, int overflowEssence, String? overflowName})
  stashEquipmentDetailed(GameState state, EquipmentItem item) =>
      GearService.stashEquipmentDetailed(state, item);
  static EquipmentItem? findGear(GameState state, String id) =>
      GearService.findGear(state, id);
  static EquipmentItem? findStashGear(GameState state, String id) =>
      GearService.findStashGear(state, id);
  static ({int heroIndex, EquipmentSlot slot})? findEquippedLocation(
    GameState state,
    String id,
  ) => GearService.findEquippedLocation(state, id);
  static GameState removeGear(GameState state, String id) =>
      GearService.removeGear(state, id);
  static List<EquipmentSlot> equipTargetsFor(EquipmentItem item) =>
      GearService.equipTargetsFor(item);
  static bool canHeroReceive(
    PartyHero hero,
    EquipmentItem item, {
    required EquipmentSlot slot,
  }) => GearService.canHeroReceive(hero, item, slot: slot);
  static GameState equipFromStash(
    GameState state,
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) => GearService.equipFromStash(
    state,
    itemId,
    heroIndex: heroIndex,
    intoSlot: intoSlot,
  );
  static GameState unequipSlot(
    GameState state,
    EquipmentSlot slot, {
    int heroIndex = 0,
  }) => GearService.unequipSlot(state, slot, heroIndex: heroIndex);
  static GameState sellGear(GameState state, String itemId) =>
      GearService.sellGear(state, itemId);
  static int combineCost(
    EquipmentItem primary,
    EquipmentItem secondary, {
    int combinatorLuck = 0,
  }) => GearService.combineCost(
    primary,
    secondary,
    combinatorLuck: combinatorLuck,
  );
  static List<List<EquipmentSlot>> equipSlotGroups() =>
      GearService.equipSlotGroups();
  static int slotEquipScore(
    PartyHero hero,
    EquipmentItem? item, {
    required EquipmentSlot slot,
    List<EquipmentItem>? pairingStash,
  }) => GearService.slotEquipScore(
    hero,
    item,
    slot: slot,
    pairingStash: pairingStash,
  );
  static int bestPairingOffHandScore(
    PartyHero hero,
    List<EquipmentItem> stash, {
    String? excludeItemId,
  }) => GearService.bestPairingOffHandScore(
    hero,
    stash,
    excludeItemId: excludeItemId,
  );
  static ({EquipmentItem item, int score})? bestPairingOffHand(
    PartyHero hero,
    List<EquipmentItem> stash, {
    String? excludeItemId,
  }) =>
      GearService.bestPairingOffHand(hero, stash, excludeItemId: excludeItemId);
  static int specEquipScore(PartyHero hero, EquipmentItem item) =>
      GearService.specEquipScore(hero, item);
  static int itemBudgetScore(PartyHero hero, EquipmentItem item) =>
      GearService.itemBudgetScore(hero, item);
  static int roleEquipScore(
    HeroRole role,
    EquipmentItem item, {
    HeroSpecId? specId,
    int level = 100,
  }) => GearService.roleEquipScore(role, item, specId: specId, level: level);
  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
    EquipmentSlot intoSlot,
  })
  compareForHero(
    PartyHero hero,
    EquipmentItem candidate, {
    EquipmentSlot? intoSlot,
    List<EquipmentItem>? pairingStash,
  }) => GearService.compareForHero(
    hero,
    candidate,
    intoSlot: intoSlot,
    pairingStash: pairingStash,
  );
  static double roleRelevantStatMass(PartyHero hero, EquipmentItem item) =>
      GearService.roleRelevantStatMass(hero, item);
  static bool emptySlotWorthFilling(
    PartyHero hero,
    EquipmentItem item,
    int score,
  ) => GearService.emptySlotWorthFilling(hero, item, score);
  static bool isMeaningfulEquipUpgrade({
    required PartyHero hero,
    required EquipmentItem item,
    required int curScore,
    required int newScore,
    required bool slotEmpty,
    EquipmentItem? worn,
  }) => GearService.isMeaningfulEquipUpgrade(
    hero: hero,
    item: item,
    curScore: curScore,
    newScore: newScore,
    slotEmpty: slotEmpty,
    worn: worn,
  );
  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
  planBiSAssignments(GameState state) => GearService.planBiSAssignments(state);
  static int gearPlanSignature(GameState state) =>
      GearService.gearPlanSignature(state);
  static GameState autoEquipBetterGear(GameState state) =>
      GearService.autoEquipBetterGear(state);
  static String formatDelta(int value) => GearService.formatDelta(value);
  static bool canCombine(EquipmentItem primary, EquipmentItem secondary) =>
      GearService.canCombine(primary, secondary);
  static LootRarity mergedRarity(LootRarity primary, LootRarity secondary) =>
      GearService.mergedRarity(primary, secondary);
  static EquipmentItem mergeEquipment(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) => GearService.mergeEquipment(primary, secondary);
  static EquipmentItem previewCombine(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) => GearService.previewCombine(primary, secondary);
  static GameState combineGear(
    GameState state, {
    required String primaryId,
    required String secondaryId,
  }) => GearService.combineGear(
    state,
    primaryId: primaryId,
    secondaryId: secondaryId,
  );
  static ({GameState state, List<LootDrop> resolved}) applyLootDrops(
    GameState state,
    List<LootDrop> drops,
  ) => GearService.applyLootDrops(state, drops);

  static ({GameState state, List<LootDrop> resolved, LootGrantResult receipt})
  grantLoot(
    GameState state,
    List<LootDrop> drops,
  ) => GearService.grantLoot(state, drops);
  static GameState unstickBagIfNeeded(GameState state) =>
      GearService.unstickBagIfNeeded(state);
  static GameState cleanBagJunk(
    GameState state, {
    bool unstickBag = false,
    bool mergeFirst = true,
    bool manualClean = false,
  }) => GearService.cleanBagJunk(
    state,
    unstickBag: unstickBag,
    mergeFirst: mergeFirst,
    manualClean: manualClean,
  );
  static ({GameState state, int merges}) autoMergeJunk(
    GameState state, {
    int maxMerges = 40,
  }) => GearService.autoMergeJunk(state, maxMerges: maxMerges);
  static GameState autoSellJunk(GameState state, {bool unstickBag = false}) =>
      GearService.autoSellJunk(state, unstickBag: unstickBag);
  static GameState autoDisassembleJunk(
    GameState state, {
    bool unstickBag = false,
  }) => GearService.autoDisassembleJunk(state, unstickBag: unstickBag);
  static String rarityFilterLabel(int rarityIndex) =>
      GearService.rarityFilterLabel(rarityIndex);
  static GameState sellGearForGold(GameState state, String itemId) =>
      GearService.sellGearForGold(state, itemId);
  static const int maxLoadouts = GearService.baseMaxLoadouts;
  static int maxLoadoutsFor(GameState state) =>
      GearService.maxLoadoutsFor(state);
  static GameState saveLoadout(
    GameState state, {
    required String id,
    required String name,
  }) => GearService.saveLoadout(state, id: id, name: name);
  static GameState deleteLoadout(GameState state, String id) =>
      GearService.deleteLoadout(state, id);
  static ({GameState state, int skipped}) applyLoadout(
    GameState state,
    String id,
  ) => GearService.applyLoadout(state, id);

  // —— Offline progress: moved to offline_progress.dart ——
  static Future<OfflineProgressResult> applyOfflineProgressAsync(
    GameState state,
    Duration elapsed,
  ) => OfflineProgress.applyOfflineProgressAsync(state, elapsed);
  static OfflineProgressResult applyOfflineProgress(
    GameState state,
    Duration elapsed,
  ) => OfflineProgress.applyOfflineProgress(state, elapsed);
  static GameState applyHubIdleProgress(GameState state, int seconds) =>
      OfflineProgress.applyHubIdleProgress(state, seconds);
  static int offlineFloorBudget(int seconds) =>
      OfflineProgress.offlineFloorBudget(seconds);
  static ({GameState state, int roomsCleared}) simulateSpatialOffline(
    GameState state,
    int seconds,
  ) => OfflineProgress.simulateSpatialOffline(state, seconds);

  // —— Pets: moved to pet_service.dart ——
  static int hatchPetCost(GameState state) => PetService.hatchPetCost(state);
  static GameState hatchPet(GameState state) => PetService.hatchPet(state);
  static bool canMergePets(GameState state, String petIdA, String petIdB) =>
      PetService.canMergePets(state, petIdA, petIdB);
  static GameState mergePets(GameState state, String petIdA, String petIdB) =>
      PetService.mergePets(state, petIdA, petIdB);
  static GameState setFavoritePetSpecies(GameState state, String speciesId) =>
      PetService.setFavoritePetSpecies(state, speciesId);
  static int petFrameCost(PetFrame frame) => PetService.petFrameCost(frame);
  static GameState buyPetFrame(GameState state, String petId, PetFrame frame) =>
      PetService.buyPetFrame(state, petId, frame);
  static const int maxPetBondLevel = PetService.maxPetBondLevel;
  static const int maxPetLevel = PetService.maxPetLevel;
  static int bondPetCost(int bondLevel) => PetService.bondPetCost(bondLevel);
  static GameState bondPet(GameState state, String petId) =>
      PetService.bondPet(state, petId);
  static GameState setActivePet(GameState state, String petId) =>
      PetService.setActivePet(state, petId);
  static int petLevelUpCost(Pet pet) => PetService.petLevelUpCost(pet);
  static GameState levelUpPet(GameState state, String petId) =>
      PetService.levelUpPet(state, petId);

  // —— Missions: moved to mission_board.dart ——
  static List<Mission> createMissionBoard({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    int bountyRung = 0,
    bool endgame = false,
    Random? random,
  }) => MissionBoard.createMissionBoard(
    ascensionLevel: ascensionLevel,
    highestDungeonCleared: highestDungeonCleared,
    highestFloorCleared: highestFloorCleared,
    hardmodeLevel: hardmodeLevel,
    bountyRung: bountyRung,
    endgame: endgame,
    random: random,
  );
  static List<Mission> createMissionBoardFor(
    GameState state, {
    Random? random,
  }) => MissionBoard.createMissionBoardFor(state, random: random);
  static GameState ensureDailyQuest(GameState state, {DateTime? now}) =>
      MissionBoard.ensureDailyQuest(state, now: now);
  static int missionDepthScore({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
  }) => MissionBoard.missionDepthScore(
    ascensionLevel: ascensionLevel,
    highestDungeonCleared: highestDungeonCleared,
    highestFloorCleared: highestFloorCleared,
    hardmodeLevel: hardmodeLevel,
  );
  static Mission createMission({
    required MissionType type,
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    Random? random,
    int slot = 0,
  }) => MissionBoard.createMission(
    type: type,
    ascensionLevel: ascensionLevel,
    highestDungeonCleared: highestDungeonCleared,
    highestFloorCleared: highestFloorCleared,
    hardmodeLevel: hardmodeLevel,
    random: random,
    slot: slot,
  );
  static Mission rollReplacementMission(
    GameState state, {
    MissionType? avoid,
    int slot = 0,
    Random? random,
  }) => MissionBoard.rollReplacementMission(
    state,
    avoid: avoid,
    slot: slot,
    random: random,
  );
  static GameState applyMissionProgress(
    GameState state, {
    int enemiesDefeated = 0,
    int bossesCleared = 0,
    int goldEarned = 0,
    int floorsCleared = 0,
    int elitesDefeated = 0,
  }) => MissionBoard.applyMissionProgress(
    state,
    enemiesDefeated: enemiesDefeated,
    bossesCleared: bossesCleared,
    goldEarned: goldEarned,
    floorsCleared: floorsCleared,
    elitesDefeated: elitesDefeated,
  );
  static GameState claimMission(GameState state, String missionId) =>
      MissionBoard.claimMission(state, missionId);

  // —— Encounter budget: moved to encounter_factory.dart ——
  static ({int attack, int hp, int gold}) roomCombatBudget(
    DungeonRoom room, {
    String? dungeonId,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
  }) => EncounterFactory.roomCombatBudget(
    room,
    dungeonId: dungeonId,
    hardmodeLevel: hardmodeLevel,
    ascensionLevel: ascensionLevel,
    gearPressure: gearPressure,
  );
  static double appliedGearPressure(
    double gearPressure, {
    required int level,
    int ascensionLevel = 0,
  }) => EncounterFactory.appliedGearPressure(
    gearPressure,
    level: level,
    ascensionLevel: ascensionLevel,
  );
  static double partyGearPressure(GameState state) =>
      EncounterFactory.partyGearPressure(state);
  static int xpPoolForLevel(int level) =>
      EncounterFactory.xpPoolForLevel(level);

  /// 0–1 fill toward the next hero level.
  static double xpProgress(PartyHero hero) {
    final need = xpPoolForLevel(hero.level);
    if (need <= 0) return 0;
    return (hero.xp / need).clamp(0.0, 1.0);
  }
  static int xpForEnemy(EnemyUnit enemy) => EncounterFactory.xpForEnemy(enemy);
  static GameState awardPartyXp(GameState state, int amount) =>
      EncounterFactory.awardPartyXp(state, amount);
  static GameState awardEnemyKillXp(GameState state, EnemyUnit enemy) =>
      EncounterFactory.awardEnemyKillXp(state, enemy);
  static List<EnemyUnit> createEnemyGroup(
    DungeonRoom room, {
    String? dungeonId,
    bool bossRush = false,
    double threatScale = 1.0,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
    GameState? fromState,
  }) => EncounterFactory.createEnemyGroup(
    room,
    dungeonId: dungeonId,
    bossRush: bossRush,
    threatScale: threatScale,
    hardmodeLevel: hardmodeLevel,
    ascensionLevel: ascensionLevel,
    gearPressure: gearPressure,
    fromState: fromState,
  );

  // —— Apex crafting: moved to apex_forge.dart ——
  static int craftMatCount(GameState state, String matId) =>
      ApexForge.craftMatCount(state, matId);
  static bool canAffordCraftCosts(GameState state, Map<String, int> costs) =>
      ApexForge.canAffordCraftCosts(state, costs);
  static GameState grantBossCraftMats(
    GameState state, {
    required bool clearedBoss,
  }) => ApexForge.grantBossCraftMats(state, clearedBoss: clearedBoss);
  static bool hasApexWeaponRank1(
    GameState state,
    HeroClassId classId,
    SpecRoleTag role,
  ) => ApexForge.hasApexWeaponRank1(state, classId, role);
  static bool canCraftApex(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) => ApexForge.canCraftApex(state, classId: classId, role: role, slot: slot);
  static GameState craftApex(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) => ApexForge.craftApex(state, classId: classId, role: role, slot: slot);
  static bool canUpgradeApex(GameState state, String itemId) =>
      ApexForge.canUpgradeApex(state, itemId);
  static GameState upgradeApex(GameState state, String itemId) =>
      ApexForge.upgradeApex(state, itemId);
  static GameState equipFromApexVault(
    GameState state,
    String itemId, {
    int? heroIndex,
    EquipmentSlot? intoSlot,
  }) => ApexForge.equipFromApexVault(
    state,
    itemId,
    heroIndex: heroIndex,
    intoSlot: intoSlot,
  );
  static ApexAutoEquipResult autoEquipAllApexVault(GameState state) =>
      ApexForge.autoEquipAllApexVault(state);
  static GameState setApexCraftGoal(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) => ApexForge.setApexCraftGoal(
    state,
    classId: classId,
    role: role,
    slot: slot,
  );
  static GameState setApexTargetMat(GameState state, String matId) =>
      ApexForge.setApexTargetMat(state, matId);
  static GameState clearApexTargetMatOverride(GameState state) =>
      ApexForge.clearApexTargetMatOverride(state);
  static String? resolveApexTargetMatId(GameState state) =>
      ApexForge.resolveTargetMatId(state);
  static int apexBossesUntilTargetGrant(GameState state) =>
      ApexForge.bossesUntilTargetGrant(state);
  static String? apexEquipBlockReason(
    GameState state,
    String itemId, {
    int? heroIndex,
  }) => ApexForge.equipBlockReason(state, itemId, heroIndex: heroIndex);
  static int? apexBestHeroIndexForItem(GameState state, EquipmentItem item) =>
      ApexForge.bestHeroIndexForApex(state, item);
  static List<MapEntry<String, int>> apexSortedMatShortages(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
    int rank = 1,
  }) => ApexForge.sortedMatShortages(
    state,
    classId: classId,
    role: role,
    slot: slot,
    rank: rank,
  );
  static Map<EquipmentSlot, EquipmentItem> keepApexOnly(PartyHero h) =>
      ApexForge.keepApexOnly(h);

  // —— Market and flasks: moved to market_service.dart ——
  static bool canUseConsumable(GameState state) =>
      MarketService.canUseConsumable(state);
  static GameState useConsumable(GameState state, {int? heroIndex}) =>
      MarketService.useConsumable(state, heroIndex: heroIndex);
  static bool isBandageConsumable(EquipmentItem item) =>
      MarketService.isBandageConsumable(item);
  static int marketFlaskCost(GameState state) =>
      MarketService.marketFlaskCost(state);
  static EquipmentItem createMarketFlask({int salt = 0}) =>
      MarketService.createMarketFlask(salt: salt);
  static GameState buyMarketFlask(GameState state, {int salt = 0}) =>
      MarketService.buyMarketFlask(state, salt: salt);
  static GameState buyMarketFlasks(GameState state, {int count = 3}) =>
      MarketService.buyMarketFlasks(state, count: count);
  static int marketBandageCost(GameState state) =>
      MarketService.marketBandageCost(state);
  static EquipmentItem createMarketBandage({int salt = 0}) =>
      MarketService.createMarketBandage(salt: salt);
  static GameState buyMarketBandage(GameState state, {int salt = 0}) =>
      MarketService.buyMarketBandage(state, salt: salt);

  // —— Market gear listings (AH-style) ——
  static GameState ensureMarketListings(GameState state, {int? nowMs}) =>
      MarketListingsService.ensureFresh(state, nowMs: nowMs);
  static GameState buyMarketListing(GameState state, String listingId) =>
      MarketListingsService.buyListing(state, listingId);
  static GameState refreshMarketListingsPaid(GameState state, {int? nowMs}) =>
      MarketListingsService.paidRefresh(state, nowMs: nowMs);
  static int marketListingsPaidRefreshCost(GameState state) =>
      MarketListingsService.paidRefreshCost(state);
}

/// Snapshot of what AFK time awarded on a single apply.
///
/// Player contract ([ChaseContract] / offline Up next): **1 wow headline**,
/// **≤3 highlight rows**, then Up next via [ChaseContract] in the UI.
class OfflineProgressResult {
  const OfflineProgressResult({
    required this.state,
    required this.secondsApplied,
    required this.goldGained,
    required this.essenceGained,
    required this.roomsCleared,
    required this.highestFloorDelta,
    required this.bossDelta,
    this.levelsGained = 0,
    this.gearFinds = 0,
  });

  static const int maxHighlightRows = 3;

  final GameState state;
  final int secondsApplied;
  final int goldGained;
  final int essenceGained;
  final int roomsCleared;
  final int highestFloorDelta;
  final int bossDelta;
  final int levelsGained;
  final int gearFinds;

  bool get foughtWhileAway =>
      roomsCleared > 0 ||
      highestFloorDelta > 0 ||
      bossDelta > 0 ||
      levelsGained > 0;

  bool get hasSummary =>
      secondsApplied >= 45 &&
      (goldGained > 0 ||
          essenceGained > 0 ||
          roomsCleared > 0 ||
          highestFloorDelta > 0 ||
          bossDelta > 0 ||
          levelsGained > 0 ||
          gearFinds > 0);

  /// Compact hub banner — wow + away time (no number dump).
  String get headline {
    final away = formatOfflineDuration(secondsApplied);
    if (!hasSummary) return 'Away $away';
    if (bossDelta > 0) {
      return bossDelta == 1
          ? 'Boss fell · Away $away'
          : 'Bosses fell · Away $away';
    }
    if (levelsGained > 0) return 'Party grew · Away $away';
    if (foughtWhileAway) return 'Party fought · Away $away';
    return 'Sanctuary earned · Away $away';
  }

  /// Dialog lead — single feeling sentence (not a stat list).
  String get welcomeLead {
    if (bossDelta > 0) {
      return bossDelta == 1
          ? 'A boss fell while you were away — Ascend moved.'
          : '$bossDelta bosses fell while you were away — Ascend moved.';
    }
    if (levelsGained > 0) {
      return levelsGained == 1
          ? 'Your party gained a level while you were away.'
          : 'Your party gained $levelsGained levels while you were away.';
    }
    if (foughtWhileAway) {
      if (highestFloorDelta > 0) {
        return highestFloorDelta == 1
            ? 'Your party pushed a floor while you were gone.'
            : 'Your party pushed +$highestFloorDelta floors while you were gone.';
      }
      if (roomsCleared > 0) {
        return roomsCleared == 1
            ? 'Your party cleared a room while you were away.'
            : 'Your party cleared $roomsCleared rooms while you were away.';
      }
    }
    if (gearFinds > 0) {
      return gearFinds == 1
          ? 'Your party found new gear while you were away.'
          : 'Your party found gear while you were away.';
    }
    if (goldGained > 0 || essenceGained > 0) {
      return 'Sanctuary kept earning while you were away.';
    }
    return 'Welcome back.';
  }

  /// Top reward rows for the welcome dialog — bosses / levels first.
  List<(String, String)> get highlightRows {
    final ranked = <(int priority, String label, String value)>[];
    if (bossDelta > 0) {
      ranked.add((0, 'Bosses defeated', '$bossDelta'));
    }
    if (levelsGained > 0) {
      ranked.add((1, 'Party levels', '+$levelsGained'));
    }
    if (gearFinds > 0) {
      ranked.add((2, 'New gear', '+$gearFinds'));
    }
    if (highestFloorDelta > 0) {
      ranked.add((3, 'Floor progress', '+$highestFloorDelta'));
    }
    if (roomsCleared > 0) {
      ranked.add((4, 'Rooms cleared', '$roomsCleared'));
    }
    if (essenceGained > 0) {
      ranked.add((5, 'Essence earned', '+$essenceGained'));
    }
    if (goldGained > 0) {
      ranked.add((6, 'Gold earned', '+${goldGained}g'));
    }
    ranked.sort((a, b) => a.$1.compareTo(b.$1));
    final take = maxHighlightRows +
        state.metaDepth.offlineHighlightBonus.clamp(0, 3);
    return [for (final row in ranked.take(take)) (row.$2, row.$3)];
  }

  static String formatOfflineDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return s == 0 ? '${m}m' : '${m}m ${s}s';
    }
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

enum PartyUpgradeType {
  attack,
  defense,
  vitality,
  moveSpeed,
  attackSpeed,
  crit,
}

/// How much wallet gold a FORGE GOLD row spends when tapped.
enum ForgeGoldSpendMode {
  one,
  pct5,
  pct25,
  pct50,
  pct100,
}

extension ForgeGoldSpendModeLabels on ForgeGoldSpendMode {
  String get chipLabel => switch (this) {
        ForgeGoldSpendMode.one => '×1',
        ForgeGoldSpendMode.pct5 => '5%',
        ForgeGoldSpendMode.pct25 => '25%',
        ForgeGoldSpendMode.pct50 => '50%',
        ForgeGoldSpendMode.pct100 => '100%',
      };
}
