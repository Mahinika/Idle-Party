import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_mode.dart';

void main() {
  GameState wipedOnFloor3() {
    final floor = DungeonGenerator.generateFloor(2);
    final room = floor.first;
    var state = GameLogic.createInitialState(now: DateTime(2026, 10, 13))
        .copyWith(
          dungeonMode: DungeonMode.push,
          inDungeon: true,
          currentRoom: room,
          dungeonFloor: floor,
          enemies: GameLogic.createEnemyGroup(
            room,
          ).map((e) => e.copyWith(currentHp: 1)).toList(),
        );
    state = GameLogic.completeCurrentRoom(
      state,
      goldGain: 10,
      skipLootRoll: true,
    );
    expect(state.currentRoom.floorNumber, 3);
    expect(state.highestFloorCleared, 2);
    return state.copyWith(
      heroes: state.heroes.map((h) => h.copyWith(currentHp: 0)).toList(),
      wipeStreakKey: GameLogic.wipeFloorKey(state),
    );
  }

  test('one wipe on a new floor retries that floor', () {
    final once = GameLogic.continueAfterWipe(
      wipedOnFloor3().copyWith(wipeStreakCount: 1),
    );
    expect(once.inDungeon, isTrue);
    expect(once.dungeonMode, DungeonMode.push);
    expect(once.currentRoom.floorNumber, 3);
    expect(once.pushResumeFloor, 0);
    expect(once.heroes.every((h) => h.currentHp > 0), isTrue);
  });

  test('two wipes farm the floor below, then one clear pushes again', () {
    final farm = GameLogic.continueAfterWipe(
      wipedOnFloor3().copyWith(wipeStreakCount: 2),
    );
    expect(farm.dungeonMode, DungeonMode.farm);
    expect(farm.currentRoom.floorNumber, 2);
    expect(farm.pushResumeFloor, 3);
    expect(farm.inDungeon, isTrue);

    final back = GameLogic.completeCurrentRoom(
      farm.copyWith(
        enemies: farm.enemies.map((e) => e.copyWith(currentHp: 1)).toList(),
      ),
      goldGain: 10,
      skipLootRoll: true,
    );
    expect(back.dungeonMode, DungeonMode.push);
    expect(back.currentRoom.floorNumber, 3);
    expect(back.pushResumeFloor, 0);
  });

  test('ascend clears a pending farm-back', () {
    final farm = GameLogic.continueAfterWipe(
      wipedOnFloor3().copyWith(wipeStreakCount: 2),
    );
    final ascended = GameLogic.ascend(
      farm.copyWith(
        bossVictories: GameLogic.bossesRequiredForAscension(0),
        essence: 9999,
      ),
    );
    expect(ascended.pushResumeFloor, 0);
  });

  test('an old save without pushResumeFloor loads as none', () {
    final fresh = GameLogic.createInitialState(now: DateTime(2026, 10, 13));
    final json = fresh.toJson()..remove('pushResumeFloor');
    final loaded = GameLogic.stateFromJson(json);
    expect(loaded.pushResumeFloor, 0);
  });
}
