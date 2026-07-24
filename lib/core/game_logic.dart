import 'dart:math';

import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/mission.dart';
import '../models/pet.dart';
import '../models/stats.dart';
import 'dungeon_generator.dart';
import 'game_state.dart';

class GameLogic {
  /// Injectable randomness for enemy targeting (seed in tests).
  static Random random = Random();

  static const String warBannerRelic = 'war_banner';
  static const String ironWardRelic = 'iron_ward';
  static const String phoenixEmberRelic = 'phoenix_ember';
  static const List<String> relicOrder = <String>[
    warBannerRelic,
    ironWardRelic,
    phoenixEmberRelic,
  ];
  static const Map<LootRarity, String> rarityNames = <LootRarity, String>{
    LootRarity.common: 'Common',
    LootRarity.uncommon: 'Uncommon',
    LootRarity.rare: 'Rare',
    LootRarity.epic: 'Epic',
  };
  static const Map<String, String> relicNames = <String, String>{
    warBannerRelic: 'War Banner',
    ironWardRelic: 'Iron Ward',
    phoenixEmberRelic: 'Phoenix Ember',
  };
  static const Map<String, String> relicDescriptions = <String, String>{
    warBannerRelic: 'Permanent +4 team attack aura.',
    ironWardRelic: 'Permanent +2 team defense aura.',
    phoenixEmberRelic: 'Permanent +10 max HP for every hero.',
  };
  static const Map<String, int> relicCosts = <String, int>{
    warBannerRelic: 6,
    ironWardRelic: 14,
    phoenixEmberRelic: 28,
  };

  static GameState createInitialState({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final floor = DungeonGenerator.generateFloor(1);
    final firstRoom = floor.first;
    return GameState(
      heroes: <PartyHero>[
        PartyHero.starting(
          name: 'Aegis',
          role: HeroRole.warrior,
          stats: const Stats(attack: 8, defense: 4, maxHp: 40),
        ),
        PartyHero.starting(
          name: 'Vale',
          role: HeroRole.healer,
          stats: const Stats(attack: 6, defense: 3, maxHp: 34),
        ),
        PartyHero.starting(
          name: 'Ember',
          role: HeroRole.mage,
          stats: const Stats(attack: 5, defense: 2, maxHp: 30),
        ),
      ],
      enemies: createEnemyGroup(firstRoom),
      gold: 0,
      essence: 0,
      bossVictories: 0,
      lastUpdated: timestamp,
      offlineSecondsRecovered: 0,
      attackBonus: 0,
      defenseBonus: 0,
      vitalityBonus: 0,
      recentLoot: <LootDrop>[],
      unlockedRelics: <String>[],
      currentRoom: firstRoom,
      dungeonFloor: floor,
      ascensionLevel: 0,
      equippedWeapon: null,
      equippedArmor: null,
      missions: createMissionBoard(ascensionLevel: 0),
      gearStash: const <EquipmentItem>[],
      dungeonMode: DungeonMode.farm,
      highestFloorCleared: 0,
      activePet: null,
      ownedPets: const <Pet>[],
      sanctuaryGoldLevel: 0,
      sanctuaryPowerLevel: 0,
      sanctuaryVitalityLevel: 0,
    );
  }

  static const Map<String, String> sanctuaryNames = <String, String>{
    'gold': 'Gold Find',
    'power': 'War Altar',
    'vitality': 'Life Well',
  };

  static int sanctuaryCost(int level) => 12 + (level * 10);

  static GameState upgradeSanctuary(GameState state, String track) {
    final level = switch (track) {
      'gold' => state.sanctuaryGoldLevel,
      'power' => state.sanctuaryPowerLevel,
      'vitality' => state.sanctuaryVitalityLevel,
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
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static const List<({String id, String name, int attack})> petCatalog =
      <({String id, String name, int attack})>[
        (id: 'ember_pup', name: 'Ember Pup', attack: 2),
        (id: 'cave_bat', name: 'Cave Bat', attack: 3),
        (id: 'loot_sprite', name: 'Loot Sprite', attack: 1),
        (id: 'warden_cub', name: 'Warden Cub', attack: 4),
      ];

  static int hatchPetCost(GameState state) => 20 + (state.ownedPets.length * 15);

  static GameState hatchPet(GameState state) {
    final cost = hatchPetCost(state);
    if (state.essence < cost) {
      return state;
    }
    final template = petCatalog[random.nextInt(petCatalog.length)];
    final pet = Pet(
      id: '${template.id}_${random.nextInt(100000)}',
      name: template.name,
      attackBonus: template.attack + state.ascensionLevel,
    );
    final pets = List<Pet>.from(state.ownedPets)..add(pet);
    return state.copyWith(
      essence: state.essence - cost,
      ownedPets: pets,
      activePet: state.activePet ?? pet,
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

  static GameState setDungeonMode(GameState state, DungeonMode mode) {
    if (state.dungeonMode == mode) {
      return state;
    }
    return state.copyWith(dungeonMode: mode, lastUpdated: DateTime.now());
  }

  static bool canTravelToFloor(GameState state, int floorNumber) {
    if (floorNumber < 1) {
      return false;
    }
    return floorNumber <= state.maxReachableFloor;
  }

  /// Jump to room 1 of an unlocked floor (farm/push zone select).
  static GameState travelToFloor(GameState state, int floorNumber) {
    if (!canTravelToFloor(state, floorNumber)) {
      return state;
    }
    if (floorNumber == state.currentRoom.floorNumber &&
        state.currentRoom.roomIndex == 0 &&
        !state.isPartyDefeated) {
      return state;
    }
    final floor = DungeonGenerator.generateFloor(floorNumber);
    final firstRoom = floor.first;
    return state.copyWith(
      currentRoom: firstRoom,
      dungeonFloor: floor,
      enemies: createEnemyGroup(firstRoom),
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Failed push: retreat to the highest cleared floor (or floor 1).
  static GameState retreatFromFailedPush(GameState state) {
    final safeFloor = max(1, state.highestFloorCleared);
    return travelToFloor(
      state.copyWith(dungeonMode: DungeonMode.farm),
      safeFloor,
    );
  }

  /// Builds the standard 3-contract board scaled by Ascension Level.
  static List<Mission> createMissionBoard({required int ascensionLevel}) {
    return MissionType.values
        .map((type) => createMission(type: type, ascensionLevel: ascensionLevel))
        .toList();
  }

  static Mission createMission({
    required MissionType type,
    required int ascensionLevel,
  }) {
    final al = ascensionLevel;
    return switch (type) {
      MissionType.defeatEnemies => Mission(
        id: 'defeat_enemies',
        type: type,
        title: 'Slay foes',
        target: 8 + (al * 4),
        progress: 0,
        goldReward: 20 + (al * 12),
        essenceReward: 2 + al,
      ),
      MissionType.clearBosses => Mission(
        id: 'clear_bosses',
        type: type,
        title: 'Fell wardens',
        target: max(1, 1 + (al ~/ 2)),
        progress: 0,
        goldReward: 35 + (al * 18),
        essenceReward: 3 + al,
      ),
      MissionType.earnGold => Mission(
        id: 'earn_gold',
        type: type,
        title: 'Gather gold',
        target: 40 + (al * 35),
        progress: 0,
        goldReward: 15 + (al * 10),
        essenceReward: 2 + (al ~/ 2),
      ),
    };
  }

  static GameState applyMissionProgress(
    GameState state, {
    int enemiesDefeated = 0,
    int bossesCleared = 0,
    int goldEarned = 0,
  }) {
    if (state.missions.isEmpty) {
      return state;
    }
    if (enemiesDefeated <= 0 && bossesCleared <= 0 && goldEarned <= 0) {
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
    final index = state.missions.indexWhere((mission) => mission.id == missionId);
    if (index < 0) {
      return state;
    }
    final mission = state.missions[index];
    if (!mission.isComplete) {
      return state;
    }

    final missions = List<Mission>.from(state.missions);
    missions[index] = createMission(
      type: mission.type,
      ascensionLevel: state.ascensionLevel,
    );

    return state.copyWith(
      gold: state.gold + mission.goldReward,
      essence: state.essence + mission.essenceReward,
      missions: missions,
      lastUpdated: DateTime.now(),
    );
  }

  /// Bosses needed this run before Ascend unlocks.
  /// AL 0 → 1 boss, AL 1 → 2 bosses, etc.
  static int bossesRequiredForAscension(int ascensionLevel) =>
      ascensionLevel + 1;

  static bool canAscend(GameState state) =>
      state.bossVictories >= bossesRequiredForAscension(state.ascensionLevel);

  /// Essence granted when ascending into [newLevel].
  static int ascendEssenceReward(int newLevel) => 4 + (newLevel * 3);

  /// Applies Ascension + Sanctuary gold bonuses.
  static int applyGoldGain(GameState state, int baseGold) {
    if (baseGold <= 0) {
      return baseGold;
    }
    final percent =
        state.ascensionGoldBonusPercent + state.sanctuaryGoldBonusPercent;
    if (percent <= 0) {
      return baseGold;
    }
    return baseGold + (baseGold * percent) ~/ 100;
  }

  /// Prestige: reset the run, keep essence/relics/sanctuary/pets, bump AL.
  /// Returns [state] unchanged if Ascend is locked.
  static GameState ascend(GameState state, {DateTime? now}) {
    if (!canAscend(state)) {
      return state;
    }

    final nextLevel = state.ascensionLevel + 1;
    final preservedEssence =
        state.essence + ascendEssenceReward(nextLevel);
    final preservedRelics = List<String>.from(state.unlockedRelics);

    final fresh = createInitialState(now: now);
    final withMeta = fresh.copyWith(
      essence: preservedEssence,
      unlockedRelics: preservedRelics,
      ascensionLevel: nextLevel,
      missions: createMissionBoard(ascensionLevel: nextLevel),
      activePet: state.activePet,
      ownedPets: List<Pet>.from(state.ownedPets),
      sanctuaryGoldLevel: state.sanctuaryGoldLevel,
      sanctuaryPowerLevel: state.sanctuaryPowerLevel,
      sanctuaryVitalityLevel: state.sanctuaryVitalityLevel,
      dungeonMode: DungeonMode.farm,
      highestFloorCleared: 0,
      lastUpdated: now ?? DateTime.now(),
    );
    return withMeta.copyWith(
      heroes: withMeta.heroes
          .map(
            (hero) =>
                hero.copyWith(currentHp: withMeta.effectiveHeroMaxHp(hero)),
          )
          .toList(),
    );
  }

  static bool isBossBattle(int battleNumber) => battleNumber % 10 == 0;

  static bool isEliteBattle(int battleNumber) {
    final roomNumber = ((battleNumber - 1) % 10) + 1;
    return roomNumber == 10; // Boss
  }

  /// Combat budget for a room: total effective attack/HP/gold the enemy
  /// group should add up to. Mirrors the pre-group single-enemy formulas so
  /// overall balance is preserved. Single source of enemy scaling.
  static ({int attack, int hp, int gold}) roomCombatBudget(DungeonRoom room) {
    final level = room.globalBattleNumber;
    final isBoss = room.type == RoomType.boss;
    final diffMult = DungeonGenerator.getDifficultyMultiplier(room.type);

    final attack = (4 + (isBoss ? 4 : 0)) * diffMult.toInt() + (level - 1) * 2;
    final hp =
        ((24 + (level * 3) + ((level ~/ 5) * 10)) * diffMult +
                (isBoss ? 48 : 0))
            .toInt() +
        (level - 1) * 8;
    final gold = (8 + (level * 2)) * (isBoss ? 3 : 1);

    return (attack: attack, hp: hp, gold: gold);
  }

  /// Builds the enemy group for a room. Treasure rooms have no enemies.
  /// The room's combat budget is split across the group so a full room is
  /// roughly as tough as the old single enemy.
  static List<EnemyUnit> createEnemyGroup(DungeonRoom room) {
    if (room.type == RoomType.treasure || room.enemyCount == 0) {
      return <EnemyUnit>[];
    }

    final budget = roomCombatBudget(room);
    final count = room.enemyCount;
    final level = room.globalBattleNumber;
    final zone = DungeonGenerator.zoneNameForFloor(room.floorNumber);

    // Share of the budget per group slot. Boss rooms are asymmetric:
    // the boss takes half, its two guards a quarter each.
    final shares = switch (room.type) {
      RoomType.boss => const <double>[0.5, 0.25, 0.25],
      _ => List<double>.filled(count, 1.0 / count),
    };

    final group = <EnemyUnit>[];
    var hpLeft = budget.hp;
    var attackLeft = budget.attack;
    var goldLeft = budget.gold;
    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final hp = isLast ? hpLeft : max(1, (budget.hp * shares[i]).round());
      final attack = isLast
          ? max(1, attackLeft)
          : max(1, (budget.attack * shares[i]).round());
      final gold = isLast
          ? max(0, goldLeft)
          : (budget.gold * shares[i]).round();
      hpLeft -= hp;
      attackLeft -= attack;
      goldLeft -= gold;

      final isBossUnit = room.type == RoomType.boss && i == 0;
      final role = isBossUnit
          ? EnemyRole.boss
          : (room.type == RoomType.boss || room.type == RoomType.elite)
          ? EnemyRole.elite
          : EnemyRole.normal;

      group.add(
        EnemyUnit(
          name: _enemyNameFor(room.type, isBossUnit: isBossUnit, zone: zone),
          level: level,
          currentHp: max(1, hp),
          stats: Stats(attack: attack, defense: 1, maxHp: max(1, hp)),
          rewardGold: gold,
          role: role,
        ),
      );
    }

    return group;
  }

  static String _enemyNameFor(
    RoomType type, {
    required bool isBossUnit,
    required String zone,
  }) {
    if (isBossUnit) {
      return 'Gate Warden';
    }
    return switch (type) {
      RoomType.boss => 'Warden Guard',
      RoomType.elite => 'Elite Golem',
      RoomType.treasure => 'Golden Sprite',
      RoomType.normal => switch (zone) {
        'Sandy Caverns' => 'Cave Slime',
        "Goblin's Hideout" => 'Goblin Scrapper',
        "King's Fort" => 'Fort Sentry',
        'Underworld' => 'Underworld Imp',
        'City of Dead' => 'Risen Husk',
        _ => 'Hellspawn',
      },
    };
  }

  /// Restarts the current floor from room 1 with a healed party
  /// (used after a full party wipe, Idle Sword 2 style).
  static GameState restartFloor(GameState state) {
    final floor = DungeonGenerator.generateFloor(state.currentRoom.floorNumber);
    final firstRoom = floor.first;
    return state.copyWith(
      heroes: state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      enemies: createEnemyGroup(firstRoom),
      currentRoom: firstRoom,
      dungeonFloor: floor,
    );
  }

  static GameState advance(GameState state, {int steps = 1}) {
    var current = state;
    for (var i = 0; i < steps; i++) {
      current = _advanceOneTick(current);
    }
    return current;
  }

  static GameState applyOfflineProgress(GameState state, Duration elapsed) {
    final seconds = elapsed.inSeconds.clamp(0, 3600);
    if (seconds == 0) {
      return state.copyWith(lastUpdated: DateTime.now());
    }

    final progressed = advance(state, steps: seconds);
    return progressed.copyWith(
      offlineSecondsRecovered: progressed.offlineSecondsRecovered + seconds,
      lastUpdated: DateTime.now(),
    );
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
    };

    return 18 + (currentTier * 10) + (state.bossVictories * 5);
  }

  static GameState trainParty(GameState state) {
    final trainingCost = partyTrainingCostFor(state);
    if (state.gold < trainingCost) {
      return state;
    }

    final trainedHeroes = state.heroes
        .map(
          (hero) => hero.copyWith(
            level: hero.level + 1,
            currentHp: hero.maxHp + state.vitalityBonus + 5,
          ),
        )
        .toList();
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
        final healedHeroes = state.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: hero.maxHp + state.vitalityBonus + 6,
              ),
            )
            .toList();
        return state.copyWith(
          vitalityBonus: state.vitalityBonus + 6,
          heroes: healedHeroes,
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

    return state.copyWith(
      essence: state.essence - cost,
      heroes: healedHeroes,
      unlockedRelics: unlockedRelics,
      lastUpdated: DateTime.now(),
    );
  }

  static List<LootDrop> rollLoot(int battleNumber) {
    final floorNumber = ((battleNumber - 1) ~/ 10) + 1;
    final roomNumber = ((battleNumber - 1) % 10) + 1;
    final isBoss = roomNumber == 10;

    final floor = DungeonGenerator.generateFloor(floorNumber);
    final room = floor[roomNumber - 1];

    final primaryRarity = _rarityForBattle(battleNumber);
    final slot = battleNumber.isOdd ? EquipmentSlot.weapon : EquipmentSlot.armor;
    final drops = <LootDrop>[
      LootDrop(
        name: _equipmentNameFor(slot, primaryRarity),
        amount: 1,
        rarity: primaryRarity,
        equipment: createEquipment(
          slot: slot,
          rarity: primaryRarity,
          battleNumber: battleNumber,
        ),
      ),
    ];

    if (battleNumber % 4 == 0) {
      drops.add(
        const LootDrop(
          name: 'Gold Pouch',
          amount: 1,
          rarity: LootRarity.common,
        ),
      );
    }

    if (battleNumber % 9 == 0) {
      drops.add(
        const LootDrop(name: 'Relic Shard', amount: 1, rarity: LootRarity.rare),
      );
    }

    if (isBoss) {
      drops.add(
        const LootDrop(name: 'Boss Sigil', amount: 1, rarity: LootRarity.epic),
      );
    }

    if (room.type == RoomType.treasure) {
      drops.add(
        const LootDrop(
          name: 'Essence Vial',
          amount: 1,
          rarity: LootRarity.rare,
        ),
      );
    }

    return drops.take(3).toList();
  }

  static EquipmentItem createEquipment({
    required EquipmentSlot slot,
    required LootRarity rarity,
    required int battleNumber,
  }) {
    final floorBonus = (battleNumber - 1) ~/ 10;
    final (atk, def, vit) = switch (rarity) {
      LootRarity.common => (1 + floorBonus, 0 + (floorBonus ~/ 2), 2 + floorBonus),
      LootRarity.uncommon => (2 + floorBonus, 1 + (floorBonus ~/ 2), 4 + floorBonus),
      LootRarity.rare => (4 + floorBonus, 2 + floorBonus, 8 + floorBonus * 2),
      LootRarity.epic => (7 + floorBonus * 2, 4 + floorBonus, 14 + floorBonus * 2),
    };

    // Weapons lean attack; armor leans defense/HP.
    final attackBonus = slot == EquipmentSlot.weapon ? atk : max(0, atk ~/ 2);
    final defenseBonus = slot == EquipmentSlot.armor ? max(1, def + 1) : def;
    final vitalityBonus = slot == EquipmentSlot.armor ? vit : max(0, vit ~/ 2);

    return EquipmentItem(
      id: '${slot.name}_${rarity.name}_${battleNumber}_${random.nextInt(100000)}',
      name: _equipmentNameFor(slot, rarity),
      slot: slot,
      rarity: rarity,
      attackBonus: attackBonus,
      defenseBonus: defenseBonus,
      vitalityBonus: vitalityBonus,
    );
  }

  static String _equipmentNameFor(EquipmentSlot slot, LootRarity rarity) {
    return switch ((slot, rarity)) {
      (EquipmentSlot.weapon, LootRarity.common) => 'Iron Blade',
      (EquipmentSlot.weapon, LootRarity.uncommon) => 'Hunter Blade',
      (EquipmentSlot.weapon, LootRarity.rare) => 'Rune Sword',
      (EquipmentSlot.weapon, LootRarity.epic) => 'Mythic Edge',
      (EquipmentSlot.armor, LootRarity.common) => 'Iron Vest',
      (EquipmentSlot.armor, LootRarity.uncommon) => 'Hunter Mail',
      (EquipmentSlot.armor, LootRarity.rare) => 'Rune Plate',
      (EquipmentSlot.armor, LootRarity.epic) => 'Mythic Aegis',
    };
  }

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
    };

    return perItem * drop.amount;
  }

  static int equipmentEssenceValue(EquipmentItem item) {
    final base = switch (item.rarity) {
      LootRarity.common => 2,
      LootRarity.uncommon => 5,
      LootRarity.rare => 9,
      LootRarity.epic => 16,
    };
    return base + (item.powerScore ~/ 4);
  }

  static const int maxGearStash = 12;

  /// Puts gear into the inventory stash. Overflow salvages the oldest piece.
  static GameState stashEquipment(GameState state, EquipmentItem item) {
    final stash = List<EquipmentItem>.from(state.gearStash);
    var essence = state.essence;
    if (stash.length >= maxGearStash) {
      final overflow = stash.removeAt(0);
      essence += equipmentEssenceValue(overflow);
    }
    stash.add(item);
    return state.copyWith(gearStash: stash, essence: essence);
  }

  static EquipmentItem? findGear(GameState state, String id) {
    if (state.equippedWeapon?.id == id) {
      return state.equippedWeapon;
    }
    if (state.equippedArmor?.id == id) {
      return state.equippedArmor;
    }
    for (final item in state.gearStash) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  static GameState removeGear(GameState state, String id) {
    if (state.equippedWeapon?.id == id) {
      return state.copyWith(clearEquippedWeapon: true);
    }
    if (state.equippedArmor?.id == id) {
      return state.copyWith(clearEquippedArmor: true);
    }
    return state.copyWith(
      gearStash: state.gearStash.where((item) => item.id != id).toList(),
    );
  }

  /// Equip a stash item into its slot (current piece moves to stash).
  static GameState equipFromStash(GameState state, String itemId) {
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

    var next = state.copyWith(
      gearStash: state.gearStash.where((g) => g.id != itemId).toList(),
    );
    final current = next.equippedFor(item.slot);
    if (current != null) {
      next = stashEquipment(next, current);
    }

    final vitalityBefore = next.totalVitalityBonus;
    next = switch (item.slot) {
      EquipmentSlot.weapon => next.copyWith(equippedWeapon: item),
      EquipmentSlot.armor => next.copyWith(equippedArmor: item),
    };
    final vitalityDelta = next.totalVitalityBonus - vitalityBefore;
    if (vitalityDelta != 0) {
      next = next.copyWith(
        heroes: next.heroes
            .map(
              (hero) => hero.copyWith(
                currentHp: vitalityDelta > 0
                    ? min(
                        next.effectiveHeroMaxHp(hero),
                        hero.currentHp + vitalityDelta,
                      )
                    : min(next.effectiveHeroMaxHp(hero), hero.currentHp),
              ),
            )
            .toList(),
      );
    }
    return next.copyWith(lastUpdated: DateTime.now());
  }

  static GameState unequipSlot(GameState state, EquipmentSlot slot) {
    final current = state.equippedFor(slot);
    if (current == null) {
      return state;
    }
    var next = switch (slot) {
      EquipmentSlot.weapon => state.copyWith(clearEquippedWeapon: true),
      EquipmentSlot.armor => state.copyWith(clearEquippedArmor: true),
    };
    next = stashEquipment(next, current);
    return next.copyWith(
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

  static GameState sellGear(GameState state, String itemId) {
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

  static int combineCost(EquipmentItem primary, EquipmentItem secondary) =>
      20 +
      primary.powerScore +
      secondary.powerScore +
      ((primary.rarity.index + secondary.rarity.index) * 5);

  static bool canCombine(EquipmentItem primary, EquipmentItem secondary) =>
      primary.slot == secondary.slot && primary.id != secondary.id;

  static LootRarity mergedRarity(LootRarity primary, LootRarity secondary) {
    if (secondary.index > primary.index) {
      return secondary;
    }
    if (secondary.index == primary.index &&
        primary.index < LootRarity.epic.index) {
      return LootRarity.values[primary.index + 1];
    }
    return primary;
  }

  static EquipmentItem mergeEquipment(
    EquipmentItem primary,
    EquipmentItem secondary,
  ) {
    final rarity = mergedRarity(primary.rarity, secondary.rarity);
    return EquipmentItem(
      id: 'combined_${primary.slot.name}_${random.nextInt(1000000)}',
      name: _equipmentNameFor(primary.slot, rarity),
      slot: primary.slot,
      rarity: rarity,
      attackBonus:
          primary.attackBonus + ((secondary.attackBonus * 50) ~/ 100),
      defenseBonus:
          primary.defenseBonus + ((secondary.defenseBonus * 50) ~/ 100),
      vitalityBonus:
          primary.vitalityBonus + ((secondary.vitalityBonus * 50) ~/ 100),
    );
  }

  /// Combines two same-slot pieces (stash and/or equipped). Primary keeps
  /// identity lean; secondary contributes half its stats.
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
    final cost = combineCost(primary, secondary);
    if (state.gold < cost) {
      return state;
    }

    var next = state.copyWith(gold: state.gold - cost);
    next = removeGear(next, primaryId);
    next = removeGear(next, secondaryId);

    final result = mergeEquipment(primary, secondary);
    final current = next.equippedFor(result.slot);
    if (current == null || result.powerScore >= current.powerScore) {
      if (current != null) {
        next = stashEquipment(next, current);
      }
      final vitalityBefore = next.totalVitalityBonus;
      next = switch (result.slot) {
        EquipmentSlot.weapon => next.copyWith(equippedWeapon: result),
        EquipmentSlot.armor => next.copyWith(equippedArmor: result),
      };
      final vitalityDelta = next.totalVitalityBonus - vitalityBefore;
      if (vitalityDelta > 0) {
        next = next.copyWith(
          heroes: next.heroes
              .map(
                (hero) => hero.copyWith(
                  currentHp: min(
                    next.effectiveHeroMaxHp(hero),
                    hero.currentHp + vitalityDelta,
                  ),
                ),
              )
              .toList(),
        );
      }
    } else {
      next = stashEquipment(next, result);
    }

    return next.copyWith(lastUpdated: DateTime.now());
  }

  /// Auto-equips into empty slots; otherwise gear goes to inventory.
  /// Stronger gear still auto-replaces when clearly better (powerScore).
  static ({GameState state, List<LootDrop> resolved}) applyLootDrops(
    GameState state,
    List<LootDrop> drops,
  ) {
    var next = state;
    final resolved = <LootDrop>[];

    for (final drop in drops) {
      final item = drop.equipment;
      if (item == null) {
        final essence = lootEssenceValue(drop);
        next = next.copyWith(essence: next.essence + essence);
        resolved.add(
          drop.copyWith(outcome: LootOutcome.essence, essenceGained: essence),
        );
        continue;
      }

      final current = next.equippedFor(item.slot);
      final shouldEquip =
          current == null || item.powerScore > current.powerScore;

      if (!shouldEquip) {
        final essenceBefore = next.essence;
        next = stashEquipment(next, item);
        resolved.add(
          drop.copyWith(
            outcome: LootOutcome.stashed,
            essenceGained: max(0, next.essence - essenceBefore),
          ),
        );
        continue;
      }

      var essence = 0;
      var outcome = LootOutcome.equipped;
      if (current != null) {
        outcome = LootOutcome.replaced;
        final essenceBefore = next.essence;
        next = stashEquipment(next, current);
        essence = max(0, next.essence - essenceBefore);
      }

      final vitalityBefore = next.totalVitalityBonus;
      next = switch (item.slot) {
        EquipmentSlot.weapon => next.copyWith(equippedWeapon: item),
        EquipmentSlot.armor => next.copyWith(equippedArmor: item),
      };
      final vitalityDelta = next.totalVitalityBonus - vitalityBefore;
      if (vitalityDelta > 0) {
        next = next.copyWith(
          heroes: next.heroes
              .map(
                (hero) => hero.copyWith(
                  currentHp: min(
                    next.effectiveHeroMaxHp(hero),
                    hero.currentHp + vitalityDelta,
                  ),
                ),
              )
              .toList(),
        );
      }

      resolved.add(
        drop.copyWith(outcome: outcome, essenceGained: essence),
      );
    }

    return (state: next, resolved: resolved);
  }

  static LootRarity _rarityForBattle(int battleNumber) {
    if (battleNumber % 12 == 0) {
      return LootRarity.epic;
    }
    if (battleNumber % 6 == 0) {
      return LootRarity.rare;
    }
    if (battleNumber % 3 == 0) {
      return LootRarity.uncommon;
    }
    return LootRarity.common;
  }

  static GameState _advanceOneTick(GameState state) {
    // Full party wipe: failed push retreats; otherwise restart the floor.
    if (state.isPartyDefeated) {
      if (state.dungeonMode == DungeonMode.push &&
          state.currentRoom.floorNumber > state.highestFloorCleared) {
        return retreatFromFailedPush(state);
      }
      return restartFloor(state);
    }

    final room = state.currentRoom;

    // Treasure room: no combat — open the chest and move on.
    if (room.type == RoomType.treasure || state.enemies.isEmpty) {
      final budget = roomCombatBudget(room);
      return _advanceToNextRoom(state, goldGain: budget.gold);
    }

    // Heroes attack: spread targeting — hero i strikes alive enemy i % n.
    final enemies = List<EnemyUnit>.from(state.enemies);
    var targetSlot = 0;
    for (final hero in state.heroes) {
      if (!hero.isAlive) {
        continue;
      }
      final aliveIndices = <int>[
        for (var i = 0; i < enemies.length; i++)
          if (!enemies[i].isDefeated) i,
      ];
      if (aliveIndices.isEmpty) {
        break;
      }
      final target = aliveIndices[targetSlot % aliveIndices.length];
      enemies[target] = enemies[target].takeDamage(
        state.effectiveHeroAttack(hero),
      );
      targetSlot++;
    }

    // Room cleared when every enemy in the group is down.
    if (enemies.every((enemy) => enemy.isDefeated)) {
      final goldGain = state.enemies.fold<int>(
        0,
        (sum, enemy) => sum + enemy.rewardGold,
      );
      return _advanceToNextRoom(state, goldGain: goldGain);
    }

    // Enemy counterattack: weighted toward living warriors (taunt).
    final heroes = List<PartyHero>.from(state.heroes);
    for (final enemy in enemies) {
      if (enemy.isDefeated) {
        continue;
      }
      final defenderIndex = _pickTauntedDefenderIndex(heroes);
      if (defenderIndex < 0) {
        break;
      }
      final defender = heroes[defenderIndex];
      final damageTaken = max(
        1,
        enemy.attack - state.effectiveHeroDefense(defender),
      );
      heroes[defenderIndex] = defender.copyWith(
        currentHp: max(0, defender.currentHp - damageTaken),
      );
    }

    // Healer passive: mend living allies after the exchange.
    final mend = state.healerMendAmount;
    if (mend > 0 && heroes.any((hero) => hero.isAlive)) {
      for (var i = 0; i < heroes.length; i++) {
        final hero = heroes[i];
        if (!hero.isAlive) {
          continue;
        }
        final maxHp = state.effectiveHeroMaxHp(hero);
        heroes[i] = hero.copyWith(
          currentHp: min(maxHp, hero.currentHp + mend),
        );
      }
    }

    return state.copyWith(heroes: heroes, enemies: enemies);
  }

  /// Prefer warriors (weight 3) over other living heroes (weight 1).
  static int _pickTauntedDefenderIndex(List<PartyHero> heroes) {
    final weighted = <int>[];
    for (var i = 0; i < heroes.length; i++) {
      final hero = heroes[i];
      if (!hero.isAlive) {
        continue;
      }
      final weight = hero.role == HeroRole.warrior ? 3 : 1;
      for (var w = 0; w < weight; w++) {
        weighted.add(i);
      }
    }
    if (weighted.isEmpty) {
      return -1;
    }
    return weighted[random.nextInt(weighted.length)];
  }

  /// Public room-clear: awards loot/gold and advances (farm loop or push).
  static GameState completeCurrentRoom(
    GameState state, {
    required int goldGain,
    bool skipLootRoll = false,
    List<LootDrop>? recentLoot,
  }) =>
      _advanceToNextRoom(
        state,
        goldGain: goldGain,
        skipLootRoll: skipLootRoll,
        recentLoot: recentLoot,
      );

  /// Marks the current room cleared, awards gold/loot/essence and moves the
  /// party to the next room. Completing room 10 either farms the same floor
  /// or pushes to the next floor depending on [GameState.dungeonMode].
  static GameState _advanceToNextRoom(
    GameState state, {
    required int goldGain,
    bool skipLootRoll = false,
    List<LootDrop>? recentLoot,
  }) {
    final room = state.currentRoom;
    final enemiesDefeated = state.enemies.length;
    final bossesCleared = room.type == RoomType.boss ? 1 : 0;

    late GameState awarded;
    late List<LootDrop> drops;
    if (skipLootRoll) {
      awarded = state;
      drops = recentLoot ?? state.recentLoot;
    } else {
      final rawDrops = rollLoot(room.globalBattleNumber);
      final lootResult = applyLootDrops(state, rawDrops);
      awarded = lootResult.state;
      drops = lootResult.resolved;
    }
    final goldAwarded = applyGoldGain(awarded, goldGain);

    final clearedFloor = awarded.dungeonFloor
        .map(
          (r) =>
              r.roomIndex == room.roomIndex ? r.copyWith(isCleared: true) : r,
        )
        .toList();

    final isLastRoom = room.roomIndex == clearedFloor.length - 1;
    late GameState progressed;
    if (isLastRoom) {
      final highest = bossesCleared > 0
          ? max(awarded.highestFloorCleared, room.floorNumber)
          : awarded.highestFloorCleared;
      final farmLoop = awarded.dungeonMode == DungeonMode.farm;
      final targetFloor = farmLoop ? room.floorNumber : room.floorNumber + 1;
      final nextFloor = DungeonGenerator.generateFloor(targetFloor);
      final nextRoom = nextFloor.first;
      progressed = awarded.copyWith(
        gold: awarded.gold + goldAwarded,
        bossVictories: awarded.bossVictories + bossesCleared,
        highestFloorCleared: highest,
        enemies: createEnemyGroup(nextRoom),
        currentRoom: nextRoom,
        dungeonFloor: nextFloor,
        heroes: awarded.heroes
            .map(
              (hero) =>
                  hero.copyWith(currentHp: awarded.effectiveHeroMaxHp(hero)),
            )
            .toList(),
        recentLoot: drops,
      );
    } else {
      final nextRoom = clearedFloor[room.roomIndex + 1];
      progressed = awarded.copyWith(
        gold: awarded.gold + goldAwarded,
        enemies: createEnemyGroup(nextRoom),
        currentRoom: nextRoom,
        dungeonFloor: clearedFloor,
        recentLoot: drops,
      );
    }

    return applyMissionProgress(
      progressed,
      enemiesDefeated: enemiesDefeated,
      bossesCleared: bossesCleared,
      goldEarned: goldAwarded,
    );
  }

  /// Parses a save of any version, migrating legacy v1 saves
  /// (single `enemy` + stored `battleNumber`) to the room-based v2 model.
  static GameState stateFromJson(Map<String, dynamic> json) {
    final loaded = json.containsKey('enemies')
        ? GameState.fromJson(json)
        : _migrateV1(json);
    if (loaded.missions.isNotEmpty) {
      return loaded;
    }
    return loaded.copyWith(
      missions: createMissionBoard(ascensionLevel: loaded.ascensionLevel),
    );
  }

  static GameState _migrateV1(Map<String, dynamic> json) {
    final battleNumber = (json['battleNumber'] as int?) ?? 1;
    final floorNumber = ((battleNumber - 1) ~/ 10) + 1;
    final roomIndex = (battleNumber - 1) % 10;

    final floor = DungeonGenerator.generateFloor(floorNumber)
        .map((r) => r.roomIndex < roomIndex ? r.copyWith(isCleared: true) : r)
        .toList();
    final room = floor[roomIndex];

    final recentLootJson = json['recentLoot'] as List<dynamic>?;
    final unlockedRelicsJson = json['unlockedRelics'] as List<dynamic>?;

    return GameState(
      heroes: (json['heroes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(PartyHero.fromJson)
          .toList(),
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
      equippedWeapon: json['equippedWeapon'] == null
          ? null
          : EquipmentItem.fromJson(
              json['equippedWeapon'] as Map<String, dynamic>,
            ),
      equippedArmor: json['equippedArmor'] == null
          ? null
          : EquipmentItem.fromJson(
              json['equippedArmor'] as Map<String, dynamic>,
            ),
    );
  }
}

enum PartyUpgradeType { attack, defense, vitality }
