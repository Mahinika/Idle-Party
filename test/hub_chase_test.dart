import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/core/local_season.dart';
import 'package:idle_party/core/ashen_crown.dart';
import 'package:idle_party/core/greater_rift.dart';
import 'package:idle_party/core/rift.dart';
import 'package:idle_party/models/meta_depth.dart';

const _gauntletMilestonesDone = <String>['f25', 'f50', 'f100', 'f150', 'f200'];

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('fresh hub prefers growing the party in the starter zone', () {
    final state = GameLogic.createInitialState(now: now);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.title, contains('Grow the party'));
    expect(chase.title, contains('Sandy'));
    expect(chase.urgency, HubChaseUrgency.normal);
    expect(chase.detail.toLowerCase(), contains('cave'));
    expect(chase.detail, isNot(contains('Combat Rogue')));
    expect(chase.detail, isNot(contains('AL1')));
  });

  test('claim daily vault beats other chases', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(
      state,
      now: now,
    );
    state = state.copyWith(
      bossVictories: 1,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
        weeklyModifier: 'fortune',
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.claimDailyVault);
    expect(chase.urgency, HubChaseUrgency.ready);
    expect(chase.progressLabel, isNull);
  });

  test('claimable vault stays on payday copy (season pays silently)', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(state, now: now);
    state = state.copyWith(
      bossVictories: 1,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
        claimedSeasonRewards: const <String>[],
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.claimDailyVault);
    expect(chase.title.toLowerCase(), contains('vault'));
    expect(chase.detail.toLowerCase(), contains('claim'));
    expect(chase.detail.toLowerCase(), isNot(contains('season')));
  });

  test('complete missions surface as claim chase', () {
    var state = GameLogic.createInitialState(now: now);
    final m = state.missions.first;
    state = state.copyWith(
      bossVictories: 1,
      missions: [
        m.copyWith(progress: m.target),
        ...state.missions.skip(1),
      ],
      metaDepth: state.metaDepth.copyWith(dailyVaultClaimed: true),
    );
    // Mark daily claimed so it doesn't win.
    state = state.copyWith(
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
    );
    expect(state.missions.first.isComplete, isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.claimMissions);
    expect(chase.detail.toLowerCase(), contains('claim quests'));
    expect(chase.detail.toLowerCase(), isNot(contains('wait under')));
  });

  test('Will ALMOST still beats midgame party-level', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      ascensionLevel: 1,
      hardmodeLevel: Keystone.maxForAl(1),
      metaDepth: state.metaDepth.copyWith(dailyVaultClaimed: true),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      // 11 ach × 2 = score 22 → 3 points to Kindled Will (ALMOST).
      achievements: [
        for (var i = 0; i < 11; i++) 'ach_$i',
      ],
      lifetimeGoldEarned: 5_000_000,
      highestDungeonCleared: 8,
    );
    expect(state.collectionScore, 22);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.willRank);
    expect(chase.urgency, HubChaseUrgency.almost);
    expect(chase.title, contains('Kindled Will'));
    expect(chase.progressLabel, contains('/25'));
    expect(chase.detail, contains('+${WillRanks.essenceForThreshold(25)}e'));
  });

  test('Gauntlet milestone chase at party max level', () {
    var state = GameLogic.createInitialState(now: now);
    state = _withPartyMaxLevel(
      state.copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        metaDepth: state.metaDepth.copyWith(
          dailyVaultClaimed: true,
          grBestTier: GreaterRift.campaignCap,
          claimedGrMilestones: const ['gr5', 'gr10', 'gr20'],
          gauntletBestFloor: 10,
        ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        achievements: [
          for (var i = 0; i < 160; i++) 'ach_$i',
        ],
        highestDungeonCleared: 8,
        lifetimeGoldEarned: 5_000_000,
      ),
    );
    expect(state.collectionScore, greaterThanOrEqualTo(320));
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.gauntletMilestone);
    expect(chase.title, contains('25'));
    expect(chase.detail, contains('+${GauntletMilestones.essenceForFloor(25)}e'));
  });

  test('normal zone unlock does not beat pushing the current dungeon', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      ascensionLevel: 1,
      lifetimeGoldEarned: 1000,
      highestDungeonCleared: -1,
      metaDepth: state.metaDepth.copyWith(dailyVaultClaimed: true),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      achievements: [
        for (var i = 0; i < 160; i++) 'ach_$i',
      ],
    );
    expect(state.collectionScore, greaterThanOrEqualTo(320));
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, isNot(HubChaseKind.unlockZone));
    expect(chase.title.toLowerCase(), isNot(contains('unlock')));
  });

  test('first boss on AL0 chases the cave vault, not sole Ascend button', () {
    var state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
    );
    expect(GameLogic.canAscend(state), isTrue);
    expect(GameLogic.showDailyRunOnHub(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.title.toLowerCase(), contains('cave'));
    expect(chase.kind, isNot(HubChaseKind.ascend));
    expect(chase.kind, isNot(HubChaseKind.dailyRun));
  });

  test('AL5 Lv40 TODAY is one cave today, not KEY or Gauntlet', () {
    final state = _withHeroLevels(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 5,
        bossVictories: 1,
        highestDungeonCleared: 14,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClears: 0,
              dailyVaultClaimed: false,
              dailyBestTimedKey: 0,
            ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
      ),
      40,
    );
    expect(GameLogic.endgameUnlocked(state), isFalse);
    expect(GameLogic.showKeystoneJargon(state), isFalse);
    expect(GameLogic.canAscend(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.title.toLowerCase(), contains('cave'));
    expect(chase.kind, isNot(HubChaseKind.keystone));
    expect(chase.kind, isNot(HubChaseKind.gauntletMilestone));
    expect(chase.title.toUpperCase(), isNot(contains('KEY')));
  });

  test('AL5 Lv40 with vault claimed chases party levels, not KEY', () {
    final state = _withHeroLevels(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 5,
        bossVictories: 1,
        highestDungeonCleared: 14,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
            ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
      ),
      40,
    );
    expect(GameLogic.endgameUnlocked(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.title, contains('Level the party to ${GameLogic.maxHeroLevel}'));
    expect(chase.urgency, HubChaseUrgency.normal);
    expect(chase.detail.toUpperCase(), contains('KEY'));
    expect(chase.detail, isNot(contains('AL20')));
    expect(chase.kind, isNot(HubChaseKind.keystone));
    expect(chase.kind, isNot(HubChaseKind.gauntletMilestone));
  });

  test('near Lv100 ALMOST party-level beats empty Daily vault', () {
    final state = _withHeroLevels(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 5,
        bossVictories: 1,
        highestDungeonCleared: 14,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClears: 0,
              dailyVaultClaimed: false,
              dailyBestTimedKey: 0,
            ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
      ),
      96,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.title, contains('Almost party Lv${GameLogic.maxHeroLevel}'));
    expect(chase.urgency, HubChaseUrgency.almost);
    expect(chase.kind, isNot(HubChaseKind.dailyVaultProgress));
  });

  test('at party max KEY habit beats Ascend READY', () {
    final state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 5,
        bossVictories: 6,
        hardmodeLevel: 2,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
            ),
      ),
    );
    expect(GameLogic.endgameUnlocked(state), isTrue);
    expect(GameLogic.canAscend(state), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.keystone);
    expect(chase.kind, isNot(HubChaseKind.ascend));
  });

  test('claimables and Ascend mark READY urgency', () {
    var state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
      bossVictories: 2,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            dailyVaultClaimed: true,
          ),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.ascend);
    expect(chase.urgency, HubChaseUrgency.ready);
    expect(chase.detail, contains('AL2'));
  });

  test('AL20 max blocks Ascend chase', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        bossVictories: 99,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              gauntletBestFloor: 42,
              ascendBlessings: 20,
            ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
      ),
    );
    expect(GameLogic.canAscend(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, isNot(HubChaseKind.ascend));
  });

  test('fresh prestige bag chases re-kit not KEY', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 5,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              freshPrestige: true,
              ascendBlessings: 20,
            ),
      ),
    );
    expect(GameLogic.endgameUnlocked(state), isTrue);
    expect(GameLogic.isFreshPrestigeGear(state), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.title, contains('Rebuild your bag'));
    expect(chase.kind, isNot(HubChaseKind.keystone));
    expect(chase.title.toUpperCase(), isNot(contains('REBORN')));
    expect(chase.progressLabel, contains('% geared'));
  });

  test('AL20 KEY chase stays when bag is not a fresh prestige wipe', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 5,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              freshPrestige: false,
              ascendBlessings: 20,
            ),
      ),
    );
    expect(GameLogic.isFreshPrestigeGear(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.keystone);
  });

  test('one boss from Ascend marks ALMOST and beats daily', () {
    // AL1 needs 2 bosses — bank 1 so one remains.
    var state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
      bossVictories: 1,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            dailyVaultClaimed: true,
          ),
    );
    expect(GameLogic.bossesRequiredForAscension(1), 2);
    // Daily still available — almost-Ascend should still win.
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.clearFloors);
    expect(chase.urgency, HubChaseUrgency.almost);
    expect(chase.title, contains('Almost Ascend'));
    expect(chase.detail, contains('AL2'));
  });

  test('zone ALMOST beats daily run', () {
    // Goblin unlocks at party Lv8 — within 3 levels counts as ALMOST.
    final base = GameLogic.createInitialState(now: now);
    var state = base.copyWith(
      bossVictories: 1,
      highestDungeonCleared: -1,
      heroes: [
        for (final h in base.heroes) h.copyWith(level: 6, xp: 0),
      ],
      metaDepth: base.metaDepth.copyWith(
        dailyVaultClaimed: true,
      ),
    );
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.unlockZone);
    expect(chase.urgency, HubChaseUrgency.almost);
    expect(chase.title, contains('Almost'));
  });

  test('vault start before party max never uses KEY jargon', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      ascensionLevel: 1,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: 0,
        dailyVaultClaimed: false,
        dailyBestTimedKey: 0,
      ),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.detail.toUpperCase(), isNot(contains('KEY')));
  });

  test('party max vault almost uses KEY jargon', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        highestDungeonCleared: 14,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClears: 0,
              dailyVaultClaimed: false,
              dailyBestTimedKey: 1,
            ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
      ),
    );
    expect(GameLogic.showKeystoneJargon(state), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.title.toUpperCase(), contains('KEY'));
  });

  test('pending hero reveal is READY meet chase', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      bossVictories: 1,
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClaimed: true,
        pendingHeroReveals: const ['combat', 'arms'],
      ),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.meetHero);
    expect(chase.urgency, HubChaseUrgency.ready);
    expect(chase.title, contains('Combat'));
    expect(chase.detail.toLowerCase(), contains('roster'));
  });

  test('endgame skips Meet backlog so TODAY keeps Gauntlet/KEY hunt', () {
    final state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
          pendingHeroReveals: const ['combat', 'arms', 'fury'],
          dailyVaultClaimed: true,
        ),
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );
    expect(GameLogic.endgameUnlocked(state), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, isNot(HubChaseKind.meetHero));
    expect(
      chase.kind,
      anyOf(
        HubChaseKind.gauntletMilestone,
        HubChaseKind.keystone,
        HubChaseKind.greaterRiftMilestone,
        HubChaseKind.riftMilestone,
        HubChaseKind.ashenCrown,
      ),
    );
  });

  test('ack clears pending hero reveals', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        pendingHeroReveals: const ['combat'],
      ),
    );
    state = GameLogic.ackPendingHeroReveals(state);
    expect(state.metaDepth.pendingHeroReveals, isEmpty);
  });

  test('after first Ascend, one cave today is the hub chase (KEY waits for party max)', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
    );
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    expect(GameLogic.showKeystoneJargon(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.title.toLowerCase(), contains('cave'));
    expect(chase.kind, isNot(HubChaseKind.keystone));
    expect(chase.kind, isNot(HubChaseKind.dailyRun));
  });

  test('KEY habit at party max when preferred key below cap', () {
    final state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 2,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              gauntletBestFloor: 200,
              claimedGauntletMilestones: _gauntletMilestonesDone,
              riftBestTier: 20,
              claimedRiftMilestones: const ['r5', 'r10', 'r20'],
            ),
        achievements: [
          for (var i = 0; i < 200; i++) 'ach_$i',
        ],
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );
    expect(GameLogic.showKeystoneJargon(state), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.keystone);
    expect(chase.keyLevel, 2);
    expect(chase.title, contains('KEY +2'));
  });

  test('KEY habit does not wait on unpaid Daily at party max', () {
    final state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 3,
        dailyClaimed: false,
        lastDailyDate: '',
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              gauntletBestFloor: 200,
              claimedGauntletMilestones: _gauntletMilestonesDone,
              riftBestTier: 20,
              claimedRiftMilestones: const ['r5', 'r10', 'r20'],
              grBestTier: 20,
              claimedGrMilestones: const ['gr5', 'gr10', 'gr20'],
              worldBossTickets: 0,
              worldBossClearedWeek: true,
            ),
        achievements: [
          for (var i = 0; i < 200; i++) 'ach_$i',
        ],
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.keystone);
    expect(chase.keyLevel, 3);
  });

  test('KEY at AL cap falls through to today\'s cave before party max', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
      hardmodeLevel: 0,
    );
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.kind, isNot(HubChaseKind.dailyRun));
  });

  test('Rift milestone chase at party max level', () {
    var state = GameLogic.createInitialState(now: now);
    state = _withPartyMaxLevel(
      state.copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        metaDepth: state.metaDepth.copyWith(
          dailyVaultClaimed: true,
          gauntletBestFloor: 200,
          claimedGauntletMilestones: _gauntletMilestonesDone,
          grBestTier: GreaterRift.campaignCap,
          claimedGrMilestones: const ['gr5', 'gr10', 'gr20'],
          riftBestTier: 0,
        ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        achievements: [
          for (var i = 0; i < 200; i++) 'ach_$i',
        ],
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.riftMilestone);
    expect(chase.title, contains('Farm Rift'));
  });

  test('Farm Rift waits until Ranked GR has a clear', () {
    final state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
          dailyVaultClaimed: true,
          gauntletBestFloor: 200,
          claimedGauntletMilestones: _gauntletMilestonesDone,
          grBestTier: 0,
          riftBestTier: 0,
        ),
        highestDungeonCleared: 14,
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, isNot(HubChaseKind.riftMilestone));
    expect(chase.kind, HubChaseKind.greaterRiftMilestone);
  });

  test('AL20 sub-max party chase names the Lv100 gate, not AL20', () {
    final base = GameLogic.createInitialState(now: now);
    final state = base.copyWith(
      ascensionLevel: GameLogic.maxAscensionLevel,
      bossVictories: 99,
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      metaDepth: base.metaDepth.copyWith(dailyVaultClaimed: true),
      heroRoster: [
        for (final h in base.heroRoster) h.copyWith(level: 88, xp: 0),
      ],
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.title, contains('${GameLogic.maxHeroLevel}'));
    expect(chase.detail.toUpperCase(), contains('KEY'));
    expect(chase.detail, isNot(contains('AL20')));
  });

  test('AL20 party-max prefers endgame ladder over Daily', () {
    final state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: false,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
            ),
        achievements: [
          for (var i = 0; i < 200; i++) 'ach_$i',
        ],
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );
    expect(GameLogic.endgameUnlocked(state), isTrue);
    final chase = HubChase.forState(state, now: now);
    // Spire-first ladder: Gauntlet before Greater Rift (FEEL 060 / 240).
    expect(chase.kind, HubChaseKind.gauntletMilestone);
    expect(chase.title, contains('Gauntlet'));
    expect(chase.kind, isNot(HubChaseKind.dailyRun));
  });

  test('Ashen Crown chase when GR Gauntlet Rift ladder is done', () {
    var md = GameLogic.createInitialState(now: now).metaDepth.copyWith(
      dailyVaultClaimed: true,
      grBestTier: GreaterRift.campaignCap,
      claimedGrMilestones: const ['gr5', 'gr10', 'gr20'],
      gauntletBestFloor: 200,
      claimedGauntletMilestones: _gauntletMilestonesDone,
      riftBestTier: Rift.campaignCap,
      claimedRiftMilestones: const ['r5', 'r10', 'r20'],
      worldBossTickets: 2,
      worldBossClearedWeek: false,
    );
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: md,
        achievements: [
          for (var i = 0; i < 200; i++) 'ach_$i',
        ],
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );
    state = AshenCrown.ensureWeek(state, now: now);
    // ensureWeek refreshes tickets; keep a clear available.
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        worldBossTickets: 2,
        worldBossClearedWeek: false,
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.ashenCrown);
    expect(chase.title, contains(AshenCrown.name));
  });

  test('endgame fallback is one KEY action not a stats dump', () {
    var state = _settledEndgameLadderState(now: now);
    state = AshenCrown.ensureWeek(state, now: now);
    const weekKey = '2026-W36'; // Veil Tempo · KEY +2
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        weeklyKey: weekKey,
        weeklyBestTimedKey: 0,
        worldBossTickets: 0,
        worldBossClearedWeek: true,
        claimedWeekGoals: <String>{
          ...state.metaDepth.claimedWeekGoals,
          week.claimIdForWeek(weekKey),
        }.toList(),
      ),
    );
    expect(state.collectionScore, greaterThanOrEqualTo(320));
    final chase = HubChase.forState(state, now: now);
    // Vault + Daily + KEY dial settled + week not cliff → soft session rest.
    expect(chase.kind, HubChaseKind.doneForToday);
    expect(chase.title, contains('Done for today'));
    expect(chase.detail.toLowerCase(), contains('boards'));
  });

  test('week ALMOST beats doneForToday soft rest', () {
    var state = _settledEndgameLadderState(now: now);
    state = AshenCrown.ensureWeek(state, now: now);
    const weekKey = '2026-W36'; // Veil Tempo · KEY +2
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        weeklyKey: weekKey,
        weeklyBestTimedKey: 1, // one KEY short of week goal → ALMOST
        worldBossTickets: 0,
        worldBossClearedWeek: true,
        claimedWeekGoals: const <String>[],
      ),
    );
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    expect(LocalSeasonCatalog.weekGoalAlmost(state, week), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.weekGoal);
    expect(chase.urgency, HubChaseUrgency.almost);
    expect(chase.kind, isNot(HubChaseKind.doneForToday));
  });

  test('week READY beats doneForToday soft rest', () {
    var state = _settledEndgameLadderState(now: now);
    state = AshenCrown.ensureWeek(state, now: now);
    const weekKey = '2026-W36'; // Veil Tempo · KEY +2
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        weeklyKey: weekKey,
        weeklyBestTimedKey: 2, // week goal met, not claimed → READY
        worldBossTickets: 0,
        worldBossClearedWeek: true,
        claimedWeekGoals: const <String>[],
      ),
    );
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    expect(LocalSeasonCatalog.weekGoalReady(state, week), isTrue);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.weekGoal);
    expect(chase.urgency, HubChaseUrgency.ready);
    expect(chase.kind, isNot(HubChaseKind.doneForToday));
  });

  test('Push Gauntlet PB when Daily still open', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: false,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
          dailyVaultClaimed: true,
          grBestTier: GreaterRift.campaignCap,
          claimedGrMilestones: const ['gr5', 'gr10', 'gr20'],
          gauntletBestFloor: 200,
          claimedGauntletMilestones: _gauntletMilestonesDone,
          riftBestTier: Rift.campaignCap,
          claimedRiftMilestones: const ['r5', 'r10', 'r20'],
          worldBossTickets: 0,
          worldBossClearedWeek: true,
        ),
        achievements: [
          for (var i = 0; i < 400; i++) 'ach_$i',
        ],
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );
    state = AshenCrown.ensureWeek(state, now: now);
    final weekKey = state.metaDepth.weeklyKey.isNotEmpty
        ? state.metaDepth.weeklyKey
        : GameLogic.isoWeekKey(now);
    final week = LocalSeasonCatalog.forWeekKey(weekKey);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        weeklyKey: weekKey,
        worldBossTickets: 0,
        worldBossClearedWeek: true,
        claimedWeekGoals: <String>{
          ...state.metaDepth.claimedWeekGoals,
          week.claimIdForWeek(weekKey),
        }.toList(),
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.gauntletMilestone);
    expect(chase.title, contains('Push Gauntlet PB'));
    expect(chase.detail, contains('PB F200'));
  });

  test('KEY chase detail names affixes and par', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 5,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              ascendBlessings: 20,
            ),
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.keystone);
    expect(chase.detail, contains('iLvl'));
    expect(chase.detail.toLowerCase(), contains('par'));
  });

  test('KEY roster hint surfaces for swarm affix week', () {
    expect(
      Keystone.rosterHintForAffixes(const ['swarm']),
      contains('Shield'),
    );
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 2,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              weeklyModifier: 'swarm',
            ),
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
      ),
    );
    final chase = HubChase.forState(state, now: now);
    if (chase.kind == HubChaseKind.keystone) {
      expect(chase.detail, contains('Shield'));
    }
  });

  test('Rebuild bag chase uses plain gear-farm copy', () {
    var state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 5,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              freshPrestige: true,
              ascendBlessings: 20,
            ),
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.title, contains('Rebuild your bag'));
    expect(chase.progressLabel, contains('% geared'));
    expect(chase.detail.toLowerCase(), contains('farm early'));
    expect(chase.detail.toLowerCase(), isNot(contains('kit pressure')));
  });

  group('session 2–5 chase matrix', () {
    test('S2 after first boss: one cave today, not Daily Run', () {
      final state = GameLogic.createInitialState(now: now).copyWith(
        bossVictories: 1,
      );
      expect(GameLogic.showDailyChase(state), isTrue);
      expect(GameLogic.showDailyRunOnHub(state), isFalse);
      final chase = HubChase.forState(state, now: now);
      expect(chase.kind, HubChaseKind.dailyVaultProgress);
      expect(chase.title.toLowerCase(), contains('cave'));
      expect(chase.detail.toUpperCase(), isNot(contains('DAILY RUN')));
    });

    test('S2 vault already claimed: level the party, not Daily Run or Ascend', () {
      final state = GameLogic.createInitialState(now: now).copyWith(
        bossVictories: 1,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
            ),
      );
      final chase = HubChase.forState(state, now: now);
      expect(chase.kind, HubChaseKind.clearFloors);
      expect(chase.title.toLowerCase(), contains('level the party'));
      expect(chase.kind, isNot(HubChaseKind.dailyRun));
      expect(chase.kind, isNot(HubChaseKind.ascend));
    });

    test('S3 Daily done, vault empty: fill Daily Vault', () {
      final state = GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 1,
        bossVictories: 0,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClears: 0,
              dailyVaultClaimed: false,
            ),
      );
      final chase = HubChase.forState(state, now: now);
      expect(chase.kind, HubChaseKind.dailyVaultProgress);
      expect(chase.detail.toLowerCase(), contains('claim'));
      expect(chase.detail.toUpperCase(), isNot(contains('DAILY RUN')));
    });

    test('S3b after first Ascend and vault claimed, Daily Run can follow', () {
      final state = GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 1,
        bossVictories: 0,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
            ),
      );
      expect(GameLogic.showDailyRunOnHub(state), isTrue);
      expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
      final chase = HubChase.forState(state, now: now);
      expect(chase.kind, HubChaseKind.dailyRun);
    });

    test('S4 vault + Daily claimed mid AL: level the party', () {
      final state = GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 1,
        bossVictories: 0,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
            ),
        achievements: [
          for (var i = 0; i < 160; i++) 'ach_$i',
        ],
      );
      final chase = HubChase.forState(state, now: now);
      expect(chase.kind, HubChaseKind.clearFloors);
      expect(chase.title.toLowerCase(), contains('level the party'));
      expect(chase.kind, isNot(HubChaseKind.willRank));
    });

    test('S5 almost Ascend still beats open Daily Run', () {
      final state = GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: 1,
        bossVictories: 1,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
            ),
      );
      expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
      final chase = HubChase.forState(state, now: now);
      expect(chase.kind, HubChaseKind.clearFloors);
      expect(chase.urgency, HubChaseUrgency.almost);
      expect(chase.title, contains('Almost Ascend'));
    });
  });
}

GameState _withHeroLevels(GameState state, int level) => state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster) h.copyWith(level: level, xp: 0),
      ],
    );

GameState _withPartyMaxLevel(GameState state) =>
    _withHeroLevels(state, GameLogic.maxHeroLevel);

/// Ladder quiet: Vault/Daily/KEY settled candidates (week cliffs set by caller).
GameState _settledEndgameLadderState({required DateTime now}) =>
    _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
          dailyVaultClaimed: true,
          grBestTier: GreaterRift.campaignCap,
          claimedGrMilestones: const ['gr5', 'gr10', 'gr20'],
          gauntletBestFloor: 200,
          claimedGauntletMilestones: _gauntletMilestonesDone,
          riftBestTier: Rift.campaignCap,
          claimedRiftMilestones: const ['r5', 'r10', 'r20'],
          worldBossTickets: 0,
          worldBossClearedWeek: true,
        ),
        achievements: [
          for (var i = 0; i < 400; i++) 'ach_$i',
        ],
        highestDungeonCleared: 14,
        lifetimeGoldEarned: 50_000_000,
      ),
    );