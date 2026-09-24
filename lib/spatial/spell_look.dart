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
    AbilityId.explosiveShot => SpellBoltStyle.fire,

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
    AbilityId.iceBlock => SpellBoltStyle.frost,

    // —— Lightning ——
    AbilityId.thunderClap ||
    AbilityId.chainLightning ||
    AbilityId.lightningBolt ||
    AbilityId.thunderstorm ||
    AbilityId.earthShock ||
    AbilityId.stormstrike => SpellBoltStyle.lightning,

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
    AbilityId.layOnHands => SpellBoltStyle.holy,

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
    AbilityId.tranquility => SpellBoltStyle.nature,

    // —— Poison (rogue toxins / hunter sting) ——
    AbilityId.envenom ||
    AbilityId.garrote ||
    AbilityId.serpentSting => SpellBoltStyle.poison,

    // —— Arcane ——
    AbilityId.arcaneBlast ||
    AbilityId.arcaneMissiles ||
    AbilityId.arcaneExplosion ||
    AbilityId.arcanePower ||
    AbilityId.slow ||
    AbilityId.antiMagicShell ||
    AbilityId.boneShield ||
    AbilityId.presenceOfMind => SpellBoltStyle.arcane,

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
    AbilityId.bestialWrath => SpellBoltStyle.arrow,

    AbilityId.handOfGuldan => SpellBoltStyle.demon,

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
    AbilityId.psychicScream => SpellBoltStyle.shadow,

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
    AbilityId.sweepingStrikes => SpellBoltStyle.weapon,
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
    _ => null,
  };
}

