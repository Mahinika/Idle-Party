import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/chase_contract.dart';
import 'package:idle_party/core/first_climb_coach.dart';
import 'package:idle_party/core/game_logic.dart';
void main() {
  final now = DateTime.utc(2026, 11, 20, 12);

  test('goalLine prefers first climb coach in the cave', () {
    final state = GameLogic.enterDungeon(
      GameLogic.createInitialState(now: now),
      dungeonId: 'sandy',
    );
    expect(
      ChaseContract.goalLine(state, inDungeon: true),
      FirstClimbCoach.line(state, inDungeon: true),
    );
  });

  test('goalLine uses hub chase after the first boss', () {
    final state = GameLogic.createInitialState(now: now).copyWith(
      bossVictories: 1,
      highestFloorCleared: 2,
    );
    final goal = ChaseContract.goalLine(state, inDungeon: false, now: now);
    expect(goal, isNotNull);
    expect(goal, isNot(contains('floor 2')));
  });
}