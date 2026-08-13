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
      // Hold Rip when a strong bleed is already rolling.
      if (d.id == AbilityId.rip &&
          focus != null &&
          focus.bleedTimer > 2.5) {
        return false;
      }
      // Rake refresh when bleed is missing/about to fall.
      if (d.id == AbilityId.rake &&
          focus != null &&
          focus.bleedTimer > 3.5) {
        return false;
      }
      // DoT maintain: don't refresh the same DoT while it has time left.
      if (_isMaintainDot(d) &&
          focus != null &&
          focus.bleedTimer > 3.5 &&
          focus.bleedAbilityId == d.id.name) {
        return false;
      }
      // Assassin Envenom wants combo points.
      if (d.id == AbilityId.envenom && hero.comboPoints < 3) {
        return false;
      }
      // Arcane Missiles dump when charged; hold early.
      if (d.id == AbilityId.arcaneMissiles && hero.arcaneCharges < 2) {
        return false;
      }
      // Frost Nova (SpecKit): pack peel, not single-target root spam.
      if (d.id == AbilityId.frostNovaMage) {
        final near = [
          for (final e in world.enemies)
            if (e.hp > 0 && !e.dormant && SpatialCombat._dist(hero, e) <= 2.4) e,
        ];
        final peel = near.any((e) => SpatialCombat._dist(hero, e) <= 1.6);
        if (near.length < 2 && !peel) return false;
      }
      // Sweeping Strikes wants a pack (or elite) to cleave into.
      if (d.id == AbilityId.sweepingStrikes) {
        if (nearby < 2 && !(nearby == 1 && focusElite)) return false;
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
        // Healers: prefer party/ST heals over enemy AoE when someone is hurt.
        if (def.isHealer && _partyNeedsHeal(world)) {
          final aHeal = a.effect == AbilityEffectKind.heal ||
              a.effect == AbilityEffectKind.absorb;
          final bHeal = b.effect == AbilityEffectKind.heal ||
              b.effect == AbilityEffectKind.absorb;
          if (aHeal != bHeal) return aHeal ? -1 : 1;
        }
        // DoT maintain before fillers when the focus has no DoT.
        if (focus != null && focus.bleedTimer < 2.0) {
          final aDot = _isMaintainDot(a);
          final bDot = _isMaintainDot(b);
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
    // Rampage keeps id furyExecute but is not an execute finisher.
    if (d.id == AbilityId.furyExecute) return false;
    if (d.id == AbilityId.armsExecute || d.id == AbilityId.hammerOfWrath) {
      return true;
    }
    final key = _abilityKey(d);
    return key.contains('arms execute') ||
        key.contains('hammer of wrath') ||
        key.contains('kill shot');
  }

  static bool _isMaintainDot(ClassAbilityDef d) => switch (d.id) {
        AbilityId.corruption ||
        AbilityId.unstableAffliction ||
        AbilityId.curseOfAgony ||
        AbilityId.shadowWordPain ||
        AbilityId.vampiricTouch ||
        AbilityId.devouringPlague ||
        AbilityId.moonfire ||
        AbilityId.immolateDemo ||
        AbilityId.immolateDestro ||
        AbilityId.serpentSting ||
        AbilityId.garrote ||
        AbilityId.rupture ||
        AbilityId.bloodBoil ||
        AbilityId.bloodBoilUnholy ||
        AbilityId.howlingBlast ||
        AbilityId.scourgeStrike ||
        AbilityId.heartStrike =>
          true,
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
        AbilityId.heartStrike =>
          true,
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

      // —— melee DPS (target ~1.22–1.30; Arms was wildly overtuned at 1.55) ——
      case AbilityId.armsStance:
        hero.kitOutMul *= 1.18;
        hero.kitInMul *= 1.04;
      case AbilityId.berserkerStance:
        hero.kitOutMul *= 1.30;
        hero.kitHasteMul *= 1.12;
        hero.kitInMul *= 1.06;
      case AbilityId.sealOfCommand:
        hero.kitOutMul *= 1.26;
      case AbilityId.improvedPoisons:
        hero.kitOutMul *= 1.36;
      case AbilityId.masterOfSubtlety:
        // Opener fantasy: damage + slight haste for ambush windows.
        hero.kitOutMul *= 1.34;
        hero.kitHasteMul *= 1.08;
      case AbilityId.frostPresence:
        hero.kitOutMul *= 1.26;
        hero.kitInMul *= 0.97;
      case AbilityId.unholyPresence:
        // Fairness: ghoul + diseases carry identity; presence is a lean, not a stomp.
        hero.kitOutMul *= 1.10;
        hero.kitHasteMul *= 1.10;
        // Ghoul companion spawned in SpatialCombat.build.
      case AbilityId.enhancementWeapons:
        hero.kitOutMul *= 1.26;
      case AbilityId.catForm:
        hero.kitOutMul *= 1.28;
        hero.kitHasteMul *= 1.10;

      // —— ranged (MM/Surv/BM were low share) ——
      case AbilityId.aspectOfHawk:
        hero.kitOutMul *= 1.28;
      case AbilityId.trueshotAura:
        hero.kitOutMul *= 1.36;
        hero.kitHasteMul *= 1.10;
      case AbilityId.trapMastery:
        hero.kitOutMul *= 1.40;
        hero.kitRootBonus += 1.0;

      // —— casters: identity buffs; spam tax is casterAbilityTax only ——
      // Mild trim so live-light gate stays inside ±20% (aff/demo/destro tip HIGH).
      case AbilityId.shadowform:
        hero.kitOutMul *= 1.02;
        hero.kitInMul *= 1.04;
      case AbilityId.elementalFocus:
        hero.kitOutMul *= 0.98;
        hero.kitHasteMul *= 1.04;
      case AbilityId.arcanePowerPassive:
        hero.kitOutMul *= 0.98;
      case AbilityId.frostArmor:
        hero.kitInMul *= 0.92;
        hero.kitOutMul *= 1.00;
        hero.kitRootBonus += 0.5;
      case AbilityId.soulSiphon:
        hero.kitOutMul *= 1.02;
        hero.kitHealMul *= 1.08;
      case AbilityId.demonicKnowledge:
        // Pet-family identity: modest personal power + haste; pet AA/empower carries share.
        hero.kitOutMul *= 0.90;
        hero.kitHasteMul *= 1.04;
      case AbilityId.cataclysm:
        hero.kitOutMul *= 0.95;
      case AbilityId.moonkinForm:
        hero.kitOutMul *= 0.96;

      // Legacy kit passives are handled in dedicated tickers.
      case AbilityId.defensiveStance:
      case AbilityId.revenge:
      case AbilityId.innerFire:
      case AbilityId.sinisterStrike:
        break;
      case AbilityId.arcaneIntellect:
        // Personal spell power is applied via GameState caster aura / kit path.
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
    if (def.id == AbilityId.armyOfDead) {
      _spendAndCd(world, hero, def);
      SpatialCombat.spawnTempPets(
        world,
        owner: hero,
        count: 4,
        duration: 16,
        atkScale: 0.30,
        namePrefix: 'Ghoul',
        idPrefix: 'army',
      );
      _castAoe(world, hero, focus, def, rng, reducedVfx: reducedVfx);
      return true;
    }
    if (def.id == AbilityId.feralSpirit) {
      _spendAndCd(world, hero, def);
      SpatialCombat.spawnTempPets(
        world,
        owner: hero,
        count: 2,
        duration: 30,
        atkScale: 0.42,
        namePrefix: 'Spirit Wolf',
        idPrefix: 'wolf',
      );
      _announce(world, hero, def.shortLabel, 0xFF90E0FF, reducedVfx);
      if (!reducedVfx) {
        SpatialCombat._spawnRing(
          world,
          x: hero.x,
          y: hero.y,
          argb: 0xFF90E0FF,
          radius: 0.95,
          life: 0.4,
        );
      }
      return true;
    }
    if (def.id == AbilityId.summonWaterElemental) {
      _spendAndCd(world, hero, def);
      SpatialCombat.spawnTempPets(
        world,
        owner: hero,
        count: 1,
        duration: 28,
        atkScale: 0.40,
        namePrefix: 'Water Elemental',
        idPrefix: 'water',
      );
      _announce(world, hero, def.shortLabel, 0xFF80D0FF, reducedVfx);
      if (!reducedVfx) {
        SpatialCombat._spawnRing(
          world,
          x: hero.x,
          y: hero.y,
          argb: 0xFF80D0FF,
          radius: 1.0,
          life: 0.45,
        );
      }
      return true;
    }
    // Shamanistic Rage: resource dump + short DR (copy promised both).
    if (def.id == AbilityId.shamanisticRage) {
      _spendAndCd(world, hero, def);
      final grant = def.coeff > 0 ? def.coeff : 30.0;
      SpatialCombat._gainRage(hero, grant);
      hero.shieldWallTimer = math.max(hero.shieldWallTimer, 4.0);
      hero.buffTimers['shield'] = 4.0;
      _announce(world, hero, def.shortLabel, 0xFFE0C040, reducedVfx);
      if (!reducedVfx) {
        SpatialCombat._spawnRing(
          world,
          x: hero.x,
          y: hero.y,
          argb: 0xFFE0A040,
          radius: 0.9,
          life: 0.4,
        );
      }
      return true;
    }
    // Real Ice Block immunity (not just Shield Wall DR).
    if (def.id == AbilityId.arcaneIceBlock ||
        def.id == AbilityId.frostMageIceBlock) {
      _spendAndCd(world, hero, def);
      hero.iceBlockTimer = math.max(hero.iceBlockTimer, 4.0);
      _announce(
        world,
        hero,
        def.shortLabel,
        0xFFA0E8FF,
        reducedVfx,
        important: true,
      );
      if (!reducedVfx) {
        SpatialCombat._spawnRing(
          world,
          x: hero.x,
          y: hero.y,
          argb: 0xAA80D0FF,
          radius: 1.0,
          life: 0.45,
        );
      }
      return true;
    }

    switch (def.effect) {
      case AbilityEffectKind.passive:
        return false;
      case AbilityEffectKind.damage:
        if (focus == null || focus.hp <= 0) return false;
        // Mongoose Bite is a melee snap — skip when out of reach.
        if (def.id == AbilityId.mongooseBite &&
            SpatialCombat._dist(hero, focus) > 1.85) {
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
          return true;
        }
        final ally = _lowestAlly(world, hero);
        if (ally == null) return false;
        _spendAndCd(world, hero, def);
        _castHeal(world, hero, ally, def, reducedVfx: reducedVfx);
        return true;
      case AbilityEffectKind.absorb:
        // Unholy AMS is a self shell — not a party bubble on the lowest ally.
        final ally = def.id == AbilityId.antiMagicShell
            ? hero
            : _lowestAlly(world, hero);
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
        if (def.id == AbilityId.slow) {
          if (focus == null || focus.hp <= 0) return false;
          _spendAndCd(world, hero, def);
          focus.attackSlowTimer =
              math.max(focus.attackSlowTimer, 4.0 + hero.kitRootBonus);
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
              if (e.hp > 0 &&
                  !e.dormant &&
                  SpatialCombat._dist(hero, e) <= 2.5)
                e,
          ];
          if (nearby.isEmpty) return false;
          if (def.id == AbilityId.frostNovaMage) {
            final peel =
                nearby.any((e) => SpatialCombat._dist(hero, e) <= 1.6);
            if (nearby.length < 2 && !peel) return false;
          }
          _spendAndCd(world, hero, def);
          final rootDur = 2.4 + hero.kitRootBonus;
          for (final e in nearby) {
            e.rootTimer = math.max(e.rootTimer, rootDur);
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
        defendTarget.shieldWallTimer =
            math.max(defendTarget.shieldWallTimer, 3.5);
        if (_actorIsTank(hero) && identical(defendTarget, hero)) {
          hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, 3.5);
          SpatialCombat._tauntLooseEnemies(
            world,
            hero,
            reducedVfx: reducedVfx,
          );
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
    var raw = math.max(
      2,
      (hero.attack * def.coeff * _abilityOutScale(hero)).round(),
    );
    // Damage amp window (Vendetta / Cold Blood / Arcane Power).
    if (hero.combustionTimer > 0) {
      raw = math.max(2, (raw * 1.22).round());
    }
    // Arcane Blast stacks; Missiles dump.
    if (def.id == AbilityId.arcaneBlast) {
      hero.arcaneCharges = math.min(4, hero.arcaneCharges + 1);
      raw = math.max(
        2,
        (raw * (1.0 + hero.arcaneCharges * 0.12)).round(),
      );
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
    final pet = _petEmpoweredAbility(def)
        ? _ownedCombatPet(world, hero)
        : null;
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
        def.id == AbilityId.shadowfury ||
        def.id == AbilityId.fireNova ||
        def.id == AbilityId.blastWave ||
        def.id == AbilityId.arcaneExplosion ||
        def.id == AbilityId.frostNova ||
        def.id == AbilityId.frostNovaMage ||
        def.id == AbilityId.bladeFlurry ||
        def.id == AbilityId.swipe ||
        def.id == AbilityId.handOfGuldan ||
        def.id == AbilityId.explosiveTrap ||
        def.vfx?.groundDisc == true ||
        SpatialCombat.groundDiscLifeFor(def.id) != null ||
        key.contains('consecrat') ||
        key.contains('bloodboil') ||
        key.contains('bladestorm') ||
        key.contains('whirlwind') ||
        key.contains('shadowfury')) {
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
      // Cone of Cold / chill AoE: slow attack cadence.
      if (def.id == AbilityId.coneOfCold) {
        e.attackSlowTimer = math.max(e.attackSlowTimer, 3.0);
      }

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
        // Disease DoTs apply on cast (bolt damage may land later).
        _applyBleedIfNeeded(world, hero, e, def, raw);
      } else {
        final wasAlive = e.hp > 0;
        final dealt = math.max(1, raw - e.effectiveDefense);
        e.hp = math.max(0, e.hp - dealt);
        SpatialCombat._recordHeroDamage(hero, dealt);
        SpatialCombat._applyTankSoftThreat(hero, e);
        _applyBleedIfNeeded(world, hero, e, def, raw);
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
        SpatialCombat._spawnRing(
          world,
          x: hero.x,
          y: hero.y,
          argb: 0xFFB060E0,
          radius: radius * 0.9,
          life: 0.55,
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
        );
      }
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
      _applyBleedIfNeeded(world, hero, e, def, raw);
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
    final style = SpatialCombat.boltStyleForAbility(caster, def: def);
    final tint = def.vfx?.castArgb ?? SpatialCombat.burstArgbForStyle(style);
    final isHot = def.id == AbilityId.riptide ||
        def.id == AbilityId.renew ||
        def.id == AbilityId.rejuvenation;
    final directCoeff = isHot ? def.coeff * 0.55 : def.coeff;
    _healLowest(world, caster, ally, directCoeff, def.shortLabel);
    if (isHot) {
      ally.buffTimers['hot'] = 12.0;
      ally.hotHps = math.max(
        ally.hotHps,
        math.max(2.0, caster.attack * 0.14 * caster.kitHealMul),
      );
      ally.hotAcc = 0;
    }
    _announce(world, caster, def.shortLabel, tint, reducedVfx);
    if (!reducedVfx) {
      SpatialCombat._spawnSpark(
        world,
        x: ally.x,
        y: ally.y,
        argb: tint,
        radius: 0.55,
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
      _healLowest(world, caster, ally, bounce, def.shortLabel);
      bounce *= 0.72;
    }
    _announce(
      world,
      caster,
      def.shortLabel,
      tint,
      reducedVfx,
    );
    if (!reducedVfx) {
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
      AbilityId.corruption ||
      AbilityId.unstableAffliction ||
      AbilityId.curseOfAgony ||
      AbilityId.moonfire ||
      AbilityId.immolateDemo ||
      AbilityId.immolateDestro ||
      AbilityId.shadowWordPain ||
      AbilityId.vampiricTouch ||
      AbilityId.devouringPlague ||
      AbilityId.bloodBoil ||
      AbilityId.bloodBoilUnholy ||
      AbilityId.howlingBlast ||
      AbilityId.scourgeStrike ||
      AbilityId.heartStrike =>
        true,
      _ => false,
    };
    if (!isBleed) return;
    final duration = switch (def.id) {
      AbilityId.rip => 12.0,
      AbilityId.rake || AbilityId.garrote => 8.0,
      AbilityId.serpentSting || AbilityId.moonfire => 10.0,
      AbilityId.corruption ||
      AbilityId.unstableAffliction ||
      AbilityId.curseOfAgony ||
      AbilityId.immolateDemo ||
      AbilityId.immolateDestro ||
      AbilityId.shadowWordPain ||
      AbilityId.vampiricTouch ||
      AbilityId.devouringPlague =>
        12.0,
      AbilityId.bloodBoil ||
      AbilityId.bloodBoilUnholy ||
      AbilityId.heartStrike =>
        12.0,
      AbilityId.howlingBlast => 12.0,
      AbilityId.scourgeStrike => 10.0,
      _ => 9.0,
    };
    final dpsFrac = switch (def.id) {
      AbilityId.rip => 0.22,
      AbilityId.rake || AbilityId.garrote => 0.14,
      AbilityId.rupture => 0.18,
      AbilityId.serpentSting => 0.12,
      AbilityId.corruption => 0.18,
      AbilityId.unstableAffliction => 0.20,
      AbilityId.curseOfAgony => 0.17,
      AbilityId.shadowWordPain => 0.13,
      AbilityId.vampiricTouch => 0.14,
      AbilityId.devouringPlague => 0.16,
      AbilityId.immolateDemo || AbilityId.immolateDestro => 0.15,
      AbilityId.moonfire => 0.11,
      AbilityId.bloodBoil || AbilityId.bloodBoilUnholy => 0.11,
      AbilityId.howlingBlast => 0.12,
      AbilityId.scourgeStrike || AbilityId.heartStrike => 0.10,
      _ => 0.12,
    };
    final fromHit = raw * 0.08;
    final newDps =
        math.max(1.5, hero.attack * dpsFrac * hero.kitOutMul + fromHit);
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
    // Explicit damage-amp windows (not Fire-only — Assa / Arcane use this too).
    if (def.id == AbilityId.vendetta ||
        def.id == AbilityId.coldBlood ||
        def.id == AbilityId.arcanePower ||
        def.id == AbilityId.combustion ||
        def.id == AbilityId.furyRecklessness) {
      final dur = switch (def.id) {
        AbilityId.vendetta => 8.0,
        AbilityId.coldBlood => 6.0,
        AbilityId.arcanePower => 7.0,
        AbilityId.furyRecklessness => 8.0,
        _ => 5.0,
      };
      hero.combustionTimer = math.max(hero.combustionTimer, dur);
      hero.buffTimers['buff'] = dur;
      return;
    }
    // Arms Sweeping Strikes — same cleave window as Combat Blade Flurry.
    if (def.id == AbilityId.sweepingStrikes) {
      hero.bladeFlurryTimer = math.max(hero.bladeFlurryTimer, 6.0);
      hero.buffTimers['buff'] = 6.0;
      return;
    }
    // Prot Paladin Holy Shield — block window, not a panic wall.
    if (def.id == AbilityId.holyShield) {
      hero.shieldBlockTimer = math.max(hero.shieldBlockTimer, 6.0);
      hero.buffTimers['shield'] = 6.0;
      return;
    }
    // Prefer existing haste / shield timers when possible.
    final name = def.id.name.toLowerCase();
    if (name.contains('haste') ||
        name.contains('rapid') ||
        name.contains('zeal') ||
        name.contains('enrage') ||
        name.contains('berserk') ||
        name.contains('wrath') ||
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
        name.contains('spirit') ||
        name.contains('gargoyle') ||
        name.contains('charge') ||
        name.contains('step') ||
        name.contains('sprint') ||
        name.contains('disengage')) {
      // One haste channel only — stacking PI × buffTimers['haste'] was ~1.79×.
      // Note: Arcane Power is damage amp above — do not match bare "power".
      hero.powerInfusionTimer = math.max(hero.powerInfusionTimer, 6.0);
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
  }
}
