part of 'spatial_combat.dart';

/// Combat "presence": micro-motion, soft personality, and speech barks.
///
/// Kept as a `part` so [SpatialCombat] stays the only fight authority — this
/// file only flavors steering / floaters, not damage math.
abstract final class CombatPresence {
  static const double idleJitterScale = 0.07;
  static const double idleJitterSpeed = 2.6;
  static const double facingLerp = 9.0;
  static const double accelHero = 16.0;
  static const double accelRogue = 26.0;
  static const double accelEnemy = 14.0;
  static const double barkCooldown = 8.0;
  static const double lowHpFrac = 0.30;

  /// Colorblind-safe speech palette (Okabe–Ito when [SpatialCombat.colorblindMode]).
  static int get barkTriumph =>
      SpatialCombat.colorblindMode ? 0xFFF0E442 : 0xFFFFE08A;
  static int get barkPanic =>
      SpatialCombat.colorblindMode ? 0xFF56B4E9 : 0xFFB8A0FF;
  static int get barkCare =>
      SpatialCombat.colorblindMode ? 0xFFCC79A7 : 0xFF9AD0FF;
  static int get barkTaunt =>
      SpatialCombat.colorblindMode ? 0xFFE69F00 : 0xFFFFAA55;

  /// Deterministic personality from actor id + kit (heroes only meaningfully).
  static void seed(SpatialActor a) {
    var h = 2166136261;
    for (final c in a.id.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0x7fffffff;
    }
    a.impatience = 0.22 + (h % 100) / 100.0 * 0.58; // ~0.22–0.80
    final sideBit = (h >> 4) & 1;
    a.kiteSide = sideBit == 0 ? 1.0 : -1.0;
    a.kiteMul = switch (a.heroSpecId) {
      HeroSpecId.fire => 1.16,
      HeroSpecId.frostMage => 1.08,
      HeroSpecId.arcane => 0.94,
      HeroSpecId.shadow || HeroSpecId.affliction => 1.12,
      HeroSpecId.marksmanship || HeroSpecId.beastMastery => 1.06,
      _ => 1.0 + (a.impatience - 0.5) * 0.1,
    };
    // Mild random kiteSide for non-arcane; Arcane keeps a strong sidestep.
    if (a.heroSpecId != HeroSpecId.arcane) {
      a.kiteSide *= 0.35 + a.impatience * 0.25;
    }
    if (a.faceAimX == 0 && a.faceAimY == 0) {
      a.faceAimX = a.x + 0.4;
      a.faceAimY = a.y;
    }
  }

  static double _accelFor(SpatialActor a) {
    if (a.team == SpatialTeam.enemy) return accelEnemy;
    if (a.heroRole == HeroRole.rogue ||
        a.heroSpecId == HeroSpecId.combat ||
        a.heroSpecId == HeroSpecId.assassination ||
        a.heroSpecId == HeroSpecId.subtlety) {
      return accelRogue;
    }
    return accelHero;
  }

  /// Soft idle breathe + separation while holding a spot.
  static void applyIdlePresence(
    SpatialActor a,
    SpatialWorld world,
    double dt, {
    List<SpatialActor>? separateFrom,
    double separationRadius = 0.95,
    double separationWeight = 1.4,
    double stepBudget = 0.08,
  }) {
    final phase =
        world.combatElapsed * idleJitterSpeed + a.assetIndex * 1.73;
    final jx = math.cos(phase) * idleJitterScale;
    final jy = math.sin(phase * 1.17 + a.impatience) * idleJitterScale;
    // Decay leftover run velocity so holds don't skid forever.
    final decay = math.exp(-8.0 * dt);
    a.vx *= decay;
    a.vy *= decay;
    final nx = a.x + jx * dt + a.vx * dt;
    final ny = a.y + jy * dt + a.vy * dt;
    if (world.canWalk(nx, a.y)) a.x = nx;
    if (world.canWalk(a.x, ny)) a.y = ny;
    SpatialCombat._applySeparation(
      a,
      world,
      separateFrom,
      stepBudget,
      radius: separationRadius,
      weight: separationWeight,
    );
  }

  /// Approach [desiredVx]/[desiredVy] with accel, then walk with slide.
  static void applyVelocityMove(
    SpatialActor a,
    SpatialWorld world, {
    required double desiredVx,
    required double desiredVy,
    required double dt,
    required double maxSpeed,
  }) {
    final accel = _accelFor(a);
    final blend = 1.0 - math.exp(-accel * dt);
    a.vx += (desiredVx - a.vx) * blend;
    a.vy += (desiredVy - a.vy) * blend;
    // Soft clamp so AFK / high haste can't orbit the map.
    final spd = math.sqrt(a.vx * a.vx + a.vy * a.vy);
    if (spd > maxSpeed * 1.15 && spd > 0.001) {
      final s = maxSpeed * 1.15 / spd;
      a.vx *= s;
      a.vy *= s;
    }
    final nx = a.x + a.vx * dt;
    final ny = a.y + a.vy * dt;
    if (world.canWalk(nx, ny)) {
      a.x = nx;
      a.y = ny;
      return;
    }
    if (world.canWalk(nx, a.y)) {
      a.x = nx;
      a.vy *= 0.35;
    } else {
      a.vx *= 0.2;
    }
    if (world.canWalk(a.x, ny)) {
      a.y = ny;
      a.vx *= 0.35;
    } else {
      a.vy *= 0.2;
    }
  }

  static void updateFacing(
    SpatialActor a,
    double aimX,
    double aimY,
    double dt,
  ) {
    if (a.faceAimX == 0 && a.faceAimY == 0) {
      a.faceAimX = aimX;
      a.faceAimY = aimY;
      return;
    }
    final t = 1.0 - math.exp(-facingLerp * dt);
    a.faceAimX += (aimX - a.faceAimX) * t;
    a.faceAimY += (aimY - a.faceAimY) * t;
  }

  /// Kit + personality preferred fight distance.
  static double preferredFightRange(SpatialActor hero, double base) {
    return base * hero.kiteMul;
  }

  /// Impatient melee: allow a longer leash before snapping back to the tank.
  static double packLeash(SpatialActor hero) {
    return 1.5 + hero.impatience * 0.95;
  }

  /// Low-HP limp: seek healer / tank cover at reduced speed.
  static bool tryEmergencyRetreat(
    SpatialActor hero,
    SpatialWorld world, {
    required SpatialActor? packAnchor,
    required void Function(double tx, double ty, double hold, double speedMul)
        setGoal,
  }) {
    if (hero.team != SpatialTeam.hero || !hero.isAlive) return false;
    final maxHp = math.max(1, hero.effectiveMaxHp);
    final frac = hero.hp / maxHp;
    if (frac > lowHpFrac) {
      hero.lowHpBarked = false;
      return false;
    }
    if (_actorIsHealer(hero) || _actorIsTank(hero)) return false;
    SpatialActor? healer;
    for (final h in world.heroes) {
      if (h.isAlive && _actorIsHealer(h) && h.id != hero.id) {
        healer = h;
        break;
      }
    }
    final shelter = healer ?? packAnchor;
    if (shelter == null || shelter.id == hero.id) return false;
    // Limp toward cover, slightly behind the shelter vs nearest foe.
    var tx = shelter.x;
    var ty = shelter.y;
    final foe = HeroFocus.nearestActiveEnemy(hero, world.enemies);
    if (foe != null) {
      final dx = shelter.x - foe.x;
      final dy = shelter.y - foe.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 0.2) {
        tx = shelter.x + dx / len * 0.55;
        ty = shelter.y + dy / len * 0.55;
      }
    }
    final limp = 0.48 + frac * 0.45;
    setGoal(tx, ty, 0.4, limp);
    return true;
  }

  /// Arcane-style sidestep kite vs Fire-style straight panic backpedal.
  static (double, double) kiteTarget(
    SpatialActor hero,
    SpatialActor target,
  ) {
    var tx = hero.x - (target.x - hero.x);
    var ty = hero.y - (target.y - hero.y);
    final side = hero.kiteSide;
    if (side.abs() < 0.05) return (tx, ty);
    final pdx = target.y - hero.y;
    final pdy = hero.x - target.x;
    final plen = math.sqrt(pdx * pdx + pdy * pdy);
    if (plen < 0.01) return (tx, ty);
    final strength = hero.heroSpecId == HeroSpecId.arcane ? 1.55 : 0.7;
    tx += pdx / plen * side * strength;
    ty += pdy / plen * side * strength;
    return (tx, ty);
  }

  /// Subtle focus bias: impatient heroes nudge toward nearer packs.
  static double impatienceFocusBias(SpatialActor self, double dist) {
    if (self.team != SpatialTeam.hero) return 0;
    final near = (1.0 - (dist / 7.0).clamp(0.0, 1.0));
    return near * self.impatience * 16.0;
  }

  static void tick(SpatialActor a, double dt) {
    if (a.barkCd > 0) a.barkCd = math.max(0, a.barkCd - dt);
  }

  static void spawnBark(
    SpatialWorld world,
    SpatialActor actor,
    String text, {
    required int argb,
    required bool reducedVfx,
    double life = 1.15,
  }) {
    if (reducedVfx || world.afkAssist) return;
    if (text.isEmpty || actor.barkCd > 0) return;
    actor.barkCd = barkCooldown;
    SpatialCombat._spawnFloater(
      world,
      x: actor.x,
      y: actor.y - 0.85,
      text: text,
      argb: argb,
      life: life,
      priority: 2,
      kind: SpatialFloaterKind.speech,
    );
  }

  static void onTaunt(
    SpatialWorld world,
    SpatialActor tank, {
    required bool reducedVfx,
  }) {
    spawnBark(
      world,
      tank,
      'Stay off my backline!',
      argb: barkTaunt,
      reducedVfx: reducedVfx,
    );
  }

  static void onCrit(
    SpatialWorld world,
    SpatialActor hero, {
    required bool reducedVfx,
    required math.Random rng,
  }) {
    if (rng.nextDouble() > 0.12) return;
    final lines = <String>[
      'Gotcha!',
      'There it is!',
      'Clean hit!',
    ];
    spawnBark(
      world,
      hero,
      lines[rng.nextInt(lines.length)],
      argb: barkTriumph,
      reducedVfx: reducedVfx,
      life: 1.0,
    );
  }

  static void onEmergencyHeal(
    SpatialWorld world,
    SpatialActor healer, {
    required bool reducedVfx,
  }) {
    spawnBark(
      world,
      healer,
      "I've got you — fight!",
      argb: barkCare,
      reducedVfx: reducedVfx,
    );
  }

  static void onPulledAggro(
    SpatialWorld world,
    SpatialActor hero, {
    required bool reducedVfx,
  }) {
    if (_actorIsTank(hero)) return;
    spawnBark(
      world,
      hero,
      "It's looking at me!",
      argb: barkPanic,
      reducedVfx: reducedVfx,
    );
  }

  static void onLowHp(
    SpatialWorld world,
    SpatialActor hero, {
    required bool reducedVfx,
  }) {
    if (hero.lowHpBarked) return;
    final maxHp = math.max(1, hero.effectiveMaxHp);
    if (hero.hp / maxHp > lowHpFrac) return;
    hero.lowHpBarked = true;
    spawnBark(
      world,
      hero,
      'Running low!',
      argb: barkPanic,
      reducedVfx: reducedVfx,
    );
  }
}
