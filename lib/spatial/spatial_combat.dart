import 'dart:math' as math;

import '../core/game_logic.dart';
import '../core/game_state.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';

enum SpatialTeam { hero, enemy }

class SpatialActor {
  SpatialActor({
    required this.id,
    required this.name,
    required this.team,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.moveSpeed,
    required this.attackRange,
    required this.attackCooldown,
    this.assetIndex = 0,
    this.role = EnemyRole.normal,
    this.fireCooldown = 0,
  });

  final String id;
  final String name;
  final SpatialTeam team;
  double x;
  double y;
  int hp;
  final int maxHp;
  final int attack;
  final int defense;
  final double moveSpeed;
  final double attackRange;
  final double attackCooldown;
  final int assetIndex;
  final EnemyRole role;
  double fireCooldown;

  bool get isAlive => hp > 0;
}

class SpatialProjectile {
  SpatialProjectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    required this.team,
    this.life = 1.6,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final int damage;
  final SpatialTeam team;
  double life;
}

class GroundLoot {
  GroundLoot({
    required this.x,
    required this.y,
    required this.drop,
    this.age = 0,
  });

  double x;
  double y;
  final LootDrop drop;
  double age;
}

class SpatialWorld {
  SpatialWorld({
    required this.cols,
    required this.rows,
    required this.heroes,
    required this.enemies,
    required this.projectiles,
    required this.groundLoot,
    required this.isTreasure,
    this.treasureOpen = false,
    this.treasureTimer = 0,
  });

  final int cols;
  final int rows;
  final List<SpatialActor> heroes;
  final List<SpatialActor> enemies;
  final List<SpatialProjectile> projectiles;
  final List<GroundLoot> groundLoot;
  final bool isTreasure;
  bool treasureOpen;
  double treasureTimer;

  bool get allEnemiesDead =>
      enemies.isEmpty || enemies.every((e) => !e.isAlive);

  bool get allHeroesDead =>
      heroes.isEmpty || heroes.every((h) => !h.isAlive);
}

class SpatialStepResult {
  const SpatialStepResult({
    required this.world,
    required this.state,
    this.roomCleared = false,
    this.partyWiped = false,
    this.goldFromKills = 0,
  });

  final SpatialWorld world;
  final GameState state;
  final bool roomCleared;
  final bool partyWiped;
  final int goldFromKills;
}

abstract final class SpatialCombat {
  /// Wide horizontal corridor (left → right crawl).
  static const int cols = 16;
  static const int rows = 7;

  /// Walkable Y band (tile centers).
  static const double laneMinY = 2.0;
  static const double laneMaxY = 4.5;
  static const double laneCenterY = 3.25;

  static SpatialWorld build(GameState state) {
    final room = state.currentRoom;
    final isTreasure =
        room.type == RoomType.treasure || state.enemies.isEmpty;

    final heroes = <SpatialActor>[];
    for (var i = 0; i < state.heroes.length; i++) {
      final hero = state.heroes[i];
      heroes.add(
        SpatialActor(
          id: 'hero_$i',
          name: hero.name,
          team: SpatialTeam.hero,
          x: 1.4 + i * 0.55,
          y: (laneCenterY - 0.7 + i * 0.7).clamp(laneMinY, laneMaxY),
          hp: hero.currentHp,
          maxHp: state.effectiveHeroMaxHp(hero),
          attack: state.effectiveHeroAttack(hero),
          defense: state.effectiveHeroDefense(hero),
          moveSpeed: hero.role == HeroRole.warrior ? 2.6 : 3.0,
          attackRange: hero.role == HeroRole.mage
              ? 5.2
              : (hero.role == HeroRole.healer ? 4.0 : 2.4),
          attackCooldown: hero.role == HeroRole.mage ? 0.5 : 0.7,
          assetIndex: i,
          fireCooldown: i * 0.12,
        ),
      );
    }

    final enemies = <SpatialActor>[];
    final n = math.max(1, state.enemies.length);
    for (var i = 0; i < state.enemies.length; i++) {
      final enemy = state.enemies[i];
      final spread = n == 1 ? 0.0 : (i / (n - 1) - 0.5) * 1.6;
      enemies.add(
        SpatialActor(
          id: 'enemy_$i',
          name: enemy.name,
          team: SpatialTeam.enemy,
          x: cols - 2.0 - (i % 2) * 0.45,
          y: (laneCenterY + spread).clamp(laneMinY, laneMaxY),
          hp: enemy.currentHp,
          maxHp: enemy.maxHp,
          attack: enemy.attack,
          defense: enemy.defense,
          moveSpeed: enemy.role == EnemyRole.boss ? 1.5 : 2.0,
          attackRange: enemy.role == EnemyRole.boss ? 2.6 : 1.7,
          attackCooldown: enemy.role == EnemyRole.boss ? 1.0 : 0.9,
          assetIndex: i,
          role: enemy.role,
          fireCooldown: 0.35 + i * 0.15,
        ),
      );
    }

    return SpatialWorld(
      cols: cols,
      rows: rows,
      heroes: heroes,
      enemies: enemies,
      projectiles: <SpatialProjectile>[],
      groundLoot: <GroundLoot>[],
      isTreasure: isTreasure,
      treasureTimer: isTreasure ? 1.2 : 0,
    );
  }

  /// Advances spatial combat by [dt] seconds and syncs HP into [state].
  static SpatialStepResult step(
    SpatialWorld world,
    GameState state, {
    required double dt,
  }) {
    var nextState = state;
    var goldFromKills = 0;
    final rng = GameLogic.random;

    if (world.isTreasure) {
      world.treasureTimer -= dt;
      if (world.treasureTimer <= 0) {
        world.treasureOpen = true;
        return SpatialStepResult(
          world: world,
          state: nextState,
          roomCleared: true,
          goldFromKills: GameLogic.roomCombatBudget(state.currentRoom).gold,
        );
      }
      return SpatialStepResult(world: world, state: nextState);
    }

    // Move + fire heroes
    for (final hero in world.heroes) {
      if (!hero.isAlive) continue;
      final target = _nearest(hero, world.enemies);
      if (target == null) continue;
      final dist = _dist(hero, target);
      if (dist > hero.attackRange * 0.85) {
        _moveToward(hero, target.x, target.y, hero.moveSpeed * dt, world);
      }
      hero.fireCooldown -= dt;
      if (hero.fireCooldown <= 0 && dist <= hero.attackRange) {
        hero.fireCooldown = hero.attackCooldown;
        world.projectiles.add(
          _shot(from: hero, to: target, damage: hero.attack),
        );
      }
    }

    // Move + fire enemies
    for (final enemy in world.enemies) {
      if (!enemy.isAlive) continue;
      final target = _nearest(enemy, world.heroes);
      if (target == null) continue;
      final dist = _dist(enemy, target);
      if (dist > enemy.attackRange * 0.9) {
        _moveToward(enemy, target.x, target.y, enemy.moveSpeed * dt, world);
      }
      enemy.fireCooldown -= dt;
      if (enemy.fireCooldown <= 0 && dist <= enemy.attackRange) {
        enemy.fireCooldown = enemy.attackCooldown;
        final dmg = math.max(1, enemy.attack - target.defense);
        world.projectiles.add(_shot(from: enemy, to: target, damage: dmg));
      }
    }

    // Projectiles
    final remaining = <SpatialProjectile>[];
    for (final p in world.projectiles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0 ||
          p.x < 0 ||
          p.y < 0 ||
          p.x > world.cols ||
          p.y > world.rows) {
        continue;
      }

      final victims = p.team == SpatialTeam.hero ? world.enemies : world.heroes;
      var hit = false;
      for (final v in victims) {
        if (!v.isAlive) continue;
        if (_distPoint(p.x, p.y, v.x, v.y) < 0.55) {
          v.hp = math.max(0, v.hp - p.damage);
          hit = true;
          if (!v.isAlive && v.team == SpatialTeam.enemy) {
            // Gold from this kill; real gear rolls once on room clear.
            final enemyIndex = world.enemies.indexOf(v);
            if (enemyIndex >= 0 && enemyIndex < state.enemies.length) {
              goldFromKills += state.enemies[enemyIndex].rewardGold;
            }
            world.groundLoot.add(
              GroundLoot(
                x: v.x + (rng.nextDouble() - 0.5) * 0.4,
                y: v.y + (rng.nextDouble() - 0.5) * 0.4,
                drop: LootDrop(
                  name: 'Coin',
                  amount: 1,
                  rarity: LootRarity.common,
                ),
              ),
            );
          }
          break;
        }
      }
      if (!hit) remaining.add(p);
    }
    world.projectiles
      ..clear()
      ..addAll(remaining);

    // Auto-pickup cosmetic drops near any living hero (visual only).
    final stillOnGround = <GroundLoot>[];
    for (final loot in world.groundLoot) {
      loot.age += dt;
      final nearHero = world.heroes.any(
        (h) => h.isAlive && _distPoint(loot.x, loot.y, h.x, h.y) < 1.1,
      );
      if (!(nearHero || loot.age > 3.5)) {
        stillOnGround.add(loot);
      }
    }
    world.groundLoot
      ..clear()
      ..addAll(stillOnGround);

    // Sync HP back to GameState
    nextState = _syncHp(nextState, world);

    if (world.allHeroesDead) {
      return SpatialStepResult(
        world: world,
        state: nextState,
        partyWiped: true,
        goldFromKills: goldFromKills,
      );
    }

    if (world.allEnemiesDead && world.groundLoot.isEmpty) {
      // Flush any pending — already empty
      final gold = goldFromKills > 0
          ? goldFromKills
          : state.enemies.fold<int>(0, (s, e) => s + e.rewardGold);
      return SpatialStepResult(
        world: world,
        state: nextState,
        roomCleared: true,
        goldFromKills: gold,
      );
    }

    return SpatialStepResult(
      world: world,
      state: nextState,
      goldFromKills: goldFromKills,
    );
  }

  /// God Hand: deal AOE damage around [tileX],[tileY].
  static SpatialStepResult godHand(
    SpatialWorld world,
    GameState state, {
    required double tileX,
    required double tileY,
    int baseDamage = 8,
  }) {
    final damage = baseDamage + state.ascensionLevel + (state.totalAttack ~/ 8);
    var gold = 0;
    for (final enemy in world.enemies) {
      if (!enemy.isAlive) continue;
      if (_distPoint(tileX, tileY, enemy.x, enemy.y) <= 1.8) {
        enemy.hp = math.max(0, enemy.hp - damage);
        if (!enemy.isAlive) {
          final idx = world.enemies.indexOf(enemy);
          if (idx >= 0 && idx < state.enemies.length) {
            gold += state.enemies[idx].rewardGold;
          }
          world.groundLoot.add(
            GroundLoot(x: enemy.x, y: enemy.y, drop: const LootDrop(
              name: 'Coin',
              amount: 1,
              rarity: LootRarity.common,
            )),
          );
        }
      }
    }
    final synced = _syncHp(state, world);
    return SpatialStepResult(
      world: world,
      state: synced,
      goldFromKills: gold,
    );
  }

  static GameState _syncHp(GameState state, SpatialWorld world) {
    final heroes = <PartyHero>[];
    for (var i = 0; i < state.heroes.length; i++) {
      final h = state.heroes[i];
      final spatial = i < world.heroes.length ? world.heroes[i] : null;
      heroes.add(
        h.copyWith(currentHp: spatial?.hp.clamp(0, spatial.maxHp) ?? 0),
      );
    }
    final enemies = <EnemyUnit>[];
    for (var i = 0; i < state.enemies.length; i++) {
      final e = state.enemies[i];
      final spatial = i < world.enemies.length ? world.enemies[i] : null;
      enemies.add(
        e.copyWith(currentHp: spatial?.hp.clamp(0, e.maxHp) ?? 0),
      );
    }
    return state.copyWith(heroes: heroes, enemies: enemies);
  }

  static SpatialActor? _nearest(SpatialActor self, List<SpatialActor> others) {
    SpatialActor? best;
    var bestD = double.infinity;
    for (final o in others) {
      if (!o.isAlive) continue;
      final d = _dist(self, o);
      if (d < bestD) {
        bestD = d;
        best = o;
      }
    }
    return best;
  }

  static double _dist(SpatialActor a, SpatialActor b) =>
      _distPoint(a.x, a.y, b.x, b.y);

  static double _distPoint(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }

  static void _moveToward(
    SpatialActor a,
    double tx,
    double ty,
    double step,
    SpatialWorld world,
  ) {
    final dx = tx - a.x;
    final dy = ty - a.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    a.x = (a.x + dx / len * step).clamp(0.9, world.cols - 0.9);
    // Stay in the corridor lane so the path reads as a straight crawl.
    a.y = (a.y + dy / len * step).clamp(laneMinY, laneMaxY);
  }

  static SpatialProjectile _shot({
    required SpatialActor from,
    required SpatialActor to,
    required int damage,
  }) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, 999);
    const speed = 7.5;
    return SpatialProjectile(
      x: from.x,
      y: from.y,
      vx: dx / len * speed,
      vy: dy / len * speed,
      damage: damage,
      team: from.team,
    );
  }
}
