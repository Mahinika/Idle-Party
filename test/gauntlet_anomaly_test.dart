import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/assets/kenney_assets.dart';
import 'package:idle_party/core/dungeon_generator.dart';
import 'package:idle_party/core/enemy_flavor.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gauntlet_anomaly.dart';
import 'package:idle_party/core/gauntlet_pact.dart';
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
    expect(GauntletAnomalies.nextBossFloor(3), 5);
    expect(GauntletAnomalies.nextAnomalyFloor(3), 8);
    expect(GauntletAnomalies.isTreasureFloor(18), isTrue);
    expect(GauntletAnomalies.climbPlaceLine(1), 'CLIMB · boss F5');
    expect(GauntletAnomalies.climbPlaceLine(2), 'CLIMB · boss F5');
    expect(GauntletAnomalies.climbPlaceLine(4), 'CLIMB · boss F5');
    expect(GauntletAnomalies.climbPlaceLine(3), 'CLIMB · TIGHT');
    expect(
      GauntletAnomalies.climbPlaceLine(5, liveBossName: 'Spire Warden'),
      'CLIMB · Spire Warden',
    );
    expect(GauntletAnomalies.climbPlaceLine(5), 'CLIMB · boss F5');
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

  test('ECHO one-liner does not claim a past boss on early floors', () {
    expect(
      GauntletAnomalies.oneLiner(GauntletAnomaly.bossEcho).toLowerCase(),
      isNot(contains('past')),
    );
    expect(
      GauntletAnomalies.oneLiner(GauntletAnomaly.bossEcho).toLowerCase(),
      contains('borrowed'),
    );
  });

  test('Gauntlet boss sprite follows gauntletBossDungeonId', () {
    // F10 cycles off Crystal to Tide — sprite must match Tide Leviathan art.
    final world = _gauntletWorld(10);
    final boss = world.enemies.firstWhere((e) => e.role == EnemyRole.boss);
    expect(boss.name, 'Tide Leviathan');
    final expectedId = EnemyFlavor.gauntletBossDungeonId(10);
    expect(expectedId, 'tide');
    final expectedSprite = KenneyAssets.enemySpriteForRole(
      EnemyRole.boss,
      dungeonId: expectedId,
    );
    expect(
      KenneyAssets.enemySpriteCatalog[boss.assetIndex],
      expectedSprite,
    );
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

  test('a Gauntlet climb can hit harder, take less, or pay double essence', () {
    final baseEss = GameLogic.gauntletEssenceForFloor(5, boss: true);
    expect(GauntletPacts.essence(baseEss, GauntletPact.greed), baseEss * 2);
    expect(GauntletPacts.essence(baseEss, GauntletPact.might), baseEss);
    expect(GauntletPacts.attackMul(GauntletPact.might), 1.2);
    expect(GauntletPacts.defenseMul(GauntletPact.ward), 1.25);
    expect(GauntletPacts.defenseMul(GauntletPact.greed), 0.85);

    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 10, 10));
    state = state.copyWith(
      heroRoster: [
        for (final h in state.heroRoster)
          h.copyWith(level: GameLogic.maxHeroLevel, xp: 0),
      ],
    );
    final hero = state.heroes.first;
    final atk = state.effectiveHeroAttack(hero);
    final def = state.effectiveHeroDefense(hero);
    final might = GameLogic.enterGauntlet(state, pact: GauntletPact.might);
    final ward = GameLogic.enterGauntlet(state, pact: GauntletPact.ward);
    final greed = GameLogic.enterGauntlet(state, pact: GauntletPact.greed);
    expect(might.gauntletPact, 'might');
    expect(might.effectiveHeroAttack(might.heroes.first), (atk * 1.2).round());
    expect(
      ward.effectiveHeroDefense(ward.heroes.first),
      (def * 1.25).round(),
    );
    expect(
      greed.effectiveHeroDefense(greed.heroes.first),
      (def * 0.85).round(),
    );
    final raw = state.toJson()..remove('gauntletPact');
    expect(GameLogic.stateFromJson(raw).gauntletPact, '');
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
