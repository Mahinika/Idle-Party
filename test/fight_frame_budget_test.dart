import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/fight_frame_budget.dart';

void main() {
  test('live pace stays inside one refresh', () {
    expect(
      FightFrameBudget.steps(pace: 1, debugScale: 1, catchUp: 0, lastSimMs: 0),
      1,
    );
    expect(
      FightFrameBudget.steps(pace: 2, debugScale: 1, catchUp: 0, lastSimMs: 10),
      2,
    );
    expect(
      FightFrameBudget.steps(pace: 2, debugScale: 1, catchUp: 0, lastSimMs: 30),
      1,
    );
  });

  test('debug scale ignores a late frame', () {
    expect(
      FightFrameBudget.steps(
        pace: 2,
        debugScale: 10,
        catchUp: 0,
        lastSimMs: 30,
      ),
      20,
    );
  });

  test('one dropped ask catches up only when the last tick was quick', () {
    expect(
      FightFrameBudget.steps(pace: 1, debugScale: 1, catchUp: 1, lastSimMs: 10),
      2,
    );
    expect(
      FightFrameBudget.steps(pace: 1, debugScale: 1, catchUp: 1, lastSimMs: 30),
      1,
    );
  });
}
