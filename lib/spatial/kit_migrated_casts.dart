part of 'spatial_combat.dart';

/// Context gates + cast resolves for the four kits formerly on dedicated tickers
/// (protection / discipline / fire / combat). Called from [AbilityEffectRunner].
abstract final class MigratedKitCasts {
  /// Hand-written gates ported from the retired per-role tickers.
  /// Returns null when the generic AbilityEffectRunner heuristics should decide.
  static bool? contextOk(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    ClassAbilityDef d, {
    required int nearby,
    required int pack,
    required bool focusElite,
    required double focusHpFrac,
    required double hpFrac,
  }) {
    switch (d.id) {
      // —— Combat Rogue ——
      case AbilityId.eviscerate:
        // Finisher rides the next white swing (_classAttackMods), never a cast.
        return false;
      case AbilityId.sliceAndDice:
        return hero.comboPoints >= 2 && hero.sliceAndDiceTimer < 2;
      case AbilityId.kidneyShot:
        return focus != null &&
            focus.hp > 0 &&
            hero.comboPoints >= 5 &&
            hero.sliceAndDiceTimer >= 2 &&
            focus.rootTimer < 0.5;
      case AbilityId.bladeFlurry:
        return nearby >= 2 || (nearby == 1 && focusElite);
      case AbilityId.sprint:
        if (focus == null) return false;
        final leader = _packLeader(world, hero);
        final nearPack =
            leader == null || SpatialCombat._dist(hero, leader) < 2.5;
        return nearPack &&
            SpatialCombat._dist(hero, focus) > hero.attackRange * 1.85;
      case AbilityId.killingSpree:
        return focus != null &&
            (focusElite || nearby >= 2 || focusHpFrac <= 0.35);
      case AbilityId.vanish:
        return hpFrac <= 0.3;

      // —— Fire Mage ——
      case AbilityId.fireball:
        if (focus == null || focus.hp <= 0) return false;
        if (SpatialCombat._dist(hero, focus) > hero.attackRange + 0.5) {
          return false;
        }
        // Hot Streak replaces the Fireball cast — it never stacks on top.
        return !(hero.hotStreakReady && _pyroblastReady(hero));
      case AbilityId.pyroblast:
        return hero.hotStreakReady &&
            focus != null &&
            focus.hp > 0 &&
            SpatialCombat._dist(hero, focus) <= hero.attackRange + 0.5;
      case AbilityId.livingBomb:
        return focus != null && focus.hp > 0 && focus.livingBombTimer < 2;
      case AbilityId.frostNova:
        final near = [
          for (final e in world.enemies)
            if (e.hp > 0 && !e.dormant && SpatialCombat._dist(hero, e) <= 2.4) e,
        ];
        final peel = near.any((e) => SpatialCombat._dist(hero, e) <= 1.6);
        return near.length >= 2 || peel;
      case AbilityId.combustion:
        // Fire's main burst — no "hold for elites" tax.
        return focus != null;
      case AbilityId.blink:
        return focus != null &&
            SpatialCombat._dist(hero, focus) <
                (hero.preferredRange ?? 3) * 0.55;
      case AbilityId.iceBlock:
        return hpFrac <= 0.28;

      // —— Disc Priest ——
      case AbilityId.prayerOfMending:
        return _pomTarget(world) != null;
      case AbilityId.powerWordFortitude:
        return world.heroes.any((h) => h.isAlive && h.fortitudeTimer < 2);
      case AbilityId.powerInfusion:
        return focus != null &&
            _partyStable(world) &&
            _powerInfusionTarget(world) != null;
      case AbilityId.painSuppression:
        return _painSuppressionTarget(world) != null;
      case AbilityId.penance:
        return _penanceHealTarget(world) != null ||
            (focus != null &&
                focus.hp > 0 &&
                SpatialCombat._dist(hero, focus) <= hero.attackRange + 1.5);

      // —— Prot Warrior ——
      case AbilityId.charge:
        if (focus == null || focus.hp <= 0 || focus.dormant) return false;
        final gap = SpatialCombat._dist(hero, focus);
        return gap > _chargeMinRange &&
            gap <= _chargeMaxRange &&
            SpatialCombat._hasClearCorridor(
              world.map,
              world.openGateIds,
              hero.x.floor(),
              hero.y.floor(),
              focus.x.floor(),
              focus.y.floor(),
            );
      case AbilityId.shieldBlock:
        return focus != null && SpatialCombat._dist(hero, focus) <= 3.2;
      case AbilityId.shieldSlam:
        return focus != null && !hero.queuedShieldSlam;
      case AbilityId.devastate:
        return focus != null &&
            focus.hp > 0 &&
            !focus.dormant &&
            SpatialCombat._dist(hero, focus) <= hero.attackRange + 0.35 &&
            (focus.sunderStacks < 5 || focus.sunderTimer < 4);
      case AbilityId.demoralizingShout:
        return world.enemies.any(
          (e) => e.hp > 0 && !e.dormant && SpatialCombat._dist(hero, e) <= 3.4,
        );
      case AbilityId.commandingShout:
        return focus != null && (hero.buffTimers['atkShout'] ?? 0) < 2;
      case AbilityId.lastStand:
        return hpFrac <= 0.4;
      case AbilityId.shieldWall:
        return hpFrac <= 0.28;
      default:
        return null;
    }
  }

  /// Charge is a short line-of-sight rush, never a map-wide teleport.
  static const double _chargeMinRange = 3.5;
  static const double _chargeMaxRange = 8.0;

  static bool _pyroblastReady(SpatialActor hero) {
    final pyro = ClassKits.defFor(AbilityId.pyroblast);
    if (pyro == null) return false;
    return ClassKits.isUnlocked(AbilityId.pyroblast, hero.heroLevel) &&
        SpatialCombat._abilityCdLeft(hero, AbilityId.pyroblast) <= 0 &&
        hero.rage + 0.001 >= pyro.resourceCost;
  }

  static SpatialActor? _packLeader(SpatialWorld world, SpatialActor self) {
    for (final h in world.heroes) {
      if (h.hp > 0 && _actorIsTank(h)) return h;
    }
    for (final h in world.heroes) {
      if (h.hp > 0 && h.id != self.id) return h;
    }
    return null;
  }

  /// Most injured ally without a Prayer of Mending already bouncing.
  static SpatialActor? _pomTarget(SpatialWorld world) {
    SpatialActor? target;
    var worst = 1.0;
    for (final h in world.heroes) {
      if (!h.isAlive || h.pomCharges > 0) continue;
      final frac = h.hp / math.max(1, h.effectiveMaxHp);
      if (frac < worst) {
        worst = frac;
        target = h;
      }
    }
    return worst < 0.95 ? target : null;
  }

  static bool _partyStable(SpatialWorld world) => !world.heroes.any(
        (h) =>
            h.isAlive && h.hp / math.max(1, h.effectiveMaxHp) < 0.55,
      );

  static SpatialActor? _powerInfusionTarget(SpatialWorld world) {
    SpatialActor? dps;
    var bestAtk = -1;
    for (final h in world.heroes) {
      if (!h.isAlive || _actorIsHealer(h)) continue;
      if (h.powerInfusionTimer > 1) continue;
      if (h.attack > bestAtk) {
        bestAtk = h.attack;
        dps = h;
      }
    }
    return dps;
  }

  static SpatialActor? _painSuppressionTarget(SpatialWorld world) {
    SpatialActor? target;
    var worst = 1.0;
    for (final h in world.heroes) {
      if (!h.isAlive || h.painSuppressionTimer > 0) continue;
      final frac = h.hp / math.max(1, h.effectiveMaxHp);
      if (frac < 0.32 && frac < worst) {
        worst = frac;
        target = h;
      }
    }
    return target;
  }

  static SpatialActor? _penanceHealTarget(SpatialWorld world) {
    SpatialActor? ally;
    var worst = 1.0;
    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      final frac = h.hp / math.max(1, h.effectiveMaxHp);
      if (frac < worst) {
        worst = frac;
        ally = h;
      }
    }
    return worst < 0.85 ? ally : null;
  }

  /// Casts ported from the retired per-role tickers, so the four original kits
  /// keep the exact feel they shipped with. Returns null when the generic
  /// [AbilityEffectRunner._resolveEffect] path already does the right thing.
  static bool? resolve(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    ClassAbilityDef def, {
    required math.Random rng,
    required bool reducedVfx,
  }) {
    switch (def.id) {
      // ——————————————— Prot Warrior ———————————————
      case AbilityId.charge:
        if (focus == null) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        final dx = focus.x - hero.x;
        final dy = focus.y - hero.y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (!reducedVfx) {
          SpatialCombat._spawnBurst(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xAAC0A070,
            radius: 0.55,
            life: 0.22,
          );
        }
        if (len > 0.1) {
          final stop = math.max(0.55, hero.attackRange * 0.85);
          final snapped = SpatialCombat._snapToWalkable(
            world.map,
            world.openGateIds,
            focus.x - (dx / len) * stop,
            focus.y - (dy / len) * stop,
          );
          hero.x = snapped.$1;
          hero.y = snapped.$2;
        }
        focus.rootTimer = math.max(focus.rootTimer, 0.85);
        SpatialCombat._gainRage(hero, 8);
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'CHARGE',
          argb: 0xFFE0C070,
          reducedVfx: reducedVfx,
          burstArgb: 0x88D0A050,
          burstRadius: 0.7,
        );
        return true;

      case AbilityId.shieldBlock:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, 2.5);
        // Sword and Board–lite: chance to reset Shield Slam.
        if (ClassKits.isUnlocked(AbilityId.shieldSlam, hero.heroLevel) &&
            rng.nextDouble() < 0.4) {
          hero.abilityCd.remove(AbilityId.shieldSlam.name);
          if (!reducedVfx) {
            SpatialCombat._spawnFloater(
              world,
              x: hero.x,
              y: hero.y - 0.7,
              text: 'SWORD & BOARD',
              argb: 0xFFFFE090,
              life: 0.7,
            );
          }
        }
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.5,
            text: 'SHIELD BLOCK',
            argb: 0xFF9AD0FF,
            life: 0.55,
          );
        }
        return true;

      case AbilityId.shieldSlam:
        // Lands as a rider on the next swing (see [_warriorAttackMods]).
        if (focus == null) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.queuedShieldSlam = true;
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'SHIELD SLAM',
          argb: 0xFFB0D0FF,
          reducedVfx: reducedVfx,
          burstArgb: 0x8890C0FF,
          burstRadius: 0.5,
        );
        return true;

      case AbilityId.devastate:
        if (focus == null || focus.hp <= 0) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        focus.sunderStacks = math.min(5, focus.sunderStacks + 1);
        focus.sunderTimer = 14;
        AbilityEffectRunner._castDamage(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        if (focus.hp > 0 &&
            ClassKits.isUnlocked(AbilityId.shieldSlam, hero.heroLevel) &&
            rng.nextDouble() < 0.18) {
          hero.abilityCd.remove(AbilityId.shieldSlam.name);
        }
        return true;

      case AbilityId.demoralizingShout:
        final shouted = _enemiesAround(world, hero, 3.4);
        if (shouted.isEmpty) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        for (final e in shouted) {
          e.demoShoutTimer = math.max(e.demoShoutTimer, 6.5);
        }
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.55,
            text: 'DEMO SHOUT',
            argb: 0xFFFF8866,
            life: 0.7,
          );
          SpatialCombat._spawnBurst(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xFFFF7040,
            radius: 1.5,
            life: 0.28,
          );
        }
        return true;

      case AbilityId.commandingShout:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        for (final h in world.heroes) {
          if (h.isAlive && !h.isPet) h.buffTimers['atkShout'] = 14;
        }
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.55,
            text: 'COMMANDING',
            argb: 0xFFFFD070,
            life: 0.75,
          );
          SpatialCombat._spawnRing(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0x88FFE080,
            radius: 1.6,
            life: 0.4,
          );
        }
        return true;

      case AbilityId.taunt:
        // Only burn the cooldown when something actually turns around.
        final pulled = SpatialCombat._tauntLooseEnemies(
          world,
          hero,
          reducedVfx: reducedVfx,
        );
        if (!pulled) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        AbilityEffectRunner._announce(
          world,
          hero,
          def.shortLabel,
          0xFFFFAA55,
          reducedVfx,
          important: true,
        );
        return true;

      case AbilityId.thunderClap:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        AbilityEffectRunner._castAoe(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        for (final e in _enemiesAround(world, hero, 2.7)) {
          e.attackSlowTimer = math.max(e.attackSlowTimer, 3.2);
        }
        SpatialCombat._gainRage(hero, 8);
        return true;

      case AbilityId.shockwave:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.shockwaveFlash = 0.6;
        final wave = _enemiesAround(world, hero, 2.7);
        if (!reducedVfx && wave.isNotEmpty) {
          final aim = wave.first;
          SpatialCombat._spawnCone(
            world,
            x: hero.x,
            y: hero.y,
            angle: math.atan2(aim.y - hero.y, aim.x - hero.x),
            argb: 0xFFFFA040,
            radius: 1.8,
            life: 0.42,
          );
        }
        AbilityEffectRunner._castAoe(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        for (final e in wave) {
          e.rootTimer = math.max(e.rootTimer, 2.2 + hero.kitRootBonus);
        }
        return true;

      case AbilityId.lastStand:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        final bonus = math.max(8, (hero.maxHp * 0.3).round());
        hero.bonusMaxHp = math.max(hero.bonusMaxHp, bonus);
        hero.lastStandTimer = 6.0;
        hero.hp = math.min(hero.effectiveMaxHp, hero.hp + bonus);
        AbilityEffectRunner._announce(
          world,
          hero,
          'LAST STAND',
          0xFFFF7070,
          reducedVfx,
          important: true,
        );
        return true;

      case AbilityId.shieldWall:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.shieldWallTimer = math.max(hero.shieldWallTimer, 5.0);
        hero.buffTimers['shield'] = 5.0;
        AbilityEffectRunner._announce(
          world,
          hero,
          'SHIELD WALL',
          0xFFB8D4FF,
          reducedVfx,
          important: true,
        );
        return true;

      // ——————————————— Disc Priest ———————————————
      case AbilityId.painSuppression:
        final target = _painSuppressionTarget(world);
        if (target == null) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        target.painSuppressionTimer = 5.5;
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: target.x,
            y: target.y - 0.5,
            text: 'PAIN SUPP',
            argb: 0xFFFF9090,
            life: 0.7,
          );
          SpatialCombat._spawnBurst(
            world,
            x: target.x,
            y: target.y,
            argb: 0xAAFF7070,
            radius: 0.75,
            life: 0.35,
          );
        }
        return true;

      case AbilityId.powerWordFortitude:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        for (final h in world.heroes) {
          if (!h.isAlive) continue;
          h.fortitudeTimer = 20;
          h.hp = math.min(h.effectiveMaxHp, h.hp + 4);
        }
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.5,
            text: 'FORTITUDE',
            argb: 0xFFFFE8A0,
            life: 0.65,
          );
          for (final h in world.heroes) {
            if (!h.isAlive) continue;
            SpatialCombat._spawnBurst(
              world,
              x: h.x,
              y: h.y,
              argb: 0xAAFFE8A0,
              radius: 0.65,
              life: 0.3,
            );
          }
        }
        return true;

      case AbilityId.powerWordShield:
        SpatialActor? bubble;
        var worstShield = 1.0;
        for (final h in world.heroes) {
          if (!h.isAlive || h.absorbShield > 4) continue;
          final frac = h.hp / math.max(1, h.effectiveMaxHp);
          if (frac < worstShield) {
            worstShield = frac;
            bubble = h;
          }
        }
        if (bubble == null || worstShield >= 0.92) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        final inner = hero.innerFireActive ? 1.25 : 1.0;
        final shield =
            math.max(10, (hero.attack * def.coeff * inner).round());
        bubble.absorbShield = math.max(bubble.absorbShield, shield);
        hero.attackFlash = 0.2;
        hero.attackAimX = bubble.x;
        hero.attackAimY = bubble.y;
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: bubble.x,
            y: bubble.y - 0.45,
            text: 'POWER WORD: SHIELD',
            argb: 0xFF90D0FF,
            life: 0.75,
          );
          SpatialCombat._spawnBurst(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xAA90C8FF,
            radius: 0.55,
            life: 0.25,
          );
          SpatialCombat._spawnBurst(
            world,
            x: bubble.x,
            y: bubble.y,
            argb: 0xCC70B8FF,
            radius: 1.05,
            life: 0.45,
          );
        }
        return true;

      case AbilityId.prayerOfMending:
        final mend = _pomTarget(world);
        if (mend == null) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        final pomInner = hero.innerFireActive ? 1.15 : 1.0;
        mend.pomCharges = 5;
        mend.pomHeal =
            math.max(5, (hero.attack * def.coeff * pomInner).round());
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: mend.x,
            y: mend.y - 0.4,
            text: 'PRAYER OF MENDING',
            argb: 0xFFFFE8A0,
            life: 0.65,
          );
          SpatialCombat._spawnSpark(
            world,
            x: mend.x,
            y: mend.y,
            argb: 0xFFFFF0A0,
            radius: 0.7,
            life: 0.4,
          );
          SpatialCombat._spawnRing(
            world,
            x: mend.x,
            y: mend.y,
            argb: 0x88FFE080,
            radius: 0.85,
            life: 0.35,
          );
        }
        return true;

      case AbilityId.powerInfusion:
        final dps = _powerInfusionTarget(world);
        if (dps == null || focus == null) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        dps.powerInfusionTimer = 8;
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: dps.x,
            y: dps.y - 0.5,
            text: 'POWER INFUSION',
            argb: 0xFFE0A0FF,
            life: 0.8,
          );
          SpatialCombat._spawnRing(
            world,
            x: dps.x,
            y: dps.y,
            argb: 0xAAC080FF,
            radius: 1.0,
            life: 0.45,
          );
          SpatialCombat._spawnSpark(
            world,
            x: dps.x,
            y: dps.y - 0.2,
            argb: 0xFFE8C0FF,
            radius: 0.55,
          );
        }
        return true;

      case AbilityId.penance:
        final mend = _penanceHealTarget(world);
        final burnable = focus != null &&
            focus.hp > 0 &&
            SpatialCombat._dist(hero, focus) <= hero.attackRange + 1.5;
        if (mend == null && !burnable) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.attackFlash = 0.2;
        if (mend != null) {
          final tick = math.max(
            5,
            (hero.attack * def.coeff * hero.kitHealMul).round(),
          );
          for (var i = 0; i < 3; i++) {
            final before = mend.hp;
            mend.hp = math.min(mend.effectiveMaxHp, mend.hp + tick);
            final gained = mend.hp - before;
            if (gained <= 0) continue;
            SpatialCombat._recordHeroHeal(hero, gained);
            if (!reducedVfx) {
              SpatialCombat._spawnFloater(
                world,
                x: mend.x,
                y: mend.y - 0.35 - i * 0.08,
                text: '+$gained',
                argb: SpatialCombat._floaterHeal,
                life: 0.55,
              );
            }
          }
          if (!reducedVfx) {
            SpatialCombat._spawnBurst(
              world,
              x: mend.x,
              y: mend.y,
              argb: 0xAAFFE080,
              radius: 0.8,
              life: 0.35,
            );
          }
        } else {
          final bolt = math.max(2, (hero.attack * 0.7).round());
          for (var i = 0; i < 3; i++) {
            SpatialCombat._addProjectile(
              world,
              SpatialCombat._spellBolt(
                from: hero,
                to: focus!,
                damage: bolt,
                style: SpellBoltStyle.holy,
                label: i == 0 ? 'PENANCE' : null,
                labelArgb: 0xFFFFF0A0,
                delay: i * 0.18,
              ),
            );
          }
          SpatialCombat._healLowestAlly(
            world,
            math.max(4, (bolt * 0.9 * hero.kitHealMul).round()),
            reducedVfx: reducedVfx,
            healer: hero,
          );
        }
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'PENANCE',
          argb: 0xFFFFF0A0,
          reducedVfx: reducedVfx,
          burstArgb: 0xAAFFE080,
          burstRadius: 0.55,
        );
        return true;

      // ——————————————— Fire Mage ———————————————
      case AbilityId.iceBlock:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.iceBlockTimer = math.max(hero.iceBlockTimer, 4.0);
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'ICE BLOCK',
          argb: 0xFFA0E8FF,
          reducedVfx: reducedVfx,
          burstArgb: 0xAA80D0FF,
          burstRadius: 0.9,
        );
        return true;

      case AbilityId.blink:
        if (focus == null) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        final awayX = hero.x - focus.x;
        final awayY = hero.y - focus.y;
        final away = math.sqrt(awayX * awayX + awayY * awayY);
        if (!reducedVfx) {
          SpatialCombat._spawnBurst(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xAAC080FF,
            radius: 0.55,
            life: 0.22,
          );
        }
        if (away > 0.1) {
          final snapped = SpatialCombat._snapToWalkable(
            world.map,
            world.openGateIds,
            hero.x + (awayX / away) * 2.2,
            hero.y + (awayY / away) * 2.2,
          );
          hero.x = snapped.$1;
          hero.y = snapped.$2;
        }
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'BLINK',
          argb: 0xFFC0A0FF,
          reducedVfx: reducedVfx,
          burstArgb: 0xAAC080FF,
          burstRadius: 0.55,
        );
        return true;

      case AbilityId.livingBomb:
        if (focus == null || focus.hp <= 0) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        focus.livingBombTimer = 8;
        focus.livingBombDps =
            math.max(3.0, hero.attack * 0.22 * AbilityEffectRunner._abilityOutScale(hero));
        focus.livingBombCasterId = hero.id;
        hero.livingBombArmed = 8;
        if (!reducedVfx) {
          SpatialCombat._spawnFloater(
            world,
            x: focus.x,
            y: focus.y - 0.4,
            text: 'LIVING BOMB',
            argb: 0xFFFF7030,
            life: 0.55,
          );
          SpatialCombat._spawnSpark(
            world,
            x: focus.x,
            y: focus.y,
            argb: 0xFFFF5020,
            radius: 0.65,
            life: 0.4,
          );
          SpatialCombat._spawnRing(
            world,
            x: focus.x,
            y: focus.y,
            argb: 0x88FF4010,
            radius: 0.7,
            life: 0.35,
          );
        }
        return true;

      case AbilityId.frostNova:
        final frozen = _enemiesAround(world, hero, 2.4);
        if (frozen.isEmpty) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        for (final e in frozen) {
          e.rootTimer = math.max(e.rootTimer, 2.4 + hero.kitRootBonus);
          e.attackSlowTimer = math.max(e.attackSlowTimer, 3);
        }
        hero.attackFlash = 0.14;
        SpatialCombat._spawnRing(
          world,
          x: hero.x,
          y: hero.y,
          argb: 0xFF60C0FF,
          radius: 1.6,
          life: 0.45,
        );
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'FROST NOVA',
          argb: 0xFF80D0FF,
          reducedVfx: reducedVfx,
          burstArgb: 0xFF60C0FF,
          burstRadius: 1.5,
        );
        return true;

      case AbilityId.blastWave:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        AbilityEffectRunner._castAoe(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        for (final e in _enemiesAround(world, hero, 2.7)) {
          e.attackSlowTimer = math.max(e.attackSlowTimer, 2.5);
        }
        return true;

      case AbilityId.fireball:
        if (focus == null || focus.hp <= 0) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.attackFlash = 0.18;
        var ball = math.max(
          2,
          (hero.attack * def.coeff * AbilityEffectRunner._abilityOutScale(hero)).round(),
        );
        if (hero.combustionTimer > 0) ball = (ball * 1.05).round();
        // Hot Streak: two Fireball crits unlock a free Pyroblast.
        final isCrit = GameLogic.random.nextInt(100) < 28;
        if (isCrit) {
          ball = (ball * 1.75).round();
          hero.hotStreakStack = math.min(2, hero.hotStreakStack + 1);
          if (hero.hotStreakStack >= 2) {
            hero.hotStreakReady = true;
            hero.hotStreakStack = 0;
          }
        } else {
          hero.hotStreakStack = 0;
        }
        SpatialCombat._addProjectile(
          world,
          SpatialCombat._spellBolt(
            from: hero,
            to: focus,
            damage: ball,
            style: SpellBoltStyle.fire,
            label: isCrit ? 'CRIT' : 'FIREBALL',
            labelArgb: 0xFFFF8040,
          ),
        );
        SpatialCombat._announceCast(
          world,
          hero,
          text: hero.hotStreakReady ? 'HOT STREAK!' : 'FIREBALL',
          argb: 0xFFFF8040,
          reducedVfx: reducedVfx,
          burstArgb: 0xFFFF9040,
          burstRadius: 0.55,
        );
        return true;

      case AbilityId.pyroblast:
        if (focus == null || focus.hp <= 0) return false;
        // Hot Streak makes it free; the cooldown still starts so it can't chain.
        SpatialCombat._startAbilityCd(world, hero, def.id, def.cooldown);
        hero.hotStreakReady = false;
        hero.hotStreakStack = 0;
        hero.attackFlash = 0.22;
        var pyro = math.max(
          3,
          (hero.attack * def.coeff * AbilityEffectRunner._abilityOutScale(hero)).round(),
        );
        if (hero.combustionTimer > 0) pyro = (pyro * 1.08).round();
        SpatialCombat._addProjectile(
          world,
          SpatialCombat._spellBolt(
            from: hero,
            to: focus,
            damage: pyro,
            style: SpellBoltStyle.fire,
            label: 'PYRO',
            labelArgb: 0xFFFF5020,
          ),
        );
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'HOT STREAK',
          argb: 0xFFFF5020,
          reducedVfx: reducedVfx,
          burstArgb: 0xFFFF6030,
          burstRadius: 0.75,
        );
        return true;

      // ——————————————— Combat Rogue ———————————————
      case AbilityId.vanish:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.vanishTimer = math.max(hero.vanishTimer, 3.5);
        for (final e in world.enemies) {
          if (e.forcedTargetId == hero.id) {
            e.forcedTargetId = null;
            e.forcedTargetTimer = 0;
          }
        }
        SpatialCombat._announceCast(
          world,
          hero,
          text: 'VANISH',
          argb: 0xFF909090,
          reducedVfx: reducedVfx,
          burstArgb: 0x88909090,
          burstRadius: 0.7,
        );
        return true;

      case AbilityId.killingSpree:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.killingSpreeTimer = 3.5;
        SpatialCombat._gainRage(hero, 35);
        final spree = _enemiesAround(world, hero, 4.5)
          ..sort(
            (a, b) => SpatialCombat._dist(hero, a)
                .compareTo(SpatialCombat._dist(hero, b)),
          );
        var prevX = hero.x;
        var prevY = hero.y;
        final hit = math.max(
          2,
          (hero.attack * def.coeff * AbilityEffectRunner._abilityOutScale(hero)).round(),
        );
        for (final e in spree.take(3)) {
          if (!reducedVfx) {
            SpatialCombat._spawnBurst(
              world,
              x: (prevX + e.x) * 0.5,
              y: (prevY + e.y) * 0.5,
              argb: 0x88FF6060,
              radius: 0.55,
              life: 0.22,
              kind: SpatialBurstKind.spark,
            );
          }
          final wasAlive = e.hp > 0;
          e.hp = math.max(0, e.hp - hit);
          SpatialCombat._recordHeroDamage(hero, hit);
          hero.x = e.x;
          hero.y = e.y;
          prevX = e.x;
          prevY = e.y;
          SpatialCombat._spawnSlash(world, from: hero, to: e, isCrit: true);
          SpatialCombat._spawnFloater(
            world,
            x: e.x,
            y: e.y - 0.3,
            text: '$hit',
            argb: 0xFFFF8060,
            life: 0.45,
          );
          if (wasAlive && e.hp <= 0) {
            final killed =
                SpatialCombat._onEnemyKilled(world, AbilityEffectRunner._stateOut!, e, rng);
            AbilityEffectRunner._goldOut += killed.gold;
            AbilityEffectRunner._stateOut = killed.state;
          }
        }
        if (!reducedVfx) {
          SpatialCombat._spawnRing(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xFFFF4040,
            radius: 1.1,
            life: 0.4,
          );
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.5,
            text: 'KILLING SPREE',
            argb: 0xFFFF6060,
            life: 0.75,
          );
        }
        return true;

      case AbilityId.sprint:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.sprintTimer = math.max(hero.sprintTimer, 4.0);
        if (!reducedVfx) {
          SpatialCombat._spawnSpark(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xFF90FF90,
            radius: 0.55,
          );
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.45,
            text: 'SPRINT',
            argb: 0xFF90FF90,
            life: 0.45,
          );
        }
        return true;

      case AbilityId.bladeFlurry:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.bladeFlurryTimer = math.max(hero.bladeFlurryTimer, 6.0);
        hero.buffTimers['buff'] = 6.0;
        if (!reducedVfx) {
          SpatialCombat._spawnRing(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xFFFFAA40,
            radius: 1.2,
            life: 0.4,
          );
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.5,
            text: 'FLURRY',
            argb: 0xFFFFAA40,
            life: 0.55,
          );
        }
        return true;

      case AbilityId.sliceAndDice:
        AbilityEffectRunner._spendAndCd(world, hero, def);
        hero.sliceAndDiceTimer = 6 + hero.comboPoints * 1.5;
        hero.comboPoints = 0;
        if (!reducedVfx) {
          SpatialCombat._spawnSpark(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xFFFFD070,
            radius: 0.5,
          );
          SpatialCombat._spawnFloater(
            world,
            x: hero.x,
            y: hero.y - 0.45,
            text: 'SnD',
            argb: 0xFFFFD070,
            life: 0.5,
          );
        }
        return true;

      case AbilityId.kidneyShot:
        if (focus == null || focus.hp <= 0) return false;
        AbilityEffectRunner._spendAndCd(world, hero, def);
        focus.rootTimer =
            2.0 + hero.comboPoints * 0.25 + hero.kitRootBonus;
        hero.comboPoints = 0;
        if (!reducedVfx) {
          SpatialCombat._spawnSpark(
            world,
            x: focus.x,
            y: focus.y,
            argb: 0xFFFFE080,
            radius: 0.6,
            life: 0.4,
          );
          SpatialCombat._spawnFloater(
            world,
            x: focus.x,
            y: focus.y - 0.4,
            text: 'KIDNEY',
            argb: 0xFFFF7070,
            life: 0.55,
          );
        }
        return true;

      default:
        return null;
    }
  }

  static List<SpatialActor> _enemiesAround(
    SpatialWorld world,
    SpatialActor self,
    double radius,
  ) =>
      [
        for (final e in world.enemies)
          if (e.hp > 0 && !e.dormant && SpatialCombat._dist(self, e) <= radius)
            e,
      ];
}
