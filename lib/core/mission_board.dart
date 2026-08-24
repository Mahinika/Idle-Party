import 'dart:math';

import '../models/mission.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';

/// Fixed board roles: Daily (0) · Bounty (1) · Side (2).
abstract final class MissionBoard {
  static const int dailySlot = 0;
  static const int bountySlot = 1;
  static const int sideSlot = 2;

  static const List<int> bountyTargetsEndgame = <int>[100, 500, 1000];
  static const List<int> bountyTargetsEarly = <int>[25, 75, 150];

  static const List<MissionType> sideTypes = <MissionType>[
    MissionType.clearBosses,
    MissionType.earnGold,
    MissionType.clearFloors,
    MissionType.defeatElites,
  ];

  /// Builds the 3-slot QUESTS board (Daily / Bounty / Side).
  static List<Mission> createMissionBoard({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    int bountyRung = 0,
    bool endgame = false,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final rung = bountyRung.clamp(0, 2);
    return [
      createDailyMission(
        ascensionLevel: ascensionLevel,
        highestDungeonCleared: highestDungeonCleared,
        highestFloorCleared: highestFloorCleared,
        hardmodeLevel: hardmodeLevel,
        endgame: endgame,
        random: rng,
      ),
      createBountyMission(
        ascensionLevel: ascensionLevel,
        highestDungeonCleared: highestDungeonCleared,
        highestFloorCleared: highestFloorCleared,
        hardmodeLevel: hardmodeLevel,
        bountyRung: rung,
        endgame: endgame,
        random: rng,
      ),
      createSideMission(
        ascensionLevel: ascensionLevel,
        highestDungeonCleared: highestDungeonCleared,
        highestFloorCleared: highestFloorCleared,
        hardmodeLevel: hardmodeLevel,
        random: rng,
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
      bountyRung: state.metaDepth.bountyRung,
      endgame: GameLogic.endgameUnlocked(state),
      random: random,
    );
  }

  /// True when the board is the legacy random 3-type layout (pre-QUESTS).
  static bool needsQuestBoardRebuild(List<Mission> missions) {
    if (missions.length != 3) return true;
    if (missions.any(
      (m) =>
          m.id == 'defeat_enemies' ||
          m.id == 'clear_bosses' ||
          m.id == 'earn_gold',
    )) {
      return true;
    }
    return missions[dailySlot].type != MissionType.defeatEnemies ||
        missions[bountySlot].type != MissionType.defeatEnemies ||
        missions[sideSlot].type == MissionType.defeatEnemies;
  }

  /// Depth score used to scale Side contract targets with account progress.
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

  /// Daily kill target: endgame 100; early lower round numbers.
  static int dailyKillTarget({
    required int ascensionLevel,
    required bool endgame,
  }) {
    if (endgame) return 100;
    if (ascensionLevel >= 15) return 75;
    if (ascensionLevel >= 10) return 50;
    if (ascensionLevel >= 5) return 40;
    if (ascensionLevel >= 2) return 30;
    return 20;
  }

  static int bountyKillTarget({
    required int bountyRung,
    required bool endgame,
  }) {
    final ladder = endgame ? bountyTargetsEndgame : bountyTargetsEarly;
    return ladder[bountyRung.clamp(0, ladder.length - 1)];
  }

  static Mission createDailyMission({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    bool endgame = false,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final depth = missionDepthScore(
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
    );
    final target = dailyKillTarget(
      ascensionLevel: ascensionLevel,
      endgame: endgame,
    );
    return Mission(
      id: 'daily_s0_${rng.nextInt(1 << 20)}',
      type: MissionType.defeatEnemies,
      title: 'Daily: Slay foes',
      target: target,
      progress: 0,
      goldReward: max(1, 24 + depth * 10 + target ~/ 4),
      essenceReward: max(1, 3 + depth + target ~/ 40),
      tier: 0,
    );
  }

  static Mission createBountyMission({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    int bountyRung = 0,
    bool endgame = false,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final depth = missionDepthScore(
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
    );
    final rung = bountyRung.clamp(0, 2);
    final target = bountyKillTarget(bountyRung: rung, endgame: endgame);
    final rungLabel = rung + 1;
    return Mission(
      id: 'bounty_s1_r$rung}_${rng.nextInt(1 << 20)}',
      type: MissionType.defeatEnemies,
      title: 'Bounty $rungLabel: Slay foes',
      target: target,
      progress: 0,
      goldReward: max(1, 30 + depth * 12 + target ~/ 5),
      essenceReward: max(1, 4 + depth + target ~/ 50),
      tier: rung == 0 ? 0 : (rung == 1 ? 1 : 2),
    );
  }

  static Mission createSideMission({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    MissionType? avoid,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final pool = List<MissionType>.from(sideTypes);
    if (avoid != null) pool.remove(avoid);
    final type = pool[rng.nextInt(pool.length)];
    return createMission(
      type: type,
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
      random: rng,
      slot: sideSlot,
    );
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

    // Bias toward harder Side quests as the account deepens.
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

  /// Picks a replacement Side quest (never defeatEnemies).
  static Mission rollReplacementMission(
    GameState state, {
    MissionType? avoid,
    int slot = sideSlot,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    if (slot == dailySlot) {
      return createDailyMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        endgame: GameLogic.endgameUnlocked(state),
        random: rng,
      );
    }
    if (slot == bountySlot) {
      return createBountyMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        bountyRung: state.metaDepth.bountyRung,
        endgame: GameLogic.endgameUnlocked(state),
        random: rng,
      );
    }
    final occupied = state.missions
        .where((m) => m.type != MissionType.defeatEnemies)
        .map((m) => m.type)
        .toSet();
    if (avoid != null) occupied.remove(avoid);
    final pool = List<MissionType>.from(sideTypes);
    if (avoid != null && pool.length > 1) pool.remove(avoid);
    final fresh = pool.where((t) => !occupied.contains(t)).toList();
    final type = (fresh.isNotEmpty ? fresh : pool)[
        rng.nextInt((fresh.isNotEmpty ? fresh : pool).length)];
    return createMission(
      type: type,
      ascensionLevel: state.ascensionLevel,
      highestDungeonCleared: state.highestDungeonCleared,
      highestFloorCleared: state.highestFloorCleared,
      hardmodeLevel: state.hardmodeLevel,
      random: rng,
      slot: sideSlot,
    );
  }

  /// Refresh Daily when the UTC calendar day rolls.
  static GameState ensureDailyQuest(GameState state, {DateTime? now}) {
    final day = MetaSystems.dailyDateKey((now ?? DateTime.now()).toUtc());
    if (state.missions.length != 3) {
      return state.copyWith(
        missions: createMissionBoardFor(state),
        metaDepth: state.metaDepth.copyWith(dailyQuestDate: day),
      );
    }
    if (state.metaDepth.dailyQuestDate == day) return state;
    final missions = List<Mission>.from(state.missions);
    missions[dailySlot] = createDailyMission(
      ascensionLevel: state.ascensionLevel,
      highestDungeonCleared: state.highestDungeonCleared,
      highestFloorCleared: state.highestFloorCleared,
      hardmodeLevel: state.hardmodeLevel,
      endgame: GameLogic.endgameUnlocked(state),
    );
    return state.copyWith(
      missions: missions,
      metaDepth: state.metaDepth.copyWith(dailyQuestDate: day),
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
    state = ensureDailyQuest(state);
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
      if (mission.claimed || mission.isComplete) {
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

  /// Claims a completed quest. Daily stays until next UTC day; Bounty advances
  /// rung; Side rolls a fresh non-kill quest. Chain streak unchanged.
  static GameState claimMission(GameState state, String missionId) {
    state = ensureDailyQuest(state);
    final index = state.missions.indexWhere(
      (mission) => mission.id == missionId,
    );
    if (index < 0) {
      return state;
    }
    final mission = state.missions[index];
    if (!mission.canClaim) {
      return state;
    }

    final missions = List<Mission>.from(state.missions);
    var nextRung = state.metaDepth.bountyRung;
    var nextDailyDate = state.metaDepth.dailyQuestDate;

    if (index == dailySlot) {
      missions[index] = mission.copyWith(claimed: true);
      nextDailyDate = MetaSystems.dailyDateKey(DateTime.now().toUtc());
    } else if (index == bountySlot) {
      nextRung = min(2, state.metaDepth.bountyRung + 1);
      // Top rung repeats: stay at 2 after claim.
      if (state.metaDepth.bountyRung >= 2) {
        nextRung = 2;
      }
      final afterRung = state.copyWith(
        metaDepth: state.metaDepth.copyWith(bountyRung: nextRung),
      );
      missions[index] = createBountyMission(
        ascensionLevel: afterRung.ascensionLevel,
        highestDungeonCleared: afterRung.highestDungeonCleared,
        highestFloorCleared: afterRung.highestFloorCleared,
        hardmodeLevel: afterRung.hardmodeLevel,
        bountyRung: nextRung,
        endgame: GameLogic.endgameUnlocked(afterRung),
      );
    } else {
      missions[index] = rollReplacementMission(
        state,
        avoid: mission.type,
        slot: sideSlot,
      );
    }

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
      metaDepth: state.metaDepth.copyWith(
        jobChainCount: nextChain,
        bountyRung: nextRung,
        dailyQuestDate: nextDailyDate,
      ),
      lastUpdated: DateTime.now(),
    );
  }
}
