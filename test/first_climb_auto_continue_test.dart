import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_director.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/remote_tune.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  Future<GameDirector> bossApproach() async {
    final director = GameDirector.preview();
    await director.boot();
    await director.startNewGame(HeroSpecs.starterUnlocked);
    director.enterDungeon(dungeonId: 'sandy');
    director.debugHoldSave(
      director.state.copyWith(highestFloorCleared: 1),
    );
    final world = SpatialCombat.build(director.state);
    world.awaitingExit = true;
    director.debugAttachSpatial(world);
    return director;
  }

  test('leaving after floor 1 clear stays in cave for the boss floor', () async {
    RemoteTune.apply(firstClimbAutoContinue: true);
    addTearDown(RemoteTune.reset);
    final director = await bossApproach();
    addTearDown(director.dispose);
    director.leaveDungeon();
    expect(director.state.inDungeon, isTrue);
    expect(
      director.state.currentRoom.floorNumber,
      GameLogic.firstBossFloor,
    );
  });

  test('auto continue respects the remote flag', () async {
    RemoteTune.apply(firstClimbAutoContinue: false);
    addTearDown(RemoteTune.reset);
    final director = await bossApproach();
    addTearDown(director.dispose);
    director.leaveDungeon();
    expect(director.state.inDungeon, isFalse);
  });
}