part of 'spatial_combat.dart';

/// Incoming damage to a hero after mitigation / absorbs.
int combatApplyHeroIncomingDamage(
  SpatialWorld world,
  SpatialActor hero,
  int rawDamage, {
  required bool reducedVfx,
  required math.Random rng,
  bool isMelee = true,
}) {
  if (hero.iceBlockTimer > 0 || hero.vanishTimer > 0) {
    if (!reducedVfx) {
      SpatialCombat.spawnFloater(
        world,
        x: hero.x,
        y: hero.y - 0.45,
        text: hero.iceBlockTimer > 0 ? 'ICE BLOCK' : 'MISS',
        argb: 0xFFA0D8FF,
        life: 0.35,
      );
    }
    return 0;
  }

  var dealt = rawDamage;
  var blocked = false;

  if (isMelee && dealt > 0) {
    final avoid = CombatAvoidance.resolveIncomingMelee(
      rawDamage: dealt,
      dodgePercent: hero.dodgePercent,
      parryPercent: hero.parryPercent,
      blockChance: hero.blockChance,
      blockValue: hero.blockValue,
      shieldBlockActive: hero.shieldBlockTimer > 0,
      rng: rng,
    );
    dealt = avoid.damage;
    blocked = avoid.blocked;
    if (avoid.avoided && !reducedVfx) {
      SpatialCombat.spawnFloater(
        world,
        x: hero.x,
        y: hero.y - 0.45,
        text: avoid.dodged ? 'DODGE' : 'PARRY',
        argb: 0xFF90E0A0,
        life: 0.35,
      );
    }
    if (blocked &&
        hero.shieldBlockTimer > 0 &&
        WarriorAbilities.isUnlocked(AbilityId.revenge, hero.heroLevel)) {
      hero.revengeReady = true;
    }
  }

  if (dealt <= 0) return 0;

  var mul = hero.kitInMul;
  if (hero.shieldWallTimer > 0) {
    mul *= 0.45;
  }
  if (hero.painSuppressionTimer > 0) {
    mul *= 0.55;
  }
  // Active Shield Block window stacks DR on top of mastery block (−30%).
  if (hero.shieldBlockTimer > 0 && !blocked) {
    mul *= 0.55;
    blocked = true;
    if (WarriorAbilities.isUnlocked(AbilityId.revenge, hero.heroLevel)) {
      hero.revengeReady = true;
    }
  }
  dealt = math.max(1, (dealt * mul).round());
  if (world.petMitigateFlat > 0) {
    dealt = math.max(1, dealt - world.petMitigateFlat);
  }
  var held = 0;
  if (hero.absorbShield > 0) {
    final absorbed = math.min(hero.absorbShield, dealt);
    hero.absorbShield -= absorbed;
    dealt -= absorbed;
    held += absorbed;
    if (!reducedVfx && absorbed > 0) {
      SpatialCombat.spawnFloater(
        world,
        x: hero.x,
        y: hero.y - 0.5,
        text: 'ABSORB $absorbed',
        argb: 0xFF80C0FF,
        life: 0.4,
      );
    }
    if (dealt <= 0) {
      SpatialCombat._recordHeroTaken(hero, held);
      return absorbed;
    }
  }
  hero.hp = math.max(0, hero.hp - dealt);
  held += dealt;
  SpatialCombat._recordHeroTaken(hero, held);
  hero.spiritRegenPaused = 5.0;
  if (dealt > 0) {
    hero.hitFlash = math.max(hero.hitFlash, 0.14);
    SpatialCombat._triggerPrayerOfMending(world, hero);
  }
  if (actorIsTank(hero) || _actorResource(hero) == SpecResource.rage) {
    SpatialCombat.gainRage(hero, 2.5 + dealt * 0.35);
  }
  if (blocked) {
    SpatialCombat.spawnFloater(
      world,
      x: hero.x,
      y: hero.y - 0.45,
      text: 'BLOCK',
      argb: 0xFF9AD0FF,
      life: 0.4,
      priority: 2,
    );
  }
  if (dealt > 0) {
    CombatPresence.onLowHp(world, hero, reducedVfx: reducedVfx);
  }
  return dealt;
}

/// Warrior attack modifiers: Defensive Stance, Shield Slam, Revenge.
({int damage, String? tag, int tagArgb}) combatWarriorAttackMods(
  SpatialActor warrior,
  int baseDamage,
) {
  var damage = baseDamage;
  String? tag;
  var tagArgb = SpatialCombat.floaterDamage;

  // Defensive Stance itself is a kit passive (kitOutMul / kitInMul); the
  // caller folds kitOutMul in, so only the swing riders live here.
  if (warrior.revengeReady &&
      WarriorAbilities.isUnlocked(AbilityId.revenge, warrior.heroLevel)) {
    final def = WarriorAbilities.defFor(AbilityId.revenge)!;
    if (warrior.rage + 0.001 >= def.resourceCost) {
      SpatialCombat.spendRage(warrior, def.resourceCost);
      warrior.revengeReady = false;
      damage = (damage * 1.85).round();
      tag = 'REVENGE';
      tagArgb = 0xFFFF9060;
      return (damage: damage, tag: tag, tagArgb: tagArgb);
    }
  }

  if (warrior.queuedShieldSlam) {
    warrior.queuedShieldSlam = false;
    damage = (damage * 1.65).round();
    tag = 'SLAM';
    tagArgb = 0xFFFFD070;
    SpatialCombat.gainRage(warrior, 10);
  }

  return (damage: damage, tag: tag, tagArgb: tagArgb);
}

({int damage, String? tag, int tagArgb}) combatClassAttackMods(
  SpatialWorld world,
  SpatialActor hero,
  int baseDamage,
) {
  // Protection-only auto mods (Revenge / Shield Slam / Defensive Stance).
  // Other warrior-legacy DPS use ClassKits + kitOutMul only.
  if (hero.heroSpecId == HeroSpecId.protection) {
    final w = combatWarriorAttackMods(hero, baseDamage);
    var scaled = math.max(1, (w.damage * hero.kitOutMul).round());
    if ((hero.buffTimers['atkShout'] ?? 0) > 0) {
      scaled = math.max(1, (scaled * 1.08).round());
    }
    return (damage: scaled, tag: w.tag, tagArgb: w.tagArgb);
  }
  var damage = math.max(1, (baseDamage * hero.kitOutMul).round());
  String? tag;
  var tagArgb = SpatialCombat.floaterDamage;

  if ((hero.buffTimers['atkShout'] ?? 0) > 0) {
    damage = math.max(1, (damage * 1.08).round());
  }
  // Vendetta / Cold Blood / Arcane Power / Combustion amp whites + kit AA.
  if (hero.combustionTimer > 0 && hero.heroSpecId != HeroSpecId.fire) {
    damage = math.max(1, (damage * 1.25).round());
    tag ??= 'AMP';
    tagArgb = 0xFFFF6060;
  }

  if (hero.heroSpecId == HeroSpecId.combat ||
      hero.heroSpecId == HeroSpecId.subtlety) {
    final buildsCombo = hero.heroSpecId == HeroSpecId.combat
        ? ClassKits.isUnlocked(AbilityId.sinisterStrike, hero.heroLevel)
        : ClassKits.isUnlocked(AbilityId.masterOfSubtlety, hero.heroLevel);
    if (buildsCombo) {
      hero.comboPoints = math.min(5, hero.comboPoints + 1);
    }
    final evisId = hero.heroSpecId == HeroSpecId.subtlety
        ? AbilityId.eviscerateSub
        : AbilityId.eviscerate;
    final evisDef = ClassKits.defFor(evisId);
    if (hero.comboPoints >= 4 &&
        evisDef != null &&
        hero.heroLevel >= evisDef.unlockLevel &&
        hero.rage + 0.001 >= evisDef.resourceCost &&
        SpatialCombat.abilityCdLeft(hero, evisId) <= 0) {
      SpatialCombat.spendRage(hero, evisDef.resourceCost);
      SpatialCombat.startAbilityCd(world, hero, evisId, evisDef.cooldown);
      final pts = hero.comboPoints;
      hero.comboPoints = 0;
      damage = (damage * (1.2 + pts * 0.35)).round();
      tag = 'EVIS';
      tagArgb = 0xFFFF4060;
    }
  }

  if (hero.setProcChance > 0 &&
      GameLogic.random.nextDouble() < hero.setProcChance) {
    damage = math.max(1, (damage * 1.35).round());
    tag = hero.setProcTag ?? 'SET';
    tagArgb = hero.setProcArgb;
  }

  // Spec mastery white-hit procs (Arms / MM / Combat). Skip finishers.
  if (tag != 'EVIS') {
    final mastery = masteryView(hero);
    final roll = GameLogic.random.nextDouble();
    switch (hero.heroSpecId) {
      case HeroSpecId.arms:
        final chance = SpecMastery.extraSwingProcChance(mastery);
        if (chance > 0 && roll < chance) {
          damage = math.max(1, (damage * 2.0).round());
          tag = 'SWING';
          tagArgb = 0xFFFFC060;
        }
      case HeroSpecId.marksmanship:
        final chance = SpecMastery.extraAutoShotProcChance(mastery);
        if (chance > 0 && roll < chance) {
          damage = math.max(1, (damage * 2.0).round());
          tag = 'WILD QUIVER';
          tagArgb = 0xFF80E080;
        }
      case HeroSpecId.combat:
        final chance = SpecMastery.mainGaucheProcChance(mastery);
        if (chance > 0 && roll < chance) {
          damage = math.max(1, (damage * 1.55).round());
          tag ??= 'MAIN GAUCHE';
          tagArgb = 0xFFFF9060;
        }
      default:
        break;
    }
  }

  return (damage: damage, tag: tag, tagArgb: tagArgb);
}

/// Apply damage to an enemy and flash the sprite so hits read on phone.
int combatHurtEnemy(SpatialActor enemy, int dealt, {bool soft = false}) {
  if (dealt <= 0 || enemy.team != SpatialTeam.enemy) return 0;
  enemy.hp = math.max(0, enemy.hp - dealt);
  final life = soft
      ? 0.07
      : (enemy.role == EnemyRole.boss ? 0.16 : 0.11);
  enemy.hitFlash = math.max(enemy.hitFlash, life);
  return dealt;
}
