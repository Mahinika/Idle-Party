import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/hub_chase.dart';
import 'package:idle_party/core/meta_systems.dart';

void main() {
  test('fresh hub prefers daily run', () {
    final state = GameLogic.createInitialState(now: DateTime(2026, 8, 8, 12));
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.dailyRun);
    expect(chase.title, isNotEmpty);
    expect(chase.detail, isNotEmpty);
  });

  test('claim weekly beats other chases', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 8, 12));
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        weeklyProgress: GameLogic.weeklyClearTarget,
        weeklyClaimed: false,
        weeklyModifier: 'fortune',
      ),
    );
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.claimWeekly);
    expect(chase.progressLabel, '3/3 ready');
  });

  test('complete missions surface as claim chase', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 8, 12));
    final m = state.missions.first;
    state = state.copyWith(
      missions: [
        m.copyWith(progress: m.target),
        ...state.missions.skip(1),
      ],
      metaDepth: state.metaDepth.copyWith(weeklyClaimed: true),
    );
    // Mark daily claimed so it doesn't win.
    state = state.copyWith(
      lastDailyDate: MetaSystems.dailyDateKey(DateTime(2026, 8, 8, 12)),
      dailyClaimed: true,
    );
    expect(state.missions.first.isComplete, isTrue);
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.claimMissions);
  });

  test('Will chase shows next threshold gap', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 8, 12));
    state = state.copyWith(
      metaDepth: state.metaDepth.copyWith(weeklyClaimed: true),
      lastDailyDate: MetaSystems.dailyDateKey(DateTime(2026, 8, 8, 12)),
      dailyClaimed: true,
      achievements: const [],
      lifetimeGoldEarned: 5_000_000,
      highestDungeonCleared: 8,
    );
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.willRank);
    expect(chase.title, contains('Kindled Will'));
    expect(chase.progressLabel, contains('/25'));
  });

  test('Gauntlet milestone chase at AL10+', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 8, 12));
    state = state.copyWith(
      ascensionLevel: 10,
      metaDepth: state.metaDepth.copyWith(
        weeklyClaimed: true,
        gauntletBestFloor: 10,
      ),
      lastDailyDate: MetaSystems.dailyDateKey(DateTime(2026, 8, 8, 12)),
      dailyClaimed: true,
      achievements: [
        for (var i = 0; i < 160; i++) 'ach_$i',
      ],
      highestDungeonCleared: 8,
      lifetimeGoldEarned: 5_000_000,
    );
    expect(state.collectionScore, greaterThanOrEqualTo(320));
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.gauntletMilestone);
    expect(chase.title, contains('25'));
  });

  test('next locked zone chase uses lifetime gold progress', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 8, 12));
    state = state.copyWith(
      lifetimeGoldEarned: 1000,
      highestDungeonCleared: -1,
      metaDepth: state.metaDepth.copyWith(weeklyClaimed: true),
      lastDailyDate: MetaSystems.dailyDateKey(DateTime(2026, 8, 8, 12)),
      dailyClaimed: true,
      achievements: [
        for (var i = 0; i < 160; i++) 'ach_$i',
      ],
    );
    expect(state.collectionScore, greaterThanOrEqualTo(320));
    final chase = HubChase.forState(state);
    expect(chase.kind, HubChaseKind.unlockZone);
    expect(chase.title, contains('Goblin'));
  });
}
