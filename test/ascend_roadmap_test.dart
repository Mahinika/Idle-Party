import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/ascend_roadmap.dart';
import 'package:idle_party/core/game_logic.dart';

void main() {
  test('Ascend roadmap unlocks key AL milestones', () {
    expect(AscendRoadmap.unlockAtAl(1), contains('Combat Rogue'));
    expect(AscendRoadmap.unlockAtAl(1), contains('Holy Paladin'));
    expect(AscendRoadmap.unlockAtAl(2), contains('5th party'));
    expect(AscendRoadmap.unlockAtAl(2), contains('80e'));
    expect(
      AscendRoadmap.unlockAtAl(GameLogic.maxAscensionLevel),
      contains('Ascension cap'),
    );
    expect(
      AscendRoadmap.unlockAtAl(GameLogic.maxAscensionLevel),
      contains('${GameLogic.maxHeroLevel}'),
    );
    expect(
      AscendRoadmap.unlockAtAl(GameLogic.maxAscensionLevel),
      contains('KEY'),
    );
    expect(AscendRoadmap.unlockAtAl(5), contains('Guardian'));
    expect(AscendRoadmap.unlockAtAl(5), contains('Blood DK'));
    expect(AscendRoadmap.unlockAtAl(4), contains('Survival'));
    expect(AscendRoadmap.unlockAtAl(4), contains('+2 more'));
    expect(AscendRoadmap.unlockAtAl(6), contains('Affliction'));
  });

  test('nextGoalLine points at the nearest unlock', () {
    expect(AscendRoadmap.nextGoalLine(0), contains('AL1'));
    expect(AscendRoadmap.nextGoalLine(1), contains('AL2'));
    expect(AscendRoadmap.nextGoalLine(9), contains('AL10'));
    expect(AscendRoadmap.nextGoalLine(19), contains('Ascension cap'));
    expect(AscendRoadmap.nextGoalLine(19), contains('${GameLogic.maxHeroLevel}'));
    expect(AscendRoadmap.chaseTeaser(0), contains('AL1'));
  });
}