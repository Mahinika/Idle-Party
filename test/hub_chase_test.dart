import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/meta_systems.dart';
import 'package:idle_party/models/meta_depth.dart';

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
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
        weeklyModifier: 'fortune',
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.claimDailyVault);
    expect(chase.progressLabel, contains('ready'));
  });

  test('season bonus surfaces on claimable vault', () {
    var state = GameLogic.createInitialState(now: now);
    state = GameLogic.ensureWeeklyContract(state, now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: GameLogic.dailyVaultClearTarget,
        dailyVaultClaimed: false,
        claimedSeasonRewards: const <String>[],
      ),
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.claimDailyVault);
    expect(chase.title.toLowerCase(), contains('season'));
  });

  test('complete missions surface as claim chase', () {
    var state = GameLogic.createInitialState(now: now);
    final m = state.missions.first;
    state = state.copyWith(
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
  });

  test('Will chase shows next threshold gap', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      ascensionLevel: 1,
      hardmodeLevel: Keystone.maxForAl(1),
      metaDepth: state.metaDepth.copyWith(dailyVaultClaimed: true),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
      achievements: const [],
      lifetimeGoldEarned: 5_000_000,
      highestDungeonCleared: 8,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.willRank);
    expect(chase.title, contains('Kindled Will'));
    expect(chase.progressLabel, contains('/25'));
    expect(chase.detail, contains('+${WillRanks.essenceForThreshold(25)}e'));
  });

  test('Gauntlet milestone chase at party Lv60', () {
    var state = GameLogic.createInitialState(now: now);
    state = _withPartyMaxLevel(
      state.copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        metaDepth: state.metaDepth.copyWith(
          dailyVaultClaimed: true,
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

  test('claimables and Ascend mark READY urgency', () {
    var state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            dailyVaultClaimed: true,
          ),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.ascend);
    expect(chase.urgency, HubChaseUrgency.ready);
    expect(chase.detail, contains('AL1'));
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
    // Goblin unlock 5k — within 12% goldNeed counts as ALMOST.
    var state = GameLogic.createInitialState(now: now).copyWith(
      lifetimeGoldEarned: 4500,
      highestDungeonCleared: -1,
      metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
            dailyVaultClaimed: true,
          ),
    );
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.unlockZone);
    expect(chase.urgency, HubChaseUrgency.almost);
    expect(chase.title, contains('Almost'));
  });

  test('vault start before party Lv60 never uses KEY jargon', () {
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

  test('party Lv60 vault almost uses KEY jargon', () {
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
    expect(chase.detail.toLowerCase(), contains('party'));
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

  test('after first Ascend, Daily is the hub chase (KEY waits for party Lv60)', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
    );
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    expect(GameLogic.showKeystoneJargon(state), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyRun);
    expect(chase.kind, isNot(HubChaseKind.keystone));
  });

  test('KEY habit at party Lv60 when preferred key below cap', () {
    final state = _withPartyMaxLevel(
      GameLogic.createInitialState(now: now).copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: 2,
        lastDailyDate: MetaSystems.dailyDateKey(now),
        dailyClaimed: true,
        metaDepth: GameLogic.createInitialState(now: now).metaDepth.copyWith(
              dailyVaultClaimed: true,
              gauntletBestFloor: 100,
              claimedGauntletMilestones: const ['f25', 'f50', 'f100'],
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

  test('KEY at AL cap falls through to Daily before party Lv60', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      ascensionLevel: 1,
      hardmodeLevel: 0,
    );
    expect(MetaSystems.isDailyClaimedToday(state, now: now), isFalse);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyRun);
  });

  test('Rift milestone chase at party Lv60', () {
    var state = GameLogic.createInitialState(now: now);
    state = _withPartyMaxLevel(
      state.copyWith(
        ascensionLevel: GameLogic.maxAscensionLevel,
        hardmodeLevel: GameLogic.maxAscensionLevel,
        metaDepth: state.metaDepth.copyWith(
          dailyVaultClaimed: true,
          gauntletBestFloor: 100,
          claimedGauntletMilestones: const ['f25', 'f50', 'f100'],
          riftBestTier: 3,
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
    expect(chase.title, contains('Rift'));
  });
}

GameState _withPartyMaxLevel(GameState state) => state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
