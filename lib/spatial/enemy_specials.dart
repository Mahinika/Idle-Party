part of 'spatial_combat.dart';

bool _worldHasAffix(SpatialWorld world, String id) =>
    world.keystoneRunAffixes.contains(id);

/// Gauntlet boss tells scale past F100 (F5 = 1.0, F150 ≈ 1.5).
double _gauntletBossScale(SpatialWorld world) {
  if (!world.inGauntlet) return 1.0;
  return 1.0 + (world.combatFloor / 100.0).clamp(0.0, 1.5);
}

double _bossCadenceMul(SpatialWorld world) {
  var mul = 1.0;
  if (_worldHasAffix(world, 'tyrannical')) mul *= 0.82;
  if (world.inGauntlet) {
    mul *= (1.0 - _gauntletBossScale(world) * 0.05).clamp(0.55, 1.0);
  }
  return mul;
}

double _bossCooldownSec(SpatialWorld world, double base) =>
    base * _bossCadenceMul(world);

void _showAffixBanners(SpatialWorld world, {required bool reducedVfx}) {
  if (world.keystoneRunAffixes.isEmpty) return;
  final leader = world.leader;
  if (leader == null) return;
  final x = leader.x;
  final y = leader.y - 0.8;
  if (_worldHasAffix(world, 'swarm')) {
    SpatialCombat._spawnFloater(
      world,
      x: x,
      y: y,
      text: 'SWARM',
      argb: 0xFFFFA040,
      life: 1.1,
      priority: 2,
    );
  }
  if (_worldHasAffix(world, 'fortified')) {
    SpatialCombat._spawnFloater(
      world,
      x: x,
      y: y - 0.35,
      text: 'FORTIFIED',
      argb: 0xFF80C0FF,
      life: 1.1,
      priority: 2,
    );
  }
  if (_worldHasAffix(world, 'tyrannical') && !reducedVfx) {
    SpatialCombat._spawnFloater(
      world,
      x: x,
      y: y - 0.7,
      text: 'TYRANNICAL',
      argb: 0xFFFF6060,
      life: 1.0,
      priority: 2,
    );
  }
  if (world.keystoneWeekDungeonId.isNotEmpty) {
    SpatialCombat._spawnFloater(
      world,
      x: x,
      y: y - 1.05,
      text: EnemyFlavor.bossTell(world.keystoneWeekDungeonId),
      argb: 0xFFE8D090,
      life: 1.2,
      priority: 2,
    );
  }
}

/// Trash specials (heal / hex / cleave / fortify) plus one unique boss tell
/// per zone. Same [SpatialCombat.step] — not a second sim.
void _tickEnemySpecials(
  SpatialWorld world,
  SpatialActor enemy,
  SpatialActor focus, {
  required math.Random rng,
  required bool reducedVfx,
}) {
  // Tank / boss: enrage under 40% HP.
  if ((enemy.archetype == EnemyArchetype.tank ||
          enemy.role == EnemyRole.boss) &&
      enemy.hp < enemy.effectiveMaxHp * 0.4 &&
      enemy.enrageTimer <= 0) {
    enemy.enrageTimer = 5.0;
    if (!reducedVfx || world.spawnPersistentVfx) {
      SpatialCombat._spawnFloater(
        world,
        x: enemy.x,
        y: enemy.y - 0.45,
        text: 'ENRAGE',
        argb: 0xFFFF4040,
        life: 0.9,
        priority: 2,
      );
      if (world.spawnPersistentVfx) {
        SpatialCombat._spawnRing(
          world,
          x: enemy.x,
          y: enemy.y,
          argb: 0xAAFF4040,
          radius: 1.1,
          life: 0.55,
        );
      }
    }
  }

  if (enemy.role == EnemyRole.boss) {
    _tickBossKit(
      world,
      enemy,
      focus,
      rng: rng,
      reducedVfx: reducedVfx,
    );
    return;
  }

  if (enemy.specialCd > 0) return;

  if (enemy.archetype == EnemyArchetype.support) {
    SpatialActor? lowest;
    for (final ally in world.enemies) {
      if (!ally.isAlive || ally.dormant) continue;
      if (SpatialCombat._dist(enemy, ally) > 5.0) continue;
      if (lowest == null ||
          ally.hp / ally.effectiveMaxHp < lowest.hp / lowest.effectiveMaxHp) {
        lowest = ally;
      }
    }
    if (lowest != null && lowest.hp < lowest.effectiveMaxHp) {
      final healMul = world.afkAssist ? 0.4 : 1.0;
      final heal = math.max(8, (enemy.attack * 1.4 * healMul).round());
      lowest.hp = math.min(lowest.effectiveMaxHp, lowest.hp + heal);
      enemy.specialCd = world.afkAssist ? 6.0 : 5.0;
      if (!reducedVfx || world.spawnPersistentVfx) {
        SpatialCombat._spawnFloater(
          world,
          x: lowest.x,
          y: lowest.y - 0.35,
          text: '+$heal',
          argb: SpatialCombat._floaterHeal,
          life: 0.7,
          priority: reducedVfx ? 2 : 0,
        );
        if (world.spawnPersistentVfx) {
          SpatialCombat._spawnBurst(
            world,
            x: lowest.x,
            y: lowest.y,
            argb: 0xFF60E080,
            radius: 0.65,
            kind: SpatialBurstKind.cross,
            life: 0.35,
          );
        }
      }
    }
  } else if (enemy.archetype == EnemyArchetype.ranged) {
    if (SpatialCombat._dist(enemy, focus) <= 5.5) {
      focus.attackSlowTimer = math.max(focus.attackSlowTimer, 2.2);
      focus.demoShoutTimer = math.max(focus.demoShoutTimer, 2.0);
      enemy.specialCd = 6.0;
      if (!reducedVfx || world.spawnPersistentVfx) {
        SpatialCombat._spawnFloater(
          world,
          x: focus.x,
          y: focus.y - 0.5,
          text: 'HEX',
          argb: 0xFFB060FF,
          life: 0.75,
          priority: reducedVfx ? 2 : 0,
        );
        if (world.spawnPersistentVfx) {
          SpatialCombat._spawnRing(
            world,
            x: focus.x,
            y: focus.y,
            argb: 0x88B060FF,
            radius: 0.85,
            life: 0.45,
          );
          SpatialCombat._spawnBurst(
            world,
            x: focus.x,
            y: focus.y,
            argb: 0xFFB060E0,
            radius: 0.5,
            kind: SpatialBurstKind.skull,
            life: 0.32,
          );
        }
      }
    }
  } else if (enemy.archetype == EnemyArchetype.brute &&
      (enemy.role == EnemyRole.elite || enemy.role == EnemyRole.boss)) {
    var hit = false;
    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      if (SpatialCombat._dist(enemy, h) > 2.6) continue;
      var chip = math.max(2, (enemy.effectiveAttack * 0.35).round());
      if (world.afkAssist) chip = math.max(1, (chip * 0.4).round());
      SpatialCombat._applyHeroIncomingDamage(
        world,
        h,
        chip,
        reducedVfx: reducedVfx,
        rng: rng,
        isMelee: true,
      );
      hit = true;
    }
    if (hit) {
      enemy.specialCd = world.afkAssist ? 7.0 : 6.5;
      if (!reducedVfx || world.spawnPersistentVfx) {
        SpatialCombat._spawnFloater(
          world,
          x: enemy.x,
          y: enemy.y - 0.4,
          text: 'CLEAVE',
          argb: 0xFFFF8040,
          life: 0.7,
          priority: reducedVfx ? 2 : 0,
        );
        if (world.spawnPersistentVfx) {
          SpatialCombat._spawnBurst(
            world,
            x: enemy.x,
            y: enemy.y,
            argb: 0xFFFF8040,
            radius: 1.2,
            kind: SpatialBurstKind.slash,
            angle: 0,
            life: 0.38,
          );
        }
      }
    }
  } else if (enemy.archetype == EnemyArchetype.tank &&
      enemy.hp <
          enemy.effectiveMaxHp *
              (_worldHasAffix(world, 'fortified') ? 0.70 : 0.55) &&
      enemy.bonusMaxHp <= 0) {
    final fortified = _worldHasAffix(world, 'fortified');
    enemy.bonusMaxHp = math.max(
      20,
      (enemy.maxHp * (fortified ? 0.22 : 0.15)).round(),
    );
    enemy.hp = math.min(enemy.effectiveMaxHp, enemy.hp + enemy.bonusMaxHp);
    enemy.specialCd = 8.0;
    if (!reducedVfx || world.spawnPersistentVfx) {
      SpatialCombat._spawnFloater(
        world,
        x: enemy.x,
        y: enemy.y - 0.4,
        text: 'FORTIFY',
        argb: 0xFF80C0FF,
        life: 0.7,
        priority: reducedVfx ? 2 : 0,
      );
      if (world.spawnPersistentVfx) {
        SpatialCombat._spawnRing(
          world,
          x: enemy.x,
          y: enemy.y,
          argb: 0xAA80C0FF,
          radius: 1.0,
          life: 0.5,
        );
      }
    }
  } else if (enemy.archetype == EnemyArchetype.swarm) {
    var hit = false;
    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      if (SpatialCombat._dist(enemy, h) > 1.85) continue;
      var chip = math.max(1, (enemy.effectiveAttack * 0.22).round());
      if (world.afkAssist) chip = math.max(1, (chip * 0.4).round());
      SpatialCombat._applyHeroIncomingDamage(
        world,
        h,
        chip,
        reducedVfx: reducedVfx,
        rng: rng,
        isMelee: true,
      );
      hit = true;
    }
    if (hit) {
      enemy.specialCd = world.afkAssist ? 5.5 : 4.8;
      if (!reducedVfx || world.spawnPersistentVfx) {
        SpatialCombat._spawnFloater(
          world,
          x: enemy.x,
          y: enemy.y - 0.4,
          text: 'SURROUND',
          argb: 0xFFFFA060,
          life: 0.65,
          priority: reducedVfx ? 2 : 0,
        );
        if (world.spawnPersistentVfx) {
          SpatialCombat._spawnRing(
            world,
            x: enemy.x,
            y: enemy.y,
            argb: 0x88FFA060,
            radius: 1.15,
            life: 0.4,
          );
        }
      }
    }
  } else if (enemy.archetype == EnemyArchetype.glass &&
      focus.hp < focus.effectiveMaxHp * 0.35 &&
      SpatialCombat._dist(enemy, focus) <= 4.2) {
    var chip = math.max(2, (enemy.effectiveAttack * 0.55).round());
    if (world.afkAssist) chip = math.max(1, (chip * 0.4).round());
    SpatialCombat._applyHeroIncomingDamage(
      world,
      focus,
      chip,
      reducedVfx: reducedVfx,
      rng: rng,
      isMelee: SpatialCombat._dist(enemy, focus) <= 2.2,
    );
    enemy.specialCd = world.afkAssist ? 6.5 : 5.8;
    if (!reducedVfx || world.spawnPersistentVfx) {
      SpatialCombat._spawnFloater(
        world,
        x: focus.x,
        y: focus.y - 0.5,
        text: 'EXECUTE',
        argb: 0xFFE8F0FF,
        life: 0.75,
        priority: reducedVfx ? 2 : 0,
      );
      if (world.spawnPersistentVfx) {
        SpatialCombat._spawnBurst(
          world,
          x: focus.x,
          y: focus.y,
          argb: 0xFFD0E8FF,
          radius: 0.7,
          kind: SpatialBurstKind.slash,
          life: 0.32,
        );
      }
    }
  }
}

void _tickBossKit(
  SpatialWorld world,
  SpatialActor enemy,
  SpatialActor focus, {
  required math.Random rng,
  required bool reducedVfx,
}) {
  if (world.inWorldBoss) {
    _tickAshenBossKit(
      world,
      enemy,
      focus,
      rng: rng,
      reducedVfx: reducedVfx,
    );
    return;
  }

  if (enemy.telegraphTimer > 0) return;

  if (enemy.telegraphSlam) {
    enemy.telegraphSlam = false;
    _resolveBossTelegraph(
      world,
      enemy,
      focus,
      rng: rng,
      reducedVfx: reducedVfx,
    );
    return;
  }

  if (enemy.specialCd > 0) return;

  final id = world.inGauntlet
      ? EnemyFlavor.gauntletBossDungeonId(world.combatFloor)
      : (world.keystoneWeekDungeonId.isNotEmpty
            ? world.keystoneWeekDungeonId
            : world.dungeonId);
  switch (id) {
    case 'brass':
    case 'sandy':
    case 'grove':
    case 'storm':
    case 'veil':
    case 'hell':
    case 'crystal':
    case 'tide':
    case 'ember':
    case 'fen':
    case 'underworld':
      _armBossTelegraph(world, enemy, reducedVfx: reducedVfx);
      return;
    case 'goblin':
      _bossRally(world, enemy, reducedVfx: reducedVfx);
      return;
    case 'king':
      var any = false;
      for (final h in world.heroes) {
        if (!h.isAlive) continue;
        h.attackSlowTimer = math.max(h.attackSlowTimer, 3.0);
        h.demoShoutTimer = math.max(h.demoShoutTimer, 2.4);
        any = true;
      }
      if (any) {
        enemy.specialCd = world.afkAssist ? 9.0 : 8.0;
        _bossTell(
          world,
          enemy,
          text: EnemyFlavor.bossTell(id),
          argb: 0xFFE0C060,
          radius: 1.6,
          reducedVfx: reducedVfx,
        );
      } else {
        enemy.specialCd = 1.2;
      }
      return;
    case 'dead':
      final healMul = world.afkAssist ? 0.4 : 1.0;
      final heal = math.max(
        12,
        (enemy.effectiveMaxHp * 0.08 * healMul).round(),
      );
      enemy.hp = math.min(enemy.effectiveMaxHp, enemy.hp + heal);
      enemy.specialCd = world.afkAssist ? 10.0 : 9.0;
      _bossTell(
        world,
        enemy,
        text: EnemyFlavor.bossTell(id),
        argb: 0xFFC0C0D8,
        radius: 1.2,
        reducedVfx: reducedVfx,
      );
      return;
    case 'rime':
      var any = false;
      for (final h in world.heroes) {
        if (!h.isAlive) continue;
        h.attackSlowTimer = math.max(h.attackSlowTimer, 2.8);
        _bossChipHero(
          world,
          enemy,
          h,
          atkMul: 0.28,
          rng: rng,
          reducedVfx: reducedVfx,
        );
        any = true;
      }
      if (any) {
        enemy.specialCd = world.afkAssist ? 9.0 : 8.0;
        _bossTell(
          world,
          enemy,
          text: EnemyFlavor.bossTell(id),
          argb: 0xFFA0E0FF,
          radius: 1.55,
          reducedVfx: reducedVfx,
        );
      } else {
        enemy.specialCd = 1.2;
      }
      return;
    default:
      _bossPulseLike(
        world,
        enemy,
        radius: 3.4,
        atkMul: 0.55,
        text: 'PULSE',
        argb: 0xFFFF5050,
        rng: rng,
        reducedVfx: reducedVfx,
      );
  }
}

void _armBossTelegraph(
  SpatialWorld world,
  SpatialActor enemy, {
  required bool reducedVfx,
}) {
  enemy.telegraphTimer = 1.4;
  enemy.telegraphSlam = true;
  _bossTell(
    world,
    enemy,
    text: 'WIND-UP',
    argb: 0xFFFFC060,
    radius: 1.2,
    reducedVfx: reducedVfx,
  );
}

void _resolveBossTelegraph(
  SpatialWorld world,
  SpatialActor enemy,
  SpatialActor focus, {
  required math.Random rng,
  required bool reducedVfx,
}) {
  final id = world.inGauntlet
      ? EnemyFlavor.gauntletBossDungeonId(world.combatFloor)
      : (world.keystoneWeekDungeonId.isNotEmpty
            ? world.keystoneWeekDungeonId
            : world.dungeonId);
  switch (id) {
    case 'sandy':
      _bossPulseLike(
        world,
        enemy,
        radius: 2.8,
        atkMul: 0.65,
        text: EnemyFlavor.bossTell(id),
        argb: 0xFFC8A070,
        rng: rng,
        reducedVfx: reducedVfx,
      );
      return;
    case 'grove':
      if (SpatialCombat._dist(enemy, focus) > 4.8) {
        enemy.specialCd = 1.2;
        return;
      }
      focus.rootTimer = math.max(focus.rootTimer, 2.0);
      enemy.specialCd = world.afkAssist ? 9.0 : 8.0;
      _bossTell(
        world,
        enemy,
        text: EnemyFlavor.bossTell(id),
        argb: 0xFF70C060,
        radius: 1.0,
        reducedVfx: reducedVfx,
        at: focus,
      );
      return;
    case 'storm':
      _bossChipHero(
        world,
        enemy,
        focus,
        atkMul: 0.5,
        rng: rng,
        reducedVfx: reducedVfx,
        isMelee: false,
      );
      SpatialActor? second;
      var best = 99.0;
      for (final h in world.heroes) {
        if (!h.isAlive || h.id == focus.id) continue;
        final d = SpatialCombat._dist(focus, h);
        if (d < best && d < 3.2) {
          best = d;
          second = h;
        }
      }
      if (second != null) {
        _bossChipHero(
          world,
          enemy,
          second,
          atkMul: 0.35,
          rng: rng,
          reducedVfx: reducedVfx,
          isMelee: false,
        );
      }
      enemy.specialCd = world.afkAssist ? 8.0 : 7.0;
      _bossTell(
        world,
        enemy,
        text: EnemyFlavor.bossTell(id),
        argb: 0xFF90D0FF,
        radius: 1.1,
        reducedVfx: reducedVfx,
        at: focus,
      );
      return;
    case 'veil':
      final hit = _bossChipInRadius(
        world,
        enemy,
        radius: 3.6,
        atkMul: 0.32,
        rng: rng,
        reducedVfx: reducedVfx,
      );
      if (hit) {
        for (final h in world.heroes) {
          if (!h.isAlive) continue;
          if (SpatialCombat._dist(enemy, h) > 3.6) continue;
          h.attackSlowTimer = math.max(h.attackSlowTimer, 2.8);
        }
        enemy.specialCd = world.afkAssist ? 9.0 : 8.0;
        _bossTell(
          world,
          enemy,
          text: EnemyFlavor.bossTell(id),
          argb: 0xFFE8D0FF,
          radius: 1.45,
          reducedVfx: reducedVfx,
        );
      } else {
        enemy.specialCd = 1.2;
      }
      return;
    case 'hell':
      final grabbed = _bossChipInRadius(
        world,
        enemy,
        radius: 2.2,
        atkMul: 0.5,
        rng: rng,
        reducedVfx: reducedVfx,
      );
      if (grabbed) {
        for (final h in world.heroes) {
          if (!h.isAlive) continue;
          if (SpatialCombat._dist(enemy, h) > 2.2) continue;
          h.rootTimer = math.max(h.rootTimer, 1.15);
        }
        enemy.specialCd = _bossCooldownSec(world, world.afkAssist ? 9.0 : 8.0);
        _bossTell(
          world,
          enemy,
          text: EnemyFlavor.bossTell(id),
          argb: 0xFFFF6030,
          radius: 1.15,
          reducedVfx: reducedVfx,
        );
      } else {
        enemy.specialCd = 1.2;
      }
      return;
    case 'crystal':
      final gScale = world.inGauntlet ? _gauntletBossScale(world) : 1.0;
      _bossPulseLike(
        world,
        enemy,
        radius: 5.5 * gScale,
        atkMul: 0.4 * math.min(gScale, 1.35),
        text: EnemyFlavor.bossTell(id),
        argb: 0xFF80D8FF,
        rng: rng,
        reducedVfx: reducedVfx,
        isMelee: false,
      );
      return;
    case 'tide':
      final wave = _bossChipInRadius(
        world,
        enemy,
        radius: 4.0,
        atkMul: 0.4,
        rng: rng,
        reducedVfx: reducedVfx,
      );
      if (wave) {
        for (final h in world.heroes) {
          if (!h.isAlive) continue;
          if (SpatialCombat._dist(enemy, h) > 4.0) continue;
          h.attackSlowTimer = math.max(h.attackSlowTimer, 2.6);
        }
        enemy.specialCd = world.afkAssist ? 9.0 : 8.0;
        _bossTell(
          world,
          enemy,
          text: EnemyFlavor.bossTell(id),
          argb: 0xFF40A0E0,
          radius: 1.7,
          reducedVfx: reducedVfx,
        );
      } else {
        enemy.specialCd = 1.2;
      }
      return;
    case 'ember':
      if (SpatialCombat._dist(enemy, focus) > 5.2) {
        enemy.specialCd = 1.2;
        return;
      }
      _bossChipHero(
        world,
        enemy,
        focus,
        atkMul: 0.4,
        rng: rng,
        reducedVfx: reducedVfx,
        isMelee: false,
      );
      focus.attackSlowTimer = math.max(focus.attackSlowTimer, 3.4);
      enemy.specialCd = world.afkAssist ? 8.0 : 7.0;
      _bossTell(
        world,
        enemy,
        text: EnemyFlavor.bossTell(id),
        argb: 0xFFFF7030,
        radius: 0.95,
        reducedVfx: reducedVfx,
        at: focus,
      );
      return;
    case 'fen':
      var spat = false;
      for (final h in world.heroes) {
        if (!h.isAlive) continue;
        if (SpatialCombat._dist(enemy, h) > 4.2) continue;
        _bossChipHero(
          world,
          enemy,
          h,
          atkMul: 0.28,
          rng: rng,
          reducedVfx: reducedVfx,
          isMelee: false,
        );
        h.attackSlowTimer = math.max(h.attackSlowTimer, 2.4);
        spat = true;
      }
      if (spat) {
        enemy.specialCd = world.afkAssist ? 8.0 : 7.0;
        _bossTell(
          world,
          enemy,
          text: EnemyFlavor.bossTell(id),
          argb: 0xFF80C040,
          radius: 1.35,
          reducedVfx: reducedVfx,
        );
      } else {
        enemy.specialCd = 1.2;
      }
      return;
    case 'underworld':
      if (SpatialCombat._dist(enemy, focus) > 6.2) {
        enemy.specialCd = 1.2;
        return;
      }
      _bossChipHero(
        world,
        enemy,
        focus,
        atkMul: 0.85,
        rng: rng,
        reducedVfx: reducedVfx,
        isMelee: false,
      );
      focus.demoShoutTimer = math.max(focus.demoShoutTimer, 2.8);
      enemy.specialCd = world.afkAssist ? 8.0 : 7.0;
      _bossTell(
        world,
        enemy,
        text: EnemyFlavor.bossTell(id),
        argb: 0xFF80FFA0,
        radius: 0.9,
        reducedVfx: reducedVfx,
        at: focus,
      );
      return;
    default:
      final slammed = _bossChipInRadius(
        world,
        enemy,
        radius: 2.8,
        atkMul: 0.8,
        rng: rng,
        reducedVfx: reducedVfx,
      );
      enemy.specialCd = _bossCooldownSec(world, world.afkAssist ? 9.0 : 8.0);
      if (slammed) {
        _bossTell(
          world,
          enemy,
          text: 'SLAM',
          argb: 0xFFFFB040,
          radius: 1.5,
          reducedVfx: reducedVfx,
        );
      }
  }
}

void _bossPulseLike(
  SpatialWorld world,
  SpatialActor enemy, {
  required double radius,
  required double atkMul,
  required String text,
  required int argb,
  required math.Random rng,
  required bool reducedVfx,
  bool isMelee = true,
}) {
  final hit = _bossChipInRadius(
    world,
    enemy,
    radius: radius,
    atkMul: atkMul,
    rng: rng,
    reducedVfx: reducedVfx,
    isMelee: isMelee,
  );
  if (hit) {
    enemy.specialCd = _bossCooldownSec(world, world.afkAssist ? 9.0 : 8.0);
    _bossTell(
      world,
      enemy,
      text: text,
      argb: argb,
      radius: math.max(1.2, radius * 0.45),
      reducedVfx: reducedVfx,
    );
  } else {
    enemy.specialCd = 1.2;
  }
}

/// Ashen Crown — telegraph slam + IGNITE chip (not generic ember boss only).
void _tickAshenBossKit(
  SpatialWorld world,
  SpatialActor enemy,
  SpatialActor focus, {
  required math.Random rng,
  required bool reducedVfx,
}) {
  if (enemy.telegraphTimer > 0) return;

  if (enemy.telegraphSlam) {
    enemy.telegraphSlam = false;
    _bossChipInRadius(
      world,
      enemy,
      radius: 3.2,
      atkMul: 0.78,
      rng: rng,
      reducedVfx: reducedVfx,
    );
    enemy.specialCd = _bossCooldownSec(world, world.afkAssist ? 6.5 : 5.5);
    _bossTell(
      world,
      enemy,
      text: 'SLAM',
      argb: 0xFFFFB040,
      radius: 1.6,
      reducedVfx: reducedVfx,
    );
    return;
  }

  if (enemy.specialCd > 0) return;

  final far = SpatialCombat._dist(enemy, focus) > 5.0;
  if (far || rng.nextDouble() < 0.42) {
    enemy.telegraphTimer = 1.5;
    enemy.telegraphSlam = true;
    _bossTell(
      world,
      enemy,
      text: AshenCrown.kitByDungeonId(world.dungeonId).telegraph,
      argb: 0xFFFF9040,
      radius: 1.35,
      reducedVfx: reducedVfx,
    );
    return;
  }

  _bossChipHero(
    world,
    enemy,
    focus,
    atkMul: 0.52,
    rng: rng,
    reducedVfx: reducedVfx,
    isMelee: false,
  );
  focus.attackSlowTimer = math.max(focus.attackSlowTimer, 3.5);
  enemy.specialCd = _bossCooldownSec(world, world.afkAssist ? 7.5 : 6.5);
  _bossTell(
    world,
    enemy,
    text: 'IGNITE',
    argb: 0xFFFF7030,
    radius: 1.0,
    reducedVfx: reducedVfx,
    at: focus,
  );
}

bool _bossChipInRadius(
  SpatialWorld world,
  SpatialActor enemy, {
  required double radius,
  required double atkMul,
  required math.Random rng,
  required bool reducedVfx,
  bool isMelee = true,
}) {
  var hit = false;
  for (final h in world.heroes) {
    if (!h.isAlive) continue;
    if (SpatialCombat._dist(enemy, h) > radius) continue;
    _bossChipHero(
      world,
      enemy,
      h,
      atkMul: atkMul,
      rng: rng,
      reducedVfx: reducedVfx,
      isMelee: isMelee,
    );
    hit = true;
  }
  return hit;
}

void _bossChipHero(
  SpatialWorld world,
  SpatialActor enemy,
  SpatialActor hero, {
  required double atkMul,
  required math.Random rng,
  required bool reducedVfx,
  bool isMelee = true,
}) {
  var chip = math.max(2, (enemy.effectiveAttack * atkMul).round());
  if (world.afkAssist) chip = math.max(1, (chip * 0.35).round());
  SpatialCombat._applyHeroIncomingDamage(
    world,
    hero,
    chip,
    reducedVfx: reducedVfx,
    rng: rng,
    isMelee: isMelee,
  );
}

void _bossRally(
  SpatialWorld world,
  SpatialActor enemy, {
  required bool reducedVfx,
}) {
  final healMul = world.afkAssist ? 0.4 : 1.0;
  final heal = math.max(8, (enemy.attack * 0.9 * healMul).round());
  var any = false;
  for (final ally in world.enemies) {
    if (!ally.isAlive || ally.dormant) continue;
    if (ally.id == enemy.id) continue;
    if (SpatialCombat._dist(enemy, ally) > 5.0) continue;
    ally.hp = math.min(ally.effectiveMaxHp, ally.hp + heal);
    any = true;
  }
  if (!any) {
    enemy.hp = math.min(enemy.effectiveMaxHp, enemy.hp + heal);
  }
  enemy.specialCd = world.afkAssist ? 8.0 : 7.0;
  _bossTell(
    world,
    enemy,
    text: EnemyFlavor.bossTell('goblin'),
    argb: 0xFFE0B040,
    radius: 1.3,
    reducedVfx: reducedVfx,
  );
}

void _bossTell(
  SpatialWorld world,
  SpatialActor enemy, {
  required String text,
  required int argb,
  required double radius,
  required bool reducedVfx,
  SpatialActor? at,
}) {
  final keepRing = world.spawnPersistentVfx || world.afkAssist;
  if (reducedVfx && !keepRing) {
    SpatialCombat._spawnFloater(
      world,
      x: (at ?? enemy).x,
      y: (at ?? enemy).y - 0.55,
      text: text,
      argb: argb,
      life: 0.85,
      priority: 2,
    );
    return;
  }
  if (!reducedVfx || keepRing) {
    if (!reducedVfx) {
      SpatialCombat._spawnBurst(
        world,
        x: enemy.x,
        y: enemy.y,
        argb: argb,
        radius: radius,
        kind: SpatialBurstKind.ring,
        life: 0.45,
      );
    }
    if (keepRing) {
      SpatialCombat._spawnRing(
        world,
        x: enemy.x,
        y: enemy.y,
        argb: argb,
        radius: radius + 0.15,
        life: world.afkAssist ? 0.4 : 0.55,
      );
    }
    SpatialCombat._spawnFloater(
      world,
      x: (at ?? enemy).x,
      y: (at ?? enemy).y - 0.55,
      text: text,
      argb: argb,
      life: 0.85,
      priority: 2,
    );
  }
}
