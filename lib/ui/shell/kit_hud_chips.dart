import '../../models/class_ability.dart';
import '../../models/hero_spec.dart';
import '../../spatial/spatial_combat.dart';

/// Party kit chip picks for the dungeon HUD.
///
/// Phone strips only show a few chips — identity CDs must not lose to catalog
/// order or long emergency walls.
abstract final class KitHudChips {
  /// Spec fantasy that must stay visible when the strip is capped.
  static const Set<AbilityId> identityIds = {
    // PROT
    AbilityId.shieldBlock,
    AbilityId.shieldSlam,
    AbilityId.thunderClap,
    AbilityId.revenge,
    AbilityId.shockwave,
    // Prot Paladin
    AbilityId.avengersShield,
    AbilityId.hammerOfTheRighteous,
    AbilityId.shieldOfRighteousness,
    AbilityId.holyShield,
    // Combat
    AbilityId.bladeFlurry,
    AbilityId.killingSpree,
    AbilityId.eviscerate,
    AbilityId.kidneyShot,
    AbilityId.sliceAndDice,
    // Disc
    AbilityId.penance,
    AbilityId.powerWordShield,
    AbilityId.painSuppression,
    AbilityId.powerInfusion,
    // Fire
    AbilityId.pyroblast,
    AbilityId.combustion,
    AbilityId.livingBomb,
    AbilityId.fireball,
  };

  static bool buffActive(ClassAbilityDef ability, SpatialActor s) {
    return switch (ability.id) {
      AbilityId.shieldBlock => s.shieldBlockTimer > 0,
      AbilityId.shieldWall => s.shieldWallTimer > 0,
      AbilityId.lastStand => s.lastStandTimer > 0,
      AbilityId.shieldSlam => s.queuedShieldSlam,
      AbilityId.shockwave => s.shockwaveFlash > 0,
      AbilityId.powerWordShield => s.absorbShield > 0,
      AbilityId.prayerOfMending => s.pomCharges > 0,
      AbilityId.painSuppression => s.painSuppressionTimer > 0,
      AbilityId.powerInfusion => s.powerInfusionTimer > 0,
      AbilityId.innerFire => s.innerFireActive,
      AbilityId.combustion => s.combustionTimer > 0,
      AbilityId.furyRecklessness => s.combustionTimer > 0,
      AbilityId.vendetta ||
      AbilityId.coldBlood ||
      AbilityId.arcanePower => s.combustionTimer > 0,
      AbilityId.pyroblast => s.hotStreakReady,
      AbilityId.iceBlock ||
      AbilityId.arcaneIceBlock ||
      AbilityId.frostMageIceBlock => s.iceBlockTimer > 0,
      AbilityId.livingBomb => s.livingBombArmed > 0,
      AbilityId.sliceAndDice => s.sliceAndDiceTimer > 0,
      AbilityId.bladeFlurry => s.bladeFlurryTimer > 0,
      AbilityId.sweepingStrikes => s.bladeFlurryTimer > 0,
      AbilityId.holyShield => s.shieldBlockTimer > 0,
      AbilityId.beaconOfLight => s.beaconTimer > 0,
      AbilityId.divineFavor => (s.buffTimers['favor'] ?? 0) > 0,
      AbilityId.sprint => s.sprintTimer > 0,
      AbilityId.vanish => s.vanishTimer > 0,
      AbilityId.killingSpree => s.killingSpreeTimer > 0,
      _ =>
        ability.effect == AbilityEffectKind.selfBuff &&
            ((s.buffTimers['buff'] ?? 0) > 0 ||
                (s.buffTimers['shield'] ?? 0) > 0 ||
                s.powerInfusionTimer > 0 ||
                s.shieldBlockTimer > 0 ||
                s.combustionTimer > 0),
    };
  }

  /// Specs whose HUD must keep more identity chips (new-game jobs).
  static int identityReserveFor(HeroSpecId? spec) {
    return switch (spec) {
      HeroSpecId.protection ||
      HeroSpecId.discipline ||
      HeroSpecId.fire => 3,
      _ => 2,
    };
  }

  /// Prefer ready / identity chips so a capped HUD still reads as the kit.
  static List<ClassAbilityDef> prioritize(
    List<ClassAbilityDef> abilities, {
    required SpatialActor spatial,
    required double resource,
    required bool hasShield,
    required int maxChips,
    SpatialWorld? world,
    double heroHpFrac = 1.0,
    HeroSpecId? spec,
  }) {
    if (abilities.length <= maxChips) return abilities;

    final focusHp = _focusHpFrac(spatial, world);
    final bombUp = _focusBombUp(spatial, world);
    final partyHealthy = heroHpFrac > 0.45;
    final defOrder = <AbilityId, int>{
      for (var i = 0; i < ClassKits.all.length; i++) ClassKits.all[i].id: i,
    };

    int readiness(ClassAbilityDef a) {
      if (buffActive(a, spatial)) return 0;
      final gated = a.requiresShield && !hasShield;
      final cd = spatial.abilityCd[a.id.name] ?? 0;
      final noRage = resource + 0.001 < a.resourceCost;
      final execFrac = a.gate.executeHpFrac;
      final execWaiting = execFrac != null && focusHp > execFrac;
      final bombWaiting = a.gate.livingBombRefresh && bombUp;
      final demoteWall = partyHealthy &&
          (a.id == AbilityId.shieldWall || a.id == AbilityId.lastStand);
      if (!gated && cd <= 0.05 && !noRage && !execWaiting && !bombWaiting) {
        return demoteWall ? 2 : 1;
      }
      if (cd > 0.05) return demoteWall ? 3 : 2;
      return demoteWall ? 4 : 3;
    }

    int fantasyBias(ClassAbilityDef a) {
      if (identityIds.contains(a.id)) return 0;
      if (a.tier == AbilityCastTier.signature) return 1;
      return switch (a.id) {
        AbilityId.aimedShot || AbilityId.chimeraShot => 0,
        AbilityId.steadyShot => 3,
        AbilityId.charge ||
        AbilityId.taunt ||
        AbilityId.handOfReckoning ||
        AbilityId.darkCommand ||
        AbilityId.growl => 0,
        AbilityId.armsExecute || AbilityId.furyExecute => 0,
        AbilityId.sealOfCommand => 0,
        AbilityId.bloodthirst ||
        AbilityId.whirlwind ||
        AbilityId.ragingBlow => 0,
        AbilityId.shieldWall || AbilityId.lastStand => partyHealthy ? 6 : 2,
        _ => a.tier == AbilityCastTier.emergency ? 5 : 4,
      };
    }

    // Reserve identity chips so CD fantasy never disappears entirely.
    // New-game jobs (PROT / DISC / FIRE) keep three; others keep two.
    final identity = [
      for (final a in abilities)
        if (identityIds.contains(a.id) || a.tier == AbilityCastTier.signature) a,
    ]..sort((a, b) {
        final byReady = readiness(a).compareTo(readiness(b));
        if (byReady != 0) return byReady;
        return fantasyBias(a).compareTo(fantasyBias(b));
      });
    final reserveN = identityReserveFor(spec ?? spatial.heroSpecId);
    final reserved = identity.take(reserveN).toList(growable: false);
    final reservedIds = reserved.map((a) => a.id).toSet();

    final ranked = [
      for (final a in abilities)
        if (!reservedIds.contains(a.id)) a,
    ]..sort((a, b) {
        final byRank = readiness(a).compareTo(readiness(b));
        if (byRank != 0) return byRank;
        final byFantasy = fantasyBias(a).compareTo(fantasyBias(b));
        if (byFantasy != 0) return byFantasy;
        final byUnlock = a.unlockLevel.compareTo(b.unlockLevel);
        if (byUnlock != 0) return byUnlock;
        final byDmg = b.coeff.compareTo(a.coeff);
        if (byDmg != 0) return byDmg;
        return (defOrder[a.id] ?? 0).compareTo(defOrder[b.id] ?? 0);
      });

    final slotsLeft = maxChips - reserved.length;
    return [...reserved, ...ranked.take(slotsLeft)];
  }

  static double _focusHpFrac(SpatialActor spatial, SpatialWorld? world) {
    final focus = _focusEnemy(spatial, world);
    if (focus == null || focus.effectiveMaxHp <= 0) return 1.0;
    return (focus.hp / focus.effectiveMaxHp).clamp(0.0, 1.0);
  }

  static bool _focusBombUp(SpatialActor spatial, SpatialWorld? world) {
    final focus = _focusEnemy(spatial, world);
    return focus != null && focus.livingBombTimer >= 2;
  }

  static SpatialActor? _focusEnemy(SpatialActor spatial, SpatialWorld? world) {
    if (world == null) return null;
    final id = spatial.focusEnemyId;
    if (id == null) return null;
    for (final e in world.enemies) {
      if (e.id == id && e.hp > 0) return e;
    }
    return null;
  }
}
