import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

TileMap _openMap({(int, int) exit = const (9, 5)}) {
  const cols = 12;
  const rows = 10;
  final tiles = List<TileKind>.filled(cols * rows, TileKind.floor);
  for (var x = 0; x < cols; x++) {
    tiles[x] = TileKind.wall;
    tiles[(rows - 1) * cols + x] = TileKind.wall;
  }
  for (var y = 0; y < rows; y++) {
    tiles[y * cols] = TileKind.wall;
    tiles[y * cols + cols - 1] = TileKind.wall;
  }
  return TileMap(
    cols: cols,
    rows: rows,
    tiles: tiles,
    spawnPoints: const [(2, 5)],
    exitPoint: exit,
    enemySpawns: const [(8, 5)],
  );
}

SpatialActor _hero({
  required String id,
  required HeroSpecId spec,
  required double x,
  required double y,
  double moveSpeed = 3.2,
}) {
  final def = HeroSpecs.def(spec);
  return SpatialActor(
    id: id,
    name: id,
    team: SpatialTeam.hero,
    x: x,
    y: y,
    hp: 99999,
    maxHp: 99999,
    attack: 1,
    defense: 500,
    moveSpeed: moveSpeed,
    attackRange: def.attackRange,
    attackCooldown: 2.0,
    heroSpecId: spec,
    ranged: def.ranged,
    preferredRange: def.preferredRange,
  );
}

SpatialActor _foe({
  required String id,
  required EnemyArchetype archetype,
  required double x,
  required double y,
  bool ranged = false,
  double attackRange = 1.45,
  double preferred = 1.1,
  double moveSpeed = 2.8,
}) {
  return SpatialActor(
    id: id,
    name: id,
    team: SpatialTeam.enemy,
    x: x,
    y: y,
    hp: 999999,
    maxHp: 999999,
    attack: 1,
    defense: 0,
    moveSpeed: moveSpeed,
    attackRange: attackRange,
    attackCooldown: 2.0,
    archetype: archetype,
    ranged: ranged,
    preferredRange: preferred,
  );
}

SpatialWorld _world({
  required List<SpatialActor> heroes,
  required List<SpatialActor> enemies,
  (int, int) exit = const (9, 5),
}) {
  return SpatialWorld(
    map: _openMap(exit: exit),
    heroes: heroes,
    enemies: enemies,
    projectiles: <SpatialProjectile>[],
    groundLoot: [],
    isTreasure: false,
    pets: <SpatialActor>[],
  );
}

void _run(SpatialWorld world, double seconds) {
  var state = GameLogic.createInitialState(now: DateTime(2026, 9, 28));
  final steps = (seconds / 0.05).round();
  for (var i = 0; i < steps; i++) {
    final step = SpatialCombat.step(world, state, dt: 0.05);
    state = step.state;
  }
}

double _dist(SpatialActor a, SpatialActor b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

void main() {
  test('front slot sits between the party and the enemy', () {
    const front = (-1.0, 0.0);
    final slot0 = CombatPresence.ringPoint(
      cx: 8,
      cy: 5,
      front: front,
      index: 0,
      radius: 1,
    );
    final slot1 = CombatPresence.ringPoint(
      cx: 8,
      cy: 5,
      front: front,
      index: 1,
      radius: 1,
    );
    expect(slot0.$1, lessThan(8));
    expect(slot0.$1, greaterThan(4));
    expect((slot0.$2 - 5).abs(), lessThan(0.05));
    expect((slot1.$2 - slot0.$2).abs(), greaterThan(0.4));
  });

  test('marching formation faces the stairs, not map-left', () {
    final tank = _hero(id: 'tank', spec: HeroSpecId.protection, x: 5.5, y: 6);
    final healer = _hero(
      id: 'heal',
      spec: HeroSpecId.discipline,
      x: 5.5,
      y: 6.2,
    );
    final world = _world(
      heroes: [tank, healer],
      enemies: const [],
      exit: (5, 2),
    );
    final spot = CombatPresence.idleSlot(
      hero: healer,
      anchor: tank,
      world: world,
      index: 0,
    );
    expect(spot.y, greaterThan(tank.y + 0.6));
    expect((spot.x - tank.x).abs(), lessThan(0.4));
  });

  test('a blocked flank slot stays in the corridor', () {
    const cols = 8;
    const rows = 14;
    final tiles = List<TileKind>.filled(cols * rows, TileKind.wall);
    for (var y = 1; y < rows - 1; y++) {
      tiles[y * cols + 3] = TileKind.floor;
    }
    final world = SpatialWorld(
      map: TileMap(
        cols: cols,
        rows: rows,
        tiles: tiles,
        spawnPoints: const [(3, 2)],
        exitPoint: (3, 12),
        enemySpawns: const [(3, 8)],
      ),
      heroes: [],
      enemies: [],
      projectiles: <SpatialProjectile>[],
      groundLoot: [],
      isTreasure: false,
      pets: <SpatialActor>[],
    );
    final spot = CombatPresence.walkableRing(
      world: world,
      cx: 3.5,
      cy: 8.5,
      front: (0, -1),
      index: 1,
      radius: 1.15,
    );
    expect(world.canWalk(spot.$1, spot.$2), isTrue);
    expect((spot.$1 - 3.5).abs(), lessThan(0.55));
    expect((spot.$2 - 8.5).abs(), greaterThan(0.3));
  });

  test('retreat picks a floor tile when the straight line is a wall', () {
    final world = _world(heroes: [], enemies: []);
    final spot = CombatPresence.walkableGoal(world, 1.2, 5, -1, 0, 1.6);
    expect(world.canWalk(spot.$1, spot.$2), isTrue);
    expect(spot.$1, greaterThan(0.9));
    final backed = CombatPresence.walkableGoal(
      world,
      1.2,
      5,
      -1,
      0,
      1.6,
      avoidX: 4,
      avoidY: 5,
    );
    final before = math.sqrt(math.pow(1.2 - 4, 2) + math.pow(5 - 5, 2));
    final after = math.sqrt(math.pow(backed.$1 - 4, 2) + math.pow(backed.$2 - 5, 2));
    expect(after + 0.05, greaterThanOrEqualTo(before));
  });

  test('party spreads: tank in front, melee off the line, backline behind', () {
    final tank = _hero(id: 'tank', spec: HeroSpecId.protection, x: 3.4, y: 5);
    final arms = _hero(id: 'arms', spec: HeroSpecId.arms, x: 3.1, y: 4.2);
    final holy = _hero(id: 'holy', spec: HeroSpecId.discipline, x: 2.6, y: 5.4);
    final fire = _hero(id: 'fire', spec: HeroSpecId.fire, x: 2.5, y: 4.5);
    final brute = _foe(
      id: 'brute',
      archetype: EnemyArchetype.brute,
      x: 8,
      y: 5,
      moveSpeed: 0,
    );
    final world = _world(heroes: [tank, arms, holy, fire], enemies: [brute]);
    _run(world, 4.5);

    final tankDist = _dist(tank, brute);
    expect(tankDist, lessThan(1.8));
    expect(_dist(arms, brute), lessThan(2.1));
    expect(_dist(arms, tank), greaterThan(0.5));
    expect(_dist(holy, brute), greaterThan(tankDist + 0.35));
    expect(_dist(fire, brute), greaterThan(tankDist + 1.2));
    expect((arms.y - brute.y).abs(), greaterThan(0.35));
  });

  test('enemies approach differently: plant, flank, and keep range', () {
    final hero = _hero(
      id: 'tank',
      spec: HeroSpecId.protection,
      x: 5,
      y: 5,
      moveSpeed: 0,
    );
    final blocker = _foe(
      id: 'blocker',
      archetype: EnemyArchetype.tank,
      x: 8.2,
      y: 5,
      moveSpeed: 2.4,
    );
    final brute = _foe(
      id: 'brute',
      archetype: EnemyArchetype.brute,
      x: 8,
      y: 6.3,
      moveSpeed: 2.8,
    );
    final glass = _foe(
      id: 'glass',
      archetype: EnemyArchetype.glass,
      x: 7.6,
      y: 3.2,
      moveSpeed: 3.3,
    );
    final shooter = _foe(
      id: 'shooter',
      archetype: EnemyArchetype.ranged,
      x: 9,
      y: 5.4,
      ranged: true,
      attackRange: 3.9,
      preferred: 3.2,
      moveSpeed: 2.5,
    );
    final support = _foe(
      id: 'support',
      archetype: EnemyArchetype.support,
      x: 9.2,
      y: 4.1,
      ranged: true,
      attackRange: 4.2,
      preferred: 3.4,
      moveSpeed: 2.4,
    );
    final world = _world(
      heroes: [hero],
      enemies: [blocker, brute, glass, shooter, support],
    );
    _run(world, 5);

    expect(_dist(blocker, hero), lessThan(1.7));
    expect(_dist(brute, hero), lessThan(1.8));
    expect(_dist(shooter, hero), greaterThan(2.3));
    expect(_dist(support, hero), greaterThan(_dist(blocker, hero) + 0.35));

    final tankAngle = math.atan2(blocker.y - hero.y, blocker.x - hero.x);
    final glassAngle = math.atan2(glass.y - hero.y, glass.x - hero.x);
    var delta = (glassAngle - tankAngle).abs();
    if (delta > math.pi) delta = math.pi * 2 - delta;
    expect(delta, greaterThan(0.4));
  });
}
