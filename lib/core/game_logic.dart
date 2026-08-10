import 'dart:convert';
import 'dart:math';

import '../models/apex_craft.dart';
import '../models/dungeon_def.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/gear_loadout.dart';
import '../models/gear_set.dart';
import '../models/equip_stat_weights.dart';
import '../models/hero.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/meta_depth.dart';
import '../models/mission.dart';
import '../models/pet.dart';
import '../models/proficiency.dart';
import '../models/stats.dart';
import '../models/vfx_quality.dart';
import '../spatial/spatial_combat.dart';
import 'dungeon_generator.dart';
import 'equipment_factory.dart';
import 'game_state.dart';
import 'keystone.dart';
import 'local_season.dart';
import 'meta_systems.dart';

class GameLogic {
  /// Injectable randomness for enemy targeting (seed in tests).
  static Random random = Random();

  static const String warBannerRelic = 'war_banner';
  static const String ironWardRelic = 'iron_ward';
  static const String phoenixEmberRelic = 'phoenix_ember';
  static const String godHandFocusRelic = 'god_hand_focus';
  static const String chamberLuckRelic = 'chamber_luck';
  static const String ironWillRelic = 'iron_will';
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
    ironWardRelic: 'Permanent +2 team defense aura.',
    phoenixEmberRelic: 'Permanent +10 max HP for every hero.',
    godHandFocusRelic: '+3 God Hand damage per tier.',
    chamberLuckRelic: '+5% loot find per tier.',
    ironWillRelic: '+1 flat damage mitigate per tier.',
  };
  static const Map<String, int> relicCosts = <String, int>{
    warBannerRelic: 6,
    ironWardRelic: 14,
    phoenixEmberRelic: 28,
    godHandFocusRelic: 36,
    chamberLuckRelic: 42,
    ironWillRelic: 48,
  };

  static const int starterPartySize = 3;

  static GameState createInitialState({
    DateTime? now,
    List<HeroSpecId>? partySpecs,
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
          equipped: _starterGearForSpec(specId),
        ),
    ];
    var state = GameState(
      heroRoster: roster,
      activeHeroIds: [for (final h in roster) h.id],
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
      state.lifetimeGoldEarned,
      state.highestDungeonCleared,
    );
    if (!unlocked && def.number > 0) {
      return state;
    }
    final layoutSeed = newLayoutSeed();
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
      enemies: createEnemyGroup(
        room,
        dungeonId: dungeonId,
        fromState: primed,
      ),
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
    final par = Keystone.parTimeMs(
      bossFloor: Keystone.bossFloorForAl(state.ascensionLevel),
      key: key,
    );
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
    final heroes = [
      for (final h in state.heroes)
        h.copyWith(
          currentHp: h.currentHp.clamp(0, state.effectiveHeroMaxHp(h)),
        ),
    ];
    var next = _clearKeystoneRun(
      state.copyWith(
        inDungeon: false,
        inGauntlet: false,
        heroes: heroes,
        lastUpdated: DateTime.now(),
      ),
    );
    if (state.inGauntlet) {
      next = recordGauntletRun(next, reachedFloor: state.currentRoom.floorNumber);
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

  static const int gauntletMinAscension = 10;

  static bool canEnterGauntlet(GameState state) =>
      state.ascensionLevel >= gauntletMinAscension && !state.inDungeon;

  /// Escalating threat: +10% enemy stats per floor beyond 1.
  static double gauntletThreatMul(int floor) =>
      1.0 + max(0, floor - 1) * 0.10;

  /// Escalating gold: +8% per floor beyond 1, plus prestige Spire Purse.
  static double gauntletGoldMul(int floor, {int prestigeBonusLevel = 0}) =>
      (1.0 + max(0, floor - 1) * 0.08) *
      (1.0 + prestigeBonusLevel * 0.04);

  static int gauntletEssenceForFloor(int floor, {required bool boss}) =>
      1 + (floor ~/ 2) + (boss ? 4 : 0);

  /// Updates best floor after a gauntlet attempt ends (wipe / leave).
  static GameState recordGauntletRun(
    GameState state, {
    required int reachedFloor,
  }) {
    final cleared = max(0, reachedFloor - 1);
    final best = max(state.metaDepth.gauntletBestFloor, cleared);
    if (best == state.metaDepth.gauntletBestFloor) {
      return syncMetaPayoffs(state);
    }
    return syncMetaPayoffs(
      state.copyWith(
        metaDepth: state.metaDepth.copyWith(gauntletBestFloor: best),
      ),
    );
  }

  /// AL10+ endless climb — Crystal Spire art, boss every 5 floors, no hub exit.
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

  /// Last mats granted by [grantBossCraftMats] (for UI toasts). Cleared on read.
  static List<String> lastCraftMatGrants = <String>[];

  static List<String> takeCraftMatGrants() {
    final out = List<String>.from(lastCraftMatGrants);
    lastCraftMatGrants = <String>[];
    return out;
  }

  /// Notices from the last [syncMetaPayoffs] (Will / Gauntlet / season). Cleared on read.
  static List<String> lastMetaPayoffNotices = <String>[];

  static List<String> takeMetaPayoffNotices() {
    final out = List<String>.from(lastMetaPayoffNotices);
    lastMetaPayoffNotices = <String>[];
    return out;
  }

  static int craftMatCount(GameState state, String matId) =>
      state.craftMaterials[matId] ?? 0;

  static bool canAffordCraftCosts(
    GameState state,
    Map<String, int> costs,
  ) {
    for (final e in costs.entries) {
      if (craftMatCount(state, e.key) < e.value) return false;
    }
    return true;
  }

  static GameState _spendCraftMats(GameState state, Map<String, int> costs) {
    final next = Map<String, int>.from(state.craftMaterials);
    for (final e in costs.entries) {
      final left = (next[e.key] ?? 0) - e.value;
      if (left <= 0) {
        next.remove(e.key);
      } else {
        next[e.key] = left;
      }
    }
    return state.copyWith(craftMaterials: next);
  }

  static GameState _addCraftMat(GameState state, String matId, [int qty = 1]) {
    final next = Map<String, int>.from(state.craftMaterials);
    next[matId] = (next[matId] ?? 0) + qty;
    return state.copyWith(craftMaterials: next);
  }

  /// Boss-only craft mat grants with soft/hard pity. Farm loops are diluted.
  static GameState grantBossCraftMats(
    GameState state, {
    required bool clearedBoss,
  }) {
    lastCraftMatGrants = <String>[];
    if (!clearedBoss) return state;

    final farm = state.dungeonMode == DungeonMode.farm;
    final weight = farm ? ApexCraft.farmPityWeight : 1.0;
    var pity = Map<String, int>.from(state.craftPity);
    var next = state;

    void bumpPity(String key, double amount) {
      final add = max(1, (amount * 10).round()); // store tenths for dilution
      pity[key] = (pity[key] ?? 0) + add;
    }

    int pityUnits(String key) => pity[key] ?? 0;

    bool rollFamily({
      required String pityKey,
      required double pBase,
      required String matId,
      required double weightMul,
    }) {
      final units = pityUnits(pityKey);
      // Convert tenths back to boss-equivalent streak.
      final streak = (units / 10).floor();
      final chance = ApexCraft.pityChance(streak, pBase: pBase) * weightMul;
      final hit = chance >= 1.0 || random.nextDouble() < chance;
      if (hit) {
        next = _addCraftMat(next, matId);
        lastCraftMatGrants.add(matId);
        pity[pityKey] = 0;
        return true;
      }
      bumpPity(pityKey, weight);
      return false;
    }

    // Zone shard
    final shardId = ApexCraft.shardIdForDungeon(state.dungeonId);
    if (ApexCraft.materialsById.containsKey(shardId)) {
      rollFamily(
        pityKey: 'pity_$shardId',
        pBase: ApexCraft.shardPBase,
        matId: shardId,
        weightMul: 1.0,
      );
    } else {
      bumpPity('pity_$shardId', weight);
    }

    // Role core — bias toward party roles
    final roleWeights = <SpecRoleTag, int>{
      for (final r in SpecRoleTag.values) r: 1,
    };
    for (final h in state.heroes) {
      roleWeights[h.spec.roleTag] = (roleWeights[h.spec.roleTag] ?? 1) + 3;
    }
    var rolePick = SpecRoleTag.meleeDps;
    var total = roleWeights.values.fold<int>(0, (s, v) => s + v);
    var roll = random.nextInt(max(1, total));
    for (final e in roleWeights.entries) {
      roll -= e.value;
      if (roll < 0) {
        rolePick = e.key;
        break;
      }
    }
    final coreId = ApexCraft.coreIdForRole(rolePick);
    rollFamily(
      pityKey: 'pity_$coreId',
      pBase: ApexCraft.corePBase,
      matId: coreId,
      weightMul: 1.0,
    );

    // Class catalyst — bias toward party classes
    final classWeights = <HeroClassId, int>{
      for (final c in HeroClassId.values) c: 1,
    };
    for (final h in state.heroes) {
      classWeights[h.spec.classId] =
          (classWeights[h.spec.classId] ?? 1) + 4;
    }
    var classPick = HeroClassId.warrior;
    total = classWeights.values.fold<int>(0, (s, v) => s + v);
    roll = random.nextInt(max(1, total));
    for (final e in classWeights.entries) {
      roll -= e.value;
      if (roll < 0) {
        classPick = e.key;
        break;
      }
    }
    final catId = ApexCraft.catalystIdForClass(classPick);
    rollFamily(
      pityKey: 'pity_$catId',
      pBase: ApexCraft.catalystPBase,
      matId: catId,
      weightMul: farm ? 0.5 : 1.0,
    );

    // Apex slag — gauntlet / crystal only
    if (state.inGauntlet || state.dungeonId == 'crystal') {
      rollFamily(
        pityKey: 'pity_apex_slag',
        pBase: ApexCraft.slagPBase,
        matId: 'apex_slag',
        weightMul: state.inGauntlet ? 1.25 : 1.0,
      );
    }

    // Keystone / challenge slight pity acceleration (still boss-gated).
    final keyCombat = Keystone.combatLevel(state);
    if (keyCombat > 0 ||
        state.challengeBossRush ||
        state.challengeNoFlask) {
      for (final key in pity.keys.toList()) {
        if ((pity[key] ?? 0) > 0) {
          pity[key] = pity[key]! + (farm ? 1 : 2);
        }
      }
    }

    return next.copyWith(craftPity: pity, lastUpdated: DateTime.now());
  }

  static bool hasApexWeaponRank1(
    GameState state,
    HeroClassId classId,
    SpecRoleTag role,
  ) {
    final id = ApexCraft.pieceId(
      classId: classId,
      role: role,
      slot: EquipmentSlot.weapon,
    );
    return _findApexItem(state, id) != null;
  }

  static EquipmentItem? _findApexItem(GameState state, String itemId) {
    for (final h in state.heroRoster) {
      for (final item in h.equipped.values) {
        if (item.id == itemId && item.isApex) return item;
      }
    }
    for (final item in state.apexVault) {
      if (item.id == itemId) return item;
    }
    for (final item in state.gearStash) {
      if (item.id == itemId && item.isApex) return item;
    }
    return null;
  }

  static bool canCraftApex(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    if (!ApexCraft.isValidPair(classId, role)) return false;
    if (!ApexCraft.craftSlots.contains(slot)) return false;
    if (_findApexItem(
          state,
          ApexCraft.pieceId(classId: classId, role: role, slot: slot),
        ) !=
        null) {
      return false;
    }
    if (slot != EquipmentSlot.weapon &&
        !hasApexWeaponRank1(state, classId, role)) {
      return false;
    }
    final costs = ApexCraft.absoluteCost(
      classId: classId,
      role: role,
      slot: slot,
      rank: 1,
    );
    return canAffordCraftCosts(state, costs);
  }

  static GameState craftApex(
    GameState state, {
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    if (!canCraftApex(
      state,
      classId: classId,
      role: role,
      slot: slot,
    )) {
      return state;
    }
    final costs = ApexCraft.absoluteCost(
      classId: classId,
      role: role,
      slot: slot,
      rank: 1,
    );
    var next = _spendCraftMats(state, costs);
    final item = ApexCraft.buildItem(
      classId: classId,
      role: role,
      slot: slot,
      rank: 1,
      ascensionLevel: state.ascensionLevel,
    );
    next = next.copyWith(
      apexVault: [...next.apexVault, item],
      lastUpdated: DateTime.now(),
    );
    return MetaSystems.evaluateAchievements(next);
  }

  static bool canUpgradeApex(GameState state, String itemId) {
    final item = _findApexItem(state, itemId);
    if (item == null || !item.isApex) return false;
    if (item.apexRank >= ApexCraft.maxRank) return false;
    final classId = HeroClassId.values.byName(item.apexClassId!);
    final role = SpecRoleTag.values.byName(item.apexRoleTag!);
    final costs = ApexCraft.upgradeDeltaCost(
      classId: classId,
      role: role,
      slot: item.slot,
      fromRank: item.apexRank,
      toRank: item.apexRank + 1,
    );
    return canAffordCraftCosts(state, costs);
  }

  static GameState upgradeApex(GameState state, String itemId) {
    if (!canUpgradeApex(state, itemId)) return state;
    final item = _findApexItem(state, itemId)!;
    final classId = HeroClassId.values.byName(item.apexClassId!);
    final role = SpecRoleTag.values.byName(item.apexRoleTag!);
    final nextRank = item.apexRank + 1;
    final costs = ApexCraft.upgradeDeltaCost(
      classId: classId,
      role: role,
      slot: item.slot,
      fromRank: item.apexRank,
      toRank: nextRank,
    );
    var next = _spendCraftMats(state, costs);
    final upgraded = ApexCraft.buildItem(
      classId: classId,
      role: role,
      slot: item.slot,
      rank: nextRank,
      ascensionLevel: state.ascensionLevel,
    ).copyWith(id: item.id);

    // Replace in vault / equipped / stash
    final vaultIdx = next.apexVault.indexWhere((e) => e.id == itemId);
    if (vaultIdx >= 0) {
      final vault = [...next.apexVault];
      vault[vaultIdx] = upgraded;
      return MetaSystems.evaluateAchievements(
        next.copyWith(apexVault: vault, lastUpdated: DateTime.now()),
      );
    }
    for (var i = 0; i < next.heroRoster.length; i++) {
      final hero = next.heroRoster[i];
      for (final e in hero.equipped.entries) {
        if (e.value.id == itemId) {
          final gear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
          gear[e.key] = upgraded;
          final roster = [...next.heroRoster];
          roster[i] = hero.copyWith(equipped: gear);
          return MetaSystems.evaluateAchievements(
            next.copyWith(heroRoster: roster, lastUpdated: DateTime.now()),
          );
        }
      }
    }
    final stashIdx = next.gearStash.indexWhere((e) => e.id == itemId);
    if (stashIdx >= 0) {
      final stash = [...next.gearStash];
      stash[stashIdx] = upgraded;
      return MetaSystems.evaluateAchievements(
        next.copyWith(gearStash: stash, lastUpdated: DateTime.now()),
      );
    }
    return state;
  }

  static GameState equipFromApexVault(
    GameState state,
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) return state;
    EquipmentItem? item;
    for (final candidate in state.apexVault) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) return state;

    final targetSlot = intoSlot ?? item.slot;
    if (!equipTargetsFor(item).contains(targetSlot)) return state;
    final heroCheck = state.heroes[heroIndex];
    if (!canHeroReceive(heroCheck, item, slot: targetSlot)) return state;

    final equippedItem =
        item.slot == targetSlot ? item : item.copyWith(slot: targetSlot);
    var next = state.copyWith(
      apexVault: state.apexVault.where((g) => g.id != itemId).toList(),
    );
    final hero = next.heroes[heroIndex];
    final prev = hero.itemIn(targetSlot);
    final gear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
    gear[targetSlot] = equippedItem;
    // 2H weapon clears off-hand into vault if apex / stash otherwise
    if (targetSlot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(equippedItem)) {
      final off = gear.remove(EquipmentSlot.offHand);
      if (off != null) {
        if (off.isApex) {
          next = next.copyWith(apexVault: [...next.apexVault, off]);
        } else {
          next = next.copyWith(gearStash: [...next.gearStash, off]);
        }
      }
    }
    var vault = List<EquipmentItem>.from(next.apexVault);
    if (prev != null) {
      if (prev.isApex) {
        vault = [...vault, prev];
      } else {
        next = next.copyWith(gearStash: [...next.gearStash, prev]);
      }
    }
    final roster = [...next.heroRoster];
    final ri = roster.indexWhere((h) => h.id == hero.id);
    if (ri < 0) return state;
    roster[ri] = hero.copyWith(equipped: gear);
    return next.copyWith(
      heroRoster: roster,
      apexVault: vault,
      lastUpdated: DateTime.now(),
    );
  }

  static Map<EquipmentSlot, EquipmentItem> _keepApexOnly(PartyHero h) => {
        for (final e in h.equipped.entries)
          if (e.value.isApex) e.key: e.value,
      };

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

  /// Bind an equipped weapon (or armor when preferred) into the permanent
  /// soulbound slot.
  static GameState bindSoulbound(GameState state, {int? heroIndex}) {
    if (state.soulboundFragments < 3) {
      return state;
    }
    final preferArmor = state.metaDepth.soulboundIsArmor;
    final preferredSlots = preferArmor
        ? <EquipmentSlot>[EquipmentSlot.chest, EquipmentSlot.cloak]
        : <EquipmentSlot>[EquipmentSlot.weapon];
    final fallbackSlots = preferArmor
        ? <EquipmentSlot>[EquipmentSlot.weapon]
        : <EquipmentSlot>[EquipmentSlot.chest, EquipmentSlot.cloak];

    var sourceIndex = heroIndex;
    EquipmentItem? piece;
    EquipmentSlot? pieceSlot;

    EquipmentItem? findOnHero(int i, List<EquipmentSlot> slots) {
      for (final slot in slots) {
        final candidate = state.heroes[i].itemIn(slot);
        if (candidate != null) return candidate;
      }
      return null;
    }

    EquipmentSlot? slotOf(PartyHero hero, EquipmentItem item) {
      for (final e in hero.equipped.entries) {
        if (e.value.id == item.id) return e.key;
      }
      return null;
    }

    if (sourceIndex != null &&
        sourceIndex >= 0 &&
        sourceIndex < state.heroes.length) {
      piece = findOnHero(sourceIndex, preferredSlots) ??
          findOnHero(sourceIndex, fallbackSlots);
      if (piece != null) {
        pieceSlot = slotOf(state.heroes[sourceIndex], piece);
      }
    }
    // Fall back to any hero if the selected one has nothing bindable.
    if (piece == null) {
      for (var i = 0; i < state.heroes.length; i++) {
        piece = findOnHero(i, preferredSlots);
        if (piece != null) {
          sourceIndex = i;
          pieceSlot = slotOf(state.heroes[i], piece);
          break;
        }
      }
    }
    if (piece == null) {
      for (var i = 0; i < state.heroes.length; i++) {
        piece = findOnHero(i, fallbackSlots);
        if (piece != null) {
          sourceIndex = i;
          pieceSlot = slotOf(state.heroes[i], piece);
          break;
        }
      }
    }
    if (piece == null || sourceIndex == null || pieceSlot == null) {
      return state;
    }
    final isArmor = pieceSlot == EquipmentSlot.chest ||
        pieceSlot == EquipmentSlot.cloak;
    final bound = piece.copyWith(
      id: 'soulbound_${piece.id}',
      name: 'Soulbound ${piece.name}',
    );
    final hero = state.heroes[sourceIndex];
    final nextHeroGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
      ..remove(pieceSlot);
    final heroes = [...state.heroes];
    heroes[sourceIndex] = hero.copyWith(equipped: nextHeroGear);
    return state.copyWith(
      heroes: heroes,
      equipped: const <EquipmentSlot, EquipmentItem>{},
      soulboundItem: bound,
      soulboundFragments: state.soulboundFragments - 3,
      metaDepth: state.metaDepth.copyWith(soulboundIsArmor: isArmor),
      lastUpdated: DateTime.now(),
    );
  }

  /// Spend soulbound fragments to refine the bound piece (+1 refine).
  static int refineSoulboundCost(int refineLevel) => 2 + (refineLevel ~/ 3);

  static GameState refineSoulbound(GameState state) {
    if (state.soulboundItem == null) return state;
    final cost = refineSoulboundCost(state.metaDepth.soulboundRefine);
    if (state.soulboundFragments < cost) return state;
    return state.copyWith(
      soulboundFragments: state.soulboundFragments - cost,
      metaDepth: state.metaDepth.copyWith(
        soulboundRefine: state.metaDepth.soulboundRefine + 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static const Map<String, String> sanctuaryNames = <String, String>{
    'gold': 'Gold Find',
    'power': 'War Altar',
    'vitality': 'Life Well',
    'xp': 'Lore Font',
  };

  static int sanctuaryCost(int level) => 15 + (level * 12);

  /// Softcapped track bonus only (no prestige). Used for "next level" labels.
  static int sanctuaryTrackBonusAt(String track, int level) {
    return switch (track) {
      'gold' => GameState.softForgePercent(level * 5, softAt: 100).round(),
      'power' => GameState.softForgePercent(level, softAt: 40).round(),
      'vitality' => GameState.softForgePercent(level * 2, softAt: 80).round(),
      'xp' => GameState.softForgePercent(level * 4, softAt: 80).round(),
      _ => 0,
    };
  }

  static String sanctuaryBonusLabel(String track, int level, {int prestige = 0}) {
    final soft = sanctuaryTrackBonusAt(track, level);
    final prestBonus = switch (track) {
      'gold' => prestige * 3,
      'xp' => prestige * 2,
      'power' || 'vitality' => prestige,
      _ => 0,
    };
    final total = soft + prestBonus;
    final unit = switch (track) {
      'gold' => '% gold find',
      'power' => ' party attack',
      'vitality' => ' max HP',
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
                  hero.currentHp + 2,
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
    final essenceGain = 25 + level;
    final md = state.metaDepth;
    final nextMd = switch (track) {
      'gold' => md.copyWith(sanctuaryGoldPrestige: md.sanctuaryGoldPrestige + 1),
      'power' =>
        md.copyWith(sanctuaryPowerPrestige: md.sanctuaryPowerPrestige + 1),
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

  static PetRarity _rollPetRarity() {
    final total = PetRarity.values.fold<int>(
      0,
      (sum, r) => sum + PetCatalog.rarityWeight(r),
    );
    var roll = random.nextInt(total);
    for (final r in PetRarity.values) {
      roll -= PetCatalog.rarityWeight(r);
      if (roll < 0) return r;
    }
    return PetRarity.common;
  }

  static int hatchPetCost(GameState state) =>
      20 + (state.ownedPets.length * 15);

  static GameState hatchPet(GameState state) {
    if (state.ownedPets.length >= state.metaDepth.basePetRosterCap) {
      return state;
    }
    final cost = hatchPetCost(state);
    if (state.essence < cost) {
      return state;
    }
    final species = PetCatalog.all[random.nextInt(PetCatalog.all.length)];
    final rarity = _rollPetRarity();
    final pet = Pet(
      id: '${species.id}_${random.nextInt(100000)}',
      name: species.name,
      attackBonus: species.baseAttack + state.ascensionLevel,
      speciesId: species.id,
      rarity: rarity,
      passive: species.passive,
      affinityDungeonId: species.affinityDungeonId,
      passivePerLevel: species.passivePerLevel,
    );
    final pets = List<Pet>.from(state.ownedPets)..add(pet);
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        essence: state.essence - cost,
        ownedPets: pets,
        activePet: state.activePet ?? pet,
        metaDepth: state.metaDepth.copyWith(
          lifetimePetHatches: state.metaDepth.lifetimePetHatches + 1,
        ),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  /// Merge two same-species pets into one higher-rarity result.
  static bool canMergePets(GameState state, String petIdA, String petIdB) {
    if (petIdA == petIdB) return false;
    Pet? a;
    Pet? b;
    for (final pet in state.ownedPets) {
      if (pet.id == petIdA) a = pet;
      if (pet.id == petIdB) b = pet;
    }
    if (a == null || b == null) return false;
    if (a.resolvedSpecies != b.resolvedSpecies) return false;
    if (a.rarity != b.rarity) return false;
    if (a.rarity == PetRarity.legendary) return false;
    return true;
  }

  /// Merge two same-species pets into one higher-rarity result.
  static GameState mergePets(GameState state, String petIdA, String petIdB) {
    if (!canMergePets(state, petIdA, petIdB)) return state;
    Pet? a;
    Pet? b;
    for (final pet in state.ownedPets) {
      if (pet.id == petIdA) a = pet;
      if (pet.id == petIdB) b = pet;
    }
    if (a == null || b == null) return state;
    final species = PetCatalog.byId(a.resolvedSpecies);
    final maxIdx = max(a.rarity.index, b.rarity.index);
    final nextIdx = min(PetRarity.values.length - 1, maxIdx + 1);
    final rarity = PetRarity.values[nextIdx];
    final bond = max(a.bondLevel, b.bondLevel);
    final level = max(a.level, b.level);
    final merged = Pet(
      id: '${a.resolvedSpecies}_${random.nextInt(100000)}',
      name: species?.name ?? a.name,
      attackBonus: max(a.attackBonus, b.attackBonus),
      level: level,
      speciesId: a.resolvedSpecies,
      rarity: rarity,
      passive: species?.passive ?? a.passive,
      affinityDungeonId: species?.affinityDungeonId ?? a.affinityDungeonId,
      bondLevel: bond,
      frame: a.frame.index >= b.frame.index ? a.frame : b.frame,
      passivePerLevel: species?.passivePerLevel ?? a.passivePerLevel,
    );
    final pets = state.ownedPets
        .where((p) => p.id != petIdA && p.id != petIdB)
        .toList()
      ..add(merged);
    final activeWasMerged =
        state.activePet?.id == petIdA || state.activePet?.id == petIdB;
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        ownedPets: pets,
        activePet: activeWasMerged ? merged : state.activePet,
        metaDepth: state.metaDepth.copyWith(
          lifetimePetMerges: state.metaDepth.lifetimePetMerges + 1,
        ),
        lastUpdated: DateTime.now(),
      ),
    );
  }

  static GameState setFavoritePetSpecies(GameState state, String speciesId) {
    if (speciesId.isEmpty) return state;
    if (!PetCatalog.all.any((s) => s.id == speciesId)) return state;
    return MetaSystems.evaluateAchievements(
      state.copyWith(
        metaDepth: state.metaDepth.copyWith(favoritePetSpecies: speciesId),
        lastUpdated: DateTime.now(),
      ),
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

  static int petFrameCost(PetFrame frame) => switch (frame) {
        PetFrame.none => 0,
        PetFrame.bronze => 5,
        PetFrame.silver => 12,
        PetFrame.gold => 22,
        PetFrame.crystal => 35,
      };

  static GameState buyPetFrame(GameState state, String petId, PetFrame frame) {
    if (frame == PetFrame.none) return state;
    final cost = petFrameCost(frame);
    if (state.essence < cost) return state;
    final idx = state.ownedPets.indexWhere((p) => p.id == petId);
    if (idx < 0) return state;
    final pet = state.ownedPets[idx];
    if (pet.frame.index >= frame.index) return state;
    final pets = List<Pet>.from(state.ownedPets);
    pets[idx] = pet.copyWith(frame: frame);
    Pet? active = state.activePet;
    if (active?.id == petId) active = pets[idx];
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: active,
      lastUpdated: DateTime.now(),
    );
  }

  static const int maxPetBondLevel = 25;
  static const int maxPetLevel = 30;

  static int bondPetCost(int bondLevel) => 5 + bondLevel * 3;

  static GameState bondPet(GameState state, String petId) {
    final idx = state.ownedPets.indexWhere((p) => p.id == petId);
    if (idx < 0) return state;
    final pet = state.ownedPets[idx];
    if (pet.bondLevel >= maxPetBondLevel) return state;
    final cost = bondPetCost(pet.bondLevel);
    if (state.essence < cost) return state;
    final pets = List<Pet>.from(state.ownedPets);
    pets[idx] = pet.copyWith(
      bondLevel: min(maxPetBondLevel, pet.bondLevel + 1),
    );
    Pet? active = state.activePet;
    if (active?.id == petId) active = pets[idx];
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: active,
      lastUpdated: DateTime.now(),
    );
  }

  static GameState setActivePet(GameState state, String petId) {
    Pet? match;
    for (final pet in state.ownedPets) {
      if (pet.id == petId) {
        match = pet;
        break;
      }
    }
    if (match == null) {
      return state;
    }
    return state.copyWith(activePet: match, lastUpdated: DateTime.now());
  }

  static int petLevelUpCost(Pet pet) => 15 + pet.level * 10;

  static GameState levelUpPet(GameState state, String petId) {
    final index = state.ownedPets.indexWhere((pet) => pet.id == petId);
    if (index < 0) {
      return state;
    }
    final pet = state.ownedPets[index];
    if (pet.level >= maxPetLevel) return state;
    final cost = petLevelUpCost(pet);
    if (state.essence < cost) {
      return state;
    }

    final leveledPet = pet.copyWith(level: min(maxPetLevel, pet.level + 1));
    final pets = List<Pet>.from(state.ownedPets)..[index] = leveledPet;
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: state.activePet?.id == petId ? leveledPet : state.activePet,
      lastUpdated: DateTime.now(),
    );
  }

  static bool canUseConsumable(GameState state) =>
      !Keystone.flasksDisabled(state) &&
      (state.heroes.any((h) => h.itemIn(EquipmentSlot.consumable) != null) ||
          state.gearStash.any((g) => g.slot == EquipmentSlot.consumable));

  static GameState useConsumable(GameState state, {int? heroIndex}) {
    if (Keystone.flasksDisabled(state)) {
      return state;
    }
    var sourceIndex = heroIndex;
    EquipmentItem? item;
    var fromStash = false;
    if (sourceIndex != null &&
        sourceIndex >= 0 &&
        sourceIndex < state.heroes.length) {
      item = state.heroes[sourceIndex].itemIn(EquipmentSlot.consumable);
    } else {
      for (var i = 0; i < state.heroes.length; i++) {
        final candidate = state.heroes[i].itemIn(EquipmentSlot.consumable);
        if (candidate != null) {
          item = candidate;
          sourceIndex = i;
          break;
        }
      }
    }
    if (item == null) {
      for (final candidate in state.gearStash) {
        if (candidate.slot == EquipmentSlot.consumable) {
          item = candidate;
          fromStash = true;
          break;
        }
      }
    }
    if (item == null) {
      return state;
    }

    var next = state;
    if (fromStash) {
      next = next.copyWith(
        gearStash: [
          for (final g in next.gearStash)
            if (g.id != item.id) g,
        ],
      );
    } else if (sourceIndex != null) {
      final hero = next.heroes[sourceIndex];
      final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
        ..remove(EquipmentSlot.consumable);
      final heroes = [...next.heroes];
      heroes[sourceIndex] = hero.copyWith(equipped: nextGear);
      next = next.copyWith(heroes: heroes);
      // Refill emptied slot from remaining stash flasks.
      EquipmentItem? refill;
      for (final g in next.gearStash) {
        if (g.slot == EquipmentSlot.consumable) {
          refill = g;
          break;
        }
      }
      if (refill != null) {
        final eq = Map<EquipmentSlot, EquipmentItem>.from(
          next.heroes[sourceIndex].equipped,
        )..[EquipmentSlot.consumable] = refill;
        final heroes2 = [...next.heroes];
        heroes2[sourceIndex] = next.heroes[sourceIndex].copyWith(equipped: eq);
        next = next.copyWith(
          heroes: heroes2,
          gearStash: [
            for (final g in next.gearStash)
              if (g.id != refill.id) g,
          ],
        );
      }
    }

    return next.copyWith(
      heroes: isBandageConsumable(item)
          ? _healLowestHero(next, ratio: 0.40)
          : [
              for (final h in next.heroes)
                if (!h.isAlive)
                  h
                else
                  h.copyWith(
                    currentHp: min(
                      next.effectiveHeroMaxHp(h),
                      h.currentHp + _flaskHealAmount(next, h),
                    ),
                  ),
            ],
    );
  }

  static bool isBandageConsumable(EquipmentItem item) =>
      item.slot == EquipmentSlot.consumable &&
      (item.iconId == 'bandage' ||
          item.name.toLowerCase().contains('bandage'));

  static List<PartyHero> _healLowestHero(GameState state, {required double ratio}) {
    var bestIndex = -1;
    var bestRatio = 2.0;
    for (var i = 0; i < state.heroes.length; i++) {
      final h = state.heroes[i];
      if (!h.isAlive) continue;
      final maxHp = state.effectiveHeroMaxHp(h);
      if (maxHp <= 0) continue;
      final r = h.currentHp / maxHp;
      if (r < bestRatio) {
        bestRatio = r;
        bestIndex = i;
      }
    }
    if (bestIndex < 0) return state.heroes;
    final target = state.heroes[bestIndex];
    final maxHp = state.effectiveHeroMaxHp(target);
    final heal = max(8, (maxHp * ratio).round());
    final heroes = [...state.heroes];
    heroes[bestIndex] = target.copyWith(
      currentHp: min(maxHp, target.currentHp + heal),
    );
    return heroes;
  }

  /// ~30% of effective max HP (min 8) — scales with level/gear instead of a flat ~13.
  static int _flaskHealAmount(GameState state, PartyHero hero) {
    final maxHp = state.effectiveHeroMaxHp(hero);
    return max(8, (maxHp * 0.30).round());
  }

  static GameState setDungeonMode(GameState state, DungeonMode mode) {
    if (state.inGauntlet) {
      // Gauntlet is endless PUSH only.
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
    if (state.inGauntlet) return false;
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

  /// Builds a 3-contract board from a shuffled type pool, scaled by progress.
  static List<Mission> createMissionBoard({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final pool = List<MissionType>.from(MissionType.values)..shuffle(rng);
    final picked = pool.take(3).toList();
    return [
      for (var i = 0; i < picked.length; i++)
        createMission(
          type: picked[i],
          ascensionLevel: ascensionLevel,
          highestDungeonCleared: highestDungeonCleared,
          highestFloorCleared: highestFloorCleared,
          hardmodeLevel: hardmodeLevel,
          random: rng,
          slot: i,
        ),
    ];
  }

  static List<Mission> createMissionBoardFor(
    GameState state, {
    Random? random,
  }) {
    return createMissionBoard(
      ascensionLevel: state.ascensionLevel,
      highestDungeonCleared: state.highestDungeonCleared,
      highestFloorCleared: state.highestFloorCleared,
      hardmodeLevel: state.hardmodeLevel,
      random: random,
    );
  }

  /// Depth score used to scale contract targets with real account progress.
  static int missionDepthScore({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
  }) {
    final floorBand = highestFloorCleared ~/ 4;
    return ascensionLevel +
        highestDungeonCleared * 2 +
        (floorBand < 0 ? 0 : floorBand) +
        hardmodeLevel;
  }

  static Mission createMission({
    required MissionType type,
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    Random? random,
    int slot = 0,
  }) {
    final rng = random ?? GameLogic.random;
    final depth = missionDepthScore(
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
    );

    // Bias toward harder contracts as the account deepens.
    final roll = rng.nextInt(100);
    final hardBias = min(25, depth * 2);
    final brutalBias = min(15, depth);
    final tier = roll < (50 - hardBias)
        ? 0
        : (roll < (85 - brutalBias) ? 1 : 2);
    final targetMul = switch (tier) {
      1 => 1.55,
      2 => 2.25,
      _ => 1.0,
    };
    final rewardMul = switch (tier) {
      1 => 1.45,
      2 => 2.1,
      _ => 1.0,
    };
    final prefix = switch (tier) {
      1 => 'Hard: ',
      2 => 'Brutal: ',
      _ => '',
    };

    int scaleTarget(int base) => max(1, (base * targetMul).round());
    int scaleGold(int base) => max(1, (base * rewardMul).round());
    int scaleEssence(int base) => max(1, (base * rewardMul).round());

    final id = '${type.name}_s${slot}_${rng.nextInt(1 << 20)}';

    return switch (type) {
      MissionType.defeatEnemies => Mission(
        id: id,
        type: type,
        title: '${prefix}Slay foes',
        target: scaleTarget(18 + depth * 6),
        progress: 0,
        goldReward: scaleGold(28 + depth * 14),
        essenceReward: scaleEssence(3 + depth),
        tier: tier,
      ),
      MissionType.clearBosses => Mission(
        id: id,
        type: type,
        title: '${prefix}Fell wardens',
        target: scaleTarget(max(2, 2 + depth ~/ 3)),
        progress: 0,
        goldReward: scaleGold(45 + depth * 20),
        essenceReward: scaleEssence(4 + depth),
        tier: tier,
      ),
      MissionType.earnGold => Mission(
        id: id,
        type: type,
        title: '${prefix}Gather gold',
        target: scaleTarget(90 + depth * 55),
        progress: 0,
        goldReward: scaleGold(22 + depth * 12),
        essenceReward: scaleEssence(2 + depth ~/ 2),
        tier: tier,
      ),
      MissionType.clearFloors => Mission(
        id: id,
        type: type,
        title: '${prefix}Clear floors',
        target: scaleTarget(5 + depth ~/ 2),
        progress: 0,
        goldReward: scaleGold(30 + depth * 15),
        essenceReward: scaleEssence(3 + depth ~/ 2),
        tier: tier,
      ),
      MissionType.defeatElites => Mission(
        id: id,
        type: type,
        title: '${prefix}Hunt elites',
        target: scaleTarget(4 + depth),
        progress: 0,
        goldReward: scaleGold(40 + depth * 16),
        essenceReward: scaleEssence(4 + depth ~/ 2),
        tier: tier,
      ),
    };
  }

  /// Picks a replacement contract, preferring a different type than [avoid].
  static Mission rollReplacementMission(
    GameState state, {
    MissionType? avoid,
    int slot = 0,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final pool = List<MissionType>.from(MissionType.values);
    if (avoid != null && pool.length > 1) {
      pool.remove(avoid);
    }
    // Prefer types not already on the board.
    final occupied = state.missions.map((m) => m.type).toSet();
    if (avoid != null) occupied.remove(avoid);
    final fresh = pool.where((t) => !occupied.contains(t)).toList();
    final type = (fresh.isNotEmpty ? fresh : pool)[rng.nextInt(
      (fresh.isNotEmpty ? fresh : pool).length,
    )];
    return createMission(
      type: type,
      ascensionLevel: state.ascensionLevel,
      highestDungeonCleared: state.highestDungeonCleared,
      highestFloorCleared: state.highestFloorCleared,
      hardmodeLevel: state.hardmodeLevel,
      random: rng,
      slot: slot,
    );
  }

  static GameState applyMissionProgress(
    GameState state, {
    int enemiesDefeated = 0,
    int bossesCleared = 0,
    int goldEarned = 0,
    int floorsCleared = 0,
    int elitesDefeated = 0,
  }) {
    if (state.missions.isEmpty) {
      return state;
    }
    if (enemiesDefeated <= 0 &&
        bossesCleared <= 0 &&
        goldEarned <= 0 &&
        floorsCleared <= 0 &&
        elitesDefeated <= 0) {
      return state;
    }

    final updated = state.missions.map((mission) {
      if (mission.isComplete) {
        return mission;
      }
      final add = switch (mission.type) {
        MissionType.defeatEnemies => enemiesDefeated,
        MissionType.clearBosses => bossesCleared,
        MissionType.earnGold => goldEarned,
        MissionType.clearFloors => floorsCleared,
        MissionType.defeatElites => elitesDefeated,
      };
      if (add <= 0) {
        return mission;
      }
      return mission.copyWith(
        progress: min(mission.target, mission.progress + add),
      );
    }).toList();

    return state.copyWith(missions: updated);
  }

  /// Claims a completed mission, grants rewards, and rolls a fresh contract.
  static GameState claimMission(GameState state, String missionId) {
    final index = state.missions.indexWhere(
      (mission) => mission.id == missionId,
    );
    if (index < 0) {
      return state;
    }
    final mission = state.missions[index];
    if (!mission.isComplete) {
      return state;
    }

    final missions = List<Mission>.from(state.missions);
    missions[index] = rollReplacementMission(
      state,
      avoid: mission.type,
      slot: index,
    );

    var nextChain = state.metaDepth.jobChainCount + 1;
    var chainBonus = 0;
    if (nextChain >= 3) {
      chainBonus = 5;
      nextChain = 0;
    }

    return state.copyWith(
      gold: state.gold + mission.goldReward,
      lifetimeGoldEarned: state.lifetimeGoldEarned + mission.goldReward,
      essence: state.essence + mission.essenceReward + chainBonus,
      missions: missions,
      metaDepth: state.metaDepth.copyWith(jobChainCount: nextChain),
      lastUpdated: DateTime.now(),
    );
  }

  /// Bosses needed this run before Ascend unlocks.
  /// AL 0 → 1 boss, AL 1 → 2 bosses, etc.
  static int bossesRequiredForAscension(int ascensionLevel) =>
      ascensionLevel + 1;

  static bool canAscend(GameState state) =>
      state.bossVictories >= bossesRequiredForAscension(state.ascensionLevel);

  /// Hub / Ascend pick: NEXT frontier zone, else deepest unlocked.
  static String recommendedDungeonId(GameState state) {
    final highest = state.highestDungeonCleared;
    final gold = state.lifetimeGoldEarned;
    for (final d in DungeonCatalog.all) {
      final unlocked = DungeonCatalog.isUnlocked(d.id, gold, highest);
      final cleared = highest >= d.number;
      if (unlocked && !cleared && d.number == highest + 1) {
        return d.id;
      }
    }
    var bestId = DungeonCatalog.all.first.id;
    var bestNum = -1;
    for (final d in DungeonCatalog.all) {
      if (!DungeonCatalog.isUnlocked(d.id, gold, highest)) continue;
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

  /// Flat DEF granted per Ascend Blessing stack.
  static const int ascendBlessingDef = 1;

  /// Flat VIT granted per Ascend Blessing stack.
  static const int ascendBlessingVit = 4;

  /// Gold-find percent granted per Ascend Blessing stack.
  static const int ascendBlessingGoldPct = 3;

  /// Applies Ascension + Sanctuary + Blessing + gear + pet gold bonuses.
  static int applyGoldGain(GameState state, int baseGold) {
    if (baseGold <= 0) {
      return baseGold;
    }
    final percent =
        state.ascensionGoldBonusPercent +
        state.sanctuaryGoldBonusPercent +
        state.ascendBlessingGoldPercent +
        state.gearGoldFindPercent +
        state.petGoldFindPercent;
    if (percent <= 0) {
      return baseGold;
    }
    return baseGold + (baseGold * percent) ~/ 100;
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

  /// Treasure / chest gold budget using full zone · HM · AL · gear pressure.
  static int treasureGoldBudget(GameState state) {
    return roomCombatBudget(
      state.currentRoom,
      dungeonId: state.dungeonId,
      hardmodeLevel: Keystone.combatLevel(state),
      ascensionLevel: state.ascensionLevel,
      gearPressure: partyGearPressure(state),
    ).gold;
  }

  /// Prestige: reset the run, keep essence/relics/sanctuary/pets/soulbound, bump AL.
  /// Returns [state] unchanged if Ascend is locked.
  static GameState ascend(GameState state, {DateTime? now}) {
    if (!canAscend(state)) {
      return state;
    }

    final nextLevel = state.ascensionLevel + 1;
    final milestoneBonus = MetaSystems.ascendMilestoneReward(
      state.ascensionLevel,
      nextLevel,
    );
    final preservedRelics = List<String>.from(state.unlockedRelics);
    final fragmentGain = 1 + (state.highestFloorCleared ~/ 3);

    final streak = state.metaDepth.noWipeAscendReady
        ? state.metaDepth.ascendStreak + 1
        : 0;
    final bestStreak = max(state.metaDepth.bestAscendStreak, streak);
    final streakEssence =
        streak > 0 && streak % 3 == 0 ? (10 + streak * 2) : 0;
    final preservedEssence = state.essence +
        ascendEssenceReward(nextLevel) +
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
      if (d.number <= state.highestDungeonCleared &&
          !trophies.contains(d.id)) {
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

    final fresh = createInitialState(now: now);
    final hmCap = min(10, 3 + nextLevel ~/ 2);

    // Preserve roster levels/XP; strip run gear but keep Apex. Combat unlocks.
    final stashApex = [
      for (final g in state.gearStash)
        if (g.isApex) g,
    ];
    final preservedVault = [
      ...state.apexVault,
      ...stashApex,
    ];
    var preservedRoster = [
      for (final h in state.heroRoster)
        h.copyWith(equipped: _keepApexOnly(h)),
    ];
    if (!preservedRoster.any((h) => h.specId == HeroSpecs.ascendUnlockSpec)) {
      final seedPool = preservedRoster.isNotEmpty
          ? preservedRoster
          : state.heroes;
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
          equipped: _starterGear(HeroRole.rogue),
          level: seedLevel,
        ),
      ];
    }
    final maxActive =
        state.metaDepth.partySlot5Unlocked ? 5 : 4;
    var preservedActive = [
      for (final id in state.activeHeroIds)
        if (preservedRoster.any((h) => h.id == id)) id,
    ];
    if (preservedActive.isEmpty) {
      preservedActive = [
        for (final h in preservedRoster.take(maxActive)) h.id,
      ];
    }

    var withMeta = fresh.copyWith(
      heroRoster: preservedRoster,
      activeHeroIds: preservedActive,
      essence: preservedEssence,
      lifetimeGoldEarned: state.lifetimeGoldEarned,
      unlockedRelics: preservedRelics,
      ascensionLevel: nextLevel,
      // Size board off post-Ascend progress (HFC resets) — not pre-Ascend depth.
      missions: createMissionBoardFor(
        state.copyWith(
          ascensionLevel: nextLevel,
          highestFloorCleared: 0,
        ),
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
      soulboundFragments: state.soulboundFragments + fragmentGain,
      soulboundItem: state.soulboundItem == null
          ? null
          : scaleSoulboundForAl(state.soulboundItem!, nextLevel),
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
      // Gear was wiped — presets would only hold dead item ids.
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
      colorblindMode: state.colorblindMode,
      uiTextScale: state.uiTextScale,
      lastDailyDate: state.lastDailyDate,
      dailyClaimed: state.dailyClaimed,
      seenChangelogVersion: state.seenChangelogVersion,
      lastUpdated: now ?? DateTime.now(),
      clearEquipped: true,
    );
    withMeta = ensureRogueHero(withMeta);
    withMeta = syncSpecUnlocks(withMeta);
    withMeta = withMeta.copyWith(
      heroes: withMeta.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: withMeta.effectiveHeroMaxHp(hero)),
          )
          .toList(),
    );
    withMeta = ensureWeeklyContract(withMeta, now: now);
    withMeta = MetaSystems.evaluateAchievements(withMeta);
    withMeta = syncMetaPayoffs(withMeta);
    // Point hub ENTER at frontier / deepest unlocked — not always Sandy.
    final recommend = recommendedDungeonId(withMeta);
    if (recommend != withMeta.dungeonId) {
      withMeta = withMeta.copyWith(dungeonId: recommend);
    }
    return withMeta;
  }

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
        equipped: _starterGear(HeroRole.rogue),
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
        next = next.copyWith(
          activeHeroIds: [...next.activeHeroIds, combat.id],
        );
      }
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
    return state.copyWith(
      activeHeroIds: next,
      lastUpdated: DateTime.now(),
    );
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
    final unlocked = <String>{
      ...state.metaDepth.unlockedSpecs,
      specId.name,
    }.toList();
    var next = state.copyWith(
      metaDepth: state.metaDepth.copyWith(unlockedSpecs: unlocked),
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
      equipped: _starterGearForSpec(def.id),
      level: rosterSeedLevel(next),
    );
    return next.copyWith(
      heroRoster: [...next.heroRoster, hero],
      lastUpdated: DateTime.now(),
    );
  }

  /// Fills empty equipment slots with class starter pieces (keeps worn gear).
  static GameState fillMissingStarterGear(GameState state) {
    var changed = false;
    final rebuilt = <PartyHero>[];
    for (final hero in state.heroRoster) {
      final starter = _starterGearForSpec(hero.specId);
      final next = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped);
      var heroChanged = false;
      final blocksOh = ClassProficiency.weaponBlocksOffHand(
        next[EquipmentSlot.weapon],
      );
      for (final entry in starter.entries) {
        if (next.containsKey(entry.key)) continue;
        // Never put a starter OH under a kept Apex (or any) 2H weapon.
        if (blocksOh && entry.key == EquipmentSlot.offHand) continue;
        next[entry.key] = entry.value.copyWith(
          id: '${entry.value.id}_fill',
        );
        heroChanged = true;
        changed = true;
      }
      rebuilt.add(heroChanged ? hero.copyWith(equipped: next) : hero);
    }
    if (!changed) return state;
    return state.copyWith(
      heroRoster: rebuilt,
      lastUpdated: DateTime.now(),
    );
  }

  /// Starter kit keyed by talent tree — armor follows [HeroSpecDef.armorTypes].
  static Map<EquipmentSlot, EquipmentItem> _starterGearForSpec(
    HeroSpecId specId,
  ) {
    final spec = HeroSpecs.def(specId);
    final kitRole = _starterKitRole(spec);
    final base = _starterGear(kitRole);
    final armorMat = preferredArmorForSpec(spec, 1);
    final matName = armorMat == null
        ? null
        : armorMat.name[0].toUpperCase() + armorMat.name.substring(1);
    final out = <EquipmentSlot, EquipmentItem>{};
    for (final e in base.entries) {
      final item = e.value;
      final id = item.id.replaceFirst(
        kitRole.name,
        spec.shortLabel.toLowerCase(),
      );
      if (armorMat != null &&
          matName != null &&
          item.slot.isArmorSlot &&
          item.armorType != null) {
        final oldMat = item.armorType!.name;
        final oldTitle =
            oldMat[0].toUpperCase() + oldMat.substring(1);
        final renamed = item.name.contains(oldTitle)
            ? item.name.replaceFirst(oldTitle, matName)
            : item.name;
        out[e.key] = item.copyWith(
          id: id,
          name: renamed,
          armorType: armorMat,
        );
      } else {
        out[e.key] = item.copyWith(id: id);
      }
    }

    // Swap illegal off-hands (e.g. Guardian Druid inheriting a warrior shield).
    final oh = out[EquipmentSlot.offHand];
    if (oh != null &&
        !ClassProficiency.canEquip(
          role: spec.gearAffinity,
          level: 1,
          item: oh,
          specId: specId,
        )) {
      if (ClassProficiency.canEquipOffHandForSpec(spec, OffHandKind.frill)) {
        out[EquipmentSlot.offHand] = EquipmentItem(
          id: 'start_${spec.shortLabel.toLowerCase()}_oh',
          name: '${spec.shortLabel} Charm',
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.common,
          offHandKind: OffHandKind.frill,
          intellectBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster ? 1 : 0,
          staminaBonus: 1,
          spiritBonus: spec.isHealer ? 1 : 0,
          spellPowerBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster ? 1 : 0,
          itemLevel: 5,
        );
      } else if (ClassProficiency.canEquipOffHandForSpec(
        spec,
        OffHandKind.weapon,
      )) {
        out[EquipmentSlot.offHand] = EquipmentItem(
          id: 'start_${spec.shortLabel.toLowerCase()}_oh',
          name: '${spec.shortLabel} Sidearm',
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.common,
          offHandKind: OffHandKind.weapon,
          weaponType: WeaponType.dagger,
          handed: WeaponHanded.oneHand,
          agilityBonus: 1,
          staminaBonus: 1,
          itemLevel: 5,
        );
      } else {
        out.remove(EquipmentSlot.offHand);
      }
    }

    // Swap illegal ranged (Holy Paladin inheriting a priest wand, etc.).
    final ranged = out[EquipmentSlot.ranged];
    if (ranged != null &&
        !ClassProficiency.canEquip(
          role: spec.gearAffinity,
          level: 1,
          item: ranged,
          specId: specId,
        )) {
      final preferWand = ClassProficiency.canEquipWeaponForSpec(
        spec,
        WeaponType.wand,
        WeaponHanded.oneHand,
        rangedSlot: true,
      );
      out[EquipmentSlot.ranged] = EquipmentItem(
        id: 'start_${spec.shortLabel.toLowerCase()}_rng',
        name: preferWand
            ? '${spec.shortLabel} Wand'
            : '${spec.shortLabel} Thrown',
        slot: EquipmentSlot.ranged,
        rarity: LootRarity.common,
        weaponType: preferWand ? WeaponType.wand : WeaponType.thrown,
        handed: WeaponHanded.oneHand,
        intellectBonus: preferWand ? 1 : 0,
        spellPowerBonus: preferWand ? 2 : 0,
        strengthBonus: preferWand ? 0 : 1,
        agilityBonus: preferWand ? 0 : 1,
        itemLevel: 5,
      );
    }

    // Swap illegal main-hand weapons.
    final weapon = out[EquipmentSlot.weapon];
    if (weapon != null &&
        !ClassProficiency.canEquip(
          role: spec.gearAffinity,
          level: 1,
          item: weapon,
          specId: specId,
        )) {
      final useStaff = ClassProficiency.canEquipWeaponForSpec(
        spec,
        WeaponType.staff,
        WeaponHanded.twoHand,
        rangedSlot: false,
      );
      final useMace = ClassProficiency.canEquipWeaponForSpec(
        spec,
        WeaponType.mace,
        WeaponHanded.oneHand,
        rangedSlot: false,
      );
      out[EquipmentSlot.weapon] = EquipmentItem(
        id: 'start_${spec.shortLabel.toLowerCase()}_wpn',
        name: useStaff
            ? '${spec.shortLabel} Staff'
            : '${spec.shortLabel} Mace',
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.common,
        weaponType: useStaff ? WeaponType.staff : WeaponType.mace,
        handed: useStaff ? WeaponHanded.twoHand : WeaponHanded.oneHand,
        intellectBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster ? 2 : 0,
        spiritBonus: spec.isHealer ? 1 : 0,
        spellPowerBonus: spec.isHealer || spec.roleTag == SpecRoleTag.caster ? 1 : 0,
        strengthBonus: useMace && !spec.isHealer ? 2 : 0,
        staminaBonus: 1,
        itemLevel: 5,
      );
      if (useStaff) {
        out.remove(EquipmentSlot.offHand);
      }
    }

    return out;
  }

  static HeroRole _starterKitRole(HeroSpecDef spec) => switch (spec.classId) {
        HeroClassId.hunter => HeroRole.rogue,
        HeroClassId.shaman => switch (spec.roleTag) {
            SpecRoleTag.meleeDps => HeroRole.rogue,
            SpecRoleTag.healer => HeroRole.healer,
            _ => HeroRole.mage, // elemental caster
          },
        HeroClassId.deathKnight => HeroRole.warrior,
        HeroClassId.paladin =>
          spec.isHealer ? HeroRole.healer : HeroRole.warrior,
        HeroClassId.warlock => HeroRole.mage,
        HeroClassId.druid => switch (spec.roleTag) {
            SpecRoleTag.tank => HeroRole.warrior,
            SpecRoleTag.healer => HeroRole.healer,
            SpecRoleTag.caster => HeroRole.mage,
            _ => HeroRole.rogue,
          },
        _ => spec.gearAffinity,
      };

  /// Heaviest armor the hero may wear at [level] (plate@40 except DK).
  static ArmorType? preferredArmorForSpec(HeroSpecDef spec, int level) {
    if (ClassProficiency.canEquipArmorForSpec(spec, level, ArmorType.plate)) {
      return ArmorType.plate;
    }
    if (spec.armorTypes.contains(ArmorType.mail)) return ArmorType.mail;
    if (spec.armorTypes.contains(ArmorType.leather)) return ArmorType.leather;
    if (spec.armorTypes.contains(ArmorType.cloth)) return ArmorType.cloth;
    return null;
  }

  static Map<EquipmentSlot, EquipmentItem> _starterGear(HeroRole role) {
    EquipmentItem piece({
      required String id,
      required String name,
      required EquipmentSlot slot,
      ArmorType? armorType,
      WeaponType? weaponType,
      WeaponHanded? handed,
      OffHandKind? offHandKind,
      int str = 0,
      int agi = 0,
      int sta = 0,
      int intel = 0,
      int spi = 0,
      int sp = 0,
      int armor = 0,
      int crit = 0,
      int aspd = 0,
      int move = 0,
      int mp5 = 0,
    }) {
      return EquipmentItem(
        id: id,
        name: name,
        slot: slot,
        rarity: LootRarity.common,
        strengthBonus: str,
        agilityBonus: agi,
        staminaBonus: sta,
        intellectBonus: intel,
        spiritBonus: spi,
        spellPowerBonus: sp,
        armorBonus: armor,
        critChanceBonus: crit,
        attackSpeedBonus: aspd,
        moveSpeedBonus: move,
        mp5Bonus: mp5,
        affinity: role.name,
        itemLevel: 5,
        armorType: armorType,
        weaponType: weaponType,
        handed: handed,
        offHandKind: offHandKind,
        iconId: slot == EquipmentSlot.consumable ? 'flask' : null,
      );
    }

    final prefix = switch (role) {
      HeroRole.warrior => 'Guard',
      HeroRole.healer => 'Soft',
      HeroRole.mage => 'Spark',
      HeroRole.rogue => 'Swift',
    };
    final armorMat = switch (role) {
      HeroRole.warrior => ArmorType.mail,
      HeroRole.rogue => ArmorType.leather,
      HeroRole.healer || HeroRole.mage => ArmorType.cloth,
    };
    final matName = armorMat.name[0].toUpperCase() + armorMat.name.substring(1);

    // Starter budget: modest — primaries mainly on weapon/chest.
    final p = switch (role) {
      HeroRole.warrior => (
          str: 1,
          agi: 0,
          sta: 1,
          intel: 0,
          spi: 0,
          sp: 0,
        ),
      HeroRole.rogue => (
          str: 0,
          agi: 1,
          sta: 1,
          intel: 0,
          spi: 0,
          sp: 0,
        ),
      HeroRole.healer => (
          str: 0,
          agi: 0,
          sta: 1,
          intel: 1,
          spi: 1,
          sp: 1,
        ),
      HeroRole.mage => (
          str: 0,
          agi: 0,
          sta: 1,
          intel: 1,
          spi: 1,
          sp: 1,
        ),
    };

    EquipmentItem armorPiece(EquipmentSlot slot, String noun, {int armorPts = 1}) {
      final isCore = slot == EquipmentSlot.chest ||
          slot == EquipmentSlot.legs ||
          slot == EquipmentSlot.head;
      return piece(
          id: 'start_${role.name}_${slot.name}',
          name: '$prefix $matName $noun',
          slot: slot,
          armorType: armorMat,
          str: isCore ? p.str : 0,
          agi: isCore ? p.agi : 0,
          sta: isCore ? p.sta : (slot == EquipmentSlot.boots ? 1 : 0),
          intel: isCore ? p.intel : 0,
          spi: isCore ? p.spi : 0,
          sp: slot == EquipmentSlot.chest ? p.sp : 0,
          armor: role == HeroRole.warrior && isCore ? armorPts + 1 : armorPts,
          move: slot == EquipmentSlot.boots ? 2 : 0,
          aspd: slot == EquipmentSlot.hands || slot == EquipmentSlot.boots
              ? 1
              : 0,
          mp5: armorMat == ArmorType.cloth ? 1 : 0,
        );
    }

    EquipmentItem jewelry(EquipmentSlot slot, String noun) => piece(
          id: 'start_${role.name}_${slot.name}',
          name: '$prefix $noun',
          slot: slot,
          str: slot == EquipmentSlot.neck ? p.str : 0,
          agi: slot == EquipmentSlot.neck ? p.agi : 0,
          sta: 0,
          intel: slot == EquipmentSlot.neck ? p.intel : 0,
          spi: slot == EquipmentSlot.neck ? p.spi : 0,
          sp: p.sp > 0 && slot == EquipmentSlot.neck ? 1 : 0,
          crit: role == HeroRole.rogue && slot == EquipmentSlot.ring ? 1 : 0,
        );

    final weapon = switch (role) {
      HeroRole.warrior => piece(
          id: 'start_war_wpn',
          name: '$prefix 1H Mace',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.mace,
          handed: WeaponHanded.oneHand,
          str: 3,
          sta: 2,
          aspd: 1,
        ),
      HeroRole.healer => piece(
          id: 'start_pri_wpn',
          name: '$prefix 1H Mace',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.mace,
          handed: WeaponHanded.oneHand,
          intel: 2,
          spi: 1,
          sp: 1,
          mp5: 1,
        ),
      HeroRole.mage => piece(
          id: 'start_mag_wpn',
          name: '$prefix 1H Sword',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.sword,
          handed: WeaponHanded.oneHand,
          intel: 2,
          spi: 1,
          sp: 1,
        ),
      HeroRole.rogue => piece(
          id: 'start_rog_wpn',
          name: '$prefix Dagger',
          slot: EquipmentSlot.weapon,
          weaponType: WeaponType.dagger,
          handed: WeaponHanded.oneHand,
          agi: 3,
          str: 1,
          crit: 1,
          aspd: 1,
        ),
    };

    final offHand = switch (role) {
      HeroRole.warrior => piece(
          id: 'start_war_oh',
          name: '$prefix Tower Shield',
          slot: EquipmentSlot.offHand,
          offHandKind: OffHandKind.shield,
          str: 1,
          sta: 2,
          armor: 3,
        ),
      HeroRole.healer || HeroRole.mage => piece(
          id: 'start_${role.name}_oh',
          name: '$prefix Tome',
          slot: EquipmentSlot.offHand,
          offHandKind: OffHandKind.frill,
          intel: 1,
          spi: 1,
          sp: 2,
          mp5: 1,
        ),
      HeroRole.rogue => piece(
          id: 'start_rog_oh',
          name: '$prefix Off-hand Dagger',
          slot: EquipmentSlot.offHand,
          offHandKind: OffHandKind.weapon,
          weaponType: WeaponType.dagger,
          handed: WeaponHanded.oneHand,
          agi: 2,
          crit: 1,
          aspd: 1,
        ),
    };

    final ranged = switch (role) {
      HeroRole.healer || HeroRole.mage => piece(
          id: 'start_${role.name}_rng',
          name: '$prefix Wand',
          slot: EquipmentSlot.ranged,
          weaponType: WeaponType.wand,
          handed: WeaponHanded.oneHand,
          intel: 1,
          sp: 2,
        ),
      HeroRole.warrior => piece(
          id: 'start_war_rng',
          name: '$prefix Thrown',
          slot: EquipmentSlot.ranged,
          weaponType: WeaponType.thrown,
          handed: WeaponHanded.oneHand,
          str: 1,
          agi: 1,
        ),
      HeroRole.rogue => piece(
          id: 'start_rog_rng',
          name: '$prefix Bow',
          slot: EquipmentSlot.ranged,
          weaponType: WeaponType.bow,
          handed: WeaponHanded.twoHand,
          agi: 2,
        ),
    };

    final flask = piece(
      id: 'start_${role.name}_flask',
      name: 'Healing Flask',
      slot: EquipmentSlot.consumable,
      sta: 1,
    );

    return {
      EquipmentSlot.weapon: weapon,
      EquipmentSlot.offHand: offHand,
      EquipmentSlot.ranged: ranged,
      EquipmentSlot.head: armorPiece(EquipmentSlot.head, 'Helm', armorPts: 2),
      EquipmentSlot.shoulder:
          armorPiece(EquipmentSlot.shoulder, 'Pauldrons', armorPts: 1),
      EquipmentSlot.chest:
          armorPiece(EquipmentSlot.chest, 'Chestguard', armorPts: 3),
      EquipmentSlot.waist: armorPiece(EquipmentSlot.waist, 'Belt'),
      EquipmentSlot.legs: armorPiece(EquipmentSlot.legs, 'Legguards', armorPts: 2),
      EquipmentSlot.boots: armorPiece(EquipmentSlot.boots, 'Boots'),
      EquipmentSlot.wrist: armorPiece(EquipmentSlot.wrist, 'Bracers'),
      EquipmentSlot.hands: armorPiece(EquipmentSlot.hands, 'Gloves'),
      EquipmentSlot.cloak: jewelry(EquipmentSlot.cloak, 'Cloak'),
      EquipmentSlot.neck: jewelry(EquipmentSlot.neck, 'Amulet'),
      EquipmentSlot.ring: jewelry(EquipmentSlot.ring, 'Ring'),
      EquipmentSlot.ring2: jewelry(EquipmentSlot.ring2, 'Band'),
      EquipmentSlot.trinket: jewelry(EquipmentSlot.trinket, 'Trinket'),
      EquipmentSlot.trinket2: jewelry(EquipmentSlot.trinket2, 'Charm'),
      EquipmentSlot.consumable: flask,
    };
  }

  static bool isBossBattle(int battleNumber, {int ascensionLevel = 0}) =>
      battleNumber == DungeonGenerator.bossFloorFor(ascensionLevel);

  static bool isEliteBattle(int battleNumber) {
    final room = DungeonGenerator.generateFloor(max(1, battleNumber)).first;
    return room.type == RoomType.elite || battleNumber % 5 == 3;
  }

  /// Combat budget for a room: total effective attack/HP/gold the enemy
  /// group should add up to. Tuned so fresh parties barely scrape early floors.
  ///
  /// Mid-game pressure: [ascensionLevel] and [gearPressure] scale threat so
  /// filling empty slots does not trivialize the same floors.
  static ({int attack, int hp, int gold}) roomCombatBudget(
    DungeonRoom room, {
    String? dungeonId,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
  }) {
    final level = room.globalBattleNumber;
    final isBoss = room.type == RoomType.boss;
    final isElite = room.type == RoomType.elite;
    final diff = DungeonGenerator.getDifficultyMultiplier(room.type);
    final zone = DungeonCatalog.byId(dungeonId ?? 'sandy').number;
    // Bosses use a gentler zone ramp — late zones were spike-wiping.
    final zoneMult = 1.0 + zone * (isBoss ? 0.22 : 0.28);
    final hm = hardmodeLevel.clamp(0, Keystone.maxLevel);
    // Key 20 ≈ old HM+10 (10× threat). See [Keystone.threatMul].
    final hmThreat = Keystone.threatMul(hm);
    final hmGold = Keystone.goldMul(hm);
    final alThreatRaw = 1.0 + ascensionLevel.clamp(0, 40) * 0.08;
    // Fresh post-ascend (gear wiped) — soften AL threat until kit rebuilds.
    final freshAscendEase =
        gearPressure <= 1.08 && ascensionLevel > 0 ? 0.65 : 1.0;
    final alThreat = alThreatRaw * freshAscendEase;
    final gpRaw = gearPressure.clamp(1.0, 2.5);
    // Fresh early floors: don't let gear-pressure spike packs before F5.
    // AL0 boss: keep mild pressure so farmed loot helps heroes more than enemies.
    final gp = switch ((level, ascensionLevel)) {
      (final l, _) when l <= 4 => 1.0 + (gpRaw - 1.0) * (0.25 + l * 0.12),
      (5, 0) => 1.0 + (gpRaw - 1.0) * 0.4,
      _ => gpRaw,
    };
    final threat = hmThreat * alThreat;
    // Early attrition ramp: F1–F3 clearable for fresh parties; first AL0 boss
    // must be beatable after a short Sandy farm (LIGHT), not MID-only.
    final earlyEase = switch (level) {
      1 => 0.94,
      2 => 0.90,
      3 => 0.86,
      4 => 0.92,
      5 when ascensionLevel == 0 => 0.72,
      5 || 6 when freshAscendEase < 1.0 => 0.94,
      _ => 1.0,
    };

    // Attrition curve: packs hurt over time, not via one-shots.
    // Extra quadratic after F2 so geared mid-run parties still feel pressure.
    final curve = level + ((level * level) ~/ 12);
    final midFloor = max(0, level - 2);
    final midHpBump = midFloor * midFloor * 12;
    // First Sandy boss: softer flats so AUTO-equipped F1–4 loot is enough.
    final firstSandyBoss = isBoss && ascensionLevel == 0 && level <= 5;
    final bossFlatHp = firstSandyBoss ? 280 : (isBoss ? 600 : 0);
    final bossFlatAtk = firstSandyBoss ? 10 : (isBoss ? 22 : 0);
    final attack = ((((42 + bossFlatAtk + (isElite ? 10 : 0)) +
                    curve * 5.5) *
                diff *
                zoneMult *
                earlyEase) *
            threat *
            (1.0 + (gp - 1.0) * 0.7))
        .round();
    final hp = ((((380 +
                        level * 62 +
                        (level ~/ 2) * 55 +
                        midHpBump) +
                    bossFlatHp +
                    (isElite ? 180 : 0)) *
                diff *
                zoneMult *
                earlyEase) *
            threat *
            gp)
        .round();
    final gold =
        (((12 + level * 2.5) *
                    (isBoss ? 3.4 : 1.0) *
                    diff *
                    zoneMult *
                    (1.0 + ascensionLevel.clamp(0, 20) * 0.025)) *
                hmGold)
            .round();

    return (attack: attack, hp: hp, gold: gold);
  }

  /// How much equipped loot should pull dungeon threat.
  /// Starters barely register; ~8–12 real upgrades is where pressure bites.
  static double partyGearPressure(GameState state) {
    var meaningful = 0;
    var primaryScore = 0;
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        // Ignore class starters / fill-ins — only real drops pull threat.
        if (item.id.startsWith('start_') || item.id.contains('_fill')) {
          continue;
        }
        // Apex kept through Ascend must not cancel fresh-AL threat ease.
        if (item.isApex) continue;
        final primary = item.strengthBonus +
            item.agilityBonus +
            item.staminaBonus +
            item.intellectBonus +
            item.spiritBonus +
            item.spellPowerBonus;
        if (primary >= 4 || item.rarity.index >= LootRarity.uncommon.index) {
          meaningful++;
          primaryScore += primary;
        }
      }
    }
    // ~4 pieces ≈ mild; ~10 pieces ≈ +70–100% HP threat.
    final pieceRamp = max(0, meaningful - 2) * 0.085;
    final scoreRamp = (primaryScore * 0.0028).clamp(0.0, 1.15);
    return (1.0 + pieceRamp + scoreRamp).clamp(1.0, 2.85);
  }

  /// XP required to go from [level] → level+1.
  static int xpPoolForLevel(int level) {
    final L = max(1, level);
    return 24 + (L * 16) + ((L * L) ~/ 2);
  }

  /// Combat XP granted for defeating one enemy.
  static int xpForEnemy(EnemyUnit enemy) {
    var xp = 5 + enemy.level + (enemy.level ~/ 3);
    xp += switch (enemy.role) {
      EnemyRole.boss => 28,
      EnemyRole.elite => 10,
      EnemyRole.normal => 0,
    };
    xp += switch (enemy.archetype) {
      EnemyArchetype.tank => 3,
      EnemyArchetype.glass => 2,
      EnemyArchetype.ranged => 2,
      EnemyArchetype.support => 1,
      EnemyArchetype.swarm => 0,
      EnemyArchetype.brute => 1,
    };
    return xp;
  }

  /// Awards [amount] XP to every hero (living or downed); levels up when pools fill.
  /// Heroes 3+ levels behind party mean get a soft catch-up bonus.
  static GameState awardPartyXp(GameState state, int amount) {
    if (amount <= 0) return state;
    final boosted = amount +
        (amount *
                (state.sanctuaryXpBonusPercent + state.petXpFindPercent)) ~/
            100;
    final meanLevel = state.heroes.isEmpty
        ? 1
        : max(
            1,
            state.heroes.fold<int>(0, (s, h) => s + h.level) ~/
                state.heroes.length,
          );
    final heroes = <PartyHero>[];
    var leveled = false;
    for (final hero in state.heroes) {
      final gain = hero.level + 3 < meanLevel
          ? (boosted * 1.4).round()
          : boosted;
      var level = hero.level;
      var xp = hero.xp + gain;
      var hp = hero.currentHp;
      var guard = 0;
      while (guard < 40) {
        guard++;
        final need = xpPoolForLevel(level);
        if (xp < need) break;
        xp -= need;
        level += 1;
        leveled = true;
        final grown = hero.copyWith(level: level);
        if (hero.isAlive) {
          hp = min(
            state.effectiveHeroMaxHp(grown),
            hp + 5 + state.vitalityBonus ~/ 4,
          );
        }
      }
      heroes.add(hero.copyWith(level: level, xp: xp, currentHp: hp));
    }
    final next = state.copyWith(heroes: heroes, lastUpdated: DateTime.now());
    return leveled ? next : next;
  }

  static GameState awardEnemyKillXp(GameState state, EnemyUnit enemy) =>
      awardPartyXp(state, xpForEnemy(enemy));

  /// Builds the enemy group for a room. Treasure rooms have no enemies.
  /// [threatScale] < 1 softens packs (used for AFK spatial sim).
  /// Pass [fromState] to apply AL + gear-pressure scaling automatically.
  static List<EnemyUnit> createEnemyGroup(
    DungeonRoom room, {
    String? dungeonId,
    bool bossRush = false,
    double threatScale = 1.0,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
    GameState? fromState,
  }) {
    if (room.type == RoomType.treasure || room.enemyCount == 0) {
      return <EnemyUnit>[];
    }

    final id = dungeonId ?? fromState?.dungeonId ?? 'sandy';
    final hm = fromState != null
        ? Keystone.combatLevel(fromState, fallback: hardmodeLevel)
        : hardmodeLevel.clamp(0, Keystone.maxLevel);
    final al = fromState?.ascensionLevel ?? ascensionLevel;
    final affixes = fromState != null && fromState.keystoneRunActive
        ? fromState.keystoneRunAffixes
        : const <String>[];
    final rush = (fromState?.challengeBossRush ?? bossRush) ||
        affixes.contains('boss_rush');
    final glassWeek = affixes.contains('glass');
    final swarmWeek = affixes.contains('swarm');
    final eliteWeek = affixes.contains('elite');
    final fortuneWeek = affixes.contains('fortune');
    final ironWeek = affixes.contains('iron');
    final fortified = affixes.contains('fortified');
    final tyrannical = affixes.contains('tyrannical');
    final level = room.globalBattleNumber;
    final gpRaw =
        (fromState != null ? partyGearPressure(fromState) : gearPressure)
            .clamp(1.0, 2.5);
    final gp = switch ((level, al)) {
      (final l, _) when l <= 4 => 1.0 + (gpRaw - 1.0) * (0.25 + l * 0.12),
      (5, 0) => 1.0 + (gpRaw - 1.0) * 0.4,
      _ => gpRaw,
    };
    var budget = roomCombatBudget(
      room,
      dungeonId: id,
      hardmodeLevel: hm,
      ascensionLevel: al,
      gearPressure: fromState != null ? partyGearPressure(fromState) : gearPressure,
    );
    // Keystone affixes (Mythic+-style) — only during an active key run.
    if (eliteWeek) {
      budget = (
        attack: (budget.attack * 1.15).round(),
        hp: (budget.hp * 1.2).round(),
        gold: (budget.gold * 1.1).round(),
      );
    }
    if (ironWeek) {
      budget = (
        attack: (budget.attack * 1.1).round(),
        hp: (budget.hp * 1.25).round(),
        gold: (budget.gold * 1.2).round(),
      );
    }
    if (fortuneWeek) {
      budget = (
        attack: budget.attack,
        hp: budget.hp,
        gold: (budget.gold * 1.15).round(),
      );
    }
    final isBossRoomEarly = room.type == RoomType.boss;
    if (fortified && !isBossRoomEarly) {
      budget = (
        attack: (budget.attack * 1.22).round(),
        hp: (budget.hp * 1.28).round(),
        gold: budget.gold,
      );
    }
    if (tyrannical && isBossRoomEarly) {
      budget = (
        attack: (budget.attack * 1.32).round(),
        hp: (budget.hp * 1.4).round(),
        gold: (budget.gold * 1.1).round(),
      );
    }
    // Key densifies packs; Swarm multiplies count before key density.
    final baseCount = max(
      1,
      (room.enemyCount * (swarmWeek ? 1.35 : 1.0)).round(),
    );
    final count = min(
      80,
      max(1, (baseCount * Keystone.densityMul(hm)).round()),
    );
    // Full density keep: each body still carries HM-scaled HP/ATK (not diluted).
    final density = count / baseCount;
    var packAttack = (budget.attack * density).round();
    var packHp = (budget.hp * density).round();
    var packGold = (budget.gold * (1.0 + (density - 1.0) * 0.25)).round();
    // 5-man parties hit harder — scale threat so early floors stay fair.
    final partySize = fromState?.heroes.length ?? 4;
    if (partySize >= 5) {
      packAttack = (packAttack * 1.12).round();
      packHp = (packHp * 1.18).round();
    }
    if (fromState?.inGauntlet ?? false) {
      final threat = gauntletThreatMul(room.floorNumber);
      packAttack = max(1, (packAttack * threat).round());
      packHp = max(1, (packHp * threat).round());
      // Gold mul applied once on clear via goldGain — not here.
    }
    final dungeon = DungeonCatalog.byId(id);
    final bossName = dungeon.bossName;
    final zone = dungeon.number;
    final rng = Random(level * 9173 + id.hashCode + room.type.index * 41);
    final isBossRoom = isBossRoomEarly;
    final pickType = eliteWeek && !isBossRoom ? RoomType.elite : room.type;

    final archetypes = <EnemyArchetype>[
      for (var i = 0; i < count; i++)
        rush && !(isBossRoom && i == 0)
            ? (i == 0
                ? EnemyArchetype.tank
                : _pickArchetype(RoomType.elite, isBossUnit: false, rng: rng))
            : _pickArchetype(
                pickType,
                isBossUnit: isBossRoom && i == 0,
                rng: rng,
              ),
    ];

    // Weight shares by archetype (tanks eat HP budget, glass eats ATK).
    final rawShares = <double>[
      for (final a in archetypes) _archetypeBudgetWeight(a),
    ];
    if (room.type == RoomType.boss && rawShares.isNotEmpty) {
      // AL0 first boss: less of the pack budget locked in the boss body.
      // Mid/late zones: soften the 2.4× spike that wiped AL3–4 parties.
      final bossShare = (al == 0 && level <= 5)
          ? 1.55
          : (zone >= 3 ? 2.05 : 2.4);
      rawShares[0] *= bossShare;
    }
    final shareSum = rawShares.fold<double>(0, (s, v) => s + v);
    final shares = rawShares.map((w) => w / shareSum).toList();

    final group = <EnemyUnit>[];
    var hpLeft = packHp;
    var attackLeft = packAttack;
    var goldLeft = packGold;

    // Front-load threat: early indices (first chambers) eat more of the budget
    // so gated maps still hurt before the whole pack wakes.
    final frontWeights = <double>[
      for (var i = 0; i < count; i++)
        shares[i] * (1.55 - (i / count) * 0.9),
    ];
    final frontSum = frontWeights.fold<double>(0, (s, v) => s + v);
    final adjShares = frontWeights.map((w) => w / frontSum).toList();

    // Absolute floor so a single woken mob is never free.
    // Early floors ease the floor so fresh parties aren't deleted by min-stats.
    final earlyMinEase = switch (level) {
      1 => 0.52,
      2 => 0.60,
      3 => 0.68,
      4 => 0.80,
      5 when al == 0 => 0.78,
      _ => 1.0,
    };
    final minHp = max(
      (55 * earlyMinEase).round().clamp(28, 110),
      ((90 + level * 42 + (isBossRoom ? 140 : 0)) *
              (0.75 + gp * 0.25) *
              earlyMinEase)
          .round(),
    );
    final minAtk = max(
      (12 * earlyMinEase).round().clamp(6, 28),
      ((24 + level * 8 + (isBossRoom ? 12 : 0)) *
              (0.85 + (gp - 1.0) * 0.4) *
              earlyMinEase)
          .round(),
    );

    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final archetype = archetypes[i];
      final skew = _archetypeStatSkew(archetype);
      final baseHp = isLast
          ? hpLeft
          : max(1, (packHp * adjShares[i]).round());
      final baseAtk = isLast
          ? max(1, attackLeft)
          : max(1, (packAttack * adjShares[i]).round());
      final gold = isLast
          ? max(0, goldLeft)
          : (packGold * adjShares[i]).round();
      hpLeft -= baseHp;
      attackLeft -= baseAtk;
      goldLeft -= gold;

      // Boss Rush: every non-boss pack fights like an elite pull.
      final rushMult = rush && !(isBossRoom && i == 0) ? 1.6 : 1.0;
      final hpRaw = max(
        (minHp * threatScale).round(),
        (baseHp * skew.hp * rushMult * threatScale).round(),
      );
      final atkRaw = max(
        (minAtk * threatScale).round(),
        (baseAtk * skew.atk * rushMult * threatScale).round(),
      );
      final hp = glassWeek ? max(1, (hpRaw * 0.75).round()) : hpRaw;
      final attack = glassWeek ? max(1, (atkRaw * 1.2).round()) : atkRaw;
      // DEF scales hard so fights aren't melted by raw ATK.
      final partyLevel = max(1, level);
      final isBossUnit = isBossRoom && i == 0;
      final role = isBossUnit
          ? EnemyRole.boss
          : (rush ||
                  eliteWeek ||
                  room.type == RoomType.boss ||
                  room.type == RoomType.elite)
          ? EnemyRole.elite
          : EnemyRole.normal;
      final defense = ((skew.def +
                  (partyLevel ~/ 3) +
                  (isBossUnit ? 6 : 0) +
                  (role == EnemyRole.elite ? 2 : 0) +
                  (rush && !isBossUnit ? 2 : 0)) *
              (0.7 + gp * 0.3))
          .round();

      final namingType = (rush && !isBossUnit) || (eliteWeek && !isBossUnit)
          ? RoomType.elite
          : room.type;

      group.add(
        EnemyUnit(
          name: _enemyNameFor(
            namingType,
            isBossUnit: isBossUnit,
            bossName: bossName,
            archetype: archetype,
            dungeonId: id,
            index: i,
          ),
          level: level,
          currentHp: hp,
          stats: Stats.enemy(attack: attack, defense: defense, maxHp: hp),
          rewardGold: rush ? (gold * 3) ~/ 2 : gold,
          role: role,
          archetype: archetype,
        ),
      );
    }

    return group;
  }

  static EnemyArchetype _pickArchetype(
    RoomType type, {
    required bool isBossUnit,
    required Random rng,
  }) {
    if (isBossUnit) return EnemyArchetype.tank;
    if (type == RoomType.elite) {
      return switch (rng.nextInt(5)) {
        0 => EnemyArchetype.tank,
        1 => EnemyArchetype.ranged,
        2 => EnemyArchetype.glass,
        3 => EnemyArchetype.support,
        _ => EnemyArchetype.brute,
      };
    }
    return switch (rng.nextInt(12)) {
      0 || 1 => EnemyArchetype.swarm,
      2 || 3 => EnemyArchetype.brute,
      4 || 5 => EnemyArchetype.tank,
      6 || 7 => EnemyArchetype.ranged,
      8 || 9 => EnemyArchetype.glass,
      _ => EnemyArchetype.support,
    };
  }

  static double _archetypeBudgetWeight(EnemyArchetype a) => switch (a) {
    EnemyArchetype.swarm => 0.55,
    EnemyArchetype.brute => 1.0,
    EnemyArchetype.tank => 1.45,
    EnemyArchetype.ranged => 0.85,
    EnemyArchetype.glass => 0.65,
    EnemyArchetype.support => 0.7,
  };

  static ({double hp, double atk, int def}) _archetypeStatSkew(
    EnemyArchetype a,
  ) => switch (a) {
    EnemyArchetype.swarm => (hp: 0.7, atk: 0.95, def: 1),
    EnemyArchetype.brute => (hp: 1.15, atk: 1.15, def: 2),
    EnemyArchetype.tank => (hp: 1.7, atk: 0.8, def: 7),
    EnemyArchetype.ranged => (hp: 0.85, atk: 1.25, def: 2),
    EnemyArchetype.glass => (hp: 0.55, atk: 1.55, def: 0),
    EnemyArchetype.support => (hp: 0.9, atk: 0.9, def: 2),
  };

  static String _enemyNameFor(
    RoomType type, {
    required bool isBossUnit,
    required String bossName,
    required EnemyArchetype archetype,
    required String dungeonId,
    required int index,
  }) {
    if (isBossUnit) {
      return bossName;
    }
    if (type == RoomType.elite) {
      return switch (archetype) {
        EnemyArchetype.tank => 'Bulwark Golem',
        EnemyArchetype.ranged => 'Hex Cultist',
        EnemyArchetype.glass => 'Blood Stalker',
        EnemyArchetype.support => 'Rift Adept',
        EnemyArchetype.swarm => 'Pack Alpha',
        EnemyArchetype.brute => 'Elite Brute',
      };
    }
    if (type == RoomType.boss) {
      return switch (archetype) {
        EnemyArchetype.ranged => 'Warden Archer',
        EnemyArchetype.tank => 'Warden Shield',
        EnemyArchetype.support => 'Warden Adept',
        EnemyArchetype.glass => 'Warden Blade',
        EnemyArchetype.swarm => 'Warden Pack',
        EnemyArchetype.brute => 'Warden Guard',
      };
    }
    return _zoneArchetypeName(dungeonId, archetype, index);
  }

  static String _zoneArchetypeName(
    String dungeonId,
    EnemyArchetype archetype,
    int index,
  ) {
    final table = switch (dungeonId) {
      'sandy' => const {
        EnemyArchetype.swarm: ['Cave Slime', 'Sand Mite', 'Drip Ooze'],
        EnemyArchetype.brute: ['Cave Brute', 'Rock Crab'],
        EnemyArchetype.tank: ['Shellback', 'Stone Maw'],
        EnemyArchetype.ranged: ['Spit Bat', 'Cavern Spitter'],
        EnemyArchetype.glass: ['Needle Rat', 'Glass Skitter'],
        EnemyArchetype.support: ['Mire Shaman', 'Glow Cultist'],
      },
      'goblin' => const {
        EnemyArchetype.swarm: ['Goblin Scrapper', 'Sneak Rat', 'Pest'],
        EnemyArchetype.brute: ['Goblin Thug', 'Clubber'],
        EnemyArchetype.tank: ['Hideout Guard', 'Scrap Shield'],
        EnemyArchetype.ranged: ['Goblin Slinger', 'Dart Rascal'],
        EnemyArchetype.glass: ['Cutthroat', 'Knife Kin'],
        EnemyArchetype.support: ['Hex Witch', 'Totem Caller'],
      },
      'king' => const {
        EnemyArchetype.swarm: ['Fort Rat', 'Drill Bat'],
        EnemyArchetype.brute: ['Fort Sentry', 'Hall Guard'],
        EnemyArchetype.tank: ['Iron Ward', 'Gate Knight'],
        EnemyArchetype.ranged: ['Crossbowman', 'Tower Archer'],
        EnemyArchetype.glass: ['Royal Assassin', 'Blade Page'],
        EnemyArchetype.support: ['Court Mage', 'Banner Cleric'],
      },
      'underworld' => const {
        EnemyArchetype.swarm: ['Imp Swarm', 'Ash Tick'],
        EnemyArchetype.brute: ['Underworld Imp', 'Bone Brute'],
        EnemyArchetype.tank: ['Obsidian Golem', 'Pit Guard'],
        EnemyArchetype.ranged: ['Soul Spitter', 'Hex Spider'],
        EnemyArchetype.glass: ['Shade Stalker', 'Wisp Blade'],
        EnemyArchetype.support: ['Cult Chanter', 'Rift Adept'],
      },
      'dead' => const {
        EnemyArchetype.swarm: ['Risen Husk', 'Bone Swarm'],
        EnemyArchetype.brute: ['Grave Knight', 'Crypt Brute'],
        EnemyArchetype.tank: ['Tomb Shield', 'Ossuary Guard'],
        EnemyArchetype.ranged: ['Wailing Ghost', 'Bone Archer'],
        EnemyArchetype.glass: ['Specter Blade', 'Pale Reaper'],
        EnemyArchetype.support: ['Necro Acolyte', 'Death Chanter'],
      },
      'hell' => const {
        EnemyArchetype.swarm: ['Hellspawn', 'Cinder Rat'],
        EnemyArchetype.brute: ['Infernal Brute', 'Flame Guard'],
        EnemyArchetype.tank: ['Molten Golem', 'Ash Colossus'],
        EnemyArchetype.ranged: ['Fire Cultist', 'Ember Archer'],
        EnemyArchetype.glass: ['Flame Assassin', 'Cinder Blade'],
        EnemyArchetype.support: ['Hell Chanter', 'Rift Priest'],
      },
      'crystal' => const {
        EnemyArchetype.swarm: ['Frost Wisp', 'Rime Bat'],
        EnemyArchetype.brute: ['Glacial Brute', 'Shard Brawler'],
        EnemyArchetype.tank: ['Crystal Golem', 'Frozen Bulwark'],
        EnemyArchetype.ranged: ['Ice Caster', 'Frost Slinger'],
        EnemyArchetype.glass: ['Splinter Blade', 'Shatter Fang'],
        EnemyArchetype.support: ['Rime Chanter', 'Frost Adept'],
      },
      'tide' => const {
        EnemyArchetype.swarm: ['Brine Mite', 'Reef Tick'],
        EnemyArchetype.brute: ['Tide Brute', 'Coral Crusher'],
        EnemyArchetype.tank: ['Shell Leviathan', 'Barnacle Guard'],
        EnemyArchetype.ranged: ['Spume Spitter', 'Salt Slinger'],
        EnemyArchetype.glass: ['Razor Eel', 'Needle Urchin'],
        EnemyArchetype.support: ['Depth Chanter', 'Tide Adept'],
      },
      'ember' => const {
        EnemyArchetype.swarm: ['Ash Mite', 'Cinder Tick'],
        EnemyArchetype.brute: ['Vault Brute', 'Slag Brawler'],
        EnemyArchetype.tank: ['Basalt Golem', 'Ember Bulwark'],
        EnemyArchetype.ranged: ['Spark Caster', 'Cinder Slinger'],
        EnemyArchetype.glass: ['Char Blade', 'Soot Fang'],
        EnemyArchetype.support: ['Ash Chanter', 'Ember Adept'],
      },
      'grove' => const {
        EnemyArchetype.swarm: ['Moss Slime', 'Root Tick', 'Leaf Mite'],
        EnemyArchetype.brute: ['Grove Brute', 'Timber Crusher'],
        EnemyArchetype.tank: ['Hollow Guard', 'Bark Bulwark'],
        EnemyArchetype.ranged: ['Spore Bat', 'Canopy Spitter'],
        EnemyArchetype.glass: ['Thorn Skitter', 'Bramble Fang'],
        EnemyArchetype.support: ['Wyrd Chanter', 'Grove Adept'],
      },
      _ => const {
        EnemyArchetype.swarm: ['Cave Slime', 'Sand Mite'],
        EnemyArchetype.brute: ['Cave Brute', 'Rock Crab'],
        EnemyArchetype.tank: ['Shellback', 'Stone Maw'],
        EnemyArchetype.ranged: ['Spit Bat', 'Cavern Spitter'],
        EnemyArchetype.glass: ['Needle Rat', 'Glass Skitter'],
        EnemyArchetype.support: ['Mire Shaman', 'Glow Cultist'],
      },
    };
    final names = table[archetype]!;
    return names[index % names.length];
  }

  /// Restarts the current floor wave with a healed party.
  static GameState restartFloor(GameState state) {
    final layoutSeed = newLayoutSeed();
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

  /// Result of crediting AFK time on boot / resume.
  static OfflineProgressResult applyOfflineProgress(
    GameState state,
    Duration elapsed,
  ) {
    // Soft wall: up to 8h of absence is credited (diminishing via floor budget).
    final seconds = elapsed.inSeconds.clamp(0, 8 * 3600);
    if (seconds == 0) {
      final next = state.copyWith(lastUpdated: DateTime.now());
      return OfflineProgressResult(
        state: next,
        secondsApplied: 0,
        goldGained: 0,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
      );
    }

    final beforeGold = state.gold;
    final beforeEssence = state.essence;
    final beforeHighest = state.highestFloorCleared;
    final beforeBoss = state.bossVictories;
    var roomsCleared = 0;

    late GameState progressed;
    if (state.inDungeon) {
      // Idle-friendly keystone: AFK time counts on the timer.
      final timed = advanceKeystoneTimer(state, seconds * 1000);
      final sim = simulateSpatialOffline(timed, seconds);
      progressed = sim.state;
      roomsCleared = sim.roomsCleared;
    } else {
      // Hub AFK: sanctuary idle gold only — no ghost combat / boss farms.
      progressed = applyHubIdleProgress(state, seconds);
    }
    progressed = progressed.copyWith(
      offlineSecondsRecovered: progressed.offlineSecondsRecovered + seconds,
      lastUpdated: DateTime.now(),
    );
    return OfflineProgressResult(
      state: progressed,
      secondsApplied: seconds,
      goldGained: progressed.gold - beforeGold,
      essenceGained: progressed.essence - beforeEssence,
      roomsCleared: roomsCleared,
      highestFloorDelta: progressed.highestFloorCleared - beforeHighest,
      bossDelta: progressed.bossVictories - beforeBoss,
    );
  }

  /// Hub-only AFK: small gold (and rare essence) from sanctuary — no combat ticks.
  static GameState applyHubIdleProgress(GameState state, int seconds) {
    if (seconds <= 0) return state;
    final perMinute = 2 +
        state.sanctuaryGoldLevel +
        state.ascensionLevel +
        (state.highestDungeonCleared + 1);
    final rawGold = max(0, (seconds * perMinute) ~/ 60);
    final gold = applyGoldGain(
      state,
      rawGold + (rawGold * state.torchOfflineGoldPercent) ~/ 100,
    );
    final essence = seconds >= 600
        ? (seconds ~/ 900) + (state.sanctuaryPowerLevel ~/ 2)
        : 0;
    if (gold <= 0 && essence <= 0) return state;
    return state.copyWith(
      gold: state.gold + gold,
      lifetimeGoldEarned: state.lifetimeGoldEarned + gold,
      essence: state.essence + essence,
    );
  }

  /// How many room clears offline combat may award for [seconds] away.
  /// Front-loaded for the first 30 minutes, then half rate, hard-capped.
  static int offlineFloorBudget(int seconds) {
    if (seconds <= 0) return 0;
    // ~1 clear / 40s for the first 30 minutes (5m≈7, 30m≈45).
    if (seconds <= 30 * 60) {
      return max(1, seconds ~/ 40);
    }
    const firstBand = (30 * 60) ~/ 40; // 45
    // After 30m: ~1 clear / 80s (1h≈45+22, 8h≈45+337 → cap).
    final extra = (seconds - 30 * 60) ~/ 80;
    return min(120, firstBand + extra);
  }

  /// Replays in-dungeon combat while offline using [SpatialCombat] (same authority
  /// as live play). Uses AFK assist + reduced VFX so boot stays responsive.
  /// Auto-uses flasks at low HP and God Hand when off cooldown.
  static ({GameState state, int roomsCleared}) simulateSpatialOffline(
    GameState state,
    int seconds,
  ) {
    if (!state.inDungeon || seconds <= 0) {
      return (state: state, roomsCleared: 0);
    }

    var maxFloors = offlineFloorBudget(seconds);
    // Gauntlet AFK: hard soft-cap so offline can't mint endless climb rewards.
    if (state.inGauntlet) {
      maxFloors = min(maxFloors, 6);
    }
    if (maxFloors <= 0) {
      return (state: state, roomsCleared: 0);
    }

    final preferVfx = state.vfxQuality;
    // Full enemy stats; AFK assist keeps boot catch-up responsive.
    const threatScale = 1.0;
    const afkAssist = true;
    const dt = 0.12;
    // Cap steps to floor budget (+ headroom) so long AFK can't burn CPU past
    // what [offlineFloorBudget] will award.
    final maxSteps = min(
      12000,
      max(240, maxFloors * 420),
    );

    var current = state.copyWith(vfxQuality: VfxQuality.minimal);
    var world = SpatialCombat.build(
      current,
      threatScale: threatScale,
      afkAssist: afkAssist,
    );
    var floorsCleared = 0;
    var abilityCasts = 0;

    for (var step = 0; step < maxSteps; step++) {
      if (!current.inDungeon || floorsCleared >= maxFloors) break;

      final stashLenBefore = current.gearStash.length;
      final result = SpatialCombat.step(world, current, dt: dt);
      world = result.world;
      current = result.state;
      if (result.goldFromKills > 0) {
        current = creditCombatGold(current, result.goldFromKills);
      }
      abilityCasts += result.abilityCasts;
      // Live parity: wear clear upgrades mid-floor and sync actor sheets.
      if (current.gearStash.length > stashLenBefore) {
        current = autoEquipBetterGear(current);
        world = SpatialCombat.syncPartyFromState(world, current);
      }

      // Keep AFK sim lean — strip accumulated VFX lists periodically.
      if (step % 40 == 0) {
        world.floaters.clear();
        world.bursts.clear();
        world.groundFx.clear();
        if (world.projectiles.length > 24) {
          world.projectiles.removeRange(0, world.projectiles.length - 24);
        }
      }

      // Wipe before flask/God Hand — avoid post-wipe loot/XP from assist.
      if (result.partyWiped) {
        // Gauntlet wipe always ends the run (same as live hub exit).
        if (current.inGauntlet) {
          current = exitToHubHealed(current);
          break;
        }
        if (MetaSystems.isActiveDailyRun(current)) {
          current = restartFloor(current);
          if (!current.inDungeon) break;
          world = SpatialCombat.build(
            current,
            threatScale: threatScale,
            afkAssist: afkAssist,
          );
          continue;
        }
        if (current.dungeonMode == DungeonMode.push &&
            current.currentRoom.floorNumber > current.highestFloorCleared) {
          current = retreatFromFailedPush(current);
          break;
        }
        current = restartFloor(current);
        if (!current.inDungeon) break;
        world = SpatialCombat.build(
          current,
          threatScale: threatScale,
          afkAssist: afkAssist,
        );
        continue;
      }

      // Mid-fight flask when living party avg HP drops below 35%.
      if (step % 12 == 0 && canUseConsumable(current)) {
        final living = <PartyHero>[
          for (final h in current.heroes)
            if (h.currentHp > 0) h,
        ];
        if (living.isNotEmpty) {
          var ratioSum = 0.0;
          for (final h in living) {
            final maxHp = current.effectiveHeroMaxHp(h);
            ratioSum += maxHp > 0 ? h.currentHp / maxHp : 0;
          }
          if (ratioSum / living.length < 0.35) {
            current = useConsumable(current);
            world = SpatialCombat.syncPartyFromState(world, current);
            SpatialCombat.spawnFlaskHealFx(
              world,
              reducedVfx: current.reducedVfx,
            );
          }
        }
      }

      // God Hand toward nearest live enemy when ready.
      // Soft cadence: every ~4.3s of sim time so AFK doesn't hard-carry mid PUSH.
      if (step % 36 == 0 && world.godHandCooldown <= 0) {
        final aim = _offlineGodHandAim(world);
        if (aim != null) {
          final gh = SpatialCombat.godHand(
            world,
            current,
            tileX: aim.$1,
            tileY: aim.$2,
          );
          world = gh.world;
          current = gh.state;
          if (gh.goldFromKills > 0) {
            current = creditCombatGold(current, gh.goldFromKills);
          }
        }
      }

      if (!result.roomCleared) continue;

      final wasTreasure = world.isTreasure;
      // Combat gold already credited per kill; treasure pays scaled chest budget.
      final gold = wasTreasure ? treasureGoldBudget(current) : 0;
      current = completeCurrentRoom(
        current,
        goldGain: gold,
        skipLootRoll: !wasTreasure,
      );
      floorsCleared++;
      if (!current.inDungeon || floorsCleared >= maxFloors) break;
      world = SpatialCombat.build(
        current,
        threatScale: threatScale,
        afkAssist: afkAssist,
      );
    }

    if (abilityCasts > 0) {
      current = current.copyWith(
        metaDepth: current.metaDepth.copyWith(
          lifetimeAbilityCasts:
              current.metaDepth.lifetimeAbilityCasts + abilityCasts,
        ),
      );
    }

    return (
      state: current.copyWith(vfxQuality: preferVfx),
      roomsCleared: floorsCleared,
    );
  }

  /// Nearest awake enemy to living party centroid, or null if none.
  /// Shared by AFK catch-up and balance sims (live/AFK assist aim).
  static (double, double)? godHandAim(SpatialWorld world) {
    return _offlineGodHandAim(world);
  }

  /// Nearest awake enemy to living party centroid, or null if none.
  static (double, double)? _offlineGodHandAim(SpatialWorld world) {
    final aliveHeroes = <SpatialActor>[
      for (final h in world.heroes)
        if (h.hp > 0) h,
    ];
    var cx = world.cols / 2.0;
    var cy = world.rows / 2.0;
    if (aliveHeroes.isNotEmpty) {
      cx = 0;
      cy = 0;
      for (final h in aliveHeroes) {
        cx += h.x;
        cy += h.y;
      }
      cx /= aliveHeroes.length;
      cy /= aliveHeroes.length;
    }
    SpatialActor? best;
    var bestD2 = double.infinity;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final dx = e.x - cx;
      final dy = e.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = e;
      }
    }
    if (best == null) return null;
    return (best.x, best.y);
  }

  static int partyTrainingCostFor(GameState state) {
    final totalLevels = state.heroes.fold<int>(
      0,
      (sum, hero) => sum + hero.level,
    );
    return 16 + (totalLevels * 3) + (state.bossVictories * 6);
  }

  static int upgradeCostFor(GameState state, PartyUpgradeType type) {
    final currentTier = switch (type) {
      PartyUpgradeType.attack => state.attackBonus ~/ 2,
      PartyUpgradeType.defense => state.defenseBonus,
      PartyUpgradeType.vitality => state.vitalityBonus ~/ 6,
      PartyUpgradeType.moveSpeed => state.moveSpeedBonus ~/ 2,
      PartyUpgradeType.attackSpeed => state.attackSpeedBonus ~/ 2,
      PartyUpgradeType.crit => state.critBonus,
    };

    return 18 + (currentTier * 10) + (state.bossVictories * 5);
  }

  static GameState trainParty(GameState state) {
    final trainingCost = partyTrainingCostFor(state);
    if (state.gold < trainingCost) {
      return state;
    }

    final trainedHeroes = state.heroes.map((hero) {
      final next = hero.copyWith(level: hero.level + 1, xp: 0);
      return next.copyWith(
        currentHp: state.effectiveHeroMaxHp(next),
      );
    }).toList();
    return state.copyWith(
      heroes: trainedHeroes,
      gold: state.gold - trainingCost,
      lastUpdated: DateTime.now(),
    );
  }

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
          attackBonus: state.attackBonus + 2,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.defense:
        return state.copyWith(
          defenseBonus: state.defenseBonus + 1,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.vitality:
        final nextVit = state.vitalityBonus + 6;
        final probe = state.copyWith(vitalityBonus: nextVit);
        final healedHeroes = state.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: probe.effectiveHeroMaxHp(hero),
              ),
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
          moveSpeedBonus: state.moveSpeedBonus + 2,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.attackSpeed:
        return state.copyWith(
          attackSpeedBonus: state.attackSpeedBonus + 2,
          gold: state.gold - cost,
          lastUpdated: DateTime.now(),
        );
      case PartyUpgradeType.crit:
        return state.copyWith(
          critBonus: state.critBonus + 1,
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
                  (relicId == phoenixEmberRelic ? 10 : 0),
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
      'legacy_spark' => md.legacyPoints >= 20,
      'daily_essence' => md.dailyEssenceBonusLevel >= 5,
      'gauntlet_gold' => md.gauntletGoldBonusLevel >= 5,
      _ => false,
    };
    if (atCap) return state;

    var nextMd = switch (id) {
      'stash_slot' =>
        md.copyWith(stashBonusSlots: min(20, md.stashBonusSlots + 2)),
      'combine_luck' =>
        md.copyWith(combinatorLuck: min(5, md.combinatorLuck + 1)),
      'torch_keep' =>
        md.copyWith(torchKeepLevel: min(10, md.torchKeepLevel + 1)),
      'gh_cdr' =>
        md.copyWith(godHandCdLevel: min(8, md.godHandCdLevel + 1)),
      'roster_cap' =>
        md.copyWith(petRosterCapBonus: min(10, md.petRosterCapBonus + 2)),
      'legacy_spark' =>
        md.copyWith(legacyPoints: min(20, md.legacyPoints + 1)),
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

  /// Display season label (ISO week + month), e.g. `2026-W32 · 2026-08`.
  static String seasonLabel(DateTime utc) =>
      '${isoWeekKey(utc)} · ${isoMonthKey(utc)}';

  static const List<String> weeklyModifiers = <String>[
    'glass',
    'swarm',
    'elite',
    'fortune',
    'iron',
  ];

  static GameState ensureWeeklyContract(GameState state, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    final key = isoWeekKey(t);
    final season = seasonLabel(t);
    var next = state;
    if (state.metaDepth.weeklyKey != key ||
        state.metaDepth.seasonKey != season) {
      final sameWeek = state.metaDepth.weeklyKey == key;
      final mod = LocalSeasonCatalog.resolveAffix(
        weekKey: key,
        currentModifier: sameWeek ? state.metaDepth.weeklyModifier : '',
      );
      next = next.copyWith(
        metaDepth: state.metaDepth.copyWith(
          weeklyKey: key,
          // Legacy weekly vault fields — kept for saves; vault is daily now.
          weeklyProgress: sameWeek ? state.metaDepth.weeklyProgress : 0,
          weeklyClaimed: sameWeek ? state.metaDepth.weeklyClaimed : false,
          weeklyModifier: sameWeek ? state.metaDepth.weeklyModifier : mod,
          weeklyBestTimedKey:
              sameWeek ? state.metaDepth.weeklyBestTimedKey : 0,
          seasonKey: season,
        ),
      );
    }
    return ensureDailyVault(next, now: t);
  }

  /// Resets daily vault progress when the UTC calendar day rolls.
  static GameState ensureDailyVault(GameState state, {DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc();
    final day = MetaSystems.dailyDateKey(t);
    if (state.metaDepth.dailyVaultDate == day) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultDate: day,
        dailyVaultClears: 0,
        dailyBestTimedKey: 0,
        dailyVaultClaimed: false,
      ),
    );
  }

  static int weeklyClaimEssence = 14;
  static const int weeklyClearTarget = 1;
  static const int dailyVaultClearTarget = 1;

  /// One-time essence when claiming the first vault of a calendar month.
  static const int seasonWeeklyBonusEssence = 12;

  /// Claim when 1 push clear **or** a timed KEY ≥2 today.
  static bool canClaimDailyVault(GameState state) {
    final md = state.metaDepth;
    if (md.dailyVaultClaimed) return false;
    return md.dailyVaultClears >= dailyVaultClearTarget ||
        md.dailyBestTimedKey >= 2;
  }

  /// Legacy name — daily vault.
  static bool canClaimWeekly(GameState state) => canClaimDailyVault(state);

  static GameState claimDailyVault(GameState state, {DateTime? now}) {
    var next = ensureWeeklyContract(state, now: now);
    final md = next.metaDepth;
    if (md.dailyVaultClaimed) return next;
    if (md.dailyVaultClears < dailyVaultClearTarget &&
        md.dailyBestTimedKey < 2) {
      return next;
    }
    var essenceGain = Keystone.dailyVaultEssence(md.dailyBestTimedKey);
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
    lastMetaPayoffNotices = notices;
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

  /// Legacy name — daily vault.
  static GameState claimWeekly(GameState state, {DateTime? now}) =>
      claimDailyVault(state, now: now);

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
        notices.add(
          'Will · ${WillRanks.titleForScore(threshold)} +${gain}e',
        );
      }
    }
    final gauntletClaims =
        List<String>.from(next.metaDepth.claimedGauntletMilestones);
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
        weekClaims.length == next.metaDepth.claimedWeekGoals.length &&
        titles.length == next.metaDepth.titles.length) {
      lastMetaPayoffNotices = const [];
      return MetaSystems.evaluateAchievements(next);
    }
    lastMetaPayoffNotices = notices;
    next = next.copyWith(
      essence: next.essence + essenceGain,
      metaDepth: next.metaDepth.copyWith(
        claimedWillRanks: willClaims,
        claimedGauntletMilestones: gauntletClaims,
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
    final capped = level.clamp(0, state.effectiveMaxHardmode);
    return MetaSystems.evaluateAchievements(
      state.copyWith(hardmodeLevel: capped, lastUpdated: DateTime.now()),
    );
  }

  /// Gold granted by a Gold Pouch drop ([LootDrop.amount] is the base gold).
  static int goldPouchBaseGold(int battleNumber) =>
      20 + max(1, battleNumber) * 5;

  static bool isWalletGoldDrop(LootDrop drop) {
    if (drop.equipment != null) return false;
    final n = drop.name.toLowerCase();
    return n.contains('gold pouch') || n.contains('coin pouch');
  }

  /// Per-kill loot: gear (or Faded Dust). No room fillers — those are
  /// [rollFloorClearLoot] once per clear.
  static List<LootDrop> rollKillLoot(
    int battleNumber, {
    int ascensionLevel = 0,
    int lootFindPercent = 0,
    int hardmodeLevel = 0,
    List<PartyHero>? party,
    String dungeonId = 'sandy',
    EnemyRole enemyRole = EnemyRole.normal,
  }) {
    final hm = hardmodeLevel.clamp(0, Keystone.maxLevel);
    final roleSkipRelief = switch (enemyRole) {
      EnemyRole.boss => 0.25,
      EnemyRole.elite => 0.12,
      EnemyRole.normal => 0.0,
    };

    // AL drop penalty: chance to skip gear entirely (pets / HM / elites blunt).
    final skipChance = (ascensionLevel * ascensionDropPenalty -
            lootFindPercent / 100.0 -
            hm * 0.012 -
            roleSkipRelief)
        .clamp(0.0, 0.55);
    if (random.nextDouble() < skipChance) {
      return <LootDrop>[
        const LootDrop(
          name: 'Faded Dust',
          amount: 1,
          rarity: LootRarity.common,
        ),
      ];
    }

    var primaryRarity = _rarityForBattle(battleNumber, hardmodeLevel: hm);
    final rarityBumps = switch (enemyRole) {
      EnemyRole.boss => 2,
      EnemyRole.elite => 1,
      EnemyRole.normal => 0,
    };
    for (var i = 0; i < rarityBumps; i++) {
      if (primaryRarity.index < LootRarity.values.length - 1) {
        primaryRarity = LootRarity.values[primaryRarity.index + 1];
      }
    }

    final slots = EquipmentSlot.values
        .where((s) => s != EquipmentSlot.consumable)
        .toList();

    (HeroRole bias, ArmorType? preferred, SpecRoleTag? roleTag) pickBias() {
      final target = _lootTargetHero(party);
      if (target != null) {
        return (
          _equipScoreRole(target.spec),
          preferredArmorForSpec(target.spec, max(1, battleNumber)),
          target.spec.roleTag,
        );
      }
      return (
        HeroRole.values[random.nextInt(HeroRole.values.length)],
        null,
        null,
      );
    }

    final slot = slots[random.nextInt(slots.length)];
    final (bias, preferredArmor, roleTag) = pickBias();
    final piece = createEquipment(
      slot: slot,
      rarity: primaryRarity,
      battleNumber: battleNumber,
      bias: bias,
      preferredArmor: preferredArmor,
      roleTag: roleTag,
      dungeonId: dungeonId,
      ascensionLevel: ascensionLevel,
      hardmodeLevel: hardmodeLevel,
    );
    final drops = <LootDrop>[
      LootDrop(
        name: piece.name,
        amount: 1,
        rarity: primaryRarity,
        equipment: piece,
      ),
    ];

    final roleSecondMul = switch (enemyRole) {
      EnemyRole.boss => 1.75,
      EnemyRole.elite => 1.35,
      EnemyRole.normal => 1.0,
    };
    final secondChance = (battleNumber >= 6
            ? (0.22 + lootFindPercent / 200.0)
            : (0.08 + lootFindPercent / 250.0)) *
        roleSecondMul;
    final secondCap = battleNumber >= 6 ? 0.55 : 0.28;
    if (battleNumber >= 4 &&
        random.nextDouble() < secondChance.clamp(0.0, secondCap)) {
      final slot2 = slots[random.nextInt(slots.length)];
      final (bias2, preferred2, roleTag2) = pickBias();
      final rarity2 = primaryRarity.index > 0
          ? LootRarity.values[primaryRarity.index - 1]
          : LootRarity.common;
      final piece2 = createEquipment(
        slot: slot2,
        rarity: rarity2,
        battleNumber: battleNumber,
        bias: bias2,
        preferredArmor: preferred2,
        roleTag: roleTag2,
        dungeonId: dungeonId,
        ascensionLevel: ascensionLevel,
        hardmodeLevel: hardmodeLevel,
      );
      drops.add(
        LootDrop(
          name: piece2.name,
          amount: 1,
          rarity: rarity2,
          equipment: piece2,
        ),
      );
    }

    return drops;
  }

  /// Once-per-clear fillers (sigil / pouch / relic / vial). Uses live [roomType]
  /// so gauntlet bosses (`floor % 5 == 0`) get Boss Sigil correctly.
  static List<LootDrop> rollFloorClearLoot(
    int battleNumber, {
    required RoomType roomType,
  }) {
    final drops = <LootDrop>[];
    if (battleNumber % 4 == 0) {
      drops.add(
        LootDrop(
          name: 'Gold Pouch',
          amount: goldPouchBaseGold(battleNumber),
          rarity: LootRarity.common,
        ),
      );
    }
    if (battleNumber % 9 == 0) {
      drops.add(
        const LootDrop(name: 'Relic Shard', amount: 1, rarity: LootRarity.rare),
      );
    }
    if (roomType == RoomType.boss) {
      drops.add(
        const LootDrop(name: 'Boss Sigil', amount: 1, rarity: LootRarity.epic),
      );
    }
    if (roomType == RoomType.treasure) {
      drops.add(
        const LootDrop(
          name: 'Essence Vial',
          amount: 1,
          rarity: LootRarity.rare,
        ),
      );
    }
    return drops;
  }

  /// Combined roll (kill gear + floor fillers). Prefer [rollKillLoot] /
  /// [rollFloorClearLoot] at call sites. Kept for tests / tooling.
  static List<LootDrop> rollLoot(
    int battleNumber, {
    int ascensionLevel = 0,
    int lootFindPercent = 0,
    int hardmodeLevel = 0,
    List<PartyHero>? party,
    String dungeonId = 'sandy',
    EnemyRole enemyRole = EnemyRole.normal,
    RoomType? roomType,
  }) {
    final resolvedType = roomType ??
        DungeonGenerator.generateFloor(
          max(1, battleNumber),
          ascensionLevel: ascensionLevel,
          dungeonId: dungeonId,
          bossEvery: null,
        ).first.type;
    return _finalizeLootDrops([
      ...rollKillLoot(
        battleNumber,
        ascensionLevel: ascensionLevel,
        lootFindPercent: lootFindPercent,
        hardmodeLevel: hardmodeLevel,
        party: party,
        dungeonId: dungeonId,
        enemyRole: enemyRole,
      ),
      ...rollFloorClearLoot(
        battleNumber,
        roomType: resolvedType,
      ),
    ]);
  }

  /// Keep all gear / sigil / relic / vial; fill remaining slots with filler
  /// (gold pouch). Soft cap 5 — never discards important drops.
  static List<LootDrop> _finalizeLootDrops(List<LootDrop> drops) {
    const softCap = 5;
    if (drops.length <= softCap) return List<LootDrop>.from(drops);

    bool important(LootDrop d) {
      if (d.isEquipment) return true;
      final n = d.name.toLowerCase();
      return n.contains('boss sigil') ||
          n.contains('relic') ||
          n.contains('essence vial');
    }

    final keep = <LootDrop>[];
    final filler = <LootDrop>[];
    for (final d in drops) {
      if (important(d)) {
        keep.add(d);
      } else {
        filler.add(d);
      }
    }
    final out = List<LootDrop>.from(keep);
    for (final d in filler) {
      if (out.length >= softCap) break;
      out.add(d);
    }
    return out;
  }

  static PartyHero? _lootTargetHero(List<PartyHero>? party) {
    if (party == null || party.isEmpty) return null;
    final living = [for (final h in party) if (h.isAlive) h];
    final pool = living.isNotEmpty ? living : party;
    return pool[random.nextInt(pool.length)];
  }

  static EquipmentItem createEquipment({
    required EquipmentSlot slot,
    required LootRarity rarity,
    required int battleNumber,
    HeroRole? bias,
    ArmorType? preferredArmor,
    SpecRoleTag? roleTag,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) {
    EquipmentFactory.random = random;
    return EquipmentFactory.create(
      slot: slot,
      rarity: rarity,
      battleNumber: battleNumber,
      bias: bias,
      preferredArmor: preferredArmor,
      roleTag: roleTag,
      dungeonId: dungeonId,
      ascensionLevel: ascensionLevel,
      hardmodeLevel: hardmodeLevel,
    );
  }

  /// Item level from floor + rarity + dungeon/AL/HM band (soft-capped late).
  static int itemLevelFor({
    required int battleNumber,
    required LootRarity rarity,
    String? dungeonId,
    int ascensionLevel = 0,
    int hardmodeLevel = 0,
  }) =>
      EquipmentFactory.itemLevelFor(
        battleNumber: battleNumber,
        rarity: rarity,
        dungeonId: dungeonId,
        ascensionLevel: ascensionLevel,
        hardmodeLevel: hardmodeLevel,
      );

  /// Recommended auto-sell iLvl ceiling for the player's progression.
  static int maxAutoSellIlvlCap(GameState state) {
    final fromDungeon = state.highestDungeonCleared * 22;
    final fromAl = state.ascensionLevel * 4;
    return (60 + fromDungeon + fromAl).clamp(60, 200);
  }

  /// Scale a soulbound piece so Ascend AL keeps it relevant vs new drops.
  static EquipmentItem scaleSoulboundForAl(
    EquipmentItem item,
    int ascensionLevel,
  ) {
    final al = ascensionLevel.clamp(0, 40);
    final targetIlvl = max(item.effectiveItemLevel, 20 + al * 3);
    if (targetIlvl <= item.effectiveItemLevel) {
      return item.copyWith(itemLevel: item.effectiveItemLevel);
    }
    final ratio = targetIlvl / max(1, item.effectiveItemLevel);
    int bump(int v) {
      if (v <= 0) return 0;
      return max(v, (v * ratio).round());
    }

    return item.copyWith(
      itemLevel: targetIlvl,
      strengthBonus: bump(item.strengthBonus),
      agilityBonus: bump(item.agilityBonus),
      staminaBonus: bump(item.staminaBonus),
      intellectBonus: bump(item.intellectBonus),
      spiritBonus: bump(item.spiritBonus),
      spellPowerBonus: bump(item.spellPowerBonus),
      armorBonus: bump(item.armorBonus),
      attackBonus: bump(item.attackBonus),
      defenseBonus: bump(item.defenseBonus),
      vitalityBonus: bump(item.vitalityBonus),
      mp5Bonus: bump(item.mp5Bonus),
      critChanceBonus: bump(item.critChanceBonus),
      attackSpeedBonus: bump(item.attackSpeedBonus),
      moveSpeedBonus: bump(item.moveSpeedBonus),
      effectValue: bump(item.effectValue),
    );
  }

  static String _equipmentNameFor(
    EquipmentSlot slot,
    LootRarity rarity, {
    HeroRole? bias,
    ArmorType? armorType,
    WeaponType? weaponType,
    OffHandKind? offHandKind,
    WeaponHanded? handed,
    String? affixPrefixId,
    String? affixSuffixId,
  }) =>
      EquipmentFactory.equipmentNameFor(
        slot: slot,
        rarity: rarity,
        bias: bias,
        armorType: armorType,
        weaponType: weaponType,
        offHandKind: offHandKind,
        handed: handed,
        affixPrefix: EquipmentFactory.affixNameById(affixPrefixId),
        affixSuffix: EquipmentFactory.affixNameById(affixSuffixId),
      );

  static int lootEssenceValue(LootDrop drop) {
    if (drop.essenceGained > 0) {
      return drop.essenceGained;
    }
    if (drop.equipment != null) {
      return equipmentEssenceValue(drop.equipment!);
    }
    final perItem = switch (drop.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
      LootRarity.legendary => 28,
    };

    return perItem * drop.amount;
  }

  static int equipmentEssenceValue(EquipmentItem item) {
    final base = switch (item.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
      LootRarity.legendary => 28,
    };
    return base + (item.powerScore ~/ 4);
  }

  /// Merchant gold payout (stash-only sales).
  /// Uses stat power + 2×ilvl (ilvl is not double-counted via [powerScore]).
  static int equipmentGoldValue(EquipmentItem item) {
    final base = switch (item.rarity) {
      LootRarity.common => 8,
      LootRarity.uncommon => 18,
      LootRarity.rare => 40,
      LootRarity.epic => 90,
      LootRarity.legendary => 160,
    };
    return base + item.statPowerScore + (item.effectiveItemLevel * 2);
  }

  static int marketFlaskCost(GameState state) =>
      40 + (state.highestFloorCleared * 3) + (state.ascensionLevel * 15);

  static EquipmentItem createMarketFlask({int salt = 0}) {
    final id = 'flask_${DateTime.now().microsecondsSinceEpoch}_$salt';
    return EquipmentItem(
      id: id,
      name: 'Healing Flask',
      slot: EquipmentSlot.consumable,
      rarity: LootRarity.common,
      vitalityBonus: 1,
      itemLevel: 1,
      iconId: 'flask',
    );
  }

  static GameState buyMarketFlask(GameState state, {int salt = 0}) {
    final cost = marketFlaskCost(state);
    if (state.gold < cost) return state;
    final flask = createMarketFlask(salt: salt);
    var next = state.copyWith(gold: state.gold - cost);
    // Prefer empty consumable slot on first hero, else stash.
    for (var i = 0; i < next.heroes.length; i++) {
      final hero = next.heroes[i];
      if (hero.itemIn(EquipmentSlot.consumable) == null) {
        final eq = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
          ..[EquipmentSlot.consumable] = flask;
        final heroes = List<PartyHero>.from(next.heroes);
        heroes[i] = hero.copyWith(equipped: eq);
        return next.copyWith(heroes: heroes, lastUpdated: DateTime.now());
      }
    }
    next = stashEquipment(next, flask);
    return next.copyWith(lastUpdated: DateTime.now());
  }

  /// Buy up to [count] flasks (empty consumable slots first, then stash).
  static GameState buyMarketFlasks(GameState state, {int count = 3}) {
    var next = state;
    final n = count.clamp(1, 9);
    for (var i = 0; i < n; i++) {
      final before = next.gold;
      next = buyMarketFlask(next, salt: i);
      if (next.gold >= before) break;
    }
    return next;
  }

  static int marketBandageCost(GameState state) =>
      25 + (state.highestFloorCleared * 2) + (state.ascensionLevel * 10);

  static EquipmentItem createMarketBandage({int salt = 0}) {
    final id = 'bandage_${DateTime.now().microsecondsSinceEpoch}_$salt';
    return EquipmentItem(
      id: id,
      name: 'Field Bandage',
      slot: EquipmentSlot.consumable,
      rarity: LootRarity.common,
      vitalityBonus: 1,
      itemLevel: 1,
      iconId: 'bandage',
    );
  }

  static GameState buyMarketBandage(GameState state, {int salt = 0}) {
    final cost = marketBandageCost(state);
    if (state.gold < cost) return state;
    final bandage = createMarketBandage(salt: salt);
    var next = state.copyWith(gold: state.gold - cost);
    for (var i = 0; i < next.heroes.length; i++) {
      final hero = next.heroes[i];
      if (hero.itemIn(EquipmentSlot.consumable) == null) {
        final eq = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
          ..[EquipmentSlot.consumable] = bandage;
        final heroes = List<PartyHero>.from(next.heroes);
        heroes[i] = hero.copyWith(equipped: eq);
        return next.copyWith(heroes: heroes, lastUpdated: DateTime.now());
      }
    }
    next = stashEquipment(next, bandage);
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState sellGearForGold(GameState state, String itemId) {
    final inStash = state.gearStash.any((g) => g.id == itemId);
    if (!inStash) return state;
    final item = findGear(state, itemId);
    if (item == null) return state;
    final value = equipmentGoldValue(item);
    final next = removeGear(state, itemId);
    return next.copyWith(
      gold: next.gold + value,
      lastUpdated: DateTime.now(),
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
    return state.copyWith(
      seenTips: seen.toList(),
      lastUpdated: DateTime.now(),
    );
  }

  static const int maxGearStash = 50;

  static int maxGearStashFor(GameState state) =>
      maxGearStash + state.metaDepth.stashBonusSlots;

  /// Puts gear into the inventory stash. Overflow salvages the oldest piece.
  static GameState stashEquipment(GameState state, EquipmentItem item) {
    return stashEquipmentDetailed(state, item).state;
  }

  /// Like [stashEquipment], also reporting overflow salvage for UI feedback.
  static ({GameState state, int overflowEssence, String? overflowName})
      stashEquipmentDetailed(GameState state, EquipmentItem item) {
    if (item.isApex) {
      return (
        state: state.copyWith(
          apexVault: [...state.apexVault, item],
        ),
        overflowEssence: 0,
        overflowName: null,
      );
    }
    final stash = List<EquipmentItem>.from(state.gearStash);
    var essence = state.essence;
    var overflowEssence = 0;
    String? overflowName;
    final cap = maxGearStashFor(state);
    if (stash.length >= cap) {
      final overflow = stash.removeAt(0);
      if (overflow.isApex) {
        return (
          state: state.copyWith(
            gearStash: stash,
            apexVault: [...state.apexVault, overflow, item],
            essence: essence,
          ),
          overflowEssence: 0,
          overflowName: null,
        );
      }
      overflowEssence = equipmentEssenceValue(overflow);
      overflowName = overflow.name;
      essence += overflowEssence;
    }
    stash.add(item);
    return (
      state: state.copyWith(gearStash: stash, essence: essence),
      overflowEssence: overflowEssence,
      overflowName: overflowName,
    );
  }

  static EquipmentItem? findGear(GameState state, String id) {
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        if (item.id == id) return item;
      }
    }
    for (final item in state.gearStash) {
      if (item.id == id) return item;
    }
    return null;
  }

  static ({int heroIndex, EquipmentSlot slot})? findEquippedLocation(
    GameState state,
    String id,
  ) {
    for (var i = 0; i < state.heroes.length; i++) {
      for (final entry in state.heroes[i].equipped.entries) {
        if (entry.value.id == id) {
          return (heroIndex: i, slot: entry.key);
        }
      }
    }
    return null;
  }

  static GameState removeGear(GameState state, String id) {
    final location = findEquippedLocation(state, id);
    if (location != null) {
      final hero = state.heroes[location.heroIndex];
      final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
        ..remove(location.slot);
      final heroes = [...state.heroes];
      heroes[location.heroIndex] = hero.copyWith(equipped: nextGear);
      return state.copyWith(heroes: heroes);
    }
    return state.copyWith(
      gearStash: state.gearStash.where((item) => item.id != id).toList(),
    );
  }

  /// Slots a stash piece may fill (rings/trinkets share dual slots).
  static List<EquipmentSlot> equipTargetsFor(EquipmentItem item) {
    return switch (item.slot) {
      EquipmentSlot.ring || EquipmentSlot.ring2 => <EquipmentSlot>[
          EquipmentSlot.ring,
          EquipmentSlot.ring2,
        ],
      EquipmentSlot.trinket || EquipmentSlot.trinket2 => <EquipmentSlot>[
          EquipmentSlot.trinket,
          EquipmentSlot.trinket2,
        ],
      _ => <EquipmentSlot>[item.slot],
    };
  }

  /// Whether [hero] can actually receive [item] into [slot] right now.
  static bool canHeroReceive(
    PartyHero hero,
    EquipmentItem item, {
    required EquipmentSlot slot,
  }) {
    if (item.isApex) {
      final className = item.apexClassId;
      if (className != null && className != hero.spec.classId.name) {
        return false;
      }
    }
    final remapped = item.slot == slot ? item : item.copyWith(slot: slot);
    if (!ClassProficiency.canEquip(
      role: hero.gearAffinity,
      level: hero.level,
      item: remapped,
      specId: hero.specId,
    )) {
      return false;
    }
    if (slot == EquipmentSlot.offHand &&
        ClassProficiency.weaponBlocksOffHand(
          hero.itemIn(EquipmentSlot.weapon),
        )) {
      return false;
    }
    return true;
  }

  /// Equip a stash item onto a hero slot (current piece moves to stash).
  static GameState equipFromStash(
    GameState state,
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) {
      return state;
    }
    EquipmentItem? item;
    for (final candidate in state.gearStash) {
      if (candidate.id == itemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      return state;
    }

    final targetSlot = intoSlot ?? item.slot;
    if (!equipTargetsFor(item).contains(targetSlot)) {
      return state;
    }

    final heroCheck = state.heroes[heroIndex];
    if (!canHeroReceive(heroCheck, item, slot: targetSlot)) {
      return state;
    }

    final equippedItem =
        item.slot == targetSlot ? item : item.copyWith(slot: targetSlot);

    var next = state.copyWith(
      gearStash: state.gearStash.where((g) => g.id != itemId).toList(),
      equipped: const <EquipmentSlot, EquipmentItem>{},
    );
    final hero = next.heroes[heroIndex];
    final current = hero.itemIn(targetSlot);
    if (current != null) {
      next = stashEquipment(next, current);
    }

    final vitalityBefore = next.effectiveHeroMaxHp(hero);
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
      next.heroes[heroIndex].equipped,
    )..[targetSlot] = equippedItem;

    // 2H main-hand unequips off-hand.
    if (targetSlot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(equippedItem)) {
      final off = nextGear.remove(EquipmentSlot.offHand);
      if (off != null) {
        next = stashEquipment(next, off);
      }
    }

    final heroes = [...next.heroes];
    heroes[heroIndex] = next.heroes[heroIndex].copyWith(equipped: nextGear);
    next = next.copyWith(heroes: heroes);
    final updated = next.heroes[heroIndex];
    final vitalityAfter = next.effectiveHeroMaxHp(updated);
    final vitalityDelta = vitalityAfter - vitalityBefore;
    if (vitalityDelta != 0) {
      heroes[heroIndex] = updated.copyWith(
        currentHp: vitalityDelta > 0
            ? min(vitalityAfter, updated.currentHp + vitalityDelta)
            : min(vitalityAfter, updated.currentHp),
      );
      next = next.copyWith(heroes: heroes);
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState unequipSlot(
    GameState state,
    EquipmentSlot slot, {
    int heroIndex = 0,
  }) {
    if (heroIndex < 0 || heroIndex >= state.heroes.length) {
      return state;
    }
    final hero = state.heroes[heroIndex];
    final current = hero.itemIn(slot);
    if (current == null) {
      return state;
    }
    final nextGear = Map<EquipmentSlot, EquipmentItem>.from(hero.equipped)
      ..remove(slot);
    final heroes = [...state.heroes];
    heroes[heroIndex] = hero.copyWith(equipped: nextGear);
    var next = state.copyWith(
      heroes: heroes,
      equipped: const <EquipmentSlot, EquipmentItem>{},
    );
    next = stashEquipment(next, current);
    final updated = next.heroes[heroIndex];
    heroes[heroIndex] = updated.copyWith(
      currentHp: min(next.effectiveHeroMaxHp(updated), updated.currentHp),
    );
    return next.copyWith(
      heroes: heroes,
      lastUpdated: DateTime.now(),
    );
  }

  /// Scrap one stash piece for essence. Refuses equipped gear (unequip first).
  static GameState sellGear(GameState state, String itemId) {
    final inStash = state.gearStash.any((g) => g.id == itemId);
    if (!inStash) {
      return state;
    }
    final item = findGear(state, itemId);
    if (item == null) {
      return state;
    }
    final value = equipmentEssenceValue(item);
    final next = removeGear(state, itemId);
    return next.copyWith(
      essence: next.essence + value,
      heroes: next.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: min(next.effectiveHeroMaxHp(hero), hero.currentHp),
            ),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  static int combineCost(
    EquipmentItem primary,
    EquipmentItem secondary, {
    int combinatorLuck = 0,
  }) =>
      max(
        1,
        20 +
            primary.powerScore +
            secondary.powerScore +
            ((primary.rarity.index + secondary.rarity.index) * 5) -
            combinatorLuck * 3,
      );

  /// Slot groups for BiS planning: dual ring/trinket, then singletons.
  static List<List<EquipmentSlot>> equipSlotGroups() {
    return <List<EquipmentSlot>>[
      <EquipmentSlot>[EquipmentSlot.ring, EquipmentSlot.ring2],
      <EquipmentSlot>[EquipmentSlot.trinket, EquipmentSlot.trinket2],
      for (final slot in EquipmentSlot.values)
        if (slot != EquipmentSlot.ring &&
            slot != EquipmentSlot.ring2 &&
            slot != EquipmentSlot.trinket &&
            slot != EquipmentSlot.trinket2 &&
            slot != EquipmentSlot.consumable)
          <EquipmentSlot>[slot],
    ];
  }

  /// Net score for putting [item] into [slot] on [hero].
  ///
  /// Two-hand weapons subtract the currently worn off-hand so Auto Equip
  /// does not drop a strong shield/tome for a marginally better 2H.
  static int slotEquipScore(
    PartyHero hero,
    EquipmentItem? item, {
    required EquipmentSlot slot,
  }) {
    if (item == null) return 0;
    if (!canHeroReceive(hero, item, slot: slot)) {
      return -999999;
    }
    var score = specEquipScore(hero, item);
    if (slot == EquipmentSlot.weapon &&
        ClassProficiency.weaponBlocksOffHand(item)) {
      final off = hero.itemIn(EquipmentSlot.offHand);
      if (off != null) {
        score -= specEquipScore(hero, off);
      }
    }
    return score;
  }

  /// Spec-aware score for deciding whether gear is an upgrade for a hero.
  static int specEquipScore(PartyHero hero, EquipmentItem item) {
    final role = _equipScoreRole(hero.spec);
    var score = roleEquipScore(
      role,
      item,
      specId: hero.specId,
      level: hero.level,
    );
    score += GearSets.equipScoreBonus(
      equipped: hero.equipped,
      candidate: item,
    );
    if (item.isApex) {
      score += 80 + item.apexRank * 40;
      if (item.apexClassId == hero.spec.classId.name) {
        score += 40;
      }
      if (item.apexRoleTag == hero.spec.roleTag.name) {
        score += 60;
      }
    }
    return score;
  }

  /// Map talent trees onto the 4 scoring archetypes (not identity labels).
  static HeroRole _equipScoreRole(HeroSpecDef spec) {
    if (spec.classId == HeroClassId.hunter) return HeroRole.rogue;
    return switch (spec.roleTag) {
      SpecRoleTag.tank => HeroRole.warrior,
      SpecRoleTag.healer => HeroRole.healer,
      SpecRoleTag.caster => HeroRole.mage,
      SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
        spec.gearAffinity == HeroRole.mage
            ? HeroRole.mage
            : (spec.gearAffinity == HeroRole.warrior
                ? HeroRole.warrior
                : HeroRole.rogue),
    };
  }

  /// Class-aware score for deciding whether gear is an upgrade for a hero.
  ///
  /// When [specId] is set, weights follow [EquipStatWeights.forSpec] so BiS
  /// matches CombatRatings (tank Sta/Armor, Str-DPS, Agi-DPS, Int>SP casters).
  static int roleEquipScore(
    HeroRole role,
    EquipmentItem item, {
    HeroSpecId? specId,
    int level = 60,
  }) {
    final spec = specId != null ? HeroSpecs.def(specId) : null;
    final w = spec != null
        ? EquipStatWeights.forSpec(spec)
        : EquipStatWeights.forRole(role);
    final roleTag = spec?.roleTag;
    final str = item.strengthBonus;
    final agi = item.agilityBonus;
    final sta = item.resolvedStamina;
    final intel = item.intellectBonus;
    final spi = item.spiritBonus;
    final sp = item.spellPowerBonus;
    final armor = item.resolvedArmor;
    final crit = item.critChanceBonus;
    final aspd = item.attackSpeedBonus;
    final move = item.moveSpeedBonus;
    final mp5 = item.mp5Bonus;
    final effect = switch (item.effectId) {
      GearEffectId.lifesteal => switch (roleTag ?? _tagForRole(role)) {
          SpecRoleTag.tank => item.effectValue * 5,
          SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
            item.effectValue * 3,
          _ => item.effectValue,
        },
      GearEffectId.pierce => switch (roleTag ?? _tagForRole(role)) {
          SpecRoleTag.caster => 24,
          SpecRoleTag.meleeDps || SpecRoleTag.rangedDps => 12,
          _ => 6,
        },
      GearEffectId.crit => switch (roleTag ?? _tagForRole(role)) {
          SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
            item.effectValue * 4,
          SpecRoleTag.caster => item.effectValue * 3,
          SpecRoleTag.healer => item.effectValue * 2,
          _ => item.effectValue,
        },
      GearEffectId.haste => switch (roleTag ?? _tagForRole(role)) {
          SpecRoleTag.caster || SpecRoleTag.healer => item.effectValue * 3,
          SpecRoleTag.meleeDps || SpecRoleTag.rangedDps =>
            item.effectValue * 2,
          _ => item.effectValue,
        },
      GearEffectId.goldFind => item.effectValue,
      GearEffectId.none => 0,
    };
    final core = (str * w.str +
            agi * w.agi +
            sta * w.sta +
            intel * w.intel +
            spi * w.spi +
            sp * w.sp +
            armor * w.armor +
            crit * w.crit +
            aspd * w.aspd +
            move * w.move +
            mp5 * w.mp5)
        .round() +
        (item.attackBonus * w.flatAtk).round();
    // Affinity is a strong class-identity signal so mage-tagged Int weapons
    // land on casters even when healer SP weights score nearly the same.
    final affinityRole = spec?.gearAffinity ?? role;
    var score = core +
        effect +
        item.rarity.index * 2 +
        // Soft ilvl tie-break — stats/rarity/set dominate BiS.
        (item.effectiveItemLevel ~/ 4) +
        (item.affinity == affinityRole.name ? 24 : 0);
    // Prefer the heaviest armor the spec can wear (stops cloth beating mail).
    // One step below preferred (mail under plate) is a soft penalty, not a dump.
    if (spec != null && item.armorType != null) {
      final preferred = preferredArmorForSpec(spec, level);
      if (preferred != null) {
        final delta =
            _armorWeightRank(preferred) - _armorWeightRank(item.armorType!);
        if (delta == 0) {
          score += 32;
        } else if (delta == 1) {
          score -= 4;
        } else if (delta > 1) {
          score -= 12;
        } else {
          score -= 6;
        }
      }
    }
    return score;
  }

  static int _armorWeightRank(ArmorType t) => switch (t) {
        ArmorType.cloth => 0,
        ArmorType.leather => 1,
        ArmorType.mail => 2,
        ArmorType.plate => 3,
      };

  static SpecRoleTag _tagForRole(HeroRole role) => switch (role) {
        HeroRole.warrior => SpecRoleTag.meleeDps,
        HeroRole.rogue => SpecRoleTag.meleeDps,
        HeroRole.healer => SpecRoleTag.healer,
        HeroRole.mage => SpecRoleTag.caster,
      };

  /// Compare a bag candidate against what a hero wears in that slot family.
  ///
  /// Rings/trinkets pick the best of the dual slots. Off-hand is not an upgrade
  /// while a two-hand weapon is equipped.
  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
    EquipmentSlot intoSlot,
  }) compareForHero(
    PartyHero hero,
    EquipmentItem candidate, {
    EquipmentSlot? intoSlot,
  }) {
    final targets = intoSlot != null
        ? <EquipmentSlot>[intoSlot]
        : equipTargetsFor(candidate);

    var bestDelta = -99999;
    var best = (
      powerDelta: -9999,
      atkDelta: 0,
      defDelta: 0,
      vitDelta: 0,
      isUpgrade: false,
      intoSlot: targets.first,
    );

    for (final slot in targets) {
      final cmp = _compareForHeroSlot(hero, candidate, slot);
      if (cmp.powerDelta > bestDelta) {
        bestDelta = cmp.powerDelta;
        best = (
          powerDelta: cmp.powerDelta,
          atkDelta: cmp.atkDelta,
          defDelta: cmp.defDelta,
          vitDelta: cmp.vitDelta,
          isUpgrade: cmp.isUpgrade,
          intoSlot: slot,
        );
      }
    }
    return best;
  }

  static ({
    int powerDelta,
    int atkDelta,
    int defDelta,
    int vitDelta,
    bool isUpgrade,
  }) _compareForHeroSlot(
    PartyHero hero,
    EquipmentItem candidate,
    EquipmentSlot slot,
  ) {
    if (!canHeroReceive(hero, candidate, slot: slot)) {
      return (
        powerDelta: -9999,
        atkDelta: 0,
        defDelta: 0,
        vitDelta: 0,
        isUpgrade: false,
      );
    }
    final current = hero.itemIn(slot);
    if (current != null && current.isApex && !candidate.isApex) {
      return (
        powerDelta: -9999,
        atkDelta: 0,
        defDelta: 0,
        vitDelta: 0,
        isUpgrade: false,
      );
    }
    final curScore = slotEquipScore(hero, current, slot: slot);
    final newScore = slotEquipScore(hero, candidate, slot: slot);
    final curAtk = (current?.strengthBonus ?? 0) +
        (current?.agilityBonus ?? 0) +
        (current?.spellPowerBonus ?? 0) +
        (current?.attackBonus ?? 0);
    final curDef = current?.resolvedArmor ?? 0;
    final curVit = current?.resolvedStamina ?? 0;
    final newAtk = candidate.strengthBonus +
        candidate.agilityBonus +
        candidate.spellPowerBonus +
        candidate.attackBonus;
    final powerDelta = newScore - curScore;
    return (
      powerDelta: powerDelta,
      atkDelta: newAtk - curAtk,
      defDelta: candidate.resolvedArmor - curDef,
      vitDelta: candidate.resolvedStamina - curVit,
      isUpgrade: isMeaningfulEquipUpgrade(
        hero: hero,
        item: candidate,
        curScore: curScore,
        newScore: newScore,
        slotEmpty: current == null,
      ),
    );
  }

  /// Role-weighted primary mass (excludes rarity / ilvl / affinity crumbs).
  static double roleRelevantStatMass(PartyHero hero, EquipmentItem item) {
    final w = EquipStatWeights.forSpec(hero.spec);
    return item.strengthBonus * w.str +
        item.agilityBonus * w.agi +
        item.resolvedStamina * w.sta +
        item.intellectBonus * w.intel +
        item.spiritBonus * w.spi +
        item.spellPowerBonus * w.sp +
        item.resolvedArmor * w.armor +
        item.critChanceBonus * w.crit +
        item.attackSpeedBonus * w.aspd +
        item.attackBonus * w.flatAtk;
  }

  /// Empty slots only fill role-plausible gear (not every wearable crumb).
  ///
  /// Affinity / preferred armor alone is not enough — low-iLvl tagged junk was
  /// filling empty slots, then BiS-keep blocked auto-sell and clogged the bag.
  static bool emptySlotWorthFilling(
    PartyHero hero,
    EquipmentItem item,
    int score,
  ) {
    final mass = roleRelevantStatMass(hero, item);
    final minIlvl = max(6, (hero.level * 0.55).floor());
    final ilvl = item.effectiveItemLevel;
    // Soft ilvl floor vs hero level — early crumbs (i5 on L20) stay in bag.
    // Strong mass still needs to be near the floor (not outleveled tank armor).
    final nearLevel = ilvl >= minIlvl - 2;

    if (mass >= 28 && nearLevel) return true;
    if (score >= 90 && mass >= 12 && nearLevel) return true;

    final spec = hero.spec;
    final affinityOk =
        item.affinity != null && item.affinity == spec.gearAffinity.name;
    final preferred = preferredArmorForSpec(spec, hero.level);
    final armorOk = preferred != null && item.armorType == preferred;
    if (!affinityOk && !armorOk) return false;

    if (ilvl >= minIlvl && mass >= 10) return true;
    if (ilvl >= minIlvl + 4 && mass >= 6) return true;
    // Preferred armor with decent mass even if slightly under ilvl floor.
    if (armorOk && nearLevel && mass >= 16) return true;
    return false;
  }

  /// Clear upgrade bar shared by Auto Equip, UI badges, and keep/sell helpers.
  ///
  /// Empty slots use [emptySlotWorthFilling]. Worn slots need a meaningful
  /// delta so +1 rarity/ilvl noise does not thrash gear.
  static bool isMeaningfulEquipUpgrade({
    required PartyHero hero,
    required EquipmentItem item,
    required int curScore,
    required int newScore,
    required bool slotEmpty,
  }) {
    final delta = newScore - curScore;
    if (delta <= 0) return false;
    if (slotEmpty) {
      return emptySlotWorthFilling(hero, item, newScore);
    }
    final minDelta = max(6, (curScore * 0.03).ceil());
    return delta >= minDelta;
  }

  /// Planned stash→slot upgrades from BiS assignment (shared by Auto Equip / Sell Junk).
  static List<({int heroIndex, EquipmentSlot slot, String itemId, int delta})>
      planBiSAssignments(GameState state) {
    final stashById = <String, EquipmentItem>{
      for (final item in state.gearStash) item.id: item,
    };
    if (stashById.isEmpty) return const [];

    final reserved = <String>{};
    final plan =
        <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];
    final filledSlots = <String>{};

    String slotKey(int heroIndex, EquipmentSlot slot) =>
        '$heroIndex:${slot.name}';

    for (var round = 0; round < 6; round++) {
      final proposals =
          <({int heroIndex, EquipmentSlot slot, String itemId, int delta})>[];

      for (var hi = 0; hi < state.heroes.length; hi++) {
        final hero = state.heroes[hi];
        String? plannedWeaponId;
        for (final p in plan) {
          if (p.heroIndex == hi && p.slot == EquipmentSlot.weapon) {
            plannedWeaponId = p.itemId;
            break;
          }
        }
        final plannedWeapon = plannedWeaponId == null
            ? hero.itemIn(EquipmentSlot.weapon)
            : stashById[plannedWeaponId] ?? hero.itemIn(EquipmentSlot.weapon);
        final blocksOffHand =
            ClassProficiency.weaponBlocksOffHand(plannedWeapon);

        for (final group in equipSlotGroups()) {
          if (blocksOffHand &&
              group.length == 1 &&
              group.first == EquipmentSlot.offHand) {
            continue;
          }

          final available = <EquipmentItem>[
            for (final item in state.gearStash)
              if (!reserved.contains(item.id)) item,
          ];

          final scored = <({EquipmentItem item, int score})>[];
          for (final item in available) {
            if (!equipTargetsFor(item).any(group.contains)) continue;
            var best = -999999;
            for (final slot in group) {
              if (filledSlots.contains(slotKey(hi, slot))) continue;
              if (!canHeroReceive(hero, item, slot: slot)) continue;
              best = max(best, slotEquipScore(hero, item, slot: slot));
            }
            if (best > -999999) {
              scored.add((item: item, score: best));
            }
          }
          scored.sort((a, b) => b.score.compareTo(a.score));

          final slots = [...group]..sort((a, b) {
              final sa = filledSlots.contains(slotKey(hi, a))
                  ? 999999
                  : slotEquipScore(hero, hero.itemIn(a), slot: a);
              final sb = filledSlots.contains(slotKey(hi, b))
                  ? 999999
                  : slotEquipScore(hero, hero.itemIn(b), slot: b);
              return sa.compareTo(sb);
            });

          final usedLocal = <String>{};
          for (final slot in slots) {
            if (filledSlots.contains(slotKey(hi, slot))) continue;
            final cur = hero.itemIn(slot);
            final curScore = slotEquipScore(hero, cur, slot: slot);
            for (final entry in scored) {
              if (usedLocal.contains(entry.item.id)) continue;
              if (reserved.contains(entry.item.id)) continue;
              if (!canHeroReceive(hero, entry.item, slot: slot)) continue;
              final sc = slotEquipScore(hero, entry.item, slot: slot);
              if (isMeaningfulEquipUpgrade(
                hero: hero,
                item: entry.item,
                curScore: curScore,
                newScore: sc,
                slotEmpty: cur == null,
              )) {
                usedLocal.add(entry.item.id);
                proposals.add((
                  heroIndex: hi,
                  slot: slot,
                  itemId: entry.item.id,
                  delta: sc - curScore,
                ));
                break;
              }
            }
          }
        }
      }

      if (proposals.isEmpty) break;

      final bestByItem = <String,
          ({int heroIndex, EquipmentSlot slot, String itemId, int delta})>{};
      for (final p in proposals) {
        final prev = bestByItem[p.itemId];
        if (prev == null || p.delta > prev.delta) {
          bestByItem[p.itemId] = p;
        }
      }

      final bestBySlot = <String,
          ({int heroIndex, EquipmentSlot slot, String itemId, int delta})>{};
      for (final p in bestByItem.values) {
        final key = slotKey(p.heroIndex, p.slot);
        final prev = bestBySlot[key];
        if (prev == null || p.delta > prev.delta) {
          bestBySlot[key] = p;
        }
      }

      var added = 0;
      final winners = bestBySlot.values.toList()
        ..sort((a, b) => b.delta.compareTo(a.delta));
      final claimedThisRound = <String>{};
      for (final w in winners) {
        if (reserved.contains(w.itemId)) continue;
        if (claimedThisRound.contains(w.itemId)) continue;
        final key = slotKey(w.heroIndex, w.slot);
        if (filledSlots.contains(key)) continue;
        reserved.add(w.itemId);
        claimedThisRound.add(w.itemId);
        filledSlots.add(key);
        plan.add(w);
        added++;
      }
      if (added == 0) break;
    }

    return plan;
  }

  /// Equip every stash piece that is a class-aware upgrade for some hero.
  ///
  /// Uses per-hero BiS slot fill with party-wide conflict resolution (largest
  /// power delta wins contested items; losers re-pick next round).
  /// Multi-pass so leftovers can fill after contested items resolve.
  static GameState autoEquipBetterGear(GameState state) {
    var next = state;
    for (var pass = 0; pass < 8; pass++) {
      final beforeLen = next.gearStash.length;
      next = _autoEquipPass(next);
      if (next.gearStash.length >= beforeLen) {
        break;
      }
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState _autoEquipPass(GameState state) {
    var next = state;
    final plan = planBiSAssignments(next);
    final ordered = [...plan]..sort((a, b) {
        final aw = a.slot == EquipmentSlot.weapon ? 0 : 1;
        final bw = b.slot == EquipmentSlot.weapon ? 0 : 1;
        return aw.compareTo(bw);
      });
    for (final step in ordered) {
      EquipmentItem? item;
      for (final g in next.gearStash) {
        if (g.id == step.itemId) {
          item = g;
          break;
        }
      }
      if (item == null) continue;
      final hero = next.heroes[step.heroIndex];
      if (!canHeroReceive(hero, item, slot: step.slot)) continue;
      final beforeLen = next.gearStash.length;
      next = equipFromStash(
        next,
        step.itemId,
        heroIndex: step.heroIndex,
        intoSlot: step.slot,
      );
      if (next.gearStash.length >= beforeLen) {
        continue;
      }
    }
    return next;
  }

  static String formatDelta(int value) {
    if (value > 0) return '+$value';
    if (value < 0) return '$value';
    return '0';
  }

  static bool canCombine(EquipmentItem primary, EquipmentItem secondary) =>
      primary.slot == secondary.slot &&
      primary.id != secondary.id &&
      !primary.isApex &&
      !secondary.isApex;

  static LootRarity mergedRarity(LootRarity primary, LootRarity secondary) {
    if (secondary.index > primary.index) {
      return secondary;
    }
    if (secondary.index == primary.index &&
        primary.index < LootRarity.legendary.index) {
      return LootRarity.values[primary.index + 1];
    }
    return primary;
  }

  static EquipmentItem mergeEquipment(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    return _mergedEquipment(
      primary,
      secondary,
      id: 'combined_${primary.slot.name}_${random.nextInt(1000000)}',
    );
  }

  /// Shows a combination result without changing state or consuming randomness.
  static EquipmentItem previewCombine(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    return _mergedEquipment(
      primary,
      secondary,
      id: 'preview_${primary.id}_${secondary.id}',
    );
  }

  static EquipmentItem _mergedEquipment(
    EquipmentItem primary,
    EquipmentItem secondary, {
    required String id,
  }) {
    final rarity = mergedRarity(primary.rarity, secondary.rarity);
    // Primary drives slot + pattern; secondary can upgrade pattern if rarer.
    final pattern = secondary.rarity.index > primary.rarity.index
        ? secondary.pattern
        : primary.pattern;
    final effectId = primary.effectId != GearEffectId.none
        ? primary.effectId
        : secondary.effectId;
    final effectValue = effectId == GearEffectId.none
        ? 0
        : max(primary.effectValue, secondary.effectValue);
    final affixPrefixId = primary.affixPrefixId ?? secondary.affixPrefixId;
    final affixSuffixId = primary.affixSuffixId ?? secondary.affixSuffixId;
    return EquipmentItem(
      id: id,
      name: _equipmentNameFor(
        primary.slot,
        rarity,
        bias: primary.affinity == null
            ? null
            : HeroRole.values.byName(primary.affinity!),
        armorType: primary.armorType ?? secondary.armorType,
        weaponType: primary.weaponType ?? secondary.weaponType,
        offHandKind: primary.offHandKind ?? secondary.offHandKind,
        handed: primary.handed ?? secondary.handed,
        affixPrefixId: affixPrefixId,
        affixSuffixId: affixSuffixId,
      ),
      slot: primary.slot,
      rarity: rarity,
      strengthBonus:
          primary.strengthBonus + ((secondary.strengthBonus * 50) ~/ 100),
      agilityBonus:
          primary.agilityBonus + ((secondary.agilityBonus * 50) ~/ 100),
      staminaBonus:
          primary.staminaBonus + ((secondary.staminaBonus * 50) ~/ 100),
      intellectBonus:
          primary.intellectBonus + ((secondary.intellectBonus * 50) ~/ 100),
      spiritBonus: primary.spiritBonus + ((secondary.spiritBonus * 50) ~/ 100),
      spellPowerBonus:
          primary.spellPowerBonus + ((secondary.spellPowerBonus * 50) ~/ 100),
      armorBonus: primary.armorBonus + ((secondary.armorBonus * 50) ~/ 100),
      mp5Bonus: primary.mp5Bonus + ((secondary.mp5Bonus * 50) ~/ 100),
      attackBonus: primary.attackBonus + ((secondary.attackBonus * 50) ~/ 100),
      defenseBonus:
          primary.defenseBonus + ((secondary.defenseBonus * 50) ~/ 100),
      vitalityBonus:
          primary.vitalityBonus + ((secondary.vitalityBonus * 50) ~/ 100),
      critChanceBonus:
          primary.critChanceBonus + ((secondary.critChanceBonus * 50) ~/ 100),
      attackSpeedBonus:
          primary.attackSpeedBonus + ((secondary.attackSpeedBonus * 50) ~/ 100),
      moveSpeedBonus:
          primary.moveSpeedBonus + ((secondary.moveSpeedBonus * 50) ~/ 100),
      pattern: pattern,
      effectId: effectId,
      effectValue: effectValue,
      affinity: primary.affinity ?? secondary.affinity,
      itemLevel: max(primary.effectiveItemLevel, secondary.effectiveItemLevel) +
          (rarity.index > primary.rarity.index ? 2 : 1),
      armorType: primary.armorType ?? secondary.armorType,
      weaponType: primary.weaponType ?? secondary.weaponType,
      handed: primary.handed ?? secondary.handed,
      offHandKind: primary.offHandKind ?? secondary.offHandKind,
      iconId: primary.iconId ?? secondary.iconId,
      affixPrefixId: affixPrefixId,
      affixSuffixId: affixSuffixId,
      setId: primary.setId ?? secondary.setId,
    );
  }

  /// Combines two same-slot pieces (stash and/or equipped). Primary keeps
  /// slot/pattern identity; secondary contributes half its stats.
  static GameState combineGear(
    GameState state, {
    required String primaryId,
    required String secondaryId,
  }) {
    final primary = findGear(state, primaryId);
    final secondary = findGear(state, secondaryId);
    if (primary == null || secondary == null) {
      return state;
    }
    if (!canCombine(primary, secondary)) {
      return state;
    }
    final cost = combineCost(
      primary,
      secondary,
      combinatorLuck: state.metaDepth.combinatorLuck,
    );
    if (state.gold < cost) {
      return state;
    }

    var next = state.copyWith(gold: state.gold - cost);
    next = removeGear(next, primaryId);
    next = removeGear(next, secondaryId);

    final result = mergeEquipment(primary, secondary);
    // Always stash result — player equips manually.
    next = stashEquipment(next, result);

    return next.copyWith(lastUpdated: DateTime.now());
  }

  /// Gear always goes to stash (manual equip). Non-gear → essence.
  /// Weak junk is auto-sold for **gold** or auto-disassembled for **essence**
  /// on pickup when filters match (sell checked first).
  static ({GameState state, List<LootDrop> resolved}) applyLootDrops(
    GameState state,
    List<LootDrop> drops,
  ) {
    var next = state;
    final resolved = <LootDrop>[];

    for (final drop in drops) {
      final item = drop.equipment;
      if (item == null) {
        if (isWalletGoldDrop(drop)) {
          final gained = applyGoldGain(next, drop.amount);
          if (gained > 0) {
            next = next.copyWith(
              gold: next.gold + gained,
              lifetimeGoldEarned: next.lifetimeGoldEarned + gained,
            );
          }
          resolved.add(
            drop.copyWith(outcome: LootOutcome.gold, essenceGained: 0),
          );
          continue;
        }
        final essence = lootEssenceValue(drop);
        next = next.copyWith(essence: next.essence + essence);
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: essence),
        );
        continue;
      }

      if (_shouldAutoSellOnPickup(next, item)) {
        final value = equipmentGoldValue(item);
        next = next.copyWith(
          gold: next.gold + value,
          lifetimeGoldEarned: next.lifetimeGoldEarned + value,
        );
        resolved.add(
          drop.copyWith(outcome: LootOutcome.gold, essenceGained: 0),
        );
        continue;
      }

      if (_shouldAutoDisassembleOnPickup(next, item)) {
        final value = equipmentEssenceValue(item);
        next = next.copyWith(essence: next.essence + value);
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: value),
        );
        continue;
      }

      final stashed = stashEquipmentDetailed(next, item);
      next = stashed.state;
      resolved.add(
        drop.copyWith(
          outcome: LootOutcome.stashed,
          essenceGained: stashed.overflowEssence,
        ),
      );
    }

    // Live spatial loot never goes through completeCurrentRoom meta progress.
    next = MetaSystems.registerItemDrops(next, drops);
    // Near-full bag: merge → sell gold → disassemble essence.
    next = unstickBagIfNeeded(next);
    return (state: next, resolved: resolved);
  }

  /// Run merge + auto-sell + auto-disassemble when stash is ≥90% full.
  static GameState unstickBagIfNeeded(GameState state) {
    final cap = maxGearStashFor(state);
    if (state.gearStash.length < (cap * 0.9).ceil()) {
      return state;
    }
    return cleanBagJunk(state, unstickBag: true);
  }

  /// Merge junk (optional), then auto-sell for gold, then auto-disassemble
  /// for essence. [unstickBag] keeps only BiS/soulbound/best-per-slot.
  static GameState cleanBagJunk(
    GameState state, {
    bool unstickBag = false,
    bool mergeFirst = true,
  }) {
    var next = state;
    if (mergeFirst) {
      next = autoMergeJunk(next).state;
    }
    next = autoSellJunk(next, unstickBag: unstickBag);
    next = autoDisassembleJunk(next, unstickBag: unstickBag);
    return next;
  }

  static bool _matchesIlvlRarityFilter(
    EquipmentItem item, {
    required int maxIlvl,
    required int maxRarity,
  }) {
    if (maxIlvl <= 0) return false;
    if (item.effectiveItemLevel > maxIlvl) return false;
    if (item.rarity.index > maxRarity.clamp(0, 4)) return false;
    return true;
  }

  static bool _shouldAutoSellOnPickup(GameState state, EquipmentItem item) {
    if (!_matchesIlvlRarityFilter(
      item,
      maxIlvl: state.autoSellMaxPower,
      maxRarity: state.autoSellMaxRarity,
    )) {
      return false;
    }
    return !_shouldKeepInBag(state, item);
  }

  static bool _shouldAutoDisassembleOnPickup(
    GameState state,
    EquipmentItem item,
  ) {
    if (!_matchesIlvlRarityFilter(
      item,
      maxIlvl: state.autoDisassembleMaxIlvl,
      maxRarity: state.autoDisassembleMaxRarity,
    )) {
      return false;
    }
    return !_shouldKeepInBag(state, item);
  }

  /// Keep bag piece if BiS planning would equip it, or it upgrades a worn slot.
  /// Empty slots alone do not keep forever — BiS plan covers meaningful fills.
  static bool _shouldKeepInBag(GameState state, EquipmentItem item) {
    if (item.isApex) return true;
    // Pickup path: candidate is not in stash yet — probe as if stashed so BiS
    // planning can claim it before auto-sell.
    final probe = state.gearStash.any((g) => g.id == item.id)
        ? state
        : state.copyWith(gearStash: [...state.gearStash, item]);
    final plan = planBiSAssignments(probe);
    if (plan.any((p) => p.itemId == item.id)) {
      return true;
    }
    for (final hero in state.heroes) {
      for (final slot in equipTargetsFor(item)) {
        if (!canHeroReceive(hero, item, slot: slot)) {
          continue;
        }
        if (hero.itemIn(slot) == null) {
          continue;
        }
        if (_compareForHeroSlot(hero, item, slot).isUpgrade) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether [item] should stay when cleaning the bag.
  ///
  /// [mode] `sell` uses gold filters; `disassemble` uses essence filters.
  /// [unstickBag]: keep BiS/soulbound/apex and the strongest piece per slot.
  static bool _shouldKeepWhenCleaning(
    GameState state,
    EquipmentItem item, {
    required bool forSell,
    bool unstickBag = false,
  }) {
    if (unstickBag) {
      if (item.isApex ||
          item.id.contains('soulbound') ||
          item.name.toLowerCase().startsWith('soulbound')) {
        return true;
      }
      final plan = planBiSAssignments(state);
      if (plan.any((p) => p.itemId == item.id)) {
        return true;
      }
      EquipmentItem? best;
      var bestScore = -999999;
      var bestIlvl = -1;
      for (final other in state.gearStash) {
        if (other.slot != item.slot) continue;
        final score = _partySlotScore(state, other);
        final ilvl = other.effectiveItemLevel;
        if (score > bestScore ||
            (score == bestScore && ilvl > bestIlvl)) {
          best = other;
          bestScore = score;
          bestIlvl = ilvl;
        }
      }
      return best?.id == item.id;
    }
    if (_shouldKeepInBag(state, item)) {
      return true;
    }
    final matches = forSell
        ? _matchesIlvlRarityFilter(
            item,
            maxIlvl: state.autoSellMaxPower,
            maxRarity: state.autoSellMaxRarity,
          )
        : _matchesIlvlRarityFilter(
            item,
            maxIlvl: state.autoDisassembleMaxIlvl,
            maxRarity: state.autoDisassembleMaxRarity,
          );
    // Matching filter → eligible to clean (do not keep).
    if (matches) return false;
    // Outside filter: keep rare+ while bag has room; commons may still go in
    // unstick-only passes.
    if (item.rarity.index >= LootRarity.rare.index) {
      return true;
    }
    // Non-matching common/uncommon: keep unless filters are off entirely
    // (manual clean with filters off should not dump everything).
    return true;
  }

  /// Best slotEquipScore for [item] across heroes who can wear it.
  static int _partySlotScore(GameState state, EquipmentItem item) {
    var best = 0;
    for (final hero in state.heroes) {
      for (final slot in equipTargetsFor(item)) {
        if (!canHeroReceive(hero, item, slot: slot)) continue;
        best = max(best, slotEquipScore(hero, item, slot: slot));
      }
    }
    return best;
  }

  /// Auto-merge junk pairs in the bag: same slot, neither is a BiS/upgrade keep,
  /// while gold covers [combineCost]. Stronger piece is base; weaker is fuel.
  ///
  /// Returns the updated state and how many merges ran (0 if none possible).
  static ({GameState state, int merges}) autoMergeJunk(
    GameState state, {
    int maxMerges = 40,
  }) {
    var next = state;
    var merges = 0;
    while (merges < maxMerges) {
      EquipmentItem? base;
      EquipmentItem? fuel;
      var bestScore = 1 << 30;
      for (var i = 0; i < next.gearStash.length; i++) {
        final a = next.gearStash[i];
        if (_shouldKeepInBag(next, a)) {
          continue;
        }
        for (var j = i + 1; j < next.gearStash.length; j++) {
          final b = next.gearStash[j];
          if (a.slot != b.slot || _shouldKeepInBag(next, b)) {
            continue;
          }
          final cost = combineCost(
            a,
            b,
            combinatorLuck: next.metaDepth.combinatorLuck,
          );
          if (next.gold < cost) {
            continue;
          }
          final score = a.powerScore + b.powerScore;
          if (score >= bestScore) {
            continue;
          }
          bestScore = score;
          if (a.powerScore >= b.powerScore) {
            base = a;
            fuel = b;
          } else {
            base = b;
            fuel = a;
          }
        }
      }
      if (base == null || fuel == null) {
        break;
      }
      final goldBefore = next.gold;
      next = combineGear(
        next,
        primaryId: base.id,
        secondaryId: fuel.id,
      );
      if (next.gold >= goldBefore) {
        break;
      }
      merges++;
    }
    return (state: next, merges: merges);
  }

  /// Last [autoSellJunk] counts (consumed by UI toasts).
  static int lastAutoSellCount = 0;
  static int lastAutoSellGold = 0;

  /// Last [autoDisassembleJunk] counts (consumed by UI toasts).
  static int lastAutoDisassembleCount = 0;
  static int lastAutoDisassembleEssence = 0;

  /// Sell stash junk for **gold** (iLvl + rarity filters; BiS kept).
  static GameState autoSellJunk(
    GameState state, {
    bool unstickBag = false,
  }) {
    var gold = state.gold;
    var lifetime = state.lifetimeGoldEarned;
    var stash = List<EquipmentItem>.from(state.gearStash);
    final beforeLen = stash.length;
    var gained = 0;
    var guard = 0;
    while (guard < 64) {
      guard++;
      final probe = state.copyWith(gearStash: stash, gold: gold);
      EquipmentItem? sellItem;
      for (final item in stash) {
        if (!_shouldKeepWhenCleaning(
          probe,
          item,
          forSell: true,
          unstickBag: unstickBag,
        )) {
          sellItem = item;
          break;
        }
      }
      if (sellItem == null) break;
      final value = equipmentGoldValue(sellItem);
      gold += value;
      lifetime += value;
      gained += value;
      stash = stash.where((g) => g.id != sellItem!.id).toList();
    }
    lastAutoSellCount = beforeLen - stash.length;
    lastAutoSellGold = gained;
    return state.copyWith(
      gearStash: stash,
      gold: gold,
      lifetimeGoldEarned: lifetime,
      lastUpdated: DateTime.now(),
    );
  }

  /// Disassemble stash junk for **essence** (iLvl + rarity filters; BiS kept).
  static GameState autoDisassembleJunk(
    GameState state, {
    bool unstickBag = false,
  }) {
    var essence = state.essence;
    var stash = List<EquipmentItem>.from(state.gearStash);
    final beforeLen = stash.length;
    var gained = 0;
    var guard = 0;
    while (guard < 64) {
      guard++;
      final probe = state.copyWith(gearStash: stash, essence: essence);
      EquipmentItem? scrap;
      for (final item in stash) {
        if (!_shouldKeepWhenCleaning(
          probe,
          item,
          forSell: false,
          unstickBag: unstickBag,
        )) {
          scrap = item;
          break;
        }
      }
      if (scrap == null) break;
      final value = equipmentEssenceValue(scrap);
      essence += value;
      gained += value;
      stash = stash.where((g) => g.id != scrap!.id).toList();
    }
    lastAutoDisassembleCount = beforeLen - stash.length;
    lastAutoDisassembleEssence = gained;
    return state.copyWith(
      gearStash: stash,
      essence: essence,
      lastUpdated: DateTime.now(),
    );
  }

  static String rarityFilterLabel(int rarityIndex) {
    final i = rarityIndex.clamp(0, LootRarity.values.length - 1);
    return switch (LootRarity.values[i]) {
      LootRarity.common => 'Common',
      LootRarity.uncommon => 'Uncommon',
      LootRarity.rare => 'Rare',
      LootRarity.epic => 'Epic',
      LootRarity.legendary => 'Legendary',
    };
  }

  static int recommendedForgeUpgrade(GameState state) {
    // Pick the forge track most behind relative to cost.
    final scores = <(int, double)>[
      for (final type in PartyUpgradeType.values)
        (
          type.index,
          switch (type) {
                PartyUpgradeType.attack => state.attackBonus / 2,
                PartyUpgradeType.defense => state.defenseBonus.toDouble(),
                PartyUpgradeType.vitality => state.vitalityBonus / 6,
                PartyUpgradeType.moveSpeed => state.moveSpeedBonus / 2,
                PartyUpgradeType.attackSpeed => state.attackSpeedBonus / 2,
                PartyUpgradeType.crit => state.critBonus.toDouble(),
              } /
              max(1, upgradeCostFor(state, type)),
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

  static LootRarity _rarityForBattle(
    int battleNumber, {
    int hardmodeLevel = 0,
  }) {
    final hm = hardmodeLevel.clamp(0, Keystone.maxLevel);
    // Direct legendary roll — key 20 ≈ old HM+10.
    final legendaryChance = Keystone.legendaryChance(hm);
    if (random.nextDouble() < legendaryChance) {
      return LootRarity.legendary;
    }

    var rarity = LootRarity.common;
    if (battleNumber % 12 == 0) {
      rarity = LootRarity.epic;
    } else if (battleNumber % 6 == 0) {
      rarity = LootRarity.rare;
    } else if (battleNumber % 3 == 0) {
      rarity = LootRarity.uncommon;
    }

    // Keystone can bump the base tier (never past legendary).
    final bumpChance = Keystone.rarityBump(hm);
    if (rarity.index < LootRarity.legendary.index &&
        random.nextDouble() < bumpChance) {
      rarity = LootRarity.values[rarity.index + 1];
    }
    if (rarity.index < LootRarity.legendary.index &&
        hm >= 14 &&
        random.nextDouble() < bumpChance * 0.5) {
      rarity = LootRarity.values[rarity.index + 1];
    }
    return rarity;
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
    // Floor fillers (sigil / pouch / relic / vial) once per clear.
    final floorDrops = rollFloorClearLoot(
      room.globalBattleNumber,
      roomType: room.type,
    );
    if (skipLootRoll) {
      // Combat: kill gear already applied on pickup; still grant floor fillers.
      final lootResult = applyLootDrops(state, floorDrops);
      awarded = lootResult.state;
      drops = lootResult.resolved;
    } else {
      // Treasure (and any explicit full roll): chest gear + floor fillers.
      final rawDrops = _finalizeLootDrops([
        ...rollKillLoot(
          room.globalBattleNumber,
          ascensionLevel: state.ascensionLevel,
          lootFindPercent: state.petLootFindPercent,
          hardmodeLevel: Keystone.combatLevel(state),
          party: state.heroes,
          dungeonId: state.dungeonId,
        ),
        ...floorDrops,
      ]);
      final lootResult = applyLootDrops(state, rawDrops);
      awarded = lootResult.state;
      drops = lootResult.resolved;
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
    final goldAwarded =
        applyGoldGain(awarded, (goldGain * goldMul).round());
    final farmLoop = awarded.dungeonMode == DungeonMode.farm;
    final clearedBoss = bossesCleared > 0;
    final gauntlet = awarded.inGauntlet;
    // Zone HFC only — Gauntlet climb lives on metaDepth.gauntletBestFloor
    // so Ascend fragments keep using real zone clears.
    final highest = gauntlet
        ? awarded.highestFloorCleared
        : max(awarded.highestFloorCleared, room.floorNumber);
    awarded = grantBossCraftMats(awarded, clearedBoss: clearedBoss);
    // Auto-wear clear upgrades so bag loot powers the party every Ascension.
    awarded = autoEquipBetterGear(awarded);

    // Push + boss floor clear → dungeon cleared, back to hub.
    // Gauntlet never exits on boss — endless climb.
    // Daily echo: claim on first clear, then return to hub (one floor).
    final wasDaily = MetaSystems.isActiveDailyRun(state);
    if (!farmLoop && clearedBoss && !gauntlet) {
      final def = DungeonCatalog.byId(awarded.dungeonId);
      var progressed = awarded.copyWith(
        gold: awarded.gold + goldAwarded,
        lifetimeGoldEarned: awarded.lifetimeGoldEarned + goldAwarded,
        bossVictories: awarded.bossVictories + bossesCleared,
        highestFloorCleared: highest,
        highestDungeonCleared: max(awarded.highestDungeonCleared, def.number),
        inDungeon: false,
        recentLoot: drops,
        heroes: awarded.heroes
            .map(
              (hero) =>
                  hero.copyWith(currentHp: awarded.effectiveHeroMaxHp(hero)),
            )
            .toList(),
      );
      progressed = _applyMetaProgress(state, progressed, drops);
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
              lifetimeGauntletFloors:
                  awarded.metaDepth.lifetimeGauntletFloors + 1,
            )
          : awarded.metaDepth,
    );
    progressed = _applyMetaProgress(state, progressed, drops);

    // Daily echo ends after the first clear (reward claimed) — no PUSH climb.
    if (wasDaily && progressed.dailyClaimed) {
      progressed = progressed.copyWith(
        inDungeon: false,
        heroes: progressed.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: progressed.effectiveHeroMaxHp(hero),
              ),
            )
            .toList(),
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
    // Daily vault: push clears (or any boss). Gauntlet clears count at AL10+.
    // Farm loops never mint vault progress.
    final gauntletVault =
        before.inGauntlet && before.ascensionLevel >= gauntletMinAscension;
    final vaultBump = (!farmLoop && (!before.inGauntlet || gauntletVault)) ||
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
    if (keystoneNotices.isNotEmpty) {
      lastMetaPayoffNotices = [
        ...lastMetaPayoffNotices,
        ...keystoneNotices,
      ];
    }
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
        25 + state.metaDepth.dailyEssenceBonusLevel * 5;
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
      enemies: createEnemyGroup(
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

  /// Parses a save of any version, migrating legacy v1 saves
  /// (single `enemy` + stored `battleNumber`) to the room-based v2 model.
  static GameState stateFromJson(Map<String, dynamic> json) {
    final loaded = json.containsKey('enemies')
        ? GameState.fromJson(json)
        : _migrateV1(json);
    final legacyBoard = loaded.missions.any(
      (m) =>
          m.id == 'defeat_enemies' ||
          m.id == 'clear_bosses' ||
          m.id == 'earn_gold',
    );
    var next = loaded.missions.isNotEmpty && !legacyBoard
        ? loaded
        : loaded.copyWith(
            missions: createMissionBoard(
              ascensionLevel: loaded.ascensionLevel,
              highestDungeonCleared: loaded.highestDungeonCleared,
              highestFloorCleared: loaded.highestFloorCleared,
              hardmodeLevel: loaded.hardmodeLevel,
            ),
          );
    if (next.ascensionLevel > 0) {
      next = next.copyWith(rogueUnlocked: true);
    }
    return MetaSystems.evaluateAchievements(
      syncSpecUnlocks(ensureRogueHero(next)),
    );
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

  static const int maxLoadouts = 3;

  /// Captures each hero's currently-equipped gear as a named preset.
  /// Replaces an existing loadout with the same [id], otherwise appends
  /// (capped at [maxLoadouts] — oldest is dropped to make room).
  static GameState saveLoadout(
    GameState state, {
    required String id,
    required String name,
  }) {
    final heroIds = <String>[for (final hero in state.heroes) hero.id];
    final heroSlots = <Map<String, String>>[
      for (final hero in state.heroes)
        <String, String>{
          for (final entry in hero.equipped.entries)
            entry.key.name: entry.value.id,
        },
    ];
    final loadout = GearLoadout(
      id: id,
      name: name,
      heroSlotItemIds: heroSlots,
      heroIds: heroIds,
    );
    final next = List<GearLoadout>.from(state.loadouts);
    final existingIndex = next.indexWhere((l) => l.id == id);
    if (existingIndex >= 0) {
      next[existingIndex] = loadout;
    } else {
      if (next.length >= maxLoadouts) {
        next.removeAt(0);
      }
      next.add(loadout);
    }
    return state.copyWith(loadouts: next, lastUpdated: DateTime.now());
  }

  static GameState deleteLoadout(GameState state, String id) {
    if (!state.loadouts.any((l) => l.id == id)) return state;
    return state.copyWith(
      loadouts: state.loadouts.where((l) => l.id != id).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Locates [itemId] anywhere it might currently live (any roster hero's
  /// equipped gear, or the stash) and removes it from there.
  static (EquipmentItem?, GameState) _extractItemById(
    GameState state,
    String itemId,
  ) {
    for (var i = 0; i < state.heroRoster.length; i++) {
      final hero = state.heroRoster[i];
      for (final entry in hero.equipped.entries) {
        if (entry.value.id == itemId) {
          final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
            hero.equipped,
          )..remove(entry.key);
          final roster = [...state.heroRoster];
          roster[i] = hero.copyWith(equipped: nextGear);
          return (entry.value, state.copyWith(heroRoster: roster));
        }
      }
    }
    for (final item in state.gearStash) {
      if (item.id == itemId) {
        return (
          item,
          state.copyWith(
            gearStash: state.gearStash.where((g) => g.id != itemId).toList(),
          ),
        );
      }
    }
    for (final item in state.apexVault) {
      if (item.id == itemId) {
        return (
          item,
          state.copyWith(
            apexVault: state.apexVault.where((g) => g.id != itemId).toList(),
          ),
        );
      }
    }
    return (null, state);
  }

  /// Re-equips a saved [GearLoadout] by id. Items sold/lost since the
  /// loadout was saved are skipped (counted in [skipped]); items that fail a
  /// class proficiency check are returned to the stash.
  static ({GameState state, int skipped}) applyLoadout(
    GameState state,
    String id,
  ) {
    GearLoadout? loadout;
    for (final l in state.loadouts) {
      if (l.id == id) {
        loadout = l;
        break;
      }
    }
    if (loadout == null) return (state: state, skipped: 0);

    var next = state;
    var skipped = 0;
    final useIds = loadout.heroIds.isNotEmpty &&
        loadout.heroIds.length == loadout.heroSlotItemIds.length;

    for (var slotIndex = 0;
        slotIndex < loadout.heroSlotItemIds.length;
        slotIndex++) {
      late int rosterIndex;
      if (useIds) {
        final heroId = loadout.heroIds[slotIndex];
        final idx = next.heroRoster.indexWhere((h) => h.id == heroId);
        if (idx < 0) continue;
        rosterIndex = idx;
      } else {
        if (slotIndex >= next.heroes.length) break;
        final activeId = next.heroes[slotIndex].id;
        final idx = next.heroRoster.indexWhere((h) => h.id == activeId);
        if (idx < 0) continue;
        rosterIndex = idx;
      }

      for (final entry in loadout.heroSlotItemIds[slotIndex].entries) {
        final slot = EquipmentSlotX.parse(entry.key);
        final itemId = entry.value;
        final target = next.heroRoster[rosterIndex];
        if (target.itemIn(slot)?.id == itemId) {
          continue;
        }
        final extracted = _extractItemById(next, itemId);
        final item = extracted.$1;
        next = extracted.$2;
        // Re-resolve index after roster mutation.
        final resolved = useIds
            ? next.heroRoster
                .indexWhere((h) => h.id == loadout!.heroIds[slotIndex])
            : next.heroRoster
                .indexWhere((h) => h.id == next.heroes[slotIndex].id);
        if (resolved < 0) continue;
        rosterIndex = resolved;
        if (item == null) {
          skipped++;
          continue;
        }

        final hero = next.heroRoster[rosterIndex];
        if (!ClassProficiency.canEquip(
          role: hero.gearAffinity,
          level: hero.level,
          item: item,
          specId: hero.specId,
        )) {
          next = stashEquipment(next, item);
          skipped++;
          continue;
        }
        final current = hero.itemIn(slot);
        if (current != null) {
          next = stashEquipment(next, current);
        }
        final nextGear = Map<EquipmentSlot, EquipmentItem>.from(
          next.heroRoster[rosterIndex].equipped,
        )..[slot] = item;
        final roster = [...next.heroRoster];
        roster[rosterIndex] =
            next.heroRoster[rosterIndex].copyWith(equipped: nextGear);
        next = next.copyWith(heroRoster: roster);
      }
    }

    next = next.copyWith(
      heroes: next.heroes
          .map(
            (hero) => hero.copyWith(
              currentHp: min(next.effectiveHeroMaxHp(hero), hero.currentHp),
            ),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
    return (state: next, skipped: skipped);
  }

  static GameState setSoulboundPreferArmor(GameState state, bool preferArmor) {
    if (state.metaDepth.soulboundIsArmor == preferArmor) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(soulboundIsArmor: preferArmor),
      lastUpdated: DateTime.now(),
    );
  }

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
      ascensionLevel: (json['ascensionLevel'] as int?) ?? 0,
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
}

/// Snapshot of what AFK time awarded on a single apply.
class OfflineProgressResult {
  const OfflineProgressResult({
    required this.state,
    required this.secondsApplied,
    required this.goldGained,
    required this.essenceGained,
    required this.roomsCleared,
    required this.highestFloorDelta,
    required this.bossDelta,
  });

  final GameState state;
  final int secondsApplied;
  final int goldGained;
  final int essenceGained;
  final int roomsCleared;
  final int highestFloorDelta;
  final int bossDelta;

  bool get foughtWhileAway =>
      roomsCleared > 0 || highestFloorDelta > 0 || bossDelta > 0;

  bool get hasSummary =>
      secondsApplied >= 45 &&
      (goldGained > 0 ||
          essenceGained > 0 ||
          roomsCleared > 0 ||
          highestFloorDelta > 0 ||
          bossDelta > 0);

  /// Compact chip / banner line — lead with the wow, then the numbers.
  String get headline {
    final away = formatOfflineDuration(secondsApplied);
    if (!hasSummary) return 'Away $away';
    final lead = foughtWhileAway
        ? 'Party kept fighting'
        : 'Sanctuary kept earning';
    final parts = <String>['$lead · Away $away'];
    if (goldGained > 0) parts.add('+${goldGained}g');
    if (essenceGained > 0) parts.add('+$essenceGained ess');
    if (roomsCleared > 0) parts.add('$roomsCleared clears');
    if (highestFloorDelta > 0) parts.add('floor +$highestFloorDelta');
    if (bossDelta > 0) parts.add('boss x$bossDelta');
    return parts.join(' · ');
  }

  /// Dialog lead sentence under the duration.
  String get welcomeLead {
    if (foughtWhileAway) {
      if (bossDelta > 0 && highestFloorDelta > 0) {
        return 'Your party pushed floors and dropped bosses while you were gone.';
      }
      if (bossDelta > 0) {
        return 'Bosses fell while you were away — Ascend progress moved.';
      }
      if (highestFloorDelta > 0 || roomsCleared > 0) {
        return 'Your party cleared rooms while you were away.';
      }
    }
    if (goldGained > 0 || essenceGained > 0) {
      return 'Sanctuary idle gold stacked up while you were away.';
    }
    return 'Welcome back.';
  }

  /// Non-zero reward rows for the welcome dialog (label, value).
  List<(String, String)> get highlightRows {
    final rows = <(String, String)>[];
    if (goldGained > 0) rows.add(('Gold earned', '+${goldGained}g'));
    if (essenceGained > 0) {
      rows.add(('Essence earned', '+$essenceGained'));
    }
    if (roomsCleared > 0) {
      rows.add(('Rooms cleared', '$roomsCleared'));
    }
    if (highestFloorDelta > 0) {
      rows.add(('Floor progress', '+$highestFloorDelta'));
    }
    if (bossDelta > 0) {
      rows.add(('Bosses defeated', '$bossDelta'));
    }
    return rows;
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
