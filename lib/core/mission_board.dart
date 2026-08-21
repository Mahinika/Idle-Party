import 'dart:math';

import '../models/mission.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// The mission board: what it offers, how progress lands, what a claim pays.
///
/// Rebuilt on Ascend for the new level, so offers scale with how deep the
/// player actually is rather than with wallet gold.
abstract final class MissionBoard {
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
    final type = (fresh.isNotEmpty
        ? fresh
        : pool)[rng.nextInt((fresh.isNotEmpty ? fresh : pool).length)];
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
}
