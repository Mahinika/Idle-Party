import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gauntlet_anomaly.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/spatial/floor_blueprint.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('Gauntlet anomalies skip boss floors and cycle on F3/8/13/18', () {
    expect(GauntletAnomalies.forFloor(5, inGauntlet: true), isNull);
    expect(GauntletAnomalies.forFloor(10, inGauntlet: true), isNull);
    expect(GauntletAnomalies.forFloor(1, inGauntlet: true), isNull);
    expect(GauntletAnomalies.forFloor(3, inGauntlet: false), isNull);
    expect(
      GauntletAnomalies.forFloor(3, inGauntlet: true),
      GauntletAnomaly.tightCorridors,
    );
    expect(
      GauntletAnomalies.forFloor(8, inGauntlet: true),
      GauntletAnomaly.swarmUprising,
    );
    expect(
      GauntletAnomalies.forFloor(13, inGauntlet: true),
      GauntletAnomaly.bossEcho,
    );
    expect(GauntletAnomalies.forFloor(18, inGauntlet: true), isNull);
    expect(
      GauntletAnomalies.forFloor(38, inGauntlet: true),
      GauntletAnomaly.gateGauntlet,
    );
    expect(
      GauntletAnomalies.forFloor(23, inGauntlet: true),
      GauntletAnomaly.tightCorridors,
    );
  });

  test('Gauntlet swarm floor packs denser than the prior non-anomaly floor', () {
    final swarm = _gauntletWorld(8);
    final prior = _gauntletWorld(7);
    expect(swarm.gauntletAnomaly, GauntletAnomaly.swarmUprising);
    expect(prior.gauntletAnomaly, isNull);
    expect(swarm.enemies.length, greaterThan(prior.enemies.length));
  });

  test('Gauntlet echo floor marks one trash tell without a boss room', () {
    final echo = _gauntletWorld(13);
    expect(echo.gauntletAnomaly, GauntletAnomaly.bossEcho);
    expect(echo.enemies.where((e) => e.bossEcho), hasLength(1));
    expect(echo.enemies.any((e) => e.role == EnemyRole.boss), isFalse);
  });

  test('Gauntlet gate floor asks for extra combat chambers', () {
    final room = DungeonGenerator.generateFloorRoom(
      floorNumber: 38,
      ascensionLevel: 0,
      dungeonId: 'crystal',
      layoutSeed: 42,
      bossEvery: GameLogic.gauntletBossEvery,
    );
    final gated = FloorBlueprint.forRoom(
      room,
      dungeonId: 'crystal',
      layoutSeed: 42,
      extraCombatRooms: GauntletAnomalies.extraCombatRooms(
        GauntletAnomaly.gateGauntlet,
      ),
    );
    final base = FloorBlueprint.forRoom(
      room,
      dungeonId: 'crystal',
      layoutSeed: 42,
    );
    expect(
      gated.storyChambers.length,
      greaterThan(base.storyChambers.length),
    );
    expect(_gauntletWorld(38).map.gates, isNotEmpty);
  });
}

SpatialWorld _gauntletWorld(int floor) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 9, 19));
  final room = DungeonGenerator.generateFloorRoom(
    floorNumber: floor,
    ascensionLevel: state.ascensionLevel,
    dungeonId: 'crystal',
    layoutSeed: 42,
    bossEvery: GameLogic.gauntletBossEvery,
  );
  final primed = state.copyWith(inGauntlet: true, dungeonId: 'crystal');
  final enemies = GameLogic.createEnemyGroup(
    room,
    dungeonId: 'crystal',
    fromState: primed,
  );
  state = primed.copyWith(
    inDungeon: true,
    currentRoom: room,
    dungeonFloor: [room],
    enemies: enemies,
    layoutSeed: 42,
  );
  return SpatialCombat.build(state);
}
