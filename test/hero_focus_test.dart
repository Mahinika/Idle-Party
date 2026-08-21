import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

SpatialActor _hero({
  required String id,
  required HeroSpecId spec,
  required double x,
  required double y,
}) {
  final def = HeroSpecs.def(spec);
  return SpatialActor(
    id: id,
    name: id,
    team: SpatialTeam.hero,
    x: x,
    y: y,
    hp: 200,
    maxHp: 200,
    attack: 20,
    defense: 10,
    moveSpeed: 2.2,
    attackRange: def.preferredRange.clamp(1.0, 6.0),
    attackCooldown: 1.0,
    heroRole: def.gearAffinity,
    heroSpecId: spec,
    ranged: def.roleTag == SpecRoleTag.rangedDps ||
        def.roleTag == SpecRoleTag.caster ||
        def.roleTag == SpecRoleTag.healer,
    preferredRange: def.preferredRange,
  );
}

SpatialActor _enemy({
  required String id,
  required double x,
  required double y,
  int hp = 100,
}) {
  return SpatialActor(
    id: id,
    name: id,
    team: SpatialTeam.enemy,
    x: x,
    y: y,
    hp: hp,
    maxHp: hp,
    attack: 8,
    defense: 2,
    moveSpeed: 1.4,
    attackRange: 1.1,
    attackCooldown: 1.2,
  );
}

TileMap _openMap() {
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
    spawnPoints: const [(2, 2)],
    exitPoint: (cols - 3, rows - 3),
    enemySpawns: const [(8, 5)],
  );
}

SpatialWorld _world({
  required List<SpatialActor> heroes,
  required List<SpatialActor> enemies,
  List<SpatialActor> pets = const [],
}) {
  return SpatialWorld(
    map: _openMap(),
    heroes: heroes,
    enemies: enemies,
    projectiles: <SpatialProjectile>[],
    groundLoot: [],
    isTreasure: false,
    pets: List<SpatialActor>.from(pets),
  );
}

void main() {
  test('DPS peels the extra mob pressing the tank, not the nearest', () {
    final tank = _hero(
      id: 'tank',
      spec: HeroSpecId.protection,
      x: 4,
      y: 5,
    );
    final dps = _hero(
      id: 'dps',
      spec: HeroSpecId.fire,
      x: 3,
      y: 5,
    );
    // A sits on the tank (nearest) but is not an "extra".
    final nearest = _enemy(id: 'nearest', x: 4.4, y: 5);
    // B is farther but forced onto the tank → peel target.
    final peeler = _enemy(id: 'peeler', x: 7.5, y: 5);
    peeler.forcedTargetId = tank.id;
    peeler.forcedTargetTimer = 3.0;

    final world = _world(
      heroes: [tank, dps],
      enemies: [nearest, peeler],
    );

    final focus = SpatialCombat.pickSmartFocusForTest(dps, world);
    expect(focus?.id, 'peeler');
    expect(dps.focusEnemyId, 'peeler');
  });

  test('sticky focus holds across small score noise', () {
    final tank = _hero(
      id: 'tank',
      spec: HeroSpecId.protection,
      x: 4,
      y: 5,
    );
    final dps = _hero(
      id: 'dps',
      spec: HeroSpecId.arms,
      x: 3.5,
      y: 5,
    );
    final a = _enemy(id: 'a', x: 5.2, y: 5);
    final b = _enemy(id: 'b', x: 5.4, y: 5.1);
    a.forcedTargetId = tank.id;
    a.forcedTargetTimer = 2.0;
    b.forcedTargetId = tank.id;
    b.forcedTargetTimer = 2.0;

    final world = _world(heroes: [tank, dps], enemies: [a, b]);

    final first = SpatialCombat.pickSmartFocusForTest(dps, world);
    expect(first, isNotNull);
    final locked = first!.id;
    expect(dps.focusLockTimer, greaterThan(0));

    // Nudge positions slightly — sticky should keep the same id.
    a.x += 0.05;
    b.x -= 0.05;
    final second = SpatialCombat.pickSmartFocusForTest(dps, world);
    expect(second?.id, locked);
  });

  test('God Hand steers movement but peel sticky focus survives', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 21));
    var world = SpatialCombat.build(state);
    expect(world.heroes.length, greaterThanOrEqualTo(2));
    expect(world.enemies.length, greaterThanOrEqualTo(2));

    SpatialActor tank = world.heroes.firstWhere(
      (h) => h.heroSpecId != null && HeroSpecs.def(h.heroSpecId!).isTank,
      orElse: () => world.heroes.first,
    );
    final dps = world.heroes.firstWhere((h) => h.id != tank.id);

    // Ensure two active pack members near the tank.
    for (final e in world.enemies) {
      e.dormant = false;
      e.hp = e.maxHp;
    }
    final nearest = world.enemies.first;
    nearest.x = tank.x + 0.6;
    nearest.y = tank.y;
    final peeler = world.enemies[1];
    peeler.x = tank.x + 3.2;
    peeler.y = tank.y;
    peeler.forcedTargetId = tank.id;
    peeler.forcedTargetTimer = 4.0;

    final before = SpatialCombat.pickSmartFocusForTest(dps, world);
    expect(before?.id, peeler.id);

    SpatialCombat.godHand(
      world,
      state,
      tileX: tank.x - 2,
      tileY: tank.y,
      baseDamage: 1,
    );
    expect(world.guideTimer, greaterThan(0));

    final step = SpatialCombat.step(world, state, dt: 0.05);
    world = step.world;
    final dpsAfter = world.heroes.firstWhere((h) => h.id == dps.id);
    expect(dpsAfter.focusEnemyId, peeler.id);
  });

  test('AFK assist still clears a wiped pack without soft-lock', () {
    var state = GameLogic.createInitialState(now: DateTime(2026, 8, 21));
    var world = SpatialCombat.build(state, afkAssist: true);
    for (final e in world.enemies) {
      e.hp = 0;
    }
    final step = SpatialCombat.step(world, state, dt: 0.05);
    expect(step.roomCleared || step.world.awaitingExit, isTrue);
  });

  test('pet prefers owner sticky focus over nearest', () {
    final hunter = _hero(
      id: 'hunter',
      spec: HeroSpecId.beastMastery,
      x: 4,
      y: 5,
    );
    final tank = _hero(
      id: 'tank',
      spec: HeroSpecId.protection,
      x: 5,
      y: 5,
    );
    final nearest = _enemy(id: 'near', x: 4.5, y: 5);
    final peel = _enemy(id: 'peel', x: 8, y: 5);
    peel.forcedTargetId = tank.id;
    peel.forcedTargetTimer = 3.0;

    final pet = SpatialActor(
      id: 'classpet_hunter',
      name: 'Pet',
      team: SpatialTeam.hero,
      x: 4.2,
      y: 5.2,
      hp: 80,
      maxHp: 80,
      attack: 12,
      defense: 1,
      moveSpeed: 2.4,
      attackRange: 1.1,
      attackCooldown: 1.0,
      isPet: true,
      petOwnerId: hunter.id,
    );

    final world = _world(
      heroes: [tank, hunter],
      enemies: [nearest, peel],
      pets: [pet],
    );

    SpatialCombat.pickSmartFocusForTest(hunter, world);
    expect(hunter.focusEnemyId, 'peel');

    // One combat step: pet should close on peel, not nearest.
    final before = (pet.x - peel.x).abs() + (pet.y - peel.y).abs();
    SpatialCombat.step(
      world,
      GameLogic.createInitialState(now: DateTime(2026, 8, 21)),
      dt: 0.2,
    );
    final after = (pet.x - peel.x).abs() + (pet.y - peel.y).abs();
    expect(after, lessThan(before));
  });
}
