import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/enemy.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/spatial/tile_map.dart';

void main() {
  test('ground disc sits on the clump, not the gap toward an edge boss', () {
    final mage = _mage(x: 3.5, y: 4);
    final far = _foe('far', 4.0, 5.6);
    final mid = _foe('mid', 5.6, 5.6);
    final nearBoss = _foe('near', 7.2, 5.6);
    final boss = _foe('boss', 10.2, 5.6, role: EnemyRole.boss);
    final world = _open(heroes: [mage], enemies: [far, mid, nearBoss, boss]);

    final spot = AoeAim.bestDisc(
      world: world,
      hero: mage,
      focus: boss,
      radius: 2.8,
    );
    expect(spot, isNotNull);
    expect(spot!.hits, greaterThanOrEqualTo(3));
    expect(_dist(spot.x, spot.y, far.x, far.y), lessThanOrEqualTo(2.8));
    expect(_dist(spot.x, spot.y, boss.x, boss.y), greaterThan(2.8));
  });

  test('a pair inside the diameter still shares one disc', () {
    final mage = _mage(x: 4, y: 4);
    final a = _foe('a', 5.2, 5);
    final b = _foe('b', 8.2, 5);
    final world = _open(heroes: [mage], enemies: [a, b]);
    final spot = AoeAim.bestDisc(
      world: world,
      hero: mage,
      focus: a,
      radius: 2.7,
    );
    expect(spot, isNotNull);
    expect(spot!.hits, 2);
    expect(_dist(spot.x, spot.y, a.x, a.y), lessThanOrEqualTo(2.7));
    expect(_dist(spot.x, spot.y, b.x, b.y), lessThanOrEqualTo(2.7));
  });

  test('a melee disc stays with the hero and ignores a far pair', () {
    final warrior = _melee(x: 4, y: 5);
    final nearA = _foe('a', 4.7, 5);
    final nearB = _foe('b', 5.1, 5.3);
    final farA = _foe('c', 9, 5);
    final farB = _foe('d', 9.4, 5.2);
    final world = _open(heroes: [warrior], enemies: [nearA, nearB, farA, farB]);

    final spot = AoeAim.bestDisc(
      world: world,
      hero: warrior,
      focus: farA,
      radius: 2.7,
    );
    expect(spot, isNotNull);
    expect(spot!.hits, 2);
    expect(spot.x, lessThan(6));
  });

  test('chain starts in the line, not on an isolated focus', () {
    final mage = _mage(x: 4, y: 4);
    final a = _foe('a', 3, 5);
    final b = _foe('b', 4.2, 5);
    final c = _foe('c', 5.4, 5);
    final alone = _foe('alone', 9.5, 5);
    final world = _open(heroes: [mage], enemies: [a, b, c, alone]);

    final path = AoeAim.chainTargets(world: world, hero: mage, focus: alone);
    expect(path.length, greaterThanOrEqualTo(3));
    expect(path.first.id, isNot('alone'));
  });

  test('Blizzard hits the clump when the focus is the edge boss', () {
    final mage = _mage(x: 3.5, y: 4);
    final far = _foe('far', 4.0, 5.6, hp: 2500);
    final mid = _foe('mid', 5.6, 5.6, hp: 2500);
    final nearBoss = _foe('near', 7.2, 5.6, hp: 2500);
    final boss = _foe('boss', 10.2, 5.6, hp: 2500, role: EnemyRole.boss);
    final world = _open(heroes: [mage], enemies: [far, mid, nearBoss, boss]);
    _pad(mage, except: AbilityId.blizzard);
    final state = GameLogic.createInitialState(now: DateTime(2026, 10, 10));

    var fired = false;
    for (var i = 0; i < 20; i++) {
      AbilityEffectRunner.tick(
        world,
        mage,
        state,
        dt: 0.1,
        rng: math.Random(1),
        reducedVfx: true,
        hasShield: false,
      );
      if ((mage.abilityCd[AbilityId.blizzard.name] ?? 0) > 0.05) {
        fired = true;
        break;
      }
      mage.rage = 100;
    }
    expect(fired, isTrue);
    expect(far.hp, lessThan(2500));
  });

  test('Blizzard waits when two foes are too far apart for the disc', () {
    final mage = _mage(x: 4, y: 4);
    final a = _foe('a', 5.2, 2.2, hp: 2500);
    final b = _foe('b', 5.2, 8.0, hp: 2500);
    final world = _open(heroes: [mage], enemies: [a, b]);
    _pad(mage, except: AbilityId.blizzard);
    final state = GameLogic.createInitialState(now: DateTime(2026, 10, 10));

    for (var i = 0; i < 20; i++) {
      AbilityEffectRunner.tick(
        world,
        mage,
        state,
        dt: 0.1,
        rng: math.Random(2),
        reducedVfx: true,
        hasShield: false,
      );
      mage.rage = 100;
    }
    expect(mage.abilityCd[AbilityId.blizzard.name] ?? 0, lessThan(0.05));
    expect(a.hp, 2500);
    expect(b.hp, 2500);
  });
}

SpatialActor _mage({required double x, required double y}) {
  return SpatialActor(
    id: 'mage',
    name: 'Glace',
    team: SpatialTeam.hero,
    x: x,
    y: y,
    hp: 400,
    maxHp: 400,
    attack: 40,
    defense: 4,
    moveSpeed: 0,
    attackRange: 5,
    attackCooldown: 1,
    fireCooldown: 99,
    heroRole: HeroRole.mage,
    heroSpecId: HeroSpecId.frostMage,
    heroLevel: 15,
    ranged: true,
    preferredRange: 4,
  )..rage = 100;
}

SpatialActor _melee({required double x, required double y}) {
  return SpatialActor(
    id: 'arms',
    name: 'Arms',
    team: SpatialTeam.hero,
    x: x,
    y: y,
    hp: 400,
    maxHp: 400,
    attack: 40,
    defense: 8,
    moveSpeed: 0,
    attackRange: 1.2,
    attackCooldown: 1,
    fireCooldown: 99,
    heroRole: HeroRole.warrior,
    heroSpecId: HeroSpecId.arms,
    heroLevel: 15,
    ranged: false,
    preferredRange: 1.2,
  );
}

SpatialActor _foe(
  String id,
  double x,
  double y, {
  int hp = 100,
  EnemyRole role = EnemyRole.normal,
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
    moveSpeed: 0,
    attackRange: 1.1,
    attackCooldown: 9,
    role: role,
  );
}

TileMap _map() {
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

SpatialWorld _open({
  required List<SpatialActor> heroes,
  required List<SpatialActor> enemies,
}) {
  return SpatialWorld(
    map: _map(),
    heroes: heroes,
    enemies: enemies,
    projectiles: <SpatialProjectile>[],
    groundLoot: [],
    isTreasure: false,
  );
}

void _pad(SpatialActor actor, {required AbilityId except}) {
  for (final def in ClassKits.all) {
    if (def.id == except || def.cooldown <= 0) continue;
    actor.abilityCd[def.id.name] = 99;
  }
}

double _dist(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return math.sqrt(dx * dx + dy * dy);
}
