import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ascend_roadmap.dart';
import 'package:idle_party/core/game_logic.dart';

void main() {
  test('Ascend roadmap unlocks key AL milestones', () {
    expect(AscendRoadmap.unlockAtAl(1), contains('Combat Rogue'));
    expect(AscendRoadmap.unlockAtAl(2), contains('5th party'));
    expect(AscendRoadmap.unlockAtAl(2), contains('80e'));
    expect(
      AscendRoadmap.unlockAtAl(GameLogic.gauntletMinAscension),
      contains('Gauntlet'),
    );
    expect(AscendRoadmap.unlockAtAl(5), contains('Warden'));
    expect(AscendRoadmap.unlockAtAl(4), isNull);
  });

  test('nextGoalLine points at the nearest unlock', () {
    expect(AscendRoadmap.nextGoalLine(0), contains('AL1'));
    expect(AscendRoadmap.nextGoalLine(1), contains('AL2'));
    expect(AscendRoadmap.nextGoalLine(9), contains('Gauntlet'));
    expect(AscendRoadmap.chaseTeaser(0), contains('AL1'));
  });
}
