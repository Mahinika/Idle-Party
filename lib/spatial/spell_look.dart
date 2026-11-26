part of 'spatial_combat.dart';

SpellBoltStyle? spellBoltStyleForAbilityId(AbilityId id) {
  return switch (id) {
    // —— Fire ——
    AbilityId.immolateDemo ||
    AbilityId.immolateDestro ||
    AbilityId.incinerate ||
    AbilityId.conflagrate ||
    AbilityId.chaosBolt ||
    AbilityId.chaosBoltDemo ||
    AbilityId.lavaBurst ||
    AbilityId.flameShock ||
    AbilityId.rainOfFire ||
    AbilityId.lavaLash ||
    AbilityId.fireNova ||
    AbilityId.blastWave ||
    AbilityId.livingBomb ||
    AbilityId.fireball ||
    AbilityId.pyroblast ||
    AbilityId.combustion ||
    AbilityId.explosiveTrap ||
    AbilityId.explosiveShot ||
    AbilityId.wildfireBomb ||
    AbilityId.fireElemental ||
    AbilityId.meteor => SpellBoltStyle.fire,

    // —— Frost ——
    AbilityId.frostShock ||
    AbilityId.howlingBlast ||
    AbilityId.frostbolt ||
    AbilityId.iceLance ||
    AbilityId.coneOfCold ||
    AbilityId.blizzard ||
    AbilityId.frostNova ||
    AbilityId.frostNovaMage ||
    AbilityId.hungeringCold ||
    AbilityId.chainsOfIce ||
    AbilityId.frostStrike ||
    AbilityId.freezingTrap ||
    AbilityId.iceBlock ||
    AbilityId.frozenOrb ||
    AbilityId.breathOfSindragosa ||
    AbilityId.empowerRuneWeapon ||
    AbilityId.iceBarrierFrost ||
    AbilityId.frostMageConeOfCold => SpellBoltStyle.frost,

    // —— Lightning ——
    AbilityId.thunderClap ||
    AbilityId.chainLightning ||
    AbilityId.lightningBolt ||
    AbilityId.thunderstorm ||
    AbilityId.earthShock ||
    AbilityId.stormstrike ||
    AbilityId.crashLightning => SpellBoltStyle.lightning,

    // —— Holy ——
    AbilityId.holyPriestNova ||
    AbilityId.holyWrath ||
    AbilityId.divineStorm ||
    AbilityId.consecration ||
    AbilityId.consecrationHoly ||
    AbilityId.hammerOfWrath ||
    AbilityId.holyShock ||
    AbilityId.hammerOfTheRighteous ||
    AbilityId.judgment ||
    AbilityId.crusaderStrike ||
    AbilityId.templarsVerdict ||
    AbilityId.avengersShield ||
    AbilityId.shieldOfRighteousness ||
    AbilityId.penance ||
    AbilityId.flashHeal ||
    AbilityId.flashOfLight ||
    AbilityId.holyLight ||
    AbilityId.divineHymn ||
    AbilityId.circleOfHealing ||
    AbilityId.powerWordShield ||
    AbilityId.prayerOfMending ||
    AbilityId.renew ||
    AbilityId.guardianSpirit ||
    AbilityId.beaconOfLight ||
    AbilityId.layOnHands ||
    AbilityId.lightOfDawn ||
    AbilityId.hammerOfJusticeHoly ||
    AbilityId.ardentDefender ||
    AbilityId.wordOfGloryProt ||
    AbilityId.consecrationRet ||
    AbilityId.hammerOfJusticeRet ||
    AbilityId.wordOfGloryRet ||
    AbilityId.powerWordBarrier ||
    AbilityId.halo ||
    AbilityId.holyFire ||
    AbilityId.holyWordSanctify ||
    AbilityId.prayerOfMendingHoly => SpellBoltStyle.holy,

    // —— Nature (resto sham / balance / resto druid) ——
    AbilityId.hurricane ||
    AbilityId.starfall ||
    AbilityId.starfire ||
    AbilityId.wrath ||
    AbilityId.moonfire ||
    AbilityId.insectSwarm ||
    AbilityId.typhoon ||
    AbilityId.riptide ||
    AbilityId.healingWave ||
    AbilityId.chainHeal ||
    AbilityId.earthShield ||
    AbilityId.healingRain ||
    AbilityId.spiritLink ||
    AbilityId.natureSwiftness ||
    AbilityId.rejuvenation ||
    AbilityId.regrowth ||
    AbilityId.wildGrowth ||
    AbilityId.lifebloom ||
    AbilityId.nourish ||
    AbilityId.tranquility ||
    AbilityId.healingSurge ||
    AbilityId.healingTideTotem ||
    AbilityId.earthbindTotem ||
    AbilityId.manaTideTotem ||
    AbilityId.starsurge ||
    AbilityId.forceOfNature ||
    AbilityId.ironbark ||
    AbilityId.innervateDruid ||
    AbilityId.entanglingRoots => SpellBoltStyle.nature,

    // —— Poison (rogue toxins / hunter sting) ——
    AbilityId.envenom ||
    AbilityId.garrote ||
    AbilityId.serpentSting ||
    AbilityId.crimsonVial => SpellBoltStyle.poison,

    // —— Arcane ——
    AbilityId.arcaneBlast ||
    AbilityId.arcaneMissiles ||
    AbilityId.arcaneExplosion ||
    AbilityId.arcanePower ||
    AbilityId.slow ||
    AbilityId.antiMagicShell ||
    AbilityId.boneShield ||
    AbilityId.presenceOfMind ||
    AbilityId.arcaneBarrage ||
    AbilityId.prismaticBarrier ||
    AbilityId.evocation => SpellBoltStyle.arcane,

    // —— Arrow (hunter ranged) ——
    AbilityId.arcaneShot ||
    AbilityId.multiShot ||
    AbilityId.multiShotSurv ||
    AbilityId.aimedShot ||
    AbilityId.steadyShot ||
    AbilityId.chimeraShot ||
    AbilityId.volley ||
    AbilityId.killCommand ||
    AbilityId.blackArrow ||
    AbilityId.bestialWrath ||
    AbilityId.stampede ||
    AbilityId.killShotBm ||
    AbilityId.killShotMm ||
    AbilityId.bindingShot ||
    AbilityId.harpoonSurvival => SpellBoltStyle.arrow,

    AbilityId.handOfGuldan ||
    AbilityId.callDreadstalkers ||
    AbilityId.soulFireDemo ||
    AbilityId.summonInfernal ||
    AbilityId.shadowburn => SpellBoltStyle.demon,

    // —— Shadow ——
    AbilityId.shadowBolt ||
    AbilityId.haunt ||
    AbilityId.hauntBurst ||
    AbilityId.corruption ||
    AbilityId.unstableAffliction ||
    AbilityId.drainLife ||
    AbilityId.mindBlast ||
    AbilityId.mindFlay ||
    AbilityId.mindSear ||
    AbilityId.devouringPlague ||
    AbilityId.shadowWordPain ||
    AbilityId.shadowfury ||
    AbilityId.seedOfCorruption ||
    AbilityId.fanOfKnivesSub ||
    AbilityId.deathCoil ||
    AbilityId.vampiricTouch ||
    AbilityId.curseOfAgony ||
    AbilityId.armyOfDead ||
    AbilityId.gargoyle ||
    AbilityId.runeTap ||
    AbilityId.psychicScream ||
    AbilityId.secretTechnique ||
    AbilityId.shadowfiendDisc ||
    AbilityId.shadowWordDeath ||
    AbilityId.shadowfiendShadow ||
    AbilityId.soulReaper ||
    AbilityId.darkTransformation ||
    AbilityId.darkSoul ||
    AbilityId.howlOfTerror => SpellBoltStyle.shadow,

    // —— Weapon / physical ——
    AbilityId.bladestorm ||
    AbilityId.whirlwind ||
    AbilityId.mortalStrike ||
    AbilityId.bloodthirst ||
    AbilityId.obliterate ||
    AbilityId.heartStrike ||
    AbilityId.deathStrike ||
    AbilityId.scourgeStrike ||
    AbilityId.bloodBoil ||
    AbilityId.bloodBoilUnholy ||
    AbilityId.cheapShot ||
    AbilityId.kidneyShot ||
    AbilityId.killingSpree ||
    AbilityId.mongooseBite ||
    AbilityId.fanOfKnives ||
    AbilityId.shred ||
    AbilityId.rake ||
    AbilityId.ferociousBite ||
    AbilityId.rip ||
    AbilityId.mangleBear ||
    AbilityId.swipe ||
    AbilityId.feralSwipe ||
    AbilityId.lacerate ||
    AbilityId.maul ||
    AbilityId.overpower ||
    AbilityId.rend ||
    AbilityId.armsExecute ||
    AbilityId.ragingBlow ||
    AbilityId.furyExecute ||
    AbilityId.devastate ||
    AbilityId.shieldSlam ||
    AbilityId.revenge ||
    AbilityId.shockwave ||
    AbilityId.eviscerate ||
    AbilityId.sinisterStrike ||
    AbilityId.bladeFlurry ||
    AbilityId.hemorrhage ||
    AbilityId.backstab ||
    AbilityId.sweepingStrikes ||
    AbilityId.colossusSmash ||
    AbilityId.dieByTheSword ||
    AbilityId.executeFury ||
    AbilityId.piercingHowl ||
    AbilityId.claw ||
    AbilityId.kidneyShotAssa ||
    AbilityId.adrenalineRush ||
    AbilityId.revealingStrike ||
    AbilityId.maim => SpellBoltStyle.weapon,
    _ => null,
  };
}


/// Lasting ground disc defaults for signature AOEs (life seconds).
double? spellGroundDiscLifeFor(AbilityId id) {
  return switch (id) {
    AbilityId.consecration || AbilityId.consecrationHoly => 6.0,
    AbilityId.healingRain || AbilityId.tranquility => 5.5,
    AbilityId.explosiveTrap => 4.0,
    AbilityId.handOfGuldan || AbilityId.wildGrowth => 3.5,
    AbilityId.earthquake ||
    AbilityId.deathAndDecayBlood ||
    AbilityId.deathAndDecayUnholy => 4.0,
    AbilityId.flamestrike || AbilityId.magmaTotem => 3.2,
    AbilityId.bladestorm ||
    AbilityId.bladeFlurry ||
    AbilityId.divineStorm => 3.2,
    AbilityId.spiritLink || AbilityId.mindSear => 3.0,
    AbilityId.bloodBoil ||
    AbilityId.bloodBoilUnholy ||
    AbilityId.whirlwind ||
    AbilityId.holyPriestNova ||
    AbilityId.circleOfHealing => 2.5,
    AbilityId.armyOfDead => 2.5,
    AbilityId.holyWrath || AbilityId.hungeringCold => 2.2,
    AbilityId.fireNova ||
    AbilityId.frostNova ||
    AbilityId.frostNovaMage ||
    AbilityId.thunderClap => 2.2,
    AbilityId.seedOfCorruption => 2.0,
    AbilityId.killingSpree => 2.0,
    AbilityId.blastWave ||
    AbilityId.shockwave ||
    AbilityId.arcaneExplosion ||
    AbilityId.shadowfury => 1.6,
    AbilityId.swipe ||
    AbilityId.feralSwipe ||
    AbilityId.fanOfKnives ||
    AbilityId.fanOfKnivesSub ||
    AbilityId.fanOfKnivesCombat ||
    AbilityId.feralThrash ||
    AbilityId.guardianThrash => 1.5,
    AbilityId.consecrationRet => 6.0,
    AbilityId.bindingShot => 2.2,
    AbilityId.wildfireBomb => 3.5,
    AbilityId.powerWordBarrier => 3.0,
    AbilityId.halo => 2.5,
    AbilityId.holyWordSanctify => 2.8,
    AbilityId.frozenOrb => 3.0,
    AbilityId.healingTideTotem => 3.5,
    AbilityId.earthbindTotem => 2.0,
    AbilityId.meteor => 3.2,
    AbilityId.summonInfernal => 3.5,
    AbilityId.entanglingRoots => 2.2,
    _ => null,
  };
}

