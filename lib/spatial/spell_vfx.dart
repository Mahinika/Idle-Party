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
        SpellBoltStyle.nature => SpatialBurstKind.spark,
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

  /// Caster pop when a spell goes off.
  static void spawnCast(
    SpatialWorld world, {
    required SpatialActor hero,
    required SpellBoltStyle style,
    AbilityAoeShape? shape,
    AbilityId? id,
    double radius = 0.7,
  }) {
    final argb = SpatialCombat.burstArgbForStyle(style);
    final kind = burstKindFor(style: style, shape: shape, id: id);
    SpatialCombat.spawnBurst(
      world,
      x: hero.x,
      y: hero.y,
      argb: argb,
      radius: radius,
      kind: kind,
      life: 0.55,
    );
    if (kind == SpatialBurstKind.flame ||
        kind == SpatialBurstKind.cross ||
        kind == SpatialBurstKind.shards) {
      SpatialCombat.spawnRing(
        world,
        x: hero.x,
        y: hero.y,
        argb: argb,
        radius: radius * 0.85,
        life: 0.32,
      );
    }
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
    final argb = SpatialCombat.burstArgbForStyle(style);
    final kind = burstKindFor(style: style, shape: shape, id: id);
    SpatialCombat.spawnBurst(
      world,
      x: x,
      y: y,
      argb: argb,
      radius: radius,
      kind: kind,
      life: 0.52,
      x2: x2,
      y2: y2,
    );
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
    _ => null,
  };
}
