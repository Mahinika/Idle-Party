import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/meta_systems.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('fresh hub prefers daily run', () {
    final state = GameLogic.createInitialState(now: now);
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyRun);
    expect(chase.title, isNotEmpty);
    expect(chase.detail, isNotEmpty);
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
  });

  test('Gauntlet milestone chase at AL10+', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      ascensionLevel: 10,
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
    );
    expect(state.collectionScore, greaterThanOrEqualTo(320));
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.gauntletMilestone);
    expect(chase.title, contains('25'));
  });

  test('next locked zone chase uses lifetime gold progress', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
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
    expect(chase.kind, HubChaseKind.unlockZone);
    expect(chase.title, contains('Goblin'));
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

  test('KEY +1 vault progress marks ALMOST', () {
    var state = GameLogic.createInitialState(now: now);
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        dailyVaultClears: 0,
        dailyVaultClaimed: false,
        dailyBestTimedKey: 1,
      ),
      lastDailyDate: MetaSystems.dailyDateKey(now),
      dailyClaimed: true,
    );
    final chase = HubChase.forState(state, now: now);
    expect(chase.kind, HubChaseKind.dailyVaultProgress);
    expect(chase.urgency, HubChaseUrgency.almost);
    expect(chase.title, contains('Almost'));
  });
}
