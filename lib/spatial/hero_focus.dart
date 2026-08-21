part of 'spatial_combat.dart';

/// Hero target pick: peel extras off the tank, sticky focus, nearest fallback.
///
/// Kept as a `part` so [SpatialCombat.step] stays the only combat authority.
abstract final class HeroFocus {
  /// Stick to the current focus unless a challenger beats it by this margin.
  static const double retargetMargin = 28;

  /// Soft lock duration after acquiring a new focus (seconds).
  static const double lockSeconds = 0.8;

  /// Bonus while [SpatialActor.focusLockTimer] is active.
  static const double lockBonus = 22;

  /// Non-tank peel: prefer mobs pressing the tank that are not the tank's
  /// nearest (main) target. Soft `_focusHero` leash alone is too broad.
  static const double peelPressingTank = 55;

  /// Light assist on the tank's nearest active enemy (was +40/+12).
  static const double assistTankNearest = 18;

  static SpatialActor? nearestActiveEnemy(
    SpatialActor self,
    List<SpatialActor> enemies,
  ) {
    SpatialActor? best;
    var bestD = double.infinity;
    for (final enemy in enemies) {
      if (enemy.hp <= 0 || enemy.dormant) continue;
      final distance = SpatialCombat._dist(self, enemy);
      if (distance < bestD) {
        bestD = distance;
        best = enemy;
      }
    }
    if (best != null) return best;
    // Next chamber still dormant: path toward them so floors don't soft-lock.
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      final distance = SpatialCombat._dist(self, enemy);
      if (distance < bestD) {
        bestD = distance;
        best = enemy;
      }
    }
    return best;
  }

  /// Resolve [self.focusEnemyId] if that enemy is still a valid fight target.
  static SpatialActor? stickyEnemy(SpatialActor self, SpatialWorld world) {
    final id = self.focusEnemyId;
    if (id == null) return null;
    for (final e in world.enemies) {
      if (e.id != id || e.hp <= 0) continue;
      final anyActive = world.enemies.any((o) => o.hp > 0 && !o.dormant);
      if (anyActive && e.dormant) continue;
      return e;
    }
    return null;
  }

  /// Role-aware focus with peel + sticky hysteresis.
  static SpatialActor? pickSmartFocus(SpatialActor self, SpatialWorld world) {
    SpatialActor? tank;
    SpatialActor? tankNearest;
    for (final h in world.heroes) {
      if (!h.isAlive || !_actorIsTank(h)) continue;
      tank = h;
      tankNearest = nearestActiveEnemy(h, world.enemies);
      break;
    }

    var anyActive = false;
    for (final e in world.enemies) {
      if (e.hp > 0 && !e.dormant) {
        anyActive = true;
        break;
      }
    }

    SpatialActor? best;
    var bestScore = -1e12;
    final scores = <String, double>{};

    for (final e in world.enemies) {
      if (e.hp <= 0) continue;
      if (anyActive && e.dormant) continue;

      final score = _scoreEnemy(
        self,
        e,
        world: world,
        tank: tank,
        tankNearest: tankNearest,
      );
      scores[e.id] = score;
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }

    best ??= nearestActiveEnemy(self, world.enemies);
    if (best == null) {
      self.focusEnemyId = null;
      return null;
    }

    final sticky = stickyEnemy(self, world);
    if (sticky != null) {
      final stickyScore = scores[sticky.id] ??
          _scoreEnemy(
            self,
            sticky,
            world: world,
            tank: tank,
            tankNearest: tankNearest,
          );
      // Keep sticky unless challenger clearly wins.
      if (best.id == sticky.id || bestScore < stickyScore + retargetMargin) {
        best = sticky;
      }
    }

    if (self.focusEnemyId != best.id) {
      self.focusEnemyId = best.id;
      self.focusLockTimer = lockSeconds;
    }
    return best;
  }

  static double _scoreEnemy(
    SpatialActor self,
    SpatialActor e, {
    required SpatialWorld world,
    required SpatialActor? tank,
    required SpatialActor? tankNearest,
  }) {
    final d = SpatialCombat._dist(self, e);
    final maxHp = math.max(1, e.maxHp);
    final hpFrac = e.hp / maxHp;
    final inRange = d <= self.attackRange + 1.4;

    var score = 0.0;
    if (inRange) {
      score += 45;
    } else {
      score -= d * 3.5;
    }

    score += switch (e.role) {
      EnemyRole.boss => 130,
      EnemyRole.elite => 55,
      EnemyRole.normal => 0,
    };
    // Finish wounded targets.
    score += (1.0 - hpFrac) * 60;

    // Threat on backline (healers / casters).
    if (e.forcedTargetTimer > 0 && e.forcedTargetId != null) {
      for (final h in world.heroes) {
        if (!h.isAlive || h.id != e.forcedTargetId) continue;
        if (_actorIsHealer(h)) {
          score += 50;
        } else if (h.ranged ||
            (h.heroSpecId != null &&
                HeroSpecs.def(h.heroSpecId!).roleTag == SpecRoleTag.caster)) {
          score += 28;
        }
        break;
      }
    }

    if (_actorIsTank(self)) {
      // Peel: prefer enemies hitting allies over ones already on us.
      if (e.forcedTargetId != null && e.forcedTargetId != self.id) {
        score += 42;
      }
      if (tankNearest != null && e.id == tankNearest.id) {
        score += assistTankNearest;
      }
    } else if (tank != null && self.id != tank.id) {
      final forcedOnTank =
          e.forcedTargetTimer > 0 && e.forcedTargetId == tank.id;
      final softOnTank =
          SpatialCombat._focusHero(e, world.heroes)?.id == tank.id;
      // Peel extras pressing the tank — not the tank's nearest main target.
      final isMain = tankNearest != null && e.id == tankNearest.id;
      if ((forcedOnTank || softOnTank) && !isMain) {
        score += peelPressingTank;
      }
      if (isMain) {
        score += assistTankNearest;
      }
    }

    if (self.focusEnemyId == e.id && self.focusLockTimer > 0) {
      score += lockBonus;
    }

    return score;
  }
}
