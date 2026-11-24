part of 'spatial_combat.dart';

/// Spell-shaped combat VFX — burst/ground kinds from bolt style + AoE shape.
///
/// Combat still resolves in [AbilityEffectRunner]; this only paints identity
/// so Fireball reads as fire, Chain Lightning as hops, Consecration as holy
/// ground — not a generic tinted ring.
abstract final class SpellVfx {
  static SpatialBurstKind burstKindFor({
    required SpellBoltStyle style,
    AbilityAoeShape? shape,
    AbilityId? id,
  }) {
    if (id != null) {
      final byId = _burstKindForId(id);
      if (byId != null) return byId;
    }
    if (shape == AbilityAoeShape.rain) return SpatialBurstKind.rain;
    if (shape == AbilityAoeShape.chain) return SpatialBurstKind.beam;
    if (shape == AbilityAoeShape.fan) return SpatialBurstKind.cone;
    return burstKindForStyle(style);
  }

  static SpatialBurstKind burstKindForStyle(SpellBoltStyle style) =>
      switch (style) {
        SpellBoltStyle.fire => SpatialBurstKind.flame,
        SpellBoltStyle.frost => SpatialBurstKind.shards,
        SpellBoltStyle.holy => SpatialBurstKind.cross,
        SpellBoltStyle.lightning => SpatialBurstKind.beam,
        SpellBoltStyle.nature => SpatialBurstKind.leaf,
        SpellBoltStyle.poison => SpatialBurstKind.poison,
        SpellBoltStyle.shadow => SpatialBurstKind.skull,
        SpellBoltStyle.demon => SpatialBurstKind.skull,
        SpellBoltStyle.arcane => SpatialBurstKind.spark,
        SpellBoltStyle.arrow => SpatialBurstKind.spark,
        SpellBoltStyle.weapon => SpatialBurstKind.slash,
      };

  static SpatialGroundFxKind groundKindFor({
    required SpellBoltStyle style,
    AbilityId? id,
  }) {
    if (id != null) {
      final byId = _groundKindForId(id);
      if (byId != null) return byId;
    }
    return groundKindForStyle(style);
  }

  static SpatialGroundFxKind groundKindForStyle(SpellBoltStyle style) =>
      switch (style) {
        SpellBoltStyle.holy => SpatialGroundFxKind.holy,
        SpellBoltStyle.frost => SpatialGroundFxKind.frost,
        SpellBoltStyle.fire => SpatialGroundFxKind.fire,
        SpellBoltStyle.nature => SpatialGroundFxKind.nature,
        SpellBoltStyle.poison => SpatialGroundFxKind.poison,
        SpellBoltStyle.shadow => SpatialGroundFxKind.shadow,
        SpellBoltStyle.demon => SpatialGroundFxKind.shadow,
        SpellBoltStyle.lightning => SpatialGroundFxKind.rain,
        SpellBoltStyle.weapon => SpatialGroundFxKind.steel,
        SpellBoltStyle.arrow => SpatialGroundFxKind.disc,
        SpellBoltStyle.arcane => SpatialGroundFxKind.disc,
      };

  /// How long a signature impact stays up. Shorter than a routine hit so a
  /// 2× fight does not stack soft discs. The school shape is unchanged.
  static const double bigImpactLife = 0.34;

  /// Cast flash above this still draws the opening glint. The sim starts the
  /// lockout and the bolt together, so the glint is that opening and then
  /// stops. It is paint only: no second burst.
  static const double castGlintFloor = 0.2;

  static bool castGlintVisible({
    required bool reduceMotion,
    required double castFlash,
  }) => !reduceMotion && castFlash > castGlintFloor;

  /// Signature nukes read bigger than a routine hit.
  static bool isBig(AbilityId? id) => switch (id) {
    AbilityId.pyroblast ||
    AbilityId.chaosBolt ||
    AbilityId.chaosBoltDemo ||
    AbilityId.starfall ||
    AbilityId.holyWrath ||
    AbilityId.bladestorm ||
    AbilityId.deathCoil ||
        AbilityId.meteor => true,
    _ => false,
  };

  static bool _showBursts(SpatialWorld world) => !world.reducedVfx;

  /// Full and Lite. Minimal (and offline, which forces Minimal) stays still.
  static bool _showSparks(SpatialWorld world) =>
      !world.reducedVfx || world.spawnPersistentVfx;

  /// Caster pop when a spell goes off.
  static void spawnCast(
    SpatialWorld world, {
    required SpatialActor hero,
    required SpellBoltStyle style,
    AbilityAoeShape? shape,
    AbilityId? id,
    double radius = 0.7,
  }) {
    if (!_showSparks(world)) return;
    final punch = isBig(id);
    final r = punch ? radius * 1.5 : radius;
    final life = punch ? 0.72 : 0.55;
    if (_showBursts(world)) {
      final argb = SpatialCombat.burstArgbForStyle(style);
      final kind = burstKindFor(style: style, shape: shape, id: id);
      SpatialCombat.spawnBurst(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: r,
        kind: kind,
        life: life,
      );
      if (kind == SpatialBurstKind.flame ||
          kind == SpatialBurstKind.cross ||
          kind == SpatialBurstKind.shards) {
        SpatialCombat.spawnRing(
          world,
          x: hero.x,
          y: hero.y,
          argb: argb,
          radius: r * 0.85,
          life: punch ? 0.42 : 0.32,
        );
      }
    }
    SpellSparks.puff(
      world,
      x: hero.x,
      y: hero.y,
      style: style,
      count: punch ? 9 : 5,
    );
  }

  /// Hit spark that matches the spell, not a generic disc.
  static void spawnImpact(
    SpatialWorld world, {
    required double x,
    required double y,
    required SpellBoltStyle style,
    AbilityAoeShape? shape,
    AbilityId? id,
    double radius = 0.55,
    double? x2,
    double? y2,
  }) {
    if (!_showSparks(world)) return;
    final punch = isBig(id);
    final r = punch ? radius * 1.5 : radius;
    final life = punch ? bigImpactLife : 0.52;
    if (_showBursts(world)) {
      final argb = SpatialCombat.burstArgbForStyle(style);
      final kind = burstKindFor(style: style, shape: shape, id: id);
      SpatialCombat.spawnBurst(
        world,
        x: x,
        y: y,
        argb: argb,
        radius: r,
        kind: kind,
        life: life,
        crisp: punch,
        x2: x2,
        y2: y2,
        paintId: id,
      );
    }
    SpellSparks.puff(world, x: x, y: y, style: style, count: punch ? 9 : 6);
  }

  static void spawnBeam(
    SpatialWorld world, {
    required double x,
    required double y,
    required double x2,
    required double y2,
    required int argb,
    double radius = 0.35,
    double life = 0.36,
  }) {
    if (world.reducedVfx) return;
    SpatialCombat.spawnBurst(
      world,
      x: x,
      y: y,
      x2: x2,
      y2: y2,
      argb: argb,
      radius: radius,
      kind: SpatialBurstKind.beam,
      life: life,
    );
  }

  static SpatialBurstKind? _burstKindForId(AbilityId id) => switch (id) {
    AbilityId.chainLightning ||
    AbilityId.lightningBolt ||
    AbilityId.stormstrike ||
    AbilityId.thunderstorm ||
    AbilityId.holyShock ||
    AbilityId.penance => SpatialBurstKind.beam,
    AbilityId.thunderClap || AbilityId.earthquake => SpatialBurstKind.ring,
    AbilityId.hurricane ||
    AbilityId.blizzard ||
    AbilityId.starfall ||
    AbilityId.healingRain ||
    AbilityId.volley ||
    AbilityId.rainOfFire ||
    AbilityId.multiShot ||
    AbilityId.multiShotMm => SpatialBurstKind.rain,
    AbilityId.howlingBlast ||
    AbilityId.frostNova ||
    AbilityId.frostNovaMage ||
    AbilityId.coneOfCold ||
    AbilityId.iceLance ||
    AbilityId.hungeringCold => SpatialBurstKind.shards,
    AbilityId.fireball ||
    AbilityId.pyroblast ||
    AbilityId.immolateDemo ||
    AbilityId.immolateDestro ||
    AbilityId.incinerate ||
    AbilityId.conflagrate ||
    AbilityId.fireNova ||
    AbilityId.flamestrike ||
    AbilityId.magmaTotem ||
    AbilityId.hellfire ||
    AbilityId.livingBomb ||
    AbilityId.lavaBurst => SpatialBurstKind.flame,
    AbilityId.consecration ||
    AbilityId.consecrationHoly ||
    AbilityId.holyWrath ||
    AbilityId.divineStorm ||
    AbilityId.holyPriestNova ||
    AbilityId.flashOfLight ||
    AbilityId.holyLight => SpatialBurstKind.cross,
    AbilityId.envenom || AbilityId.garrote => SpatialBurstKind.poison,
    AbilityId.shadowBolt ||
    AbilityId.mindBlast ||
    AbilityId.deathCoil ||
    AbilityId.shadowfury ||
    AbilityId.handOfGuldan ||
    AbilityId.deathAndDecayBlood ||
    AbilityId.deathAndDecayUnholy => SpatialBurstKind.skull,
    AbilityId.chaosBolt || AbilityId.chaosBoltDemo => SpatialBurstKind.flame,
    AbilityId.bladestorm ||
    AbilityId.whirlwind ||
    AbilityId.bladeFlurry ||
    AbilityId.killingSpree ||
    AbilityId.fanOfKnivesCombat ||
    AbilityId.feralThrash ||
    AbilityId.guardianThrash => SpatialBurstKind.slash,
    AbilityId.shockwave => SpatialBurstKind.cone,
    AbilityId.dieByTheSword => SpatialBurstKind.ring,
    AbilityId.colossusSmash => SpatialBurstKind.cone,
    AbilityId.armsCharge => SpatialBurstKind.cone,
    AbilityId.lightOfDawn => SpatialBurstKind.cross,
    AbilityId.ardentDefender => SpatialBurstKind.ring,
    AbilityId.wordOfGloryProt => SpatialBurstKind.cross,
    AbilityId.wordOfGloryRet => SpatialBurstKind.cross,
    AbilityId.stampede => SpatialBurstKind.summon,
    AbilityId.prayerOfMendingHoly => SpatialBurstKind.cross,
    AbilityId.healingSurge => SpatialBurstKind.cross,
    AbilityId.manaTideTotem => SpatialBurstKind.leaf,
    AbilityId.prismaticBarrier => SpatialBurstKind.shards,
    AbilityId.evocation => SpatialBurstKind.spark,
    AbilityId.iceBarrierFrost => SpatialBurstKind.shards,
    AbilityId.ironbark => SpatialBurstKind.ring,
    AbilityId.innervateDruid => SpatialBurstKind.leaf,
    AbilityId.executeFury => SpatialBurstKind.slash,
    AbilityId.piercingHowl => SpatialBurstKind.ring,
    AbilityId.hammerOfJusticeHoly => SpatialBurstKind.cross,
    AbilityId.consecrationRet => SpatialBurstKind.cross,
    AbilityId.hammerOfJusticeRet => SpatialBurstKind.cross,
    AbilityId.killShotBm => SpatialBurstKind.rain,
    AbilityId.claw => SpatialBurstKind.slash,
    AbilityId.killShotMm => SpatialBurstKind.beam,
    AbilityId.bindingShot => SpatialBurstKind.beam,
    AbilityId.wildfireBomb => SpatialBurstKind.flame,
    AbilityId.harpoonSurvival => SpatialBurstKind.beam,
    AbilityId.kidneyShotAssa => SpatialBurstKind.slash,
    AbilityId.crimsonVial => SpatialBurstKind.poison,
    AbilityId.adrenalineRush => SpatialBurstKind.slash,
    AbilityId.revealingStrike => SpatialBurstKind.slash,
    AbilityId.secretTechnique => SpatialBurstKind.slash,
    AbilityId.powerWordBarrier => SpatialBurstKind.ring,
    AbilityId.halo => SpatialBurstKind.cross,
    AbilityId.shadowfiendDisc => SpatialBurstKind.summon,
    AbilityId.holyFire => SpatialBurstKind.pillar,
    AbilityId.holyWordSanctify => SpatialBurstKind.cross,
    AbilityId.shadowWordDeath => SpatialBurstKind.skull,
    AbilityId.shadowfiendShadow => SpatialBurstKind.summon,
    AbilityId.frozenOrb => SpatialBurstKind.rain,
    AbilityId.breathOfSindragosa => SpatialBurstKind.cone,
    AbilityId.empowerRuneWeapon => SpatialBurstKind.ring,
    AbilityId.soulReaper => SpatialBurstKind.skull,
    AbilityId.darkTransformation => SpatialBurstKind.skull,
    AbilityId.fireElemental => SpatialBurstKind.summon,
    AbilityId.crashLightning => SpatialBurstKind.beam,
    AbilityId.healingTideTotem => SpatialBurstKind.leaf,
    AbilityId.earthbindTotem => SpatialBurstKind.leaf,
    AbilityId.arcaneBarrage => SpatialBurstKind.beam,
    AbilityId.meteor => SpatialBurstKind.rain,
    AbilityId.frostMageConeOfCold => SpatialBurstKind.shards,
    AbilityId.darkSoul => SpatialBurstKind.skull,
    AbilityId.howlOfTerror => SpatialBurstKind.skull,
    AbilityId.callDreadstalkers => SpatialBurstKind.summon,
    AbilityId.soulFireDemo => SpatialBurstKind.pillar,
    AbilityId.summonInfernal => SpatialBurstKind.summon,
    AbilityId.shadowburn => SpatialBurstKind.skull,
    AbilityId.starsurge => SpatialBurstKind.beam,
    AbilityId.forceOfNature => SpatialBurstKind.summon,
    AbilityId.maim => SpatialBurstKind.slash,
    AbilityId.entanglingRoots => SpatialBurstKind.leaf,
    _ => null,
  };

  static SpatialGroundFxKind? _groundKindForId(AbilityId id) => switch (id) {
    AbilityId.consecration ||
    AbilityId.consecrationHoly ||
    AbilityId.divineStorm ||
    AbilityId.holyWrath => SpatialGroundFxKind.holy,
    AbilityId.healingRain ||
    AbilityId.hurricane ||
    AbilityId.blizzard ||
    AbilityId.starfall ||
    AbilityId.thunderstorm ||
    AbilityId.volley => SpatialGroundFxKind.rain,
    AbilityId.explosiveTrap ||
    AbilityId.rainOfFire ||
    AbilityId.fireNova ||
    AbilityId.flamestrike ||
    AbilityId.magmaTotem ||
    AbilityId.hellfire => SpatialGroundFxKind.fire,
    AbilityId.hungeringCold ||
    AbilityId.frostNova ||
    AbilityId.frostNovaMage ||
    AbilityId.howlingBlast => SpatialGroundFxKind.frost,
    AbilityId.shadowfury ||
    AbilityId.handOfGuldan ||
    AbilityId.mindSear ||
    AbilityId.deathAndDecayBlood ||
    AbilityId.deathAndDecayUnholy => SpatialGroundFxKind.shadow,
    AbilityId.tranquility ||
    AbilityId.wildGrowth ||
    AbilityId.spiritLink ||
    AbilityId.earthquake => SpatialGroundFxKind.nature,
    AbilityId.thunderClap => SpatialGroundFxKind.disc,
    AbilityId.bloodBoil ||
    AbilityId.bloodBoilUnholy => SpatialGroundFxKind.blood,
    AbilityId.envenom || AbilityId.garrote => SpatialGroundFxKind.poison,
    AbilityId.bladestorm ||
    AbilityId.whirlwind ||
    AbilityId.bladeFlurry ||
    AbilityId.killingSpree ||
    AbilityId.fanOfKnivesCombat ||
    AbilityId.feralThrash ||
    AbilityId.guardianThrash => SpatialGroundFxKind.steel,
    AbilityId.consecrationRet => SpatialGroundFxKind.holy,
    AbilityId.bindingShot => SpatialGroundFxKind.disc,
    AbilityId.wildfireBomb => SpatialGroundFxKind.fire,
    AbilityId.secretTechnique => SpatialGroundFxKind.shadow,
    AbilityId.halo => SpatialGroundFxKind.holy,
    AbilityId.powerWordBarrier => SpatialGroundFxKind.holy,
    AbilityId.holyWordSanctify => SpatialGroundFxKind.holy,
    AbilityId.frozenOrb => SpatialGroundFxKind.frost,
    AbilityId.healingTideTotem => SpatialGroundFxKind.nature,
    AbilityId.earthbindTotem => SpatialGroundFxKind.nature,
    AbilityId.meteor => SpatialGroundFxKind.fire,
    AbilityId.summonInfernal => SpatialGroundFxKind.fire,
    AbilityId.entanglingRoots => SpatialGroundFxKind.nature,
    _ => null,
  };
}
