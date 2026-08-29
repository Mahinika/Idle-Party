part of 'spatial_combat.dart';

/// Dispatches class-kit casts for live spatial combat.
///
/// Every [HeroSpecId] runs the shared data-driven path: kit passives feed the
/// sticky `kit*Mul` fields, [contextOk] decides when a row may fire, and
/// [_resolveEffect] applies it. White-hit riders (Revenge / Shield Slam /
/// Eviscerate / Living Bomb ticks / Prayer of Mending bounce) still live in
/// [SpatialCombat] because they hang off swings, not casts.
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

  static int _abilityPower(SpatialActor hero, ClassAbilityDef def) {
    if (ClassAbilityDef.inferUsesSpellPower(def)) {
      return hero.spellPower > 0 ? hero.spellPower : hero.attack;
    }
    return hero.physicalAttack > 0 ? hero.physicalAttack : hero.attack;
  }

  static int _healPower(SpatialActor hero) {
    return hero.spellPower >= hero.physicalAttack
        ? (hero.spellPower > 0 ? hero.spellPower : hero.attack)
        : (hero.physicalAttack > 0 ? hero.physicalAttack : hero.attack);
  }

  static double _castDelaySeconds(SpatialActor hero, ClassAbilityDef def) {
    if (def.castDelaySeconds <= 0) return 0;
    final haste = math.max(
      0.45,
      hero.kitHasteMul * hero.attackSpeedMul,
    );
    return def.castDelaySeconds / haste;
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
    final role = hero.heroRole;
    // Saves from before specs existed only carry a role — read the kit off it.
    final specId =
        hero.heroSpecId ??
        (role == null ? null : HeroSpecs.fromGearAffinity(role));
    final focus = SpatialCombat._pickSmartFocus(hero, world);

    if (specId != null) {
      _tickSpecKit(
        world,
        hero,
        focus,
        specId,
        dt: dt,
        rng: rng,
        reducedVfx: reducedVfx,
        hasShield: hasShield,
      );
    }

    return world.pendingAbilityCasts - before;
  }

  static void _tickSpecKit(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor? focus,
    HeroSpecId specId, {
    required double dt,
    required math.Random rng,
    required bool reducedVfx,
    required bool hasShield,
  }) {
    final def = HeroSpecs.def(specId);
    // Passive resource while near combat. Healers also tick without a
    // target so the first heal is not gated on picking a focus.
    if (focus != null || def.isHealer) {
      final rate = _resourceRate(specId, def.resource);
      SpatialCombat._gainRage(hero, rate * dt);
      // Combat Rogue floods energy during Killing Spree.
      if (specId == HeroSpecId.combat && hero.killingSpreeTimer > 0) {
        SpatialCombat._gainRage(hero, 6 * dt);
      }
    }
    if (def.resource == SpecResource.mana) {
      var spiritMul = 1.0;
      if (hero.spiritRegenPaused > 0) {
        spiritMul = 0.15;
      } else if (focus != null) {
        spiritMul = 0.55;
      }
      SpatialCombat._gainRage(
        hero,
        (hero.spiritRegenBonus * spiritMul + hero.mp5RegenBonus) * dt,
      );
    }

    final unlocked = ClassKits.unlockedAtSpec(specId, hero.heroLevel);
    // Sticky kit passives — always-on multipliers matching AbilityId flavor.
    hero.kitOutMul = 1.0;
    hero.kitInMul = 1.0;
    hero.kitHealMul = 1.0;
    hero.kitHasteMul = 1.0;
    hero.kitRootBonus = 0.0;
    hero.innerFireActive = false;
    for (final d in unlocked) {
      if (d.effect != AbilityEffectKind.passive) continue;
      _applyPassive(hero, d, def);
    }
    if ((hero.buffTimers['favor'] ?? 0) > 0) {
      hero.kitHealMul *= 1.35;
    }

    final castable = unlocked
        .where((d) => d.runnerMayCast)
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
      if (d.requiresShield && !hasShield) return false;
      if (hero.castingTimer > 0) return false;
      if (SpatialCombat._abilityCdLeft(hero, d.id) > 0) return false;
      if (hero.rage + 0.001 < d.resourceCost) return false;
      return true;
    }

    final nearby = SpatialCombat._countNearbyEnemies(hero, world);
    final aroundFocus = focus == null
        ? 0
        : SpatialCombat._countNearbyEnemies(focus, world);
    // Ranged kits kite outside self-radius; packs around the focus still count.
    final pack = math.max(nearby, aroundFocus);
    final focusHpFrac = focus == null || focus.maxHp <= 0
        ? 1.0
        : focus.hp / focus.maxHp;
    final focusElite =
        focus != null &&
        (focus.role == EnemyRole.boss || focus.role == EnemyRole.elite);

    bool contextOk(ClassAbilityDef d) {
      final g = d.gate;
      final dist = focus == null ? 999.0 : SpatialCombat._dist(hero, focus);

      if (g.requireFocus && (focus == null || focus.hp <= 0 || focus.dormant)) {
        return false;
      }
      if (g.notQueued && hero.queuedShieldSlam) return false;
      if (g.casterHpMax != null && hpFrac > g.casterHpMax!) return false;
      if (g.comboMin > 0 && hero.comboPoints < g.comboMin) return false;
      if (g.arcaneChargesMin > 0 && hero.arcaneCharges < g.arcaneChargesMin) {
        return false;
      }
      if (g.sliceAndDiceMin > 0 && hero.sliceAndDiceTimer < g.sliceAndDiceMin) {
        return false;
      }
      if (g.focusRootMax != null &&
          (focus == null || focus.rootTimer >= g.focusRootMax!)) {
        return false;
      }
      if (g.hotStreakOnly && !hero.hotStreakReady) return false;
      if (g.hotStreakBlocks &&
          hero.hotStreakReady &&
          KitNamedCasts.pyroblastReady(hero)) {
        return false;
      }

      var maxR = g.maxRange ?? 0.0;
      if (g.maxRangePad != null) {
        maxR = hero.attackRange + g.maxRangePad!;
      }
      if (g.maxRangeMul != null) {
        maxR = (hero.preferredRange ?? 3) * g.maxRangeMul!;
      }
      if (maxR > 0 && dist > maxR) return false;

      var minR = g.minRange ?? 0.0;
      if (g.minRangeMul != null) {
        minR = hero.attackRange * g.minRangeMul!;
      }
      if (minR > 0 && dist < minR) return false;

      if (g.needClearCorridor) {
        if (focus == null) return false;
        if (!SpatialCombat._hasClearCorridor(
          world.map,
          world.openGateIds,
          hero.x.floor(),
          hero.y.floor(),
          focus.x.floor(),
          focus.y.floor(),
        )) {
          return false;
        }
      }
      if (g.nearPackLeader) {
        final leader = KitNamedCasts.packLeader(world, hero);
        final nearPack =
            leader == null || SpatialCombat._dist(hero, leader) < 2.5;
        if (!nearPack) return false;
      }

      if (g.peelRange != null) {
        final scan = g.peelScanRange;
        final near = [
          for (final e in world.enemies)
            if (e.hp > 0 && !e.dormant && SpatialCombat._dist(hero, e) <= scan)
              e,
        ];
        final peel = near.any(
          (e) => SpatialCombat._dist(hero, e) <= g.peelRange!,
        );
        final need = g.packMin > 0 ? g.packMin : 2;
        if (near.length < need && !peel) return false;
      } else if (g.anyCombatWindow) {
        final packOk =
            pack >= math.max(g.packMin, 2) || (pack == 1 && focusElite);
        final execOk =
            g.executeHpFrac != null && focusHpFrac <= g.executeHpFrac!;
        if (!packOk && !execOk && !focusElite) return false;
      } else if (g.packMin > 0) {
        if (pack < g.packMin && !(g.packMin <= 2 && pack == 1 && focusElite)) {
          return false;
        }
      } else if (d.effect == AbilityEffectKind.aoe) {
        if (pack < 2 && !(pack == 1 && focusElite)) return false;
      }

      if (g.executeHpFrac != null &&
          !g.anyCombatWindow &&
          focusHpFrac > g.executeHpFrac!) {
        return false;
      }

      final hold =
          g.holdLongCdOnTrash ??
          (d.tier == AbilityCastTier.signature && d.cooldown >= 30);
      if (hold && !focusElite && nearby < 3 && focusHpFrac > 0.4) {
        return false;
      }

      if (g.maintainDot &&
          focus != null &&
          focus.bleedTimer > 3.5 &&
          focus.bleedAbilityId == d.id.name) {
        return false;
      }
      if (g.skipIfBleedAbove != null &&
          focus != null &&
          focus.bleedTimer > g.skipIfBleedAbove!) {
        return false;
      }
      if (g.skipIfBeaconAbove != null &&
          hero.beaconTimer > g.skipIfBeaconAbove!) {
        return false;
      }
      if (g.sunderRefresh &&
          focus != null &&
          focus.sunderStacks >= 5 &&
          focus.sunderTimer >= 4) {
        return false;
      }
      if (g.livingBombRefresh && focus != null && focus.livingBombTimer >= 2) {
        return false;
      }
      if (g.sliceAndDiceRefresh && hero.sliceAndDiceTimer >= 2) {
        return false;
      }
      if (g.fortitudeRefresh &&
          !world.heroes.any((h) => h.isAlive && h.fortitudeTimer < 2)) {
        return false;
      }
      if (g.atkShoutRefresh && (hero.buffTimers['atkShout'] ?? 0) >= 2) {
        return false;
      }
      if (g.nearbyRadius != null) {
        final r = g.nearbyRadius!;
        if (!world.enemies.any(
          (e) => e.hp > 0 && !e.dormant && SpatialCombat._dist(hero, e) <= r,
        )) {
          return false;
        }
      }
      if (g.needsPomTarget && KitNamedCasts.pomTarget(world) == null) {
        return false;
      }
      if (g.needsPiTarget) {
        if (!KitNamedCasts.partyStable(world) ||
            KitNamedCasts.powerInfusionTarget(world) == null) {
          return false;
        }
      }
      if (g.needsPainTarget &&
          KitNamedCasts.painSuppressionTarget(world) == null) {
        return false;
      }
      if (g.needsPenance) {
        final heal = KitNamedCasts.penanceHealTarget(world) != null;
        final burn =
            focus != null &&
            focus.hp > 0 &&
            SpatialCombat._dist(hero, focus) <= hero.attackRange + 1.5;
        if (!heal && !burn) return false;
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
        // Positioning first: their gates already say "you are out of place",
        // so they must not lose the single filler slot to a big spender.
        final aMove = _isPositioningAbility(a);
        final bMove = _isPositioningAbility(b);
        if (aMove != bMove) return aMove ? -1 : 1;
        // Healers: prefer party/ST heals over enemy AoE when someone is hurt.
        if (def.isHealer && _partyNeedsHeal(world)) {
          final aHeal =
              a.effect == AbilityEffectKind.heal ||
              a.effect == AbilityEffectKind.absorb;
          final bHeal =
              b.effect == AbilityEffectKind.heal ||
              b.effect == AbilityEffectKind.absorb;
          if (aHeal != bHeal) return aHeal ? -1 : 1;
        }
        // DoT maintain before fillers when the focus has no DoT.
        if (focus != null && focus.bleedTimer < 2.0) {
          final aDot = a.gate.maintainDot;
          final bDot = b.gate.maintainDot;
          if (aDot != bDot) return aDot ? -1 : 1;
        }
        // Arcane: build Blast stacks, then dump Missiles.
        if (hero.heroSpecId == HeroSpecId.arcane) {
          if (hero.arcaneCharges >= 3) {
            final aDump = a.id == AbilityId.arcaneMissiles;
            final bDump = b.id == AbilityId.arcaneMissiles;
            if (aDump != bDump) return aDump ? -1 : 1;
          } else {
            final aBuild = a.id == AbilityId.arcaneBlast;
            final bBuild = b.id == AbilityId.arcaneBlast;
            if (aBuild != bBuild) return aBuild ? -1 : 1;
          }
        }
        // Assassin: Envenom when combo is ready.
        if (hero.heroSpecId == HeroSpecId.assassination &&
            hero.comboPoints >= 4) {
          final aEnv = a.id == AbilityId.envenom;
          final bEnv = b.id == AbilityId.envenom;
          if (aEnv != bEnv) return aEnv ? -1 : 1;
        }
        // Prefer AoE in packs, ST otherwise.
        final aAoe = a.effect == AbilityEffectKind.aoe;
        final bAoe = b.effect == AbilityEffectKind.aoe;
        if (pack >= 2 && aAoe != bAoe) return aAoe ? -1 : 1;
        if (pack < 2 && aAoe != bAoe) return aAoe ? 1 : -1;
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

  /// Resource per second while a focus is up. The four kits that used to run
  /// dedicated tickers keep their old rates so pacing did not shift on migrate.
  static double _resourceRate(HeroSpecId specId, SpecResource resource) {
    switch (specId) {
      case HeroSpecId.protection:
        return 6.0;
      case HeroSpecId.discipline:
        return 7.0;
      case HeroSpecId.fire:
        return 8.0;
      case HeroSpecId.combat:
        return 10.0;
      default:
        // Rage/mana bumped so mid-kit spenders can fire between openers.
        return switch (resource) {
          SpecResource.rage => 8.0,
          SpecResource.mana => 9.0,
          SpecResource.energy => 11.0,
          SpecResource.runic => 9.0,
        };
    }
  }

  /// Gap-closers / kites whose gate already means "you are out of position".
  static bool _isPositioningAbility(ClassAbilityDef d) => switch (d.id) {
    AbilityId.charge || AbilityId.blink || AbilityId.sprint => true,
    _ => false,
  };

  static bool _isStackingDot(ClassAbilityDef d) => switch (d.id) {
    AbilityId.corruption ||
    AbilityId.unstableAffliction ||
    AbilityId.curseOfAgony ||
    AbilityId.shadowWordPain ||
    AbilityId.vampiricTouch ||
    AbilityId.devouringPlague ||
    AbilityId.bloodBoil ||
    AbilityId.bloodBoilUnholy ||
    AbilityId.howlingBlast ||
    AbilityId.scourgeStrike ||
    AbilityId.heartStrike => true,
    _ => false,
  };

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
        // Self-heal tank: stronger DR + heal amp than presence-only peers.
        hero.kitInMul *= 0.85;
        hero.kitHealMul *= 1.18;
        hero.kitOutMul *= 0.98;
      case AbilityId.bearForm:
        hero.kitInMul *= 0.88;
        hero.kitOutMul *= 0.95;

      // —— healer amplify ——
      case AbilityId.holyLightAura:
      case AbilityId.spiritOfRedemption:
      case AbilityId.ancestralAwakening:
        hero.kitHealMul *= 1.32;
      case AbilityId.treeOfLife:
        // HoT healer amp — match / slightly lead peer healer passives.
        hero.kitHealMul *= 1.34;

      // —— melee DPS (target ~1.22–1.34; Arms leans on Sweeping, not raw mul) ——
      case AbilityId.armsStance:
        hero.kitOutMul *= 1.26;
        hero.kitInMul *= 1.04;
      case AbilityId.berserkerStance:
        hero.kitOutMul *= 1.30;
        hero.kitHasteMul *= 1.12;
        hero.kitInMul *= 1.06;
      case AbilityId.sealOfCommand:
        hero.kitOutMul *= 1.40;
      case AbilityId.improvedPoisons:
        // Assass led the board — slight lean so lows can rise without HIGH.
        hero.kitOutMul *= 1.28;
      case AbilityId.masterOfSubtlety:
        // Opener fantasy: damage + slight haste for ambush windows.
        hero.kitOutMul *= 1.32;
        hero.kitHasteMul *= 1.08;
      case AbilityId.frostPresence:
        hero.kitOutMul *= 1.40;
        hero.kitInMul *= 0.97;
      case AbilityId.unholyPresence:
        // Fairness: ghoul + diseases carry identity; presence is a lean, not a stomp.
        hero.kitOutMul *= 1.16;
        hero.kitHasteMul *= 1.10;
      // Ghoul companion spawned in SpatialCombat.build.
      case AbilityId.enhancementWeapons:
        hero.kitOutMul *= 1.26;
      case AbilityId.catForm:
        hero.kitOutMul *= 1.28;
        hero.kitHasteMul *= 1.10;

      // —— ranged ——
      case AbilityId.aspectOfHawk:
        hero.kitOutMul *= 1.18;
      case AbilityId.trueshotAura:
        hero.kitOutMul *= 1.22;
        hero.kitHasteMul *= 1.06;
      case AbilityId.trapMastery:
        hero.kitOutMul *= 1.26;
        hero.kitRootBonus += 1.0;

      // —— casters: identity buffs; spam tax is casterAbilityTax only ——
      case AbilityId.shadowform:
        hero.kitOutMul *= 1.16;
        hero.kitInMul *= 1.04;
      case AbilityId.elementalFocus:
        hero.kitOutMul *= 1.20;
        hero.kitHasteMul *= 1.10;
      case AbilityId.arcanePowerPassive:
        hero.kitOutMul *= 1.12;
      case AbilityId.frostArmor:
        hero.kitInMul *= 0.92;
        hero.kitOutMul *= 1.12;
        hero.kitRootBonus += 0.5;
      case AbilityId.soulSiphon:
        hero.kitOutMul *= 1.14;
        hero.kitHealMul *= 1.08;
      case AbilityId.demonicKnowledge:
        // Pet-family identity: personal power + haste; pet AA/empower carries share.
        hero.kitOutMul *= 1.02;
        hero.kitHasteMul *= 1.06;
      case AbilityId.cataclysm:
        hero.kitOutMul *= 1.12;
      case AbilityId.moonkinForm:
        hero.kitOutMul *= 1.16;
        hero.kitInMul *= 0.92;

      // —— original four kits ——
      case AbilityId.defensiveStance:
        // White-hit half of the stance lives in [_warriorAttackMods].
        hero.kitOutMul *= 0.9;
        hero.kitInMul *= 0.92;
      case AbilityId.revenge:
        // Rider on blocked swings — no always-on multiplier.
        break;
      case AbilityId.innerFire:
        hero.innerFireActive = true;
        hero.kitHealMul *= 1.36;
        hero.kitInMul *= 0.94;
      case AbilityId.sinisterStrike:
        // Combo build rides white swings; 2 AP/Agi already lifts the sheet.
        hero.kitOutMul *= 0.92;
      case AbilityId.arcaneIntellect:
        // Personal spell power; party-wide Int is the GameState caster aura.
        hero.kitOutMul *= 1.24;
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
    if (def.customId != AbilityCustomId.none) {
      return KitNamedCasts.run(
        world,
        hero,
        focus,
        def,
        rng: rng,
        reducedVfx: reducedVfx,
      );
    }

    switch (def.effect) {
      case AbilityEffectKind.passive:
        return false;
      case AbilityEffectKind.damage:
        if (focus == null || focus.hp <= 0) return false;
        if (def.gate.maxRange != null &&
            SpatialCombat._dist(hero, focus) > def.gate.maxRange!) {
          return false;
        }
        _spendAndCd(world, hero, def);
        _castDamage(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        if (def.id == AbilityId.bloodthirst) {
          SpatialCombat._gainRage(hero, 10);
        }
        return true;
      case AbilityEffectKind.aoe:
        _spendAndCd(world, hero, def);
        _castAoe(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.heal:
        // Blood Rune Tap / Guardian FR are self-sustain, not party triage.
        if (def.id == AbilityId.runeTap || def.id == AbilityId.frenziedRegen) {
          if (!_allyNeedsHeal(hero)) return false;
          _spendAndCd(world, hero, def);
          _castHeal(world, hero, hero, def, reducedVfx: reducedVfx);
          return true;
        }
        // Holy Shock: heal if someone is hurt, otherwise smite the focus.
        if (def.id == AbilityId.holyShock) {
          if (_partyNeedsHeal(world)) {
            final ally = _lowestAlly(world, hero);
            if (ally == null) return false;
            _spendAndCd(world, hero, def);
            _castHeal(world, hero, ally, def, reducedVfx: reducedVfx);
            return true;
          }
          if (focus == null || focus.hp <= 0) return false;
          _spendAndCd(world, hero, def);
          _castDamage(world, hero, focus, def, rng, reducedVfx: reducedVfx);
          return true;
        }
        if (_isPartyHeal(def)) {
          if (!_partyNeedsHeal(world)) return false;
          _spendAndCd(world, hero, def);
          _castPartyHeal(world, hero, def, reducedVfx: reducedVfx);
          return true;
        }
        final ally = _lowestAlly(world, hero);
        if (ally == null) return false;
        // Skip overheal when nobody is meaningfully hurt (Disc-style triage).
        if (!_allyNeedsHeal(ally)) return false;
        _spendAndCd(world, hero, def);
        _castHeal(world, hero, ally, def, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.emergencyHeal:
        if (_isPartyHeal(def)) {
          _spendAndCd(world, hero, def);
          _castPartyHeal(world, hero, def, reducedVfx: reducedVfx);
          CombatPresence.onEmergencyHeal(
            world,
            hero,
            reducedVfx: reducedVfx,
          );
          return true;
        }
        final ally = _lowestAlly(world, hero);
        if (ally == null) return false;
        _spendAndCd(world, hero, def);
        _castHeal(world, hero, ally, def, reducedVfx: reducedVfx);
        CombatPresence.onEmergencyHeal(world, hero, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.absorb:
        // Unholy AMS / Blood Bone Shield are self shells — not party bubbles.
        final ally =
            def.id == AbilityId.antiMagicShell || def.id == AbilityId.boneShield
            ? hero
            : _lowestAlly(world, hero);
        if (ally == null) return false;
        if (!_allyNeedsAbsorb(ally)) return false;
        _spendAndCd(world, hero, def);
        _castAbsorb(world, hero, ally, def, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.selfBuff:
        if (def.id == AbilityId.beaconOfLight) {
          final mark = _beaconMarkTarget(world, hero);
          hero.beaconTargetId = mark.id;
          hero.beaconTimer = 18;
          _spendAndCd(world, hero, def);
          _announce(world, hero, def.shortLabel, 0xFFFFF0A8, reducedVfx);
          if (!reducedVfx) {
            SpatialCombat._spawnRing(
              world,
              x: mark.x,
              y: mark.y,
              argb: 0xFFFFF0A8,
              radius: 0.9,
              life: 0.4,
            );
          }
          return true;
        }
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
        if (def.id == AbilityId.slow) {
          if (focus == null || focus.hp <= 0) return false;
          _spendAndCd(world, hero, def);
          focus.attackSlowTimer = math.max(
            focus.attackSlowTimer,
            4.0 + hero.kitRootBonus,
          );
          hero.attackFlash = 0.12;
          _announce(world, hero, def.shortLabel, 0xFFB090FF, reducedVfx);
          if (!reducedVfx) {
            SpatialCombat._spawnRing(
              world,
              x: focus.x,
              y: focus.y,
              argb: 0xAAB090FF,
              radius: 0.7,
              life: 0.4,
            );
          }
          return true;
        }
        if (def.id == AbilityId.frostNovaMage ||
            def.id == AbilityId.psychicScream ||
            def.id == AbilityId.hungeringCold) {
          final nearby = [
            for (final e in world.enemies)
              if (e.hp > 0 && !e.dormant && SpatialCombat._dist(hero, e) <= 2.5)
                e,
          ];
          if (nearby.isEmpty) return false;
          _spendAndCd(world, hero, def);
          final rootDur = 2.4 + hero.kitRootBonus;
          for (final e in nearby) {
            _applyEnemyRoot(e, rootDur);
            e.attackSlowTimer = math.max(e.attackSlowTimer, 3.0);
          }
          hero.attackFlash = 0.14;
          _announce(world, hero, def.shortLabel, 0xFF80D0FF, reducedVfx);
          if (!reducedVfx) {
            SpatialCombat._spawnRing(
              world,
              x: hero.x,
              y: hero.y,
              argb: 0xFF60C0FF,
              radius: 1.6,
              life: 0.45,
            );
          }
          return true;
        }
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
        // Preparation: reset other kit CDs (Prep stays on CD).
        if (def.id == AbilityId.preparation) {
          final spec = hero.heroSpecId;
          if (spec != null) {
            final kitKeys = {
              for (final d in ClassKits.forSpec(spec)) d.id.name,
            };
            hero.abilityCd.removeWhere(
              (k, _) => k != AbilityId.preparation.name && kitKeys.contains(k),
            );
          } else {
            hero.abilityCd.removeWhere(
              (k, _) => k != AbilityId.preparation.name,
            );
          }
          hero.powerInfusionTimer = math.max(hero.powerInfusionTimer, 4.0);
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
              argb: 0xFF90A0C0,
              radius: 1.05,
              life: 0.4,
            );
          }
          return true;
        }
        // Guardian Spirit: panic bubble + DR on the lowest ally.
        if (def.id == AbilityId.guardianSpirit) {
          final ally = _lowestAlly(world, hero) ?? hero;
          final amount = math.max(
            12,
            (hero.attack * def.coeff * hero.kitHealMul).round(),
          );
          ally.absorbShield += amount;
          ally.shieldWallTimer = math.max(ally.shieldWallTimer, 4.0);
          ally.buffTimers['shield'] = 4.0;
          _announce(
            world,
            hero,
            def.shortLabel,
            0xFFFFD090,
            reducedVfx,
            important: true,
          );
          if (!reducedVfx) {
            SpatialCombat._spawnRing(
              world,
              x: ally.x,
              y: ally.y,
              argb: 0xAAFFE090,
              radius: 1.0,
              life: 0.5,
            );
          }
          return true;
        }
        // Feign Death: drop aggro + brief untargetable (Vanish pattern).
        if (def.id == AbilityId.feignDeath) {
          hero.vanishTimer = math.max(hero.vanishTimer, 2.2);
          hero.shieldWallTimer = math.max(hero.shieldWallTimer, 1.5);
          for (final e in world.enemies) {
            if (e.forcedTargetId == hero.id) {
              e.forcedTargetId = null;
              e.forcedTargetTimer = 0;
            }
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
              argb: 0xFF90A0B0,
              radius: 1.0,
              life: 0.35,
            );
          }
          return true;
        }
        // Disengage: kite speed + short DR (not a full tank wall).
        if (def.id == AbilityId.disengage) {
          hero.sprintTimer = math.max(hero.sprintTimer, 3.5);
          hero.shieldWallTimer = math.max(hero.shieldWallTimer, 2.0);
          hero.powerInfusionTimer = math.max(hero.powerInfusionTimer, 3.0);
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
              argb: 0xFF70C090,
              radius: 1.1,
              life: 0.35,
            );
          }
          return true;
        }
        final lowest = _lowestAlly(world, hero);
        final lowestFrac = lowest == null || lowest.effectiveMaxHp <= 0
            ? 1.0
            : lowest.hp / lowest.effectiveMaxHp;
        final defendTarget =
            (!_actorIsTank(hero) && lowest != null && lowestFrac <= 0.32)
            ? lowest
            : hero;
        defendTarget.shieldWallTimer = math.max(
          defendTarget.shieldWallTimer,
          3.5,
        );
        if (_actorIsTank(hero) && identical(defendTarget, hero)) {
          hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, 3.5);
          SpatialCombat._tauntLooseEnemies(world, hero, reducedVfx: reducedVfx);
        }
        defendTarget.buffTimers['shield'] = 3.5;
        if (identical(defendTarget, hero) &&
            hero.hp / math.max(1, hero.effectiveMaxHp) <= 0.4) {
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
            x: defendTarget.x,
            y: defendTarget.y,
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

  /// Outgoing scale for kit casts. Casters get [SpatialCombat.casterAbilityTax]
  /// because Int-based ability spam outpaced melee Str kits on mid-band sims.
  static double _abilityOutScale(SpatialActor hero) {
    var scale = hero.kitOutMul;
    final id = hero.heroSpecId;
    if (id != null && HeroSpecs.def(id).roleTag == SpecRoleTag.caster) {
      scale *= SpatialCombat.casterAbilityTax;
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
    final delay = _castDelaySeconds(hero, def);
    if (delay > 0) {
      hero.castingTimer = math.max(hero.castingTimer, delay);
      hero.pendingCastDef = def.id.name;
    }
    var raw = math.max(
      2,
      (_abilityPower(hero, def) * def.coeff * _abilityOutScale(hero)).round(),
    );
    raw = math.max(
      2,
      (raw *
              SpecMastery.damageMul(
                _masteryView(hero),
                def,
                _masteryView(enemy),
              ))
          .round(),
    );
    // Damage amp window (Vendetta / Cold Blood / Arcane Power).
    if (hero.combustionTimer > 0) {
      raw = math.max(2, (raw * 1.22).round());
    }
    // Arcane Blast stacks; Missiles dump.
    if (def.id == AbilityId.arcaneBlast) {
      hero.arcaneCharges = math.min(4, hero.arcaneCharges + 1);
      raw = math.max(2, (raw * (1.0 + hero.arcaneCharges * 0.12)).round());
    } else if (def.id == AbilityId.arcaneMissiles) {
      final charges = hero.arcaneCharges;
      hero.arcaneCharges = 0;
      raw = math.max(2, (raw * (1.0 + charges * 0.2)).round());
    }
    // Frost Ice Lance shatters rooted targets.
    if (def.id == AbilityId.iceLance && enemy.rootTimer > 0) {
      raw = math.max(2, (raw * 1.75).round());
    }
    // Frost DK finisher pops rooted packs (Hungering Cold → shatter).
    if (def.id == AbilityId.frostStrike && enemy.rootTimer > 0) {
      raw = math.max(2, (raw * 1.4).round());
    }
    // Assassination: build combo on Mut/Garrote; Envenom spends.
    if (hero.heroSpecId == HeroSpecId.assassination) {
      if (def.id == AbilityId.mutilate) {
        hero.comboPoints = math.min(5, hero.comboPoints + 2);
      } else if (def.id == AbilityId.garrote) {
        hero.comboPoints = math.min(5, hero.comboPoints + 1);
      } else if (def.id == AbilityId.envenom) {
        final pts = hero.comboPoints;
        hero.comboPoints = 0;
        raw = math.max(2, (raw * (1.05 + pts * 0.22)).round());
      }
    }
    final style = SpatialCombat.boltStyleForAbility(hero, def: def);
    final pet = _petEmpoweredAbility(def) ? _ownedCombatPet(world, hero) : null;
    if (pet != null) {
      // BM Kill Command / Demo pet-lean nukes hit harder with companion up.
      final petMul = def.id == AbilityId.killCommand ? 1.55 : 1.22;
      raw = (raw * petMul).round();
    }
    // Mongoose Bite is always melee; Kill Command snaps melee when pet is up.
    final useBolt = def.id == AbilityId.mongooseBite
        ? false
        : (def.id == AbilityId.killCommand && pet != null
              ? false
              : (hero.ranged || SpatialCombat._dist(hero, enemy) > 2.2));
    final tint = SpatialCombat.burstArgbForStyle(style);

    hero.attackFlash = 0.16;
    SpatialCombat._setAttackAnim(hero, enemy, 0.22);
    _announce(world, hero, def.shortLabel, tint, reducedVfx);
    _applyDamageSideEffects(world, hero, def, rawEstimate: raw);
    _applyBleedIfNeeded(world, hero, enemy, def, raw);

    if (useBolt) {
      SpatialCombat._addProjectile(
        world,
        SpatialCombat._spellBolt(
          from: hero,
          to: enemy,
          damage: raw,
          style: style,
          label: null,
          labelArgb: null,
        ),
      );
      if (!reducedVfx) {
        SpellVfx.spawnCast(
          world,
          hero: hero,
          style: style,
          id: def.id,
          radius: 0.55,
        );
        if (style == SpellBoltStyle.lightning || style == SpellBoltStyle.holy) {
          SpellVfx.spawnBeam(
            world,
            x: hero.x,
            y: hero.y,
            x2: enemy.x,
            y2: enemy.y,
            argb: tint,
            life: 0.22,
          );
        }
      }
      return;
    }

    final dealt = CombatRatings.mitigateByArmor(
      rawDamage: raw,
      defense: enemy.effectiveDefense,
      attackerAttack: hero.attack,
    );
    final wasAlive = enemy.hp > 0;
    enemy.hp = math.max(0, enemy.hp - dealt);
    SpatialCombat._recordHeroDamage(hero, dealt);
    SpatialCombat._applyTankSoftThreat(hero, enemy);
    SpatialCombat._spawnSlash(world, from: hero, to: enemy, isCrit: false);
    if (!reducedVfx) {
      SpellVfx.spawnImpact(
        world,
        x: enemy.x,
        y: enemy.y,
        style: style,
        id: def.id,
        radius: 0.5,
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
      final killed = SpatialCombat._onEnemyKilled(
        world,
        _stateOut!,
        enemy,
        rng,
      );
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
    final style = SpatialCombat.boltStyleForAbility(hero, def: def);
    _announce(
      world,
      hero,
      def.shortLabel,
      SpatialCombat.burstArgbForStyle(style),
      reducedVfx,
    );
    if (!reducedVfx) {
      SpellVfx.spawnCast(
        world,
        hero: hero,
        style: style,
        shape: def.aoeShape,
        id: def.id,
        radius: 0.85,
      );
    }

    final shape =
        def.aoeShape ??
        (def.vfx?.groundDisc == true
            ? AbilityAoeShape.ground
            : AbilityAoeShape.nova);
    switch (shape) {
      case AbilityAoeShape.chain:
        _chainLightning(world, hero, focus, def, rng, reducedVfx: reducedVfx);
        return;
      case AbilityAoeShape.fan:
        _fanBolts(
          world,
          hero,
          focus,
          def,
          style,
          rng,
          hops: 4,
          reducedVfx: reducedVfx,
        );
        return;
      case AbilityAoeShape.rain:
        _rainBolts(world, hero, focus, def, style, rng, reducedVfx: reducedVfx);
        return;
      case AbilityAoeShape.ground:
        _groundNova(world, hero, def, style, rng, reducedVfx: reducedVfx);
        return;
      case AbilityAoeShape.nova:
        _novaStrike(world, hero, def, style, rng, reducedVfx: reducedVfx);
        return;
    }
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
    final base = math.max(
      2,
      (hero.attack * def.coeff * _abilityOutScale(hero)).round(),
    );
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
      SpatialCombat._addProjectile(
        world,
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
        SpellVfx.spawnBeam(
          world,
          x: px,
          y: py,
          x2: t.x,
          y2: t.y,
          argb: SpatialCombat.burstArgbForStyle(style),
          life: 0.32 + delay * 0.1,
        );
        SpellVfx.spawnImpact(
          world,
          x: t.x,
          y: t.y,
          style: style,
          shape: AbilityAoeShape.chain,
          id: def.id,
          radius: 0.5 - i * 0.05,
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
    SpatialActor? focus,
    ClassAbilityDef def,
    SpellBoltStyle style,
    math.Random rng, {
    required int hops,
    required bool reducedVfx,
  }) {
    final raw = math.max(
      2,
      (hero.attack * def.coeff * _abilityOutScale(hero)).round(),
    );
    final anchor = focus != null && focus.hp > 0 && !focus.dormant
        ? focus
        : hero;
    final enemies = world.enemies.where((e) => e.hp > 0 && !e.dormant).toList()
      ..sort(
        (a, b) => SpatialCombat._dist(
          anchor,
          a,
        ).compareTo(SpatialCombat._dist(anchor, b)),
      );
    final picks = enemies.take(hops).toList();
    if (picks.isEmpty) return;
    hero.attackFlash = 0.18;
    for (var i = 0; i < picks.length; i++) {
      SpatialCombat._addProjectile(
        world,
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
    final raw = math.max(
      2,
      (hero.attack * def.coeff * _abilityOutScale(hero)).round(),
    );
    final argb = SpatialCombat.burstArgbForStyle(style);
    hero.attackFlash = 0.18;

    if (!reducedVfx) {
      SpellVfx.spawnCast(
        world,
        hero: hero,
        style: style,
        shape: AbilityAoeShape.nova,
        id: def.id,
        radius: radius * 0.45,
      );
      SpatialCombat._spawnRing(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: radius * 0.55,
        life: 0.4,
      );
    }

    var i = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat._dist(hero, e) > radius) continue;
      // Cone of Cold / chill AoE: slow attack cadence.
      if (def.id == AbilityId.coneOfCold) {
        e.attackSlowTimer = math.max(e.attackSlowTimer, 3.0);
      }

      final fly =
          hero.ranged ||
          style == SpellBoltStyle.lightning ||
          style == SpellBoltStyle.frost ||
          style == SpellBoltStyle.fire ||
          style == SpellBoltStyle.shadow ||
          style == SpellBoltStyle.arcane ||
          style == SpellBoltStyle.nature;
      if (fly) {
        SpatialCombat._addProjectile(
          world,
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
        // Disease DoTs apply on cast (bolt damage may land later).
        _applyBleedIfNeeded(world, hero, e, def, raw);
      } else {
        final wasAlive = e.hp > 0;
        final dealt = CombatRatings.mitigateByArmor(
          rawDamage: raw,
          defense: e.effectiveDefense,
          attackerAttack: hero.attack,
        );
        e.hp = math.max(0, e.hp - dealt);
        SpatialCombat._recordHeroDamage(hero, dealt);
        SpatialCombat._applyTankSoftThreat(hero, e);
        _applyBleedIfNeeded(world, hero, e, def, raw);
        if (!reducedVfx) {
          SpellVfx.spawnImpact(
            world,
            x: e.x,
            y: e.y,
            style: style,
            shape: AbilityAoeShape.nova,
            id: def.id,
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
          final killed = SpatialCombat._onEnemyKilled(
            world,
            _stateOut!,
            e,
            rng,
          );
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
    SpatialActor? focus,
    ClassAbilityDef def,
    SpellBoltStyle style,
    math.Random rng, {
    required bool reducedVfx,
  }) {
    final radius = style == SpellBoltStyle.lightning ? 3.2 : 2.9;
    final raw = math.max(
      2,
      (hero.attack * def.coeff * _abilityOutScale(hero)).round(),
    );
    final argb = SpatialCombat.burstArgbForStyle(style);
    hero.attackFlash = 0.2;
    // Ranged kits kite outside self-radius — rain on the focus pack.
    final anchor = focus != null && focus.hp > 0 && !focus.dormant
        ? focus
        : hero;

    if (!reducedVfx) {
      SpatialCombat._spawnBurst(
        world,
        x: anchor.x,
        y: anchor.y,
        argb: argb,
        radius: radius * 0.55,
        kind: SpatialBurstKind.rain,
        life: 0.55,
      );
      SpatialCombat._spawnRing(
        world,
        x: anchor.x,
        y: anchor.y,
        argb: argb,
        radius: radius * 0.45,
        life: 0.5,
      );
    }

    var i = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat._dist(anchor, e) > radius) continue;
      if (i >= 4) break;
      SpatialCombat._addProjectile(
        world,
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
        SpellVfx.spawnImpact(
          world,
          x: e.x,
          y: e.y,
          style: style,
          shape: AbilityAoeShape.rain,
          id: def.id,
          radius: 0.45,
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
    final raw = math.max(
      2,
      (hero.attack * def.coeff * _abilityOutScale(hero)).round(),
    );
    final argb = SpatialCombat.burstArgbForStyle(style);
    hero.attackFlash = 0.2;

    if (!reducedVfx) {
      SpellVfx.spawnCast(
        world,
        hero: hero,
        style: style,
        shape: AbilityAoeShape.ground,
        id: def.id,
        radius: radius * 0.4,
      );
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
      // Signature spin arcs for Bladestorm.
      if (def.id == AbilityId.bladestorm) {
        for (var i = 0; i < 3; i++) {
          SpatialCombat._spawnBurst(
            world,
            x: hero.x,
            y: hero.y,
            argb: 0xCCFFE08A,
            radius: radius * (0.45 + i * 0.12),
            angle: i * 2.1,
            slash: true,
            life: 0.34 + i * 0.04,
          );
        }
      }
      // Purple nova pop for Shadowfury.
      if (def.id == AbilityId.shadowfury) {
        SpellVfx.spawnImpact(
          world,
          x: hero.x,
          y: hero.y,
          style: SpellBoltStyle.shadow,
          id: AbilityId.shadowfury,
          radius: radius * 0.7,
        );
      }
      final vfx = def.vfx;
      final discLife =
          vfx?.groundLife ?? SpatialCombat.groundDiscLifeFor(def.id);
      if (vfx?.groundDisc == true || discLife != null) {
        SpatialCombat._spawnGroundFx(
          world,
          x: hero.x,
          y: hero.y,
          argb: vfx?.groundArgb ?? ((argb & 0x00FFFFFF) | 0x55000000),
          radius: vfx?.groundRadius ?? radius,
          life: discLife ?? 2.5,
          kind: SpellVfx.groundKindFor(style: style, id: def.id),
        );
      }
    }

    var hitCount = 0;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      if (SpatialCombat._dist(hero, e) > radius) continue;
      final wasAlive = e.hp > 0;
      final dealt = CombatRatings.mitigateByArmor(
        rawDamage: raw,
        defense: e.effectiveDefense,
        attackerAttack: hero.attack,
      );
      e.hp = math.max(0, e.hp - dealt);
      SpatialCombat._recordHeroDamage(hero, dealt);
      SpatialCombat._applyTankSoftThreat(hero, e);
      _applyBleedIfNeeded(world, hero, e, def, raw);
      hitCount++;
      if (!reducedVfx) {
        SpellVfx.spawnImpact(
          world,
          x: e.x,
          y: e.y,
          style: style,
          shape: AbilityAoeShape.ground,
          id: def.id,
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
        final killed = SpatialCombat._onEnemyKilled(world, _stateOut!, e, rng);
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
    _applyEnemyRoot(focus, 2.2 + hero.kitRootBonus);
    hero.attackFlash = 0.14;
    _announce(world, hero, def.shortLabel, 0xFF80D0FF, reducedVfx);

    if (hero.ranged || SpatialCombat._dist(hero, focus) > 2.0) {
      SpatialCombat._addProjectile(
        world,
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
      SpellVfx.spawnImpact(
        world,
        x: focus.x,
        y: focus.y,
        style: style,
        id: def.id,
        radius: 0.7,
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
    final style = SpatialCombat.boltStyleForAbility(caster, def: def);
    final tint = def.vfx?.castArgb ?? SpatialCombat.burstArgbForStyle(style);
    final isHot =
        def.id == AbilityId.riptide ||
        def.id == AbilityId.renew ||
        def.id == AbilityId.rejuvenation ||
        def.id == AbilityId.lifebloom;
    final directCoeff = isHot ? def.coeff * 0.55 : def.coeff;
    _healLowest(world, caster, ally, directCoeff, def.shortLabel);
    if (isHot) {
      final nextHps = math.max(2.0, caster.attack * 0.14 * caster.kitHealMul);
      // Stronger (or equal) refresh owns the tick credit on the meter.
      if (nextHps >= ally.hotHps) {
        ally.hotCasterId = caster.id;
      }
      ally.buffTimers['hot'] = 12.0;
      ally.hotHps = math.max(ally.hotHps, nextHps);
      ally.hotAcc = 0;
    }
    _announce(world, caster, def.shortLabel, tint, reducedVfx);
    if (!reducedVfx) {
      SpellVfx.spawnImpact(
        world,
        x: ally.x,
        y: ally.y,
        style: style,
        id: def.id,
        radius: 0.6,
      );
      SpatialCombat._spawnRing(
        world,
        x: ally.x,
        y: ally.y,
        argb: (tint & 0x00FFFFFF) | 0x88000000,
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
    final style = SpatialCombat.boltStyleForAbility(caster, def: def);
    final tint = def.vfx?.castArgb ?? SpatialCombat.burstArgbForStyle(style);
    _absorbLowest(world, caster, ally, def.coeff, def.shortLabel);
    _announce(world, caster, def.shortLabel, tint, reducedVfx);
    if (!reducedVfx) {
      SpellVfx.spawnImpact(
        world,
        x: ally.x,
        y: ally.y,
        style: style,
        id: def.id,
        radius: 0.7,
      );
      SpatialCombat._spawnRing(
        world,
        x: ally.x,
        y: ally.y,
        argb: (tint & 0x00FFFFFF) | 0xAA000000,
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
    // Always give a small style-colored cast burst so kits aren't silent.
    if (!reducedVfx) {
      SpatialCombat._spawnBurst(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: important ? 0.85 : 0.55,
        life: important ? 0.32 : 0.22,
      );
    }
    // Routine ability-name shoutouts drown the stage.
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

  static SpatialActor _beaconMarkTarget(SpatialWorld world, SpatialActor pala) {
    SpatialActor? tank;
    SpatialActor? stoutest;
    var bestMax = -1;
    for (final h in world.heroes) {
      if (!h.isAlive || h.isPet) continue;
      if (_actorIsTank(h)) {
        if (tank == null || h.effectiveMaxHp > tank.effectiveMaxHp) {
          tank = h;
        }
      }
      if (h.effectiveMaxHp > bestMax) {
        bestMax = h.effectiveMaxHp;
        stoutest = h;
      }
    }
    return tank ?? stoutest ?? pala;
  }

  static SpatialActor? _lowestAlly(SpatialWorld world, SpatialActor self) {
    SpatialActor? best;
    var bestFrac = 2.0;
    for (final h in world.heroes) {
      if (!h.isAlive) continue;
      final frac = h.effectiveMaxHp <= 0 ? 1.0 : h.hp / h.effectiveMaxHp;
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

  static bool _isPartyHeal(ClassAbilityDef def) {
    switch (def.id) {
      case AbilityId.chainHeal ||
          AbilityId.healingRain ||
          AbilityId.spiritLink ||
          AbilityId.wildGrowth ||
          AbilityId.tranquility ||
          AbilityId.divineHymn ||
          AbilityId.holyPriestNova ||
          AbilityId.circleOfHealing:
        return true;
      default:
        final key = _abilityKey(def);
        return key.contains('chain heal') ||
            key.contains('rain') ||
            key.contains('spirit link') ||
            key.contains('wild growth') ||
            key.contains('tranquility') ||
            key.contains('hymn') ||
            key.contains('holy nova') ||
            key.contains('circle of healing');
    }
  }

  static bool _partyNeedsHeal(SpatialWorld world) {
    for (final h in world.heroes) {
      if (h.isAlive && _allyNeedsHeal(h)) return true;
    }
    return false;
  }

  static void _castPartyHeal(
    SpatialWorld world,
    SpatialActor caster,
    ClassAbilityDef def, {
    required bool reducedVfx,
  }) {
    final style = SpatialCombat.boltStyleForAbility(caster, def: def);
    final tint = def.vfx?.castArgb ?? SpatialCombat.burstArgbForStyle(style);
    final living = [
      for (final h in world.heroes)
        if (h.isAlive) h,
    ];
    if (living.isEmpty) return;
    living.sort((a, b) {
      final af = a.effectiveMaxHp <= 0 ? 1.0 : a.hp / a.effectiveMaxHp;
      final bf = b.effectiveMaxHp <= 0 ? 1.0 : b.hp / b.effectiveMaxHp;
      return af.compareTo(bf);
    });
    var bounce = def.coeff;
    final maxTargets = living.length.clamp(1, 4);
    for (var i = 0; i < maxTargets; i++) {
      final ally = living[i];
      _healLowest(
        world,
        caster,
        ally,
        bounce,
        def.shortLabel,
        beaconPeel: false,
      );
      bounce *= 0.72;
    }
    _announce(world, caster, def.shortLabel, tint, reducedVfx);
    if (!reducedVfx) {
      SpellVfx.spawnCast(
        world,
        hero: caster,
        style: style,
        id: def.id,
        radius: 1.1,
      );
      SpatialCombat._spawnRing(
        world,
        x: caster.x,
        y: caster.y,
        argb: (tint & 0x00FFFFFF) | 0x88000000,
        radius: 1.4,
        life: 0.4,
      );
      final discLife = SpatialCombat.groundDiscLifeFor(def.id);
      if (discLife != null || def.vfx?.groundDisc == true) {
        SpatialCombat._spawnGroundFx(
          world,
          x: caster.x,
          y: caster.y,
          argb: (tint & 0x00FFFFFF) | 0x55000000,
          radius: def.vfx?.groundRadius ?? 2.8,
          life: def.vfx?.groundLife ?? discLife ?? 4.0,
          kind: SpellVfx.groundKindFor(style: style, id: def.id),
        );
      }
    }
  }

  static void _applyDamageSideEffects(
    SpatialWorld world,
    SpatialActor hero,
    ClassAbilityDef def, {
    required int rawEstimate,
  }) {
    if (def.id == AbilityId.drainLife || def.id == AbilityId.deathStrike) {
      // Blood Death Strike leans harder into self-heal fantasy than Affliction drain.
      final ratio = def.id == AbilityId.deathStrike ? 0.75 : 0.65;
      final heal = math.max(3, (rawEstimate * ratio * hero.kitHealMul).round());
      final before = hero.hp;
      hero.hp = math.min(hero.effectiveMaxHp, hero.hp + heal);
      final gained = hero.hp - before;
      if (gained > 0) {
        hero.healingDone += gained;
        SpatialCombat._spawnFloater(
          world,
          x: hero.x,
          y: hero.y - 0.4,
          text: '+$gained',
          argb: SpatialCombat._floaterHeal,
          life: 0.45,
        );
      }
    }
    if (def.id == AbilityId.vampiricTouch) {
      SpatialCombat._gainRage(hero, 12);
    }
  }

  static void _applyBleedIfNeeded(
    SpatialWorld world,
    SpatialActor hero,
    SpatialActor enemy,
    ClassAbilityDef def,
    int raw,
  ) {
    final isBleed = switch (def.id) {
      AbilityId.rip ||
      AbilityId.rake ||
      AbilityId.rend ||
      AbilityId.garrote ||
      AbilityId.rupture ||
      AbilityId.serpentSting ||
      AbilityId.lacerate ||
      AbilityId.corruption ||
      AbilityId.unstableAffliction ||
      AbilityId.curseOfAgony ||
      AbilityId.moonfire ||
      AbilityId.immolateDemo ||
      AbilityId.immolateDestro ||
      AbilityId.flameShock ||
      AbilityId.shadowWordPain ||
      AbilityId.vampiricTouch ||
      AbilityId.devouringPlague ||
      AbilityId.bloodBoil ||
      AbilityId.bloodBoilUnholy ||
      AbilityId.howlingBlast ||
      AbilityId.scourgeStrike ||
      AbilityId.heartStrike => true,
      _ => false,
    };
    if (!isBleed) return;
    final duration = switch (def.id) {
      AbilityId.rip => 12.0,
      AbilityId.rake || AbilityId.garrote => 8.0,
      AbilityId.serpentSting ||
      AbilityId.moonfire ||
      AbilityId.lacerate => 10.0,
      AbilityId.corruption ||
      AbilityId.unstableAffliction ||
      AbilityId.curseOfAgony ||
      AbilityId.immolateDemo ||
      AbilityId.immolateDestro ||
      AbilityId.flameShock ||
      AbilityId.shadowWordPain ||
      AbilityId.vampiricTouch ||
      AbilityId.devouringPlague => 12.0,
      AbilityId.bloodBoil ||
      AbilityId.bloodBoilUnholy ||
      AbilityId.heartStrike => 12.0,
      AbilityId.howlingBlast => 12.0,
      AbilityId.scourgeStrike => 10.0,
      _ => 9.0,
    };
    final dpsFrac = switch (def.id) {
      AbilityId.rip => 0.22,
      AbilityId.rake || AbilityId.garrote => 0.14,
      AbilityId.rupture => 0.18,
      AbilityId.serpentSting => 0.12,
      AbilityId.lacerate => 0.13,
      AbilityId.corruption => 0.18,
      AbilityId.unstableAffliction => 0.20,
      AbilityId.curseOfAgony => 0.17,
      AbilityId.shadowWordPain => 0.13,
      AbilityId.vampiricTouch => 0.14,
      AbilityId.devouringPlague => 0.16,
      AbilityId.immolateDemo ||
      AbilityId.immolateDestro ||
      AbilityId.flameShock => 0.15,
      AbilityId.moonfire => 0.11,
      AbilityId.bloodBoil || AbilityId.bloodBoilUnholy => 0.11,
      AbilityId.howlingBlast => 0.12,
      AbilityId.scourgeStrike || AbilityId.heartStrike => 0.10,
      _ => 0.12,
    };
    final dotMul = SpecMastery.dotTickMul(_masteryView(hero));
    final fromHit = raw * 0.08;
    final newDps = math.max(
      1.5,
      _abilityPower(hero, def) * dpsFrac * hero.kitOutMul * dotMul + fromHit,
    );
    // Affliction / Shadow: stacking DoTs add instead of fully overwriting.
    if (_isStackingDot(def) &&
        enemy.bleedTimer > 0.4 &&
        enemy.bleedCasterId == hero.id &&
        enemy.bleedAbilityId != def.id.name) {
      enemy.bleedDps = math.min(
        hero.attack * 0.62 * hero.kitOutMul,
        enemy.bleedDps + newDps * 0.55,
      );
      enemy.bleedTimer = math.max(enemy.bleedTimer, duration);
    } else {
      enemy.bleedTimer = duration;
      enemy.bleedDps = newDps;
      enemy.bleedAcc = 0;
    }
    enemy.bleedCasterId = hero.id;
    enemy.bleedAbilityId = def.id.name;
    if (def.id == AbilityId.rip) {
      SpatialCombat._spawnFloater(
        world,
        x: enemy.x,
        y: enemy.y - 0.55,
        text: 'RIP',
        argb: 0xFFC05050,
        life: 0.45,
      );
    }
  }

  static SpatialActor? _ownedCombatPet(SpatialWorld world, SpatialActor hero) {
    for (final p in world.pets) {
      if (p.hp > 0 && p.petOwnerId == hero.id) return p;
    }
    return null;
  }

  /// Abilities that gain a damage bump when the hero's combat pet is alive.
  static bool _petEmpoweredAbility(ClassAbilityDef def) {
    switch (def.id) {
      case AbilityId.killCommand ||
          AbilityId.shadowBolt ||
          AbilityId.handOfGuldan ||
          AbilityId.immolateDemo ||
          AbilityId.chaosBoltDemo:
        return true;
      default:
        return false;
    }
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
    String label, {
    bool beaconPeel = true,
  }) {
    final missing = ally.effectiveMaxHp <= 0
        ? 0.0
        : (1.0 - ally.hp / ally.effectiveMaxHp).clamp(0.0, 1.0);
    final healMul =
        SpecMastery.healMul(_masteryView(caster), missing) * caster.kitHealMul;
    final amount = math.max(
      4,
      (_healPower(caster) * coeff * healMul).round(),
    );
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
    if (!beaconPeel ||
        caster.beaconTimer <= 0 ||
        caster.beaconTargetId == null ||
        caster.beaconTargetId == ally.id) {
      return;
    }
    SpatialActor? marked;
    for (final h in world.heroes) {
      if (h.id == caster.beaconTargetId && h.isAlive && !h.isPet) {
        marked = h;
        break;
      }
    }
    if (marked == null) return;
    final peel = math.max(2, (amount * 0.4).round());
    final markedBefore = marked.hp;
    marked.hp = math.min(marked.effectiveMaxHp, marked.hp + peel);
    final peeled = marked.hp - markedBefore;
    if (peeled > 0) {
      caster.healingDone += peeled;
      SpatialCombat._spawnFloater(
        world,
        x: marked.x,
        y: marked.y - 0.55,
        text: '+$peeled',
        argb: 0xFFFFF0A8,
        life: 0.5,
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
    final amount = math.max(
      6,
      (_healPower(caster) *
              coeff *
              1.1 *
              caster.kitHealMul *
              SpecMastery.absorbStrengthMul(_masteryView(caster)))
          .round(),
    );
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
    final kind = def.selfBuffKind ?? AbilitySelfBuffKind.amp;
    final dur = def.selfBuffDuration > 0
        ? def.selfBuffDuration
        : switch (kind) {
            AbilitySelfBuffKind.haste => 6.0,
            AbilitySelfBuffKind.amp => 5.0,
            AbilitySelfBuffKind.healAmp => 8.0,
            AbilitySelfBuffKind.cleave => 6.0,
            AbilitySelfBuffKind.block => 6.0,
            AbilitySelfBuffKind.absorb => 3.0,
          };
    switch (kind) {
      case AbilitySelfBuffKind.haste:
        hero.powerInfusionTimer = math.max(hero.powerInfusionTimer, dur);
      case AbilitySelfBuffKind.amp:
        hero.combustionTimer = math.max(hero.combustionTimer, dur);
        hero.buffTimers['buff'] = dur;
      case AbilitySelfBuffKind.healAmp:
        hero.buffTimers['favor'] = dur;
      case AbilitySelfBuffKind.cleave:
        hero.bladeFlurryTimer = math.max(hero.bladeFlurryTimer, dur);
        hero.buffTimers['buff'] = dur;
      case AbilitySelfBuffKind.block:
        hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, dur);
        hero.buffTimers['shield'] = dur;
      case AbilitySelfBuffKind.absorb:
        hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, dur);
        hero.buffTimers['shield'] = dur;
    }
  }
}
