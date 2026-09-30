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
    if (actorIsHealer(hero) || actorIsTank(hero)) return false;
    SpatialActor? healer;
    for (final h in world.heroes) {
      if (h.isAlive && actorIsHealer(h) && h.id != hero.id) {
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
    SpatialCombat.spawnFloater(
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
    final lines = switch (hero.heroRole) {
      HeroRole.mage => const ['Burn!', 'There it is!', 'Clean hit!'],
      HeroRole.rogue => const ['From the dark!', 'Gotcha!', 'Clean hit!'],
      HeroRole.healer => const ['Keep swinging!', 'There it is!', 'Gotcha!'],
      _ => const ['Gotcha!', 'There it is!', 'Clean hit!'],
    };
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
      healer.heroSpecId == HeroSpecId.holyPaladin
          ? 'Light holds you!'
          : "I've got you — fight!",
      argb: barkCare,
      reducedVfx: reducedVfx,
    );
  }

  static void onPulledAggro(
    SpatialWorld world,
    SpatialActor hero, {
    required bool reducedVfx,
  }) {
    if (actorIsTank(hero)) return;
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

  static SpecRoleTag? roleTag(SpatialActor hero) {
    final id = hero.heroSpecId;
    if (id == null) return null;
    return HeroSpecs.def(id).roleTag;
  }

  static bool isHealerRole(SpatialActor hero) {
    if (actorIsHealer(hero)) return true;
    if (roleTag(hero) == SpecRoleTag.healer) return true;
    return hero.heroRole == HeroRole.healer;
  }

  /// Casters, ranged, and healers stand off the front line.
  static bool isBackliner(SpatialActor hero) {
    if (isHealerRole(hero) || hero.ranged) return true;
    final tag = roleTag(hero);
    return tag == SpecRoleTag.caster || tag == SpecRoleTag.rangedDps;
  }

  /// How far behind the tank this hero trails when the pack is marching.
  static double packDepth(SpatialActor hero) {
    if (isHealerRole(hero)) return 1.25;
    final tag = roleTag(hero);
    if (tag == SpecRoleTag.caster ||
        tag == SpecRoleTag.rangedDps ||
        hero.ranged ||
        hero.heroRole == HeroRole.mage) {
      return 1.05;
    }
    if (tag == SpecRoleTag.meleeDps || hero.heroRole == HeroRole.rogue) {
      return 0.45;
    }
    return 0.2;
  }

  /// 0, +1, −1, +2, −2… so party index spreads bodies sideways.
  static double wing(int index) {
    if (index <= 0) return 0;
    final mag = ((index + 1) ~/ 2).toDouble();
    return index.isOdd ? mag : -mag;
  }

  /// Unit vector from [from] toward [to]. Falls back to +x when stacked.
  static (double, double) fightForward({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
  }) {
    final dx = toX - fromX;
    final dy = toY - fromY;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.25) return (1.0, 0.0);
    return (dx / len, dy / len);
  }

  /// [along] follows [forward] (negative = behind). [lateral] is to the left.
  static (double, double) offsetAlong(
    double x,
    double y,
    (double, double) forward, {
    required double along,
    required double lateral,
  }) {
    final fx = forward.$1;
    final fy = forward.$2;
    final lx = -fy;
    final ly = fx;
    return (x + fx * along + lx * lateral, y + fy * along + ly * lateral);
  }

  /// Slot 0 sits on [front]. Later slots alternate left and right.
  static (double, double) ringPoint({
    required double cx,
    required double cy,
    required (double, double) front,
    required int index,
    required double radius,
    double firstAngle = 0,
    double step = 1.15,
  }) {
    final bx = front.$1;
    final by = front.$2;
    final lx = -by;
    final ly = bx;
    final n = index < 0 ? 0 : index;
    final signed = n == 0 ? 0 : (n.isOdd ? (n + 1) ~/ 2 : -(n ~/ 2));
    final ang = firstAngle + signed * step;
    final c = math.cos(ang);
    final s = math.sin(ang);
    return (cx + (bx * c + lx * s) * radius, cy + (by * c + ly * s) * radius);
  }

  /// Step toward [dir] but pick a nearby angle that lands on a floor tile.
  /// [avoidX]/[avoidY] rejects steps that move closer to a threat.
  static (double, double) walkableGoal(
    SpatialWorld world,
    double x,
    double y,
    double dirX,
    double dirY,
    double distance, {
    double? avoidX,
    double? avoidY,
  }) {
    var dx = dirX;
    var dy = dirY;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.001 || distance <= 0) return (x, y);
    dx /= len;
    dy /= len;
    final avoid = avoidX != null && avoidY != null;
    final before = avoid
        ? SpatialCombat.distPoint(x, y, avoidX, avoidY)
        : 0.0;
    const angles = <double>[0, 0.65, -0.65, 1.2, -1.2, 1.85, -1.85, 2.5, -2.5];
    for (final scale in const <double>[1, 0.62, 0.35]) {
      final dist = distance * scale;
      for (final ang in angles) {
        final c = math.cos(ang);
        final s = math.sin(ang);
        final rx = dx * c - dy * s;
        final ry = dx * s + dy * c;
        final tx = x + rx * dist;
        final ty = y + ry * dist;
        if (!world.canWalk(tx, ty)) continue;
        if (avoid &&
            SpatialCombat.distPoint(tx, ty, avoidX, avoidY) + 0.04 < before) {
          continue;
        }
        return (tx, ty);
      }
    }
    return (x, y);
  }

  /// Ring slot that stays on a floor. In a corridor, pull toward the front
  /// instead of collapsing everyone onto the same tile.
  static (double, double) walkableRing({
    required SpatialWorld world,
    required double cx,
    required double cy,
    required (double, double) front,
    required int index,
    required double radius,
    double firstAngle = 0,
    double step = 1.15,
    double? fallbackX,
    double? fallbackY,
  }) {
    (double, double) at(int idx, double rad, double ang0) => ringPoint(
      cx: cx,
      cy: cy,
      front: front,
      index: idx,
      radius: rad,
      firstAngle: ang0,
      step: step,
    );

    final raw = at(index, radius, firstAngle);
    if (world.canWalk(raw.$1, raw.$2)) return raw;
    for (final scale in const <double>[0.85, 0.7, 0.55]) {
      final idx = index <= 0 ? 0 : index - 1;
      for (final candidate in [idx, 0]) {
        final p = at(candidate, radius * scale, firstAngle * scale);
        if (world.canWalk(p.$1, p.$2)) return p;
      }
    }
    return clampGoal(
      world,
      raw.$1,
      raw.$2,
      fallbackX ?? cx,
      fallbackY ?? cy,
    );
  }

  /// Ease the party facing toward the next threat so slots do not twitch.
  static void refreshPackFacing(
    SpatialWorld world,
    SpatialActor anchor,
    double dt,
  ) {
    final exitX = world.map.exitPoint.$1 + 0.5;
    final exitY = world.map.exitPoint.$2 + 0.5;
    var toX = exitX;
    var toY = exitY;
    var best = double.infinity;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final d = SpatialCombat.distPoint(anchor.x, anchor.y, e.x, e.y);
      if (d < best) {
        best = d;
        toX = e.x;
        toY = e.y;
      }
    }
    final dx = toX - anchor.x;
    final dy = toY - anchor.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 0.35) return;
    final fx = dx / len;
    final fy = dy / len;
    if (!world.packFaceReady) {
      world.packFaceX = fx;
      world.packFaceY = fy;
      world.packFaceReady = true;
      return;
    }
    final t = 1 - math.exp(-2.8 * dt);
    world.packFaceX += (fx - world.packFaceX) * t;
    world.packFaceY += (fy - world.packFaceY) * t;
    final n = math.sqrt(
      world.packFaceX * world.packFaceX + world.packFaceY * world.packFaceY,
    );
    if (n < 0.05) return;
    world.packFaceX /= n;
    world.packFaceY /= n;
  }

  static (double, double) _facingFor(
    SpatialWorld world,
    double fromX,
    double fromY,
    double toX,
    double toY,
  ) {
    final instant = fightForward(
      fromX: fromX,
      fromY: fromY,
      toX: toX,
      toY: toY,
    );
    if (!world.packFaceReady) return instant;
    final dot =
        instant.$1 * world.packFaceX + instant.$2 * world.packFaceY;
    if (dot < 0.55) return instant;
    return (world.packFaceX, world.packFaceY);
  }

  static (double, double) clampGoal(
    SpatialWorld world,
    double tx,
    double ty,
    double fallbackX,
    double fallbackY,
  ) {
    if (world.canWalk(tx, ty)) return (tx, ty);
    for (var t = 0.8; t >= 0.2; t -= 0.2) {
      final x = fallbackX + (tx - fallbackX) * t;
      final y = fallbackY + (ty - fallbackY) * t;
      if (world.canWalk(x, y)) return (x, y);
    }
    if (world.canWalk(fallbackX, fallbackY)) return (fallbackX, fallbackY);
    return SpatialCombat.snapToWalkable(world.map, world.openGateIds, tx, ty);
  }

  static int meleeSlot(SpatialActor hero, List<SpatialActor> heroes) {
    final tanks = <SpatialActor>[];
    final dps = <SpatialActor>[];
    for (final h in heroes) {
      if (!h.isAlive || isBackliner(h)) continue;
      if (actorIsTank(h)) {
        tanks.add(h);
      } else {
        dps.add(h);
      }
    }
    final ti = tanks.indexWhere((h) => h.id == hero.id);
    if (ti >= 0) return ti;
    final di = dps.indexWhere((h) => h.id == hero.id);
    return tanks.length + (di < 0 ? 0 : di);
  }

  static int _backlineSlot(SpatialActor hero, List<SpatialActor> heroes) {
    var slot = 0;
    for (final h in heroes) {
      if (!h.isAlive || !isBackliner(h) || isHealerRole(h)) continue;
      if (h.id == hero.id) return slot;
      slot++;
    }
    return 0;
  }

  static bool _clearSight(
    SpatialWorld world,
    double fromX,
    double fromY,
    double toX,
    double toY,
  ) {
    return SpatialCombat.hasClearCorridor(
      world.map,
      world.openGateIds,
      fromX.floor(),
      fromY.floor(),
      toX.floor(),
      toY.floor(),
      tight: true,
    );
  }

  /// Chamber that contains [x],[y], if the fight is inside a carved room.
  static Chamber? _fightRoom(SpatialWorld world, double x, double y) {
    for (final c in world.map.chambers) {
      if (c.containsWorld(x, y)) return c;
    }
    return null;
  }

  /// [lip] keeps the doorway tile; the approach hall beyond that does not count.
  static bool _inFightRoom(
    SpatialWorld world,
    double x,
    double y,
    double lookX,
    double lookY, {
    required bool lip,
  }) {
    final room = _fightRoom(world, lookX, lookY);
    if (room == null) return true;
    final tx = x.floor();
    final ty = y.floor();
    if (room.containsTile(tx, ty)) return true;
    if (!lip) return false;
    return tx >= room.x - 1 &&
        tx <= room.x + room.w &&
        ty >= room.y - 1 &&
        ty <= room.y + room.h;
  }

  static (double, double)? _bestFloorTile({
    required SpatialWorld world,
    required double originX,
    required double originY,
    required int radius,
    required double? Function(double x, double y) score,
  }) {
    final cx = originX.floor();
    final cy = originY.floor();
    (double, double)? best;
    var bestScore = double.infinity;
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        final x = cx + dx + 0.5;
        final y = cy + dy + 0.5;
        final s = score(x, y);
        if (s == null || s >= bestScore) continue;
        bestScore = s;
        best = (x, y);
      }
    }
    return best;
  }

  /// Casters stand on the party side of the foe, inside the fight room,
  /// on a tile that can actually see them. A straight max-range ring lands
  /// in the approach hall on these maps.
  static (double, double) _rangedStand({
    required SpatialWorld world,
    required SpatialActor hero,
    required SpatialActor target,
    required SpatialActor anchor,
    required double preferred,
    required bool hasLos,
  }) {
    final stand = math.min(preferred, hero.attackRange * 0.9).clamp(1.5, 4.6);
    final maxDist = math.min(hero.attackRange * 0.95, 5.2);
    final minStand = hasLos ? 1.35 : 0.85;
    final back = fightForward(
      fromX: target.x,
      fromY: target.y,
      toX: anchor.x,
      toY: anchor.y,
    );
    final slot = _backlineSlot(hero, world.heroes);
    final hint = offsetAlong(
      target.x,
      target.y,
      back,
      along: stand,
      lateral: wing(slot) * 0.62 + hero.kiteSide * 0.28,
    );
    final bx = anchor.x - target.x;
    final by = anchor.y - target.y;
    final bl = math.sqrt(bx * bx + by * by);

    bool fits(double x, double y, {required bool lip, required double minD}) {
      if (!world.canWalk(x, y)) return false;
      if (!_inFightRoom(world, x, y, target.x, target.y, lip: lip)) {
        return false;
      }
      final d = SpatialCombat.distPoint(x, y, target.x, target.y);
      if (d < minD || d > maxDist + 0.2) return false;
      return _clearSight(world, x, y, target.x, target.y);
    }

    double scoreOf(double x, double y) {
      final d = SpatialCombat.distPoint(x, y, target.x, target.y);
      final hintD = SpatialCombat.distPoint(x, y, hint.$1, hint.$2);
      var side = 1.0;
      if (bl > 0.25 && d > 0.05) {
        side = ((x - target.x) * bx + (y - target.y) * by) / (d * bl);
      }
      final sidePenalty = side < 0.12 ? (0.12 - side) * 5.5 : 0.0;
      var crowd = 0.0;
      for (final h in world.heroes) {
        if (!h.isAlive || h.id == hero.id) continue;
        if (SpatialCombat.distPoint(x, y, h.x, h.y) < 0.5) crowd += 1.6;
      }
      final stick =
          SpatialCombat.distPoint(x, y, hero.x, hero.y) < 0.48 ? 0.65 : 0.0;
      return (d - stand).abs() + hintD * 0.72 + sidePenalty + crowd - stick;
    }

    if (fits(hint.$1, hint.$2, lip: false, minD: minStand)) {
      return hint;
    }

    (double, double)? pick({required bool lip, required double minD}) {
      return _bestFloorTile(
        world: world,
        originX: target.x,
        originY: target.y,
        radius: maxDist.ceil() + 2,
        score: (x, y) {
          if (!fits(x, y, lip: lip, minD: minD)) return null;
          return scoreOf(x, y);
        },
      );
    }

    return pick(lip: false, minD: minStand) ??
        pick(lip: false, minD: 0.7) ??
        pick(lip: true, minD: 0.7) ??
        (target.x, target.y);
  }

  /// Healer tucks just behind the tank, but only on a tile that can see the
  /// tank and, when the room allows, the fight. The straight "behind" step
  /// walks out the door on a south-facing choke.
  static (double, double) _healerPocket({
    required SpatialWorld world,
    required SpatialActor hero,
    required SpatialActor tank,
    required SpatialActor target,
    required int index,
  }) {
    final fwd = fightForward(
      fromX: tank.x,
      fromY: tank.y,
      toX: target.x,
      toY: target.y,
    );
    final hint = offsetAlong(
      tank.x,
      tank.y,
      fwd,
      along: -1.05,
      lateral: wing(index) * 0.34,
    );

    bool pocket(
      double x,
      double y, {
      required bool needTarget,
    }) {
      if (!world.canWalk(x, y)) return false;
      final d = SpatialCombat.distPoint(x, y, tank.x, tank.y);
      if (d < 0.4 || d > 2.15) return false;
      if (!_inFightRoom(world, x, y, tank.x, tank.y, lip: false)) return false;
      if (!_clearSight(world, x, y, tank.x, tank.y)) return false;
      if (needTarget && !_clearSight(world, x, y, target.x, target.y)) {
        return false;
      }
      return true;
    }

    double scoreOf(double x, double y) {
      final stick =
          SpatialCombat.distPoint(x, y, hero.x, hero.y) < 0.48 ? 0.65 : 0.0;
      return SpatialCombat.distPoint(x, y, hint.$1, hint.$2) - stick;
    }

    if (pocket(hint.$1, hint.$2, needTarget: true)) return hint;

    (double, double)? pick({required bool needTarget}) {
      return _bestFloorTile(
        world: world,
        originX: tank.x,
        originY: tank.y,
        radius: 3,
        score: (x, y) {
          if (!pocket(x, y, needTarget: needTarget)) return null;
          return scoreOf(x, y);
        },
      );
    }

    return pick(needTarget: true) ??
        (pocket(hint.$1, hint.$2, needTarget: false) ? hint : null) ??
        pick(needTarget: false) ??
        (tank.x, tank.y);
  }

  /// In-fight stand point: melee wedge on the enemy. Ranged and healers
  /// stay inside the fight room on a tile with a clear shot — not at max
  /// range down the corridor they entered from.
  static ({double x, double y, double hold}) heroFightGoal({
    required SpatialActor hero,
    required SpatialActor target,
    required SpatialWorld world,
    required SpatialActor? packAnchor,
    required int index,
    required double preferred,
    required bool hasLos,
  }) {
    final anchor = packAnchor ?? hero;
    final healer = isHealerRole(hero);
    if (healer && packAnchor != null && packAnchor.id != hero.id) {
      final g = _healerPocket(
        world: world,
        hero: hero,
        tank: packAnchor,
        target: target,
        index: index,
      );
      return (x: g.$1, y: g.$2, hold: 0.2);
    }

    if (!isBackliner(hero)) {
      final fwd = _facingFor(
        world,
        anchor.x,
        anchor.y,
        target.x,
        target.y,
      );
      final radius = math
          .min(preferred, hero.attackRange * 0.78)
          .clamp(0.8, 1.2);
      final front = (-fwd.$1, -fwd.$2);
      final g = walkableRing(
        world: world,
        cx: target.x,
        cy: target.y,
        front: front,
        index: meleeSlot(hero, world.heroes),
        radius: radius,
        fallbackX: anchor.x,
        fallbackY: anchor.y,
      );
      // A diagonal floor tile can "touch" the foe through two walls.
      // Path around instead of holding there.
      if (!_clearSight(world, g.$1, g.$2, target.x, target.y)) {
        return (x: target.x, y: target.y, hold: 0.4);
      }
      return (x: g.$1, y: g.$2, hold: 0.16);
    }

    final g = _rangedStand(
      world: world,
      hero: hero,
      target: target,
      anchor: anchor,
      preferred: preferred,
      hasLos: hasLos,
    );
    return (x: g.$1, y: g.$2, hold: 0.18);
  }

  /// Marching formation faces the next threat, or the stairs.
  static ({double x, double y}) idleSlot({
    required SpatialActor hero,
    required SpatialActor anchor,
    required SpatialWorld world,
    required int index,
  }) {
    final exitX = world.map.exitPoint.$1 + 0.5;
    final exitY = world.map.exitPoint.$2 + 0.5;
    var toX = exitX;
    var toY = exitY;
    var best = double.infinity;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final d = SpatialCombat.distPoint(anchor.x, anchor.y, e.x, e.y);
      if (d < best) {
        best = d;
        toX = e.x;
        toY = e.y;
      }
    }
    final fwd = world.packFaceReady
        ? (world.packFaceX, world.packFaceY)
        : fightForward(
            fromX: anchor.x,
            fromY: anchor.y,
            toX: toX,
            toY: toY,
          );
    var depth = packDepth(hero);
    var lat = wing(index) * 0.48;
    var p = offsetAlong(
      anchor.x,
      anchor.y,
      fwd,
      along: -depth,
      lateral: lat,
    );
    // A corner turns "behind the tank" into another hallway. Step in until
    // the slot can see the anchor.
    for (var n = 0; n < 4; n++) {
      if (world.canWalk(p.$1, p.$2) &&
          _clearSight(world, p.$1, p.$2, anchor.x, anchor.y)) {
        break;
      }
      depth *= 0.55;
      lat *= 0.55;
      p = offsetAlong(
        anchor.x,
        anchor.y,
        fwd,
        along: -depth,
        lateral: lat,
      );
    }
    final g = clampGoal(world, p.$1, p.$2, anchor.x, anchor.y);
    return (x: g.$1, y: g.$2);
  }

  /// Pet heels just behind and to the side of its owner, facing the fight.
  static (double, double) heelPoint(
    SpatialActor owner,
    SpatialWorld world, {
    SpatialActor? threat,
  }) {
    final exitX = world.map.exitPoint.$1 + 0.5;
    final exitY = world.map.exitPoint.$2 + 0.5;
    final fwd = fightForward(
      fromX: owner.x,
      fromY: owner.y,
      toX: threat?.x ?? exitX,
      toY: threat?.y ?? exitY,
    );
    final p = offsetAlong(owner.x, owner.y, fwd, along: -0.4, lateral: 0.55);
    return clampGoal(world, p.$1, p.$2, owner.x, owner.y);
  }

  static void lockApproach(SpatialActor enemy, SpatialActor target) {
    final same = enemy.approachFocusId == target.id;
    final heroMoved = SpatialCombat.distPoint(
          target.x,
          target.y,
          enemy.approachHeroX,
          enemy.approachHeroY,
        ) >
        2.4;
    if (same && !heroMoved) return;
    enemy.approachFocusId = target.id;
    enemy.approachX = enemy.x;
    enemy.approachY = enemy.y;
    enemy.approachHeroX = target.x;
    enemy.approachHeroY = target.y;
  }

  static (double, double)? _lockedFront(
    SpatialActor hero,
    SpatialWorld world,
    bool Function(SpatialActor e) include,
  ) {
    var sx = 0.0;
    var sy = 0.0;
    var n = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant || !include(e)) continue;
      if (e.approachFocusId != hero.id) continue;
      sx += e.approachX;
      sy += e.approachY;
      n++;
    }
    if (n == 0) return null;
    return fightForward(fromX: hero.x, fromY: hero.y, toX: sx / n, toY: sy / n);
  }

  static int enemySlot(
    SpatialActor self,
    SpatialWorld world,
    SpatialActor focus,
    bool Function(SpatialActor e) match,
  ) {
    final group = <SpatialActor>[];
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant || !match(e)) continue;
      final f = SpatialCombat._focusHero(e, world.heroes);
      if (f == null || f.id != focus.id) continue;
      group.add(e);
    }
    group.sort((a, b) {
      final byRank = _slotRank(a).compareTo(_slotRank(b));
      if (byRank != 0) return byRank;
      return a.id.compareTo(b.id);
    });
    final i = group.indexWhere((e) => e.id == self.id);
    return i < 0 ? 0 : i;
  }

  static int _slotRank(SpatialActor e) {
    if (e.role == EnemyRole.boss) return 0;
    if (e.archetype == EnemyArchetype.tank) return 1;
    return 2;
  }

  static bool _frontMelee(SpatialActor e) =>
      !e.ranged &&
      e.archetype != EnemyArchetype.glass &&
      e.archetype != EnemyArchetype.swarm &&
      e.archetype != EnemyArchetype.support;

  static SpatialActor? _nearestFront(SpatialActor enemy, SpatialWorld world) {
    SpatialActor? front;
    SpatialActor? any;
    var frontD = double.infinity;
    var anyD = double.infinity;
    for (final o in world.enemies) {
      if (identical(o, enemy) || o.hp <= 0 || o.dormant) continue;
      if (o.ranged || o.archetype == EnemyArchetype.support) continue;
      final d = SpatialCombat.actorDist(enemy, o);
      if (d < anyD) {
        anyD = d;
        any = o;
      }
      if (_frontMelee(o) && d < frontD) {
        frontD = d;
        front = o;
      }
    }
    return front ?? any;
  }

  /// Where this enemy wants to stand: front plant, flank, ring, or back line.
  static ({double x, double y, double hold, double separation}) enemyMoveGoal(
    SpatialActor enemy,
    SpatialActor target,
    SpatialWorld world,
  ) {
    lockApproach(enemy, target);
    final preferred = enemy.preferredRange ?? (enemy.attackRange * 0.75);
    final separation = switch (enemy.archetype) {
      EnemyArchetype.swarm => 0.5,
      EnemyArchetype.tank => 0.95,
      EnemyArchetype.glass => 0.7,
      EnemyArchetype.brute => 0.72,
      _ => 0.9,
    };

    if (enemy.archetype == EnemyArchetype.support) {
      final frontAlly = _nearestFront(enemy, world);
      if (frontAlly != null) {
        final face = fightForward(
          fromX: frontAlly.x,
          fromY: frontAlly.y,
          toX: target.x,
          toY: target.y,
        );
        final slot = enemySlot(
          enemy,
          world,
          target,
          (e) => e.archetype == EnemyArchetype.support,
        );
        final p = offsetAlong(
          frontAlly.x,
          frontAlly.y,
          face,
          along: -1.2,
          lateral: wing(slot + 1) * 0.4,
        );
        final g = clampGoal(world, p.$1, p.$2, frontAlly.x, frontAlly.y);
        return (x: g.$1, y: g.$2, hold: 0.28, separation: separation);
      }
    }

    if (enemy.ranged) {
      final dist = SpatialCombat.actorDist(enemy, target);
      if (dist < preferred * 0.72) {
        final safe = walkableGoal(
          world,
          enemy.x,
          enemy.y,
          enemy.x - target.x,
          enemy.y - target.y,
          1.45,
          avoidX: target.x,
          avoidY: target.y,
        );
        return (x: safe.$1, y: safe.$2, hold: 0, separation: separation);
      }
      // Already in range: hold this side. Only slide if stacked on another shooter.
      if (dist <= preferred * 1.22) {
        SpatialActor? crowded;
        for (final o in world.enemies) {
          if (identical(o, enemy) || o.hp <= 0 || o.dormant || !o.ranged) {
            continue;
          }
          if (SpatialCombat.actorDist(enemy, o) < 0.75) {
            crowded = o;
            break;
          }
        }
        if (crowded == null) {
          return (x: enemy.x, y: enemy.y, hold: 0.2, separation: separation);
        }
        final safe = walkableGoal(
          world,
          enemy.x,
          enemy.y,
          enemy.x - crowded.x,
          enemy.y - crowded.y,
          0.8,
          avoidX: target.x,
          avoidY: target.y,
        );
        return (x: safe.$1, y: safe.$2, hold: 0.15, separation: separation);
      }
      // Still far: close along this body's own line, not across the pack.
      final front = fightForward(
        fromX: target.x,
        fromY: target.y,
        toX: enemy.x,
        toY: enemy.y,
      );
      final slot = enemySlot(
        enemy,
        world,
        target,
        (e) => e.ranged && e.archetype != EnemyArchetype.support,
      );
      final radius = math
          .min(preferred, enemy.attackRange * 0.88)
          .clamp(1.8, 5.5);
      final g = walkableRing(
        world: world,
        cx: target.x,
        cy: target.y,
        front: front,
        index: slot,
        radius: radius,
        firstAngle: 0.15,
        step: 0.38,
        fallbackX: enemy.x,
        fallbackY: enemy.y,
      );
      return (x: g.$1, y: g.$2, hold: 0.34, separation: separation);
    }

    final glass = enemy.archetype == EnemyArchetype.glass;
    final swarm = enemy.archetype == EnemyArchetype.swarm;
    var front = _lockedFront(target, world, _frontMelee);
    if (swarm) {
      front = _lockedFront(
        target,
        world,
        (e) => e.archetype == EnemyArchetype.swarm,
      );
    } else if (glass && front == null) {
      front = _lockedFront(
        target,
        world,
        (e) => e.archetype == EnemyArchetype.glass,
      );
    }
    front ??= fightForward(
      fromX: target.x,
      fromY: target.y,
      toX: enemy.approachX,
      toY: enemy.approachY,
    );
    final slot = enemySlot(enemy, world, target, (e) {
      if (swarm) return e.archetype == EnemyArchetype.swarm;
      if (glass) return e.archetype == EnemyArchetype.glass;
      return _frontMelee(e);
    });
    final radius = swarm
        ? 0.68
        : math.min(
            enemy.attackRange * 0.58,
            enemy.role == EnemyRole.boss ? 1.05 : 0.86,
          );
    final g = walkableRing(
      world: world,
      cx: target.x,
      cy: target.y,
      front: front,
      index: slot,
      radius: radius,
      firstAngle: glass ? 1.75 : (swarm ? 0.45 : 0),
      step: swarm ? 0.78 : 0.95,
      fallbackX: enemy.x,
      fallbackY: enemy.y,
    );
    return (x: g.$1, y: g.$2, hold: swarm ? 0.1 : 0.14, separation: separation);
  }
}
