part of 'spatial_combat.dart';

/// Dispatches class-kit casts for live spatial combat.
///
/// Original four specs (protection / discipline / fire / combat) keep their
/// dedicated tickers; every other [HeroSpecId] uses the shared data-driven path.
abstract final class AbilityEffectRunner {
  static GameState? _stateOut;
  static int _goldOut = 0;

  /// Last [GameState] produced by ability kills (warrior legacy / spec kits).
  static GameState takeState(GameState fallback) {
    final s = _stateOut ?? fallback;
    _stateOut = null;
    return s;
  }

  static int takeGold() {
    final g = _goldOut;
    _goldOut = 0;
    return g;
  }

  /// Returns ability cast count this tick (also increments
  /// [SpatialWorld.pendingAbilityCasts] via [_startAbilityCd]).
  static int tick(
    SpatialWorld world,
    SpatialActor hero,
    GameState state, {
    required double dt,
    required math.Random rng,
    required bool reducedVfx,
    required bool hasShield,
  }) {
    _stateOut = state;
    _goldOut = 0;
    if (!hero.isAlive) return 0;

    final before = world.pendingAbilityCasts;
    final specId = hero.heroSpecId;
    final focus = SpatialCombat._pickSmartFocus(hero, world);

    if (_useLegacyTicker(specId)) {
      _tickLegacy(
        world,
        hero,
        focus,
        dt: dt,
        rng: rng,
        reducedVfx: reducedVfx,
        hasShield: hasShield,
      );
    } else if (specId != null) {
      _tickSpecKit(
        world,
        hero,
        focus,
        specId,
        dt: dt,
        rng: rng,
        reducedVfx: reducedVfx,
      );
    } else {
      _tickLegacy(
        world,
        hero,
        focus,
        dt: dt,
        rng: rng,
        reducedVfx: reducedVfx,
        hasShield: hasShield,
      );
    }

    return world.pendingAbilityCasts - before;
  }

  static bool _useLegacyTicker(HeroSpecId? specId) {
    if (specId == null) return true;
    return ClassKits.isLegacySpec(specId);
  }

  static void _tickLegacy(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus, {
    required double dt,
    required math.Random rng,
    required bool reducedVfx,
    required bool hasShield,
  }) {
    final role = hero.heroRole;
    if (role == HeroRole.warrior) {
      final cast = SpatialCombat._tickWarriorAbilities(
        world,
        _stateOut!,
        hero,
        focus,
        dt,
        rng,
        reducedVfx: reducedVfx,
        hasShield: hasShield,
      );
      _stateOut = cast.state;
      _goldOut += cast.gold;
    } else if (role == HeroRole.healer) {
      SpatialCombat._tickPriestAbilities(
        world,
        hero,
        focus,
        dt,
        reducedVfx: reducedVfx,
      );
    } else if (role == HeroRole.mage) {
      SpatialCombat._tickMageAbilities(
        world,
        hero,
        focus,
        dt,
        reducedVfx: reducedVfx,
      );
    } else if (role == HeroRole.rogue) {
      SpatialCombat._tickRogueAbilities(
        world,
        hero,
        focus,
        dt,
        reducedVfx: reducedVfx,
      );
    }
  }

  static void _tickSpecKit(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    HeroSpecId specId, {
    required double dt,
    required math.Random rng,
    required bool reducedVfx,
  }) {
    final def = HeroSpecs.def(specId);
    // Passive resource while near combat.
    if (focus != null) {
      final rate = switch (def.resource) {
        // Kit-path regen (legacy tickers keep their own rates).
        // Rage/mana bumped so mid-kit spenders can fire between openers.
        SpecResource.rage => 8.0,
        SpecResource.mana => 9.0,
        SpecResource.energy => 11.0,
        SpecResource.runic => 9.0,
      };
      SpatialCombat._gainRage(hero, rate * dt);
    }
    if (def.resource == SpecResource.mana) {
      SpatialCombat._gainRage(
        hero,
        (hero.spiritRegenBonus + hero.mp5RegenBonus) * dt,
      );
    }

    final unlocked = ClassKits.unlockedAtSpec(specId, hero.heroLevel);
    // Sticky kit passives — always-on multipliers matching AbilityId flavor.
    hero.kitOutMul = 1.0;
    hero.kitInMul = 1.0;
    hero.kitHealMul = 1.0;
    hero.kitHasteMul = 1.0;
    hero.kitRootBonus = 0.0;
    for (final d in unlocked) {
      if (d.effect != AbilityEffectKind.passive) continue;
      _applyPassive(hero, d, def);
    }

    final castable = unlocked
        .where((d) => d.effect != AbilityEffectKind.passive)
        .toList(growable: false);
    if (castable.isEmpty) return;

    final hpFrac = hero.effectiveMaxHp <= 0
        ? 0.0
        : hero.hp / hero.effectiveMaxHp;
    final low = hpFrac <= 0.35;
    final allyLow = _lowestAlly(world, hero);
    final allyFrac = allyLow == null || allyLow.effectiveMaxHp <= 0
        ? 1.0
        : allyLow.hp / allyLow.effectiveMaxHp;

    bool can(ClassAbilityDef d) {
      if (!ClassKits.isUnlocked(d.id, hero.heroLevel)) return false;
      if (SpatialCombat._abilityCdLeft(hero, d.id) > 0) return false;
      if (hero.rage + 0.001 < d.resourceCost) return false;
      return true;
    }

    final nearby = SpatialCombat._countNearbyEnemies(hero, world);
    final focusHpFrac = focus == null || focus.maxHp <= 0
        ? 1.0
        : focus.hp / focus.maxHp;
    final focusElite = focus != null &&
        (focus.role == EnemyRole.boss || focus.role == EnemyRole.elite);

    bool contextOk(ClassAbilityDef d) {
      // AoE only when a pack is present (still allow on lone boss).
      if (d.effect == AbilityEffectKind.aoe) {
        if (nearby < 2 && !(nearby == 1 && focusElite)) return false;
      }
      // Execute-style finishers.
      if (_isExecuteAbility(d) && focusHpFrac > 0.25) return false;
      // Hold long CDs for elite/boss, packs, or execute windows.
      if (d.tier == AbilityCastTier.signature &&
          d.cooldown >= 30 &&
          !focusElite &&
          nearby < 3 &&
          focusHpFrac > 0.4) {
        return false;
      }
      return true;
    }

    bool tryCast(ClassAbilityDef d) {
      if (!can(d) || !contextOk(d)) return false;
      return _resolveEffect(
        world,
        hero,
        focus,
        d,
        rng: rng,
        reducedVfx: reducedVfx,
      );
    }

    // 1) Emergencies when self or ally is critically low.
    if (low || allyFrac <= 0.32) {
      for (final d in castable) {
        if (d.tier != AbilityCastTier.emergency) continue;
        if (d.effect == AbilityEffectKind.emergencyHeal ||
            d.effect == AbilityEffectKind.heal ||
            d.effect == AbilityEffectKind.absorb ||
            d.effect == AbilityEffectKind.emergencyDefend) {
          if (tryCast(d)) break;
        }
      }
    }

    // 1.5) Kit tanks: hard-taunt before signature/filler DPS.
    if (_actorIsTank(hero) && focus != null) {
      for (final d in castable) {
        if (d.effect != AbilityEffectKind.taunt) continue;
        if (tryCast(d)) break;
      }
    }

    // 2) Signature when fighting — prefer the priciest ready signature so
    // big spenders beat cheap utility buffs when both are up.
    if (focus != null) {
      final sigs = <ClassAbilityDef>[
        for (final d in castable)
          if (d.tier == AbilityCastTier.signature &&
              d.effect != AbilityEffectKind.taunt &&
              can(d) &&
              contextOk(d))
            d,
      ];
      sigs.sort((a, b) {
        final byCost = b.resourceCost.compareTo(a.resourceCost);
        if (byCost != 0) return byCost;
        return b.coeff.compareTo(a.coeff);
      });
      for (final d in sigs) {
        if (tryCast(d)) break;
      }
    }

    // 3) One filler — prefer highest-cost ready ability so cheap openers
    // don't starve the rest of the kit (Arms Overpower, Steady Shot, etc.).
    if (focus != null || def.isHealer) {
      final fillers = <ClassAbilityDef>[
        for (final d in castable)
          if (d.tier == AbilityCastTier.filler &&
              d.effect != AbilityEffectKind.taunt &&
              can(d) &&
              contextOk(d))
            d,
      ];
      fillers.sort((a, b) {
        // Prefer AoE in packs, ST otherwise.
        final aAoe = a.effect == AbilityEffectKind.aoe;
        final bAoe = b.effect == AbilityEffectKind.aoe;
        if (nearby >= 2 && aAoe != bAoe) return aAoe ? -1 : 1;
        if (nearby < 2 && aAoe != bAoe) return aAoe ? 1 : -1;
        final byCost = b.resourceCost.compareTo(a.resourceCost);
        if (byCost != 0) return byCost;
        final byCoeff = b.coeff.compareTo(a.coeff);
        if (byCoeff != 0) return byCoeff;
        return b.unlockLevel.compareTo(a.unlockLevel);
      });
      for (final d in fillers) {
        if (tryCast(d)) break;
      }
    }
  }

  static bool _isExecuteAbility(ClassAbilityDef d) {
    if (d.id == AbilityId.armsExecute || d.id == AbilityId.hammerOfWrath) {
      return true;
    }
    final key = _abilityKey(d);
    return key.contains('execute') ||
        key.contains('hammer of wrath') ||
        key.contains('kill shot');
  }

  /// Applies always-on kit passive bonuses from [ability.id].
  /// Magnitudes are mild so stacking with GameState auras stays sane.
  static void _applyPassive(
    SpatialActor hero,
    ClassAbilityDef ability,
    HeroSpecDef spec,
  ) {
    switch (ability.id) {
      // —— tanks ——
      case AbilityId.righteousFury:
        hero.kitInMul *= 0.82;
        hero.kitOutMul *= 0.97;
      case AbilityId.bloodPresence:
        hero.kitInMul *= 0.90;
        hero.kitHealMul *= 1.08;
      case AbilityId.bearForm:
        hero.kitInMul *= 0.88;
        hero.kitOutMul *= 0.95;

      // —— healer amplify ——
      case AbilityId.holyLightAura:
      case AbilityId.spiritOfRedemption:
      case AbilityId.ancestralAwakening:
        hero.kitHealMul *= 1.32;
      case AbilityId.treeOfLife:
        hero.kitHealMul *= 1.18;

      // —— melee DPS ——
      case AbilityId.armsStance:
        hero.kitOutMul *= 1.38;
        hero.kitInMul *= 1.04;
      case AbilityId.berserkerStance:
        hero.kitOutMul *= 1.18;
        hero.kitHasteMul *= 1.10;
        hero.kitInMul *= 1.06;
      case AbilityId.sealOfCommand:
        hero.kitOutMul *= 1.38;
      case AbilityId.improvedPoisons:
        hero.kitOutMul *= 1.40;
      case AbilityId.masterOfSubtlety:
        hero.kitOutMul *= 1.40;
      case AbilityId.frostPresence:
        hero.kitOutMul *= 1.35;
        hero.kitInMul *= 0.97;
      case AbilityId.unholyPresence:
        hero.kitOutMul *= 1.35;
        hero.kitHasteMul *= 1.12;
      case AbilityId.enhancementWeapons:
        hero.kitOutMul *= 1.38;
      case AbilityId.catForm:
        hero.kitOutMul *= 1.28;
        hero.kitHasteMul *= 1.10;

      // —— ranged ——
      case AbilityId.aspectOfHawk:
        hero.kitOutMul *= 1.18;
      case AbilityId.trueshotAura:
        hero.kitOutMul *= 1.14;
        hero.kitHasteMul *= 1.06;
      case AbilityId.trapMastery:
        hero.kitOutMul *= 1.30;
        hero.kitRootBonus += 1.0;

      // —— casters (mid-band ability spam outpaced melee ~2–3×) ——
      case AbilityId.shadowform:
        hero.kitOutMul *= 0.68;
        hero.kitInMul *= 1.04;
      case AbilityId.elementalFocus:
        hero.kitOutMul *= 0.68;
        hero.kitHasteMul *= 1.05;
      case AbilityId.arcanePowerPassive:
        hero.kitOutMul *= 0.68;
      case AbilityId.frostArmor:
        hero.kitInMul *= 0.92;
        hero.kitOutMul *= 0.65;
        hero.kitRootBonus += 0.5;
      case AbilityId.soulSiphon:
        hero.kitOutMul *= 0.70;
        hero.kitHealMul *= 1.06;
      case AbilityId.demonicKnowledge:
        hero.kitOutMul *= 0.65;
      case AbilityId.cataclysm:
        hero.kitOutMul *= 0.66;
      case AbilityId.moonkinForm:
        hero.kitOutMul *= 0.72;

      // Legacy kit passives are handled in dedicated tickers.
      case AbilityId.defensiveStance:
      case AbilityId.revenge:
      case AbilityId.innerFire:
      case AbilityId.arcaneIntellect:
      case AbilityId.sinisterStrike:
        break;
      default:
        // Fallback: mild role-appropriate crumb if a new passive is added.
        if (spec.isTank) {
          hero.kitInMul *= 0.94;
        } else if (spec.isHealer) {
          hero.kitHealMul *= 1.08;
        } else if (spec.roleTag == SpecRoleTag.caster) {
          hero.kitOutMul *= 1.06;
        } else {
          hero.kitOutMul *= 1.06;
        }
    }
  }

  static bool _resolveEffect(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    ClassAbilityDef def, {
    required math.Random rng,
    required bool reducedVfx,
  }) {
    switch (def.effect) {
      case AbilityEffectKind.passive:
        return false;
      case AbilityEffectKind.damage:
        if (focus == null || focus.hp <= 0) return false;
        _spendAndCd(world, hero, def);
        _castDamage(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.aoe:
        _spendAndCd(world, hero, def);
        _castAoe(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.heal:
        final ally = _lowestAlly(world, hero);
        if (ally == null) return false;
        // Skip overheal when nobody is meaningfully hurt (Disc-style triage).
        if (!_allyNeedsHeal(ally)) return false;
        _spendAndCd(world, hero, def);
        _castHeal(world, hero, ally, def, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.emergencyHeal:
        final ally = _lowestAlly(world, hero);
        if (ally == null) return false;
        _spendAndCd(world, hero, def);
        _castHeal(world, hero, ally, def, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.absorb:
        final ally = _lowestAlly(world, hero);
        if (ally == null) return false;
        if (!_allyNeedsAbsorb(ally)) return false;
        _spendAndCd(world, hero, def);
        _castAbsorb(world, hero, ally, def, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.selfBuff:
        _spendAndCd(world, hero, def);
        _selfBuff(hero, def);
        _announce(world, hero, def.shortLabel, 0xFF90E0FF, reducedVfx);
        if (!reducedVfx) {
          SpatialCombat._spawnRing(
            world,
            x: hero.x,
            y: hero.y,
            argb: SpatialCombat.burstArgbForStyle(
              SpatialCombat.boltStyleForAbility(hero, def: def),
            ),
            radius: 0.85,
            life: 0.35,
          );
        }
        return true;
      case AbilityEffectKind.root:
        if (focus == null || focus.hp <= 0) return false;
        _spendAndCd(world, hero, def);
        _castRoot(world, hero, focus, def, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.grantResource:
        _spendAndCd(world, hero, def);
        final grant = def.coeff > 0 ? def.coeff : 20.0;
        SpatialCombat._gainRage(hero, grant);
        _announce(world, hero, def.shortLabel, 0xFFE0C040, reducedVfx);
        return true;
      case AbilityEffectKind.emergencyDefend:
        _spendAndCd(world, hero, def);
        hero.shieldWallTimer = math.max(hero.shieldWallTimer, 3.5);
        // Prot Warrior Shield Block uses shieldBlockTimer for blockValue;
        // kit tanks (Holy Shield, Barkskin, …) share that window.
        if (_actorIsTank(hero)) {
          hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, 3.5);
          SpatialCombat._tauntLooseEnemies(
            world,
            hero,
            reducedVfx: reducedVfx,
          );
        }
        hero.buffTimers['shield'] = 3.5;
        if (hero.hp / math.max(1, hero.effectiveMaxHp) <= 0.4) {
          final bonus = math.max(6, (hero.maxHp * 0.2).round());
          hero.bonusMaxHp = math.max(hero.bonusMaxHp, bonus);
          hero.lastStandTimer = math.max(hero.lastStandTimer, 4.0);
          hero.hp = math.min(hero.effectiveMaxHp, hero.hp + bonus ~/ 2);
        }
        _announce(
          world,
          hero,
          def.shortLabel,
          0xFFB8D4FF,
          reducedVfx,
          important: true,
        );
        if (!reducedVfx) {
          SpatialCombat._spawnRing(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xFFB8D4FF,
            radius: 1.0,
            life: 0.4,
          );
        }
        return true;
      case AbilityEffectKind.taunt:
        _spendAndCd(world, hero, def);
        final pulled = SpatialCombat._tauntLooseEnemies(
          world,
          hero,
          reducedVfx: reducedVfx,
        );
        _announce(
          world,
          hero,
          def.shortLabel,
          0xFFFFAA55,
          reducedVfx,
          important: pulled,
        );
        return true;
    }
  }

  static String _abilityKey(ClassAbilityDef def) =>
      '${def.id.name} ${def.shortLabel} ${def.name}'.toLowerCase();

  /// Outgoing scale for kit casts. Casters get an extra tax because Int-based
  /// ability spam outpaced melee Str kits on mid-band sims (~2–3× raw DPS).
  static double _abilityOutScale(SpatialActor hero) {
    var scale = hero.kitOutMul;
    final id = hero.heroSpecId;
    if (id != null && HeroSpecs.def(id).roleTag == SpecRoleTag.caster) {
      scale *= 0.70;
    }
    return scale;
  }

  static void _castDamage(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor enemy,
    ClassAbilityDef def,
    math.Random rng, {
    required bool reducedVfx,
  }) {
    final raw = math.max(
      2,
      (hero.attack * def.coeff * _abilityOutScale(hero)).round(),
    );
    final style = SpatialCombat.boltStyleForAbility(hero, def: def);
    final useBolt = hero.ranged || SpatialCombat._dist(hero, enemy) > 2.2;
    final tint = SpatialCombat.burstArgbForStyle(style);

    hero.attackFlash = 0.16;
    SpatialCombat._setAttackAnim(hero, enemy, 0.22);
    _announce(world, hero, def.shortLabel, tint, reducedVfx);

    if (useBolt) {
      SpatialCombat._addProjectile(world, 
        SpatialCombat._spellBolt(
          from: hero,
          to: enemy,
          damage: raw,
          style: style,
          label: null,
          labelArgb: null,
        ),
      );
      return;
    }

    final dealt = math.max(1, raw - enemy.effectiveDefense);
    final wasAlive = enemy.hp > 0;
    enemy.hp = math.max(0, enemy.hp - dealt);
    SpatialCombat._recordHeroDamage(hero, dealt);
    SpatialCombat._applyTankSoftThreat(hero, enemy);
    SpatialCombat._spawnSlash(world, from: hero, to: enemy, isCrit: false);
    if (!reducedVfx) {
      SpatialCombat._spawnSpark(
        world,
        x: enemy.x,
        y: enemy.y,
        argb: tint,
        radius: 0.45,
      );
    }
    SpatialCombat._spawnFloater(
      world,
      x: enemy.x,
      y: enemy.y - 0.4,
      text: '$dealt',
      argb: SpatialCombat._floaterDamage,
      life: 0.45,
      priority: 0,
    );
    if (wasAlive && enemy.hp <= 0) {
      final killed =
          SpatialCombat._onEnemyKilled(world, _stateOut!, enemy, rng);
      _goldOut += killed.gold;
      _stateOut = killed.state;
    }
  }

  static void _castAoe(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    ClassAbilityDef def,
    math.Random rng, {
    required bool reducedVfx,
  }) {
    final key = _abilityKey(def);
    final style = SpatialCombat.boltStyleForAbility(hero, def: def);
    _announce(
      world,
      hero,
      def.shortLabel,
      SpatialCombat.burstArgbForStyle(style),
      reducedVfx,
    );

    if (key.contains('chain') || def.id == AbilityId.chainLightning) {
      _chainLightning(world, hero, focus, def, rng, reducedVfx: reducedVfx);
      return;
    }
    if (key.contains('multi') ||
        key.contains('volley') ||
        key.contains('barrage') ||
        def.id == AbilityId.multiShot ||
        (style == SpellBoltStyle.arrow &&
            (key.contains('shot') || key.contains('arrow')))) {
      _fanBolts(
        world,
        hero,
        def,
        style,
        rng,
        hops: 4,
        reducedVfx: reducedVfx,
      );
      return;
    }
    // Rain / storm / howling — delayed bolts onto enemies in radius.
    if (def.id == AbilityId.hurricane ||
        def.id == AbilityId.starfall ||
        def.id == AbilityId.thunderstorm ||
        def.id == AbilityId.howlingBlast ||
        key.contains('hurricane') ||
        key.contains('starfall') ||
        key.contains('thunderstorm')) {
      _rainBolts(world, hero, def, style, rng, reducedVfx: reducedVfx);
      return;
    }
    // Ground zones — heavier rings + on-target sparks (no projectile spam).
    if (def.id == AbilityId.consecration ||
        def.id == AbilityId.bloodBoil ||
        def.id == AbilityId.bloodBoilUnholy ||
        def.id == AbilityId.bladestorm ||
        def.id == AbilityId.whirlwind ||
        def.id == AbilityId.divineStorm ||
        def.id == AbilityId.thunderClap ||
        def.id == AbilityId.shockwave ||
        key.contains('consecrat') ||
        key.contains('bloodboil') ||
        key.contains('bladestorm') ||
        key.contains('whirlwind')) {
      _groundNova(world, hero, def, style, rng, reducedVfx: reducedVfx);
      return;
    }

    _novaStrike(world, hero, def, style, rng, reducedVfx: reducedVfx);
  }

  /// Chain Lightning — bolts hop focus → nearest → nearest…
  static void _chainLightning(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    ClassAbilityDef def,
    math.Random rng, {
    required bool reducedVfx,
  }) {
    const style = SpellBoltStyle.lightning;
    final base =
        math.max(2, (hero.attack * def.coeff * _abilityOutScale(hero)).round());
    final targets = <SpatialActor>[];
    SpatialActor? cursor = focus != null && focus.hp > 0 && !focus.dormant
        ? focus
        : SpatialCombat._nearestActiveEnemy(hero, world.enemies);
    final used = <String>{};
    while (cursor != null && targets.length < 4) {
      targets.add(cursor);
      used.add(cursor.id);
      SpatialActor? next;
      var best = 3.6;
      for (final e in world.enemies) {
        if (e.hp <= 0 || e.dormant || used.contains(e.id)) continue;
        final d = SpatialCombat._dist(cursor, e);
        if (d < best) {
          best = d;
          next = e;
        }
      }
      cursor = next;
    }
    if (targets.isEmpty) {
      _novaStrike(world, hero, def, style, rng, reducedVfx: reducedVfx);
      return;
    }

    hero.attackFlash = 0.2;
    double delay = 0;
    double px = hero.x;
    double py = hero.y;
    for (var i = 0; i < targets.length; i++) {
      final t = targets[i];
      final dmg = math.max(1, (base * (1.0 - i * 0.18)).round());
      final dx = t.x - px;
      final dy = t.y - py;
      final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, 999.0);
      // Nudge off the previous target so hops don't instantly re-hit it.
      final ox = i == 0 ? 0.0 : dx / len * 0.4;
      final oy = i == 0 ? 0.0 : dy / len * 0.4;
      SpatialCombat._addProjectile(world, 
        SpatialCombat.spellBoltBetween(
          x0: px + ox,
          y0: py + oy,
          x1: t.x,
          y1: t.y,
          damage: dmg,
          style: style,
          team: SpatialTeam.hero,
          casterId: hero.id,
          label: null,
          labelArgb: null,
          delay: delay,
        ),
      );
      if (!reducedVfx) {
        SpatialCombat._spawnSpark(
          world,
          x: t.x,
          y: t.y,
          argb: SpatialCombat.burstArgbForStyle(style),
          radius: 0.55 - i * 0.06,
          life: 0.35 + delay * 0.15,
        );
      }
      px = t.x;
      py = t.y;
      delay += 0.12;
    }
  }

  static void _fanBolts(
    SpatialWorld world,
    SpatialActor hero,
    ClassAbilityDef def,
    SpellBoltStyle style,
    math.Random rng, {
    required int hops,
    required bool reducedVfx,
  }) {
    final raw =
        math.max(2, (hero.attack * def.coeff * _abilityOutScale(hero)).round());
    final enemies = world.enemies
        .where((e) => e.hp > 0 && !e.dormant)
        .toList()
      ..sort(
        (a, b) => SpatialCombat._dist(hero, a)
            .compareTo(SpatialCombat._dist(hero, b)),
      );
    final picks = enemies.take(hops).toList();
    if (picks.isEmpty) return;
    hero.attackFlash = 0.18;
    for (var i = 0; i < picks.length; i++) {
      SpatialCombat._addProjectile(world, 
        SpatialCombat._spellBolt(
          from: hero,
          to: picks[i],
          damage: raw,
          style: style,
          label: null,
          labelArgb: null,
          delay: i * 0.04,
        ),
      );
    }
  }

  static void _novaStrike(
    SpatialWorld world,
    SpatialActor hero,
    ClassAbilityDef def,
    SpellBoltStyle style,
    math.Random rng, {
    required bool reducedVfx,
  }) {
    final radius = style == SpellBoltStyle.lightning ? 3.0 : 2.6;
    final raw =
        math.max(2, (hero.attack * def.coeff * _abilityOutScale(hero)).round());
    final argb = SpatialCombat.burstArgbForStyle(style);
    hero.attackFlash = 0.18;

    if (!reducedVfx) {
      SpatialCombat._spawnRing(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: radius * 0.55,
        life: 0.4,
      );
      SpatialCombat._spawnBurst(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: radius * 0.35,
        life: 0.28,
      );
    }

    var i = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat._dist(hero, e) > radius) continue;

      final fly = hero.ranged ||
          style == SpellBoltStyle.lightning ||
          style == SpellBoltStyle.frost ||
          style == SpellBoltStyle.fire ||
          style == SpellBoltStyle.shadow ||
          style == SpellBoltStyle.arcane ||
          style == SpellBoltStyle.nature;
      if (fly) {
        SpatialCombat._addProjectile(world, 
          SpatialCombat._spellBolt(
            from: hero,
            to: e,
            damage: raw,
            style: style,
            label: null,
          labelArgb: null,
            delay: i * 0.05,
          ),
        );
      } else {
        final wasAlive = e.hp > 0;
        final dealt = math.max(1, raw - e.effectiveDefense);
        e.hp = math.max(0, e.hp - dealt);
        SpatialCombat._recordHeroDamage(hero, dealt);
        SpatialCombat._applyTankSoftThreat(hero, e);
        if (!reducedVfx) {
          SpatialCombat._spawnSpark(
            world,
            x: e.x,
            y: e.y,
            argb: argb,
            radius: 0.5,
          );
          SpatialCombat._spawnFloater(
            world,
            x: e.x,
            y: e.y - 0.35,
            text: '$dealt',
            argb: SpatialCombat._floaterDamage,
            life: 0.45,
          );
        }
        if (wasAlive && e.hp <= 0) {
          final killed =
              SpatialCombat._onEnemyKilled(world, _stateOut!, e, rng);
          _goldOut += killed.gold;
          _stateOut = killed.state;
        }
      }
      i++;
    }
  }

  /// Hurricane / Starfall / Thunderstorm / Howling Blast — bolts rain onto foes.
  static void _rainBolts(
    SpatialWorld world,
    SpatialActor hero,
    ClassAbilityDef def,
    SpellBoltStyle style,
    math.Random rng, {
    required bool reducedVfx,
  }) {
    final radius = style == SpellBoltStyle.lightning ? 3.2 : 2.9;
    final raw =
        math.max(2, (hero.attack * def.coeff * _abilityOutScale(hero)).round());
    final argb = SpatialCombat.burstArgbForStyle(style);
    hero.attackFlash = 0.2;

    if (!reducedVfx) {
      SpatialCombat._spawnRing(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: radius * 0.45,
        life: 0.5,
      );
    }

    var i = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat._dist(hero, e) > radius) continue;
      if (i >= 4) break;
      SpatialCombat._addProjectile(world, 
        SpatialCombat.spellBoltBetween(
          x0: e.x + (rng.nextDouble() - 0.5) * 0.6,
          y0: e.y - 1.35 - rng.nextDouble() * 0.35,
          x1: e.x,
          y1: e.y,
          damage: raw,
          style: style,
          team: SpatialTeam.hero,
          casterId: hero.id,
          label: null,
          labelArgb: null,
          delay: i * 0.06,
        ),
      );
      if (!reducedVfx) {
        SpatialCombat._spawnSpark(
          world,
          x: e.x,
          y: e.y,
          argb: argb,
          radius: 0.45,
          life: 0.35 + i * 0.04,
        );
      }
      i++;
    }
  }

  /// Consecration / WW / Bladestorm / Blood Boil — ground pulse, no bolt spam.
  static void _groundNova(
    SpatialWorld world,
    SpatialActor hero,
    ClassAbilityDef def,
    SpellBoltStyle style,
    math.Random rng, {
    required bool reducedVfx,
  }) {
    final radius = style == SpellBoltStyle.lightning ? 3.0 : 2.7;
    final raw =
        math.max(2, (hero.attack * def.coeff * _abilityOutScale(hero)).round());
    final argb = SpatialCombat.burstArgbForStyle(style);
    hero.attackFlash = 0.2;

    if (!reducedVfx) {
      SpatialCombat._spawnRing(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: radius * 0.4,
        life: 0.55,
      );
      SpatialCombat._spawnRing(
        world,
        x: hero.x,
        y: hero.y,
        argb: (argb & 0x00FFFFFF) | 0x66000000,
        radius: radius * 0.7,
        life: 0.4,
      );
      SpatialCombat._spawnBurst(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: radius * 0.35,
        life: 0.3,
      );
    }

    var hitCount = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat._dist(hero, e) > radius) continue;
      final wasAlive = e.hp > 0;
      final dealt = math.max(1, raw - e.effectiveDefense);
      e.hp = math.max(0, e.hp - dealt);
      SpatialCombat._recordHeroDamage(hero, dealt);
      SpatialCombat._applyTankSoftThreat(hero, e);
      hitCount++;
      if (!reducedVfx) {
        SpatialCombat._spawnSpark(
          world,
          x: e.x,
          y: e.y,
          argb: argb,
          radius: 0.55,
        );
        // Cap per-target numbers on big ground AOEs.
        if (hitCount <= 3) {
          SpatialCombat._spawnFloater(
            world,
            x: e.x,
            y: e.y - 0.35,
            text: '$dealt',
            argb: SpatialCombat._floaterDamage,
            life: 0.4,
            priority: 0,
          );
        }
      }
      if (wasAlive && e.hp <= 0) {
        final killed =
            SpatialCombat._onEnemyKilled(world, _stateOut!, e, rng);
        _goldOut += killed.gold;
        _stateOut = killed.state;
      }
    }
  }

  static void _castRoot(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor focus,
    ClassAbilityDef def, {
    required bool reducedVfx,
  }) {
    final style = SpatialCombat.boltStyleForAbility(hero, def: def);
    focus.rootTimer = math.max(focus.rootTimer, 2.2 + hero.kitRootBonus);
    hero.attackFlash = 0.14;
    _announce(world, hero, def.shortLabel, 0xFF80D0FF, reducedVfx);

    if (hero.ranged || SpatialCombat._dist(hero, focus) > 2.0) {
      SpatialCombat._addProjectile(world, 
        SpatialCombat._spellBolt(
          from: hero,
          to: focus,
          damage: math.max(1, (hero.attack * 0.35).round()),
          style: style,
          label: null,
          labelArgb: null,
        ),
      );
    }
    if (!reducedVfx) {
      SpatialCombat._spawnRing(
        world,
        x: focus.x,
        y: focus.y,
        argb: 0xAA80D0FF,
        radius: 0.7,
        life: 0.45,
      );
    }
  }

  static void _castHeal(
    SpatialWorld world,
    SpatialActor caster,
    SpatialActor ally,
    ClassAbilityDef def, {
    required bool reducedVfx,
  }) {
    _healLowest(world, caster, ally, def.coeff, def.shortLabel);
    _announce(
      world,
      caster,
      def.shortLabel,
      SpatialCombat._floaterHeal,
      reducedVfx,
    );
    if (!reducedVfx) {
      SpatialCombat._spawnSpark(
        world,
        x: ally.x,
        y: ally.y,
        argb: SpatialCombat._floaterHeal,
        radius: 0.55,
      );
      SpatialCombat._spawnRing(
        world,
        x: ally.x,
        y: ally.y,
        argb: 0x887AAB6E,
        radius: 0.65,
        life: 0.35,
      );
    }
  }

  static void _castAbsorb(
    SpatialWorld world,
    SpatialActor caster,
    SpatialActor ally,
    ClassAbilityDef def, {
    required bool reducedVfx,
  }) {
    _absorbLowest(world, caster, ally, def.coeff, def.shortLabel);
    _announce(world, caster, def.shortLabel, 0xFF90C0FF, reducedVfx);
    if (!reducedVfx) {
      SpatialCombat._spawnRing(
        world,
        x: ally.x,
        y: ally.y,
        argb: 0xAA90C0FF,
        radius: 0.75,
        life: 0.4,
      );
    }
  }

  static void _spendAndCd(
    SpatialWorld world,
    SpatialActor hero,
    ClassAbilityDef def,
  ) {
    SpatialCombat._spendRage(hero, def.resourceCost);
    SpatialCombat._startAbilityCd(world, hero, def.id, def.cooldown);
  }

  static void _announce(
    SpatialWorld world,
    SpatialActor hero,
    String text,
    int argb,
    bool reducedVfx, {
    bool important = false,
  }) {
    // Routine ability-name shoutouts drown the stage; keep bursts/sparks instead.
    if (reducedVfx || !important) return;
    SpatialCombat._spawnFloater(
      world,
      x: hero.x,
      y: hero.y - 0.5,
      text: text.toUpperCase(),
      argb: argb,
      life: 0.5,
      priority: 1,
    );
  }

  static SpatialActor? _lowestAlly(SpatialWorld world, SpatialActor self) {
    SpatialActor? best;
    var bestFrac = 2.0;
    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      final frac =
          h.effectiveMaxHp <= 0 ? 1.0 : h.hp / h.effectiveMaxHp;
      if (frac < bestFrac) {
        bestFrac = frac;
        best = h;
      }
    }
    return best ?? (self.isAlive ? self : null);
  }

  /// Kit heal filler/signature — only spend mana when someone is hurt.
  static bool _allyNeedsHeal(SpatialActor ally) {
    if (ally.effectiveMaxHp <= 0) return false;
    return ally.hp / ally.effectiveMaxHp < 0.92;
  }

  /// Kit absorb — cast when hurt or when the bubble is gone.
  static bool _allyNeedsAbsorb(SpatialActor ally) {
    if (ally.absorbShield <= 4) {
      if (ally.effectiveMaxHp <= 0) return true;
      return ally.hp / ally.effectiveMaxHp < 0.98;
    }
    if (ally.effectiveMaxHp <= 0) return false;
    return ally.hp / ally.effectiveMaxHp < 0.85;
  }

  static void _healLowest(
    SpatialWorld world,
    SpatialActor caster,
    SpatialActor ally,
    double coeff,
    String label,
  ) {
    final amount =
        math.max(4, (caster.attack * coeff * caster.kitHealMul).round());
    final before = ally.hp;
    ally.hp = math.min(ally.effectiveMaxHp, ally.hp + amount);
    final gained = ally.hp - before;
    if (gained > 0) {
      caster.healingDone += gained;
      SpatialCombat._spawnFloater(
        world,
        x: ally.x,
        y: ally.y - 0.4,
        text: '+$gained',
        argb: SpatialCombat._floaterHeal,
        life: 0.55,
      );
    }
  }

  static void _absorbLowest(
    SpatialWorld world,
    SpatialActor caster,
    SpatialActor ally,
    double coeff,
    String label,
  ) {
    final amount =
        math.max(6, (caster.attack * coeff * 1.1 * caster.kitHealMul).round());
    ally.absorbShield += amount;
    SpatialCombat._spawnFloater(
      world,
      x: ally.x,
      y: ally.y - 0.45,
      text: label.toUpperCase(),
      argb: 0xFF90C0FF,
      life: 0.55,
    );
  }

  static void _selfBuff(SpatialActor hero, ClassAbilityDef def) {
    // Prefer existing haste / shield timers when possible.
    final name = def.id.name.toLowerCase();
    if (name.contains('haste') ||
        name.contains('rapid') ||
        name.contains('zeal') ||
        name.contains('enrage') ||
        name.contains('berserk') ||
        name.contains('wrath') ||
        name.contains('power') ||
        name.contains('veins') ||
        name.contains('dance') ||
        name.contains('wish') ||
        name.contains('meta') ||
        name.contains('pillar') ||
        name.contains('trueshot') ||
        name.contains('beast') ||
        name.contains('backdraft') ||
        name.contains('presence') ||
        name.contains('mastery') ||
        name.contains('favor') ||
        name.contains('beacon') ||
        name.contains('spirit') ||
        name.contains('gargoyle') ||
        name.contains('water') ||
        name.contains('charge') ||
        name.contains('step') ||
        name.contains('sprint') ||
        name.contains('disengage')) {
      hero.powerInfusionTimer = math.max(hero.powerInfusionTimer, 6.0);
      hero.buffTimers['haste'] = 6.0;
      return;
    }
    if (name.contains('shield') ||
        name.contains('bark') ||
        name.contains('deter') ||
        name.contains('ward') ||
        name.contains('fort')) {
      hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, 3.0);
      hero.buffTimers['shield'] = 3.0;
      return;
    }
    hero.buffTimers['buff'] = 5.0;
    hero.combustionTimer = math.max(hero.combustionTimer, 5.0);
  }
}
