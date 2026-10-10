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
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  test('Gauntlet opening night is four squeezes then a boss', () {
    expect(GauntletAnomalies.forFloor(1, inGauntlet: false), isNull);
    expect(
      GauntletAnomalies.forFloor(1, inGauntlet: true),
      GauntletAnomaly.tightCorridors,
    );
    expect(
      GauntletAnomalies.forFloor(2, inGauntlet: true),
      GauntletAnomaly.swarmUprising,
    );
    expect(
      GauntletAnomalies.forFloor(3, inGauntlet: true),
      GauntletAnomaly.bossEcho,
    );
    expect(
      GauntletAnomalies.forFloor(4, inGauntlet: true),
      GauntletAnomaly.gateGauntlet,
    );
    expect(GauntletAnomalies.forFloor(5, inGauntlet: true), isNull);
    expect(GauntletAnomalies.forFloor(6, inGauntlet: true), isNull);
    expect(GauntletAnomalies.forFloor(7, inGauntlet: true), isNull);
    expect(GauntletAnomalies.climbPlaceLine(1), 'CLIMB · TIGHT');
    expect(GauntletAnomalies.climbPlaceLine(2), 'CLIMB · SWARM');
    expect(GauntletAnomalies.climbPlaceLine(3), 'CLIMB · ECHO');
    expect(GauntletAnomalies.climbPlaceLine(4), 'CLIMB · GATES');
    expect(GauntletAnomalies.climbPlaceLine(5), 'CLIMB · boss F5');
    expect(
      GauntletAnomalies.climbPlaceLine(5, liveBossName: 'Spire Warden'),
      'CLIMB · Spire Warden',
    );
    expect(GauntletAnomalies.nextBossFloor(1), 5);
    expect(GauntletAnomalies.nextAnomalyFloor(1), 2);
    expect(GauntletAnomalies.nextAnomalyFloor(4), 8);
  });

  test('Gauntlet anomalies skip boss floors and cycle after the opening night', () {
    expect(GauntletAnomalies.forFloor(10, inGauntlet: true), isNull);
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
    expect(GauntletAnomalies.nextAnomalyFloor(3), 4);
    expect(GauntletAnomalies.isTreasureFloor(18), isTrue);
  });

  test('opening night tight floor is narrower than a later plain floor', () {
    final tight = _gauntletWorld(1);
    final plain = _gauntletWorld(7);
    expect(tight.gauntletAnomaly, GauntletAnomaly.tightCorridors);
    expect(plain.gauntletAnomaly, isNull);
    final tightRooms = _fightChambers(tight);
    final plainRooms = _fightChambers(plain);
    expect(tightRooms, isNotEmpty);
    expect(plainRooms, isNotEmpty);
    final tightWide = tightRooms.map((c) => c.w).reduce((a, b) => a > b ? a : b);
    final plainWide = plainRooms.map((c) => c.w).reduce((a, b) => a > b ? a : b);
    expect(tightWide, lessThanOrEqualTo(9));
    expect(tightWide, lessThan(plainWide));
  });

  test('opening night swarm packs denser than the same floor without it', () {
    final room = DungeonGenerator.generateFloorRoom(
      floorNumber: 2,
      ascensionLevel: 0,
      dungeonId: 'crystal',
      layoutSeed: 42,
      bossEvery: GameLogic.gauntletBossEvery,
    );
    final state = GameLogic.createInitialState(now: DateTime(2026, 9, 19));
    final swarm = GameLogic.createEnemyGroup(
      room,
      dungeonId: 'crystal',
      fromState: state.copyWith(inGauntlet: true, dungeonId: 'crystal'),
    );
    final plain = GameLogic.createEnemyGroup(
      room,
      dungeonId: 'crystal',
      fromState: state.copyWith(inGauntlet: false, dungeonId: 'crystal'),
    );
    expect(swarm.length, greaterThan(plain.length));
    expect(_gauntletWorld(2).gauntletAnomaly, GauntletAnomaly.swarmUprising);
  });

  test('opening night echo marks one trash tell on floor 3', () {
    final echo = _gauntletWorld(3);
    expect(echo.gauntletAnomaly, GauntletAnomaly.bossEcho);
    expect(echo.enemies.where((e) => e.bossEcho), hasLength(1));
    expect(echo.enemies.any((e) => e.role == EnemyRole.boss), isFalse);
  });

  test('opening night gate floor has gates before the first boss', () {
    final gates = _gauntletWorld(4);
    final boss = _gauntletWorld(5);
    expect(gates.gauntletAnomaly, GauntletAnomaly.gateGauntlet);
    expect(gates.map.gates, isNotEmpty);
    expect(boss.gauntletAnomaly, isNull);
    expect(boss.enemies.any((e) => e.role == EnemyRole.boss), isTrue);
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

List<Chamber> _fightChambers(SpatialWorld world) {
  return world.map.chambers
      .where(
        (c) =>
            c.beatKind != null &&
            !c.beatKind!.isQuiet &&
            c.beatKind != FloorBeatKind.exitHold,
      )
      .toList();
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
