import 'dart:math';

import '../models/mission.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'logic_notices.dart';
import 'meta_systems.dart';

/// Fixed board roles: Daily (0) · Bounty (1) · Side (2) · Week (3) · Contract (4).
abstract final class MissionBoard {
  static const int dailySlot = 0;
  static const int bountySlot = 1;
  static const int sideSlot = 2;
  static const int weekSlot = 3;
  static const int contractSlot = 4;
  static const int boardSize = 5;

  /// Endgame ladder continues past 1000 (rungs 0…5).
  static const List<int> bountyTargetsEndgame = <int>[
    100,
    500,
    1000,
    5000,
    10000,
    25000,
  ];
  static const List<int> bountyTargetsEarly = <int>[25, 75, 150];

  static int bountyRungMax({required bool endgame}) =>
      (endgame ? bountyTargetsEndgame : bountyTargetsEarly).length - 1;

  static const List<MissionType> sideTypes = <MissionType>[
    MissionType.clearBosses,
    MissionType.earnGold,
    MissionType.clearFloors,
    MissionType.defeatElites,
  ];

  static const List<MissionType> endgameContractTypes = <MissionType>[
    MissionType.timedKeys,
    MissionType.gauntletFloors,
    MissionType.clearRifts,
    MissionType.clearGreaterRifts,
    MissionType.ashenCrown,
  ];

  static bool isEndgameType(MissionType type) =>
      endgameContractTypes.contains(type);

  /// Builds the 5-slot QUESTS board.
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
    final rung = bountyRung.clamp(0, bountyRungMax(endgame: endgame));
    final side = createSideMission(
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
      random: rng,
    );
    final week = createWeekMission(
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
      endgame: endgame,
      avoidTypes: <MissionType>[side.type],
      random: rng,
    );
    final contract = createContractMission(
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
      endgame: endgame,
      avoidTypes: <MissionType>[week.type, side.type],
      random: rng,
    );
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
      side,
      week,
      contract,
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

  /// True when the board is legacy (pre-5-slot) or wrong slot grammar.
  static bool needsQuestBoardRebuild(List<Mission> missions) {
    if (missions.length != boardSize) return true;
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
        missions[sideSlot].type == MissionType.defeatEnemies ||
        !missions[weekSlot].title.startsWith('Week:') ||
        !missions[contractSlot].title.startsWith('Contract:');
  }

  /// Depth score used to scale Side / Week / Contract targets.
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

  /// Player-facing job line. [prefix] keeps Daily:/Bounty/Week:/Contract:.
  static String goalTitle({
    required MissionType type,
    required int target,
    String prefix = '',
  }) {
    final n = max(1, target);
    final body = switch (type) {
      MissionType.defeatEnemies => 'Defeat $n',
      MissionType.clearBosses => n == 1 ? 'Clear 1 boss' : 'Clear $n bosses',
      MissionType.earnGold => 'Earn $n gold',
      MissionType.clearFloors => n == 1 ? 'Clear 1 floor' : 'Clear $n floors',
      MissionType.defeatElites => n == 1 ? 'Defeat 1 elite' : 'Defeat $n elites',
      MissionType.timedKeys =>
        n == 1 ? 'Time 1 KEY' : 'Time $n KEY clears',
      MissionType.gauntletFloors =>
        n == 1 ? 'Climb 1 Gauntlet floor' : 'Climb $n Gauntlet floors',
      MissionType.clearRifts =>
        n == 1 ? 'Clear 1 Farm Rift' : 'Clear $n Farm Rifts',
      MissionType.clearGreaterRifts =>
        n == 1 ? 'Clear 1 Ranked GR' : 'Clear $n Ranked GR',
      MissionType.ashenCrown => 'Beat Ashen Crown',
    };
    return '$prefix$body';
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
      title: goalTitle(
        type: MissionType.defeatEnemies,
        target: target,
        prefix: 'Daily: ',
      ),
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
    final rung = bountyRung.clamp(0, bountyRungMax(endgame: endgame));
    final target = bountyKillTarget(bountyRung: rung, endgame: endgame);
    final rungLabel = rung + 1;
    return Mission(
      id: 'bounty_s1_r$rung}_${rng.nextInt(1 << 20)}',
      type: MissionType.defeatEnemies,
      title: goalTitle(
        type: MissionType.defeatEnemies,
        target: target,
        prefix: 'Bounty $rungLabel: ',
      ),
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
      titlePrefix: '',
    );
  }

  /// Heavier weekly goal — claim once per ISO week.
  static Mission createWeekMission({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    bool endgame = false,
    MissionType? avoid,
    Iterable<MissionType> avoidTypes = const <MissionType>[],
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final pool = <MissionType>[
      ...sideTypes,
      if (endgame) ...endgameContractTypes,
    ];
    final type = _pickType(
      pool,
      rng,
      avoid: <MissionType>[
        ?avoid,
        ...avoidTypes,
      ],
    );
    return createMission(
      type: type,
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
      random: rng,
      slot: weekSlot,
      titlePrefix: 'Week: ',
      targetScale: 1.75,
      rewardScale: 1.55,
      forceTier: 1,
    );
  }

  /// Big Contract — endgame KEY/Gauntlet/Rift/Ashen when unlocked.
  static Mission createContractMission({
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    bool endgame = false,
    MissionType? avoid,
    Iterable<MissionType> avoidTypes = const <MissionType>[],
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final pool = endgame
        ? List<MissionType>.from(endgameContractTypes)
        : List<MissionType>.from(sideTypes);
    final type = _pickType(
      pool,
      rng,
      avoid: <MissionType>[
        ?avoid,
        ...avoidTypes,
      ],
    );
    return createMission(
      type: type,
      ascensionLevel: ascensionLevel,
      highestDungeonCleared: highestDungeonCleared,
      highestFloorCleared: highestFloorCleared,
      hardmodeLevel: hardmodeLevel,
      random: rng,
      slot: contractSlot,
      titlePrefix: 'Contract: ',
      targetScale: endgame ? 1.0 : 1.35,
      rewardScale: endgame ? 1.7 : 1.4,
      forceTier: endgame ? 0 : 1,
    );
  }

  static MissionType _pickType(
    List<MissionType> pool,
    Random rng, {
    Iterable<MissionType> avoid = const <MissionType>[],
  }) {
    if (pool.isEmpty) return MissionType.clearFloors;
    final blocked = avoid.toSet();
    final fresh = pool.where((t) => !blocked.contains(t)).toList();
    final use = fresh.isNotEmpty ? fresh : pool;
    return use[rng.nextInt(use.length)];
  }

  static Mission createMission({
    required MissionType type,
    required int ascensionLevel,
    int highestDungeonCleared = 0,
    int highestFloorCleared = 1,
    int hardmodeLevel = 0,
    Random? random,
    int slot = 0,
    String titlePrefix = '',
    double targetScale = 1.0,
    double rewardScale = 1.0,
    int? forceTier,
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
    final tier =
        forceTier ??
        (roll < (50 - hardBias) ? 0 : (roll < (85 - brutalBias) ? 1 : 2));
    final targetMul =
        switch (tier) {
          1 => 1.55,
          2 => 2.25,
          _ => 1.0,
        } *
        targetScale;
    final rewardMul =
        switch (tier) {
          1 => 1.45,
          2 => 2.1,
          _ => 1.0,
        } *
        rewardScale;
    // Hard/Brutal is border color only — titles name the job.
    final prefix = titlePrefix;

    int scaleTarget(int base) => max(1, (base * targetMul).round());
    int scaleGold(int base) => max(1, (base * rewardMul).round());
    int scaleEssence(int base) => max(1, (base * rewardMul).round());

    final id = '${type.name}_s${slot}_${rng.nextInt(1 << 20)}';

    Mission typed({
      required int target,
      required int goldReward,
      required int essenceReward,
      int? tierOverride,
    }) {
      return Mission(
        id: id,
        type: type,
        title: goalTitle(type: type, target: target, prefix: prefix),
        target: target,
        progress: 0,
        goldReward: goldReward,
        essenceReward: essenceReward,
        tier: tierOverride ?? tier,
      );
    }

    return switch (type) {
      MissionType.defeatEnemies => typed(
        target: scaleTarget(18 + depth * 6),
        goldReward: scaleGold(28 + depth * 14),
        essenceReward: scaleEssence(3 + depth),
      ),
      MissionType.clearBosses => typed(
        target: scaleTarget(max(2, 2 + depth ~/ 3)),
        goldReward: scaleGold(45 + depth * 20),
        essenceReward: scaleEssence(4 + depth),
      ),
      MissionType.earnGold => typed(
        target: scaleTarget(90 + depth * 55),
        goldReward: scaleGold(22 + depth * 12),
        essenceReward: scaleEssence(2 + depth ~/ 2),
      ),
      MissionType.clearFloors => typed(
        target: scaleTarget(5 + depth ~/ 2),
        goldReward: scaleGold(30 + depth * 15),
        essenceReward: scaleEssence(3 + depth ~/ 2),
      ),
      MissionType.defeatElites => typed(
        target: scaleTarget(4 + depth),
        goldReward: scaleGold(40 + depth * 16),
        essenceReward: scaleEssence(4 + depth ~/ 2),
      ),
      MissionType.timedKeys => typed(
        target: scaleTarget(max(1, 1 + depth ~/ 8)),
        goldReward: scaleGold(55 + depth * 18),
        essenceReward: scaleEssence(6 + depth),
      ),
      MissionType.gauntletFloors => typed(
        target: scaleTarget(max(5, 8 + depth ~/ 2)),
        goldReward: scaleGold(50 + depth * 16),
        essenceReward: scaleEssence(5 + depth),
      ),
      MissionType.clearRifts => typed(
        target: scaleTarget(max(1, 1 + depth ~/ 10)),
        goldReward: scaleGold(48 + depth * 15),
        essenceReward: scaleEssence(5 + depth),
      ),
      MissionType.clearGreaterRifts => typed(
        target: scaleTarget(1),
        goldReward: scaleGold(70 + depth * 20),
        essenceReward: scaleEssence(8 + depth),
        tierOverride: max(tier, 1),
      ),
      MissionType.ashenCrown => typed(
        target: 1,
        goldReward: scaleGold(80 + depth * 22),
        essenceReward: scaleEssence(10 + depth),
        tierOverride: max(tier, 1),
      ),
    };
  }

  /// Picks a replacement for Side / Contract (or rebuilds Daily / Bounty / Week).
  static Mission rollReplacementMission(
    GameState state, {
    MissionType? avoid,
    int slot = sideSlot,
    Random? random,
  }) {
    final rng = random ?? GameLogic.random;
    final endgame = GameLogic.endgameUnlocked(state);
    if (slot == dailySlot) {
      return createDailyMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        endgame: endgame,
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
        endgame: endgame,
        random: rng,
      );
    }
    if (slot == weekSlot) {
      final contractType = state.missions.length > contractSlot
          ? state.missions[contractSlot].type
          : null;
      return createWeekMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        endgame: endgame,
        avoid: avoid,
        avoidTypes: <MissionType>[
          ?contractType,
        ],
        random: rng,
      );
    }
    if (slot == contractSlot) {
      final weekType = state.missions.length > weekSlot
          ? state.missions[weekSlot].type
          : null;
      return createContractMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        endgame: endgame,
        avoid: avoid,
        avoidTypes: <MissionType>[
          ?weekType,
        ],
        random: rng,
      );
    }
    final occupied = state.missions
        .where((m) => sideTypes.contains(m.type))
        .map((m) => m.type)
        .toSet();
    if (avoid != null) occupied.remove(avoid);
    final pool = List<MissionType>.from(sideTypes);
    if (avoid != null && pool.length > 1) pool.remove(avoid);
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
      slot: sideSlot,
    );
  }

  /// Refresh Daily / Week when UTC day or ISO week rolls.
  static GameState ensureDailyQuest(GameState state, {DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    final day = MetaSystems.dailyDateKey(clock);
    final week = GameLogic.isoWeekKey(clock);
    if (state.missions.length != boardSize ||
        needsQuestBoardRebuild(state.missions)) {
      return state.copyWith(
        missions: createMissionBoardFor(state),
        metaDepth: state.metaDepth.copyWith(
          dailyQuestDate: day,
          questWeekKey: week,
        ),
      );
    }
    var missions = List<Mission>.from(state.missions);
    var md = state.metaDepth;
    var changed = false;
    if (md.dailyQuestDate != day) {
      missions[dailySlot] = createDailyMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        endgame: GameLogic.endgameUnlocked(state),
      );
      md = md.copyWith(dailyQuestDate: day);
      changed = true;
    }
    if (md.questWeekKey != week) {
      missions[weekSlot] = createWeekMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        endgame: GameLogic.endgameUnlocked(state),
        avoidTypes: <MissionType>[missions[contractSlot].type],
      );
      md = md.copyWith(questWeekKey: week);
      changed = true;
    }
    // Soft-fix live boards that rolled the same Week + Contract goal.
    if (missions[weekSlot].type == missions[contractSlot].type) {
      missions[contractSlot] = createContractMission(
        ascensionLevel: state.ascensionLevel,
        highestDungeonCleared: state.highestDungeonCleared,
        highestFloorCleared: state.highestFloorCleared,
        hardmodeLevel: state.hardmodeLevel,
        endgame: GameLogic.endgameUnlocked(state),
        avoidTypes: <MissionType>[
          missions[weekSlot].type,
          missions[sideSlot].type,
        ],
      );
      changed = true;
    }
    if (!changed) return state;
    return state.copyWith(missions: missions, metaDepth: md);
  }

  static GameState applyMissionProgress(
    GameState state, {
    int enemiesDefeated = 0,
    int bossesCleared = 0,
    int goldEarned = 0,
    int floorsCleared = 0,
    int elitesDefeated = 0,
    int timedKeys = 0,
    int gauntletFloors = 0,
    int riftClears = 0,
    int greaterRiftClears = 0,
    int ashenClears = 0,
  }) {
    state = ensureDailyQuest(state);
    if (state.missions.isEmpty) {
      return state;
    }
    if (enemiesDefeated <= 0 &&
        bossesCleared <= 0 &&
        goldEarned <= 0 &&
        floorsCleared <= 0 &&
        elitesDefeated <= 0 &&
        timedKeys <= 0 &&
        gauntletFloors <= 0 &&
        riftClears <= 0 &&
        greaterRiftClears <= 0 &&
        ashenClears <= 0) {
      return state;
    }

    var newlyReady = 0;
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
        MissionType.timedKeys => timedKeys,
        MissionType.gauntletFloors => gauntletFloors,
        MissionType.clearRifts => riftClears,
        MissionType.clearGreaterRifts => greaterRiftClears,
        MissionType.ashenCrown => ashenClears,
      };
      if (add <= 0) {
        return mission;
      }
      final next = mission.copyWith(
        progress: min(mission.target, mission.progress + add),
      );
      if (next.canClaim) newlyReady++;
      return next;
    }).toList();

    if (newlyReady > 0) LogicNotices.recordQuestReady(newlyReady);
    return state.copyWith(missions: updated);
  }

  /// Claims a completed quest.
  /// Daily / Week stay claimed until calendar rolls; Bounty advances rung;
  /// Side / Contract roll fresh goals.
  static GameState claimMission(
    GameState state,
    String missionId, {
    DateTime? now,
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    state = ensureDailyQuest(state, now: clock);
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
    var nextWeekKey = state.metaDepth.questWeekKey;

    if (index == dailySlot) {
      missions[index] = mission.copyWith(claimed: true);
      nextDailyDate = MetaSystems.dailyDateKey(clock);
    } else if (index == weekSlot) {
      missions[index] = mission.copyWith(claimed: true);
      nextWeekKey = GameLogic.isoWeekKey(clock);
    } else if (index == bountySlot) {
      final endgame = GameLogic.endgameUnlocked(state);
      final maxRung = bountyRungMax(endgame: endgame);
      nextRung = min(maxRung, state.metaDepth.bountyRung + 1);
      // Top rung repeats after claim.
      if (state.metaDepth.bountyRung >= maxRung) {
        nextRung = maxRung;
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
        endgame: endgame,
      );
    } else {
      missions[index] = rollReplacementMission(
        state,
        avoid: mission.type,
        slot: index,
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
        questWeekKey: nextWeekKey,
      ),
      lastUpdated: clock,
    );
  }
}
