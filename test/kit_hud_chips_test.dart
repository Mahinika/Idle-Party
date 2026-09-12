import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/shell/kit_hud_chips.dart';

void main() {
  SpatialActor hero(HeroSpecId spec) {
    final def = HeroSpecs.def(spec);
    return SpatialActor(
      id: '1',
      name: def.shortLabel,
      team: SpatialTeam.hero,
      x: 2,
      y: 2,
      hp: 500,
      maxHp: 500,
      attack: 40,
      defense: 20,
      moveSpeed: 2.2,
      attackRange: 1.2,
      attackCooldown: 1.2,
      heroSpecId: spec,
      heroRole: def.gearAffinity,
    )..rage = 100;
  }

  test('capped HUD keeps identity CDs for starter kits', () {
    const cases = <(HeroSpecId, Set<AbilityId>)>[
      (
        HeroSpecId.protection,
        {AbilityId.shieldBlock, AbilityId.shieldSlam, AbilityId.thunderClap},
      ),
      (
        HeroSpecId.protPaladin,
        {
          AbilityId.avengersShield,
          AbilityId.hammerOfTheRighteous,
          AbilityId.shieldOfRighteousness,
        },
      ),
      (
        HeroSpecId.combat,
        {
          AbilityId.bladeFlurry,
          AbilityId.killingSpree,
          AbilityId.eviscerate,
          AbilityId.sliceAndDice,
        },
      ),
      (
        HeroSpecId.discipline,
        {
          AbilityId.penance,
          AbilityId.powerWordShield,
          AbilityId.painSuppression,
        },
      ),
      (
        HeroSpecId.fire,
        {
          AbilityId.pyroblast,
          AbilityId.combustion,
          AbilityId.livingBomb,
          AbilityId.fireball,
        },
      ),
    ];

    for (final (spec, must) in cases) {
      final all = ClassKits.hudAbilitiesAtSpec(spec, 15);
      expect(all.length, greaterThan(4), reason: '$spec should have >4 HUD chips');
      final visible = KitHudChips.prioritize(
        all,
        spatial: hero(spec),
        resource: 100,
        hasShield: true,
        maxChips: 4,
      );
      expect(visible.length, 4, reason: '$spec');
      final ids = visible.map((d) => d.id).toSet();
      final identityHit = ids.intersection(must);
      expect(
        identityHit,
        isNotEmpty,
        reason: '$spec visible $ids missed identity $must',
      );
      if (spec == HeroSpecId.protection ||
          spec == HeroSpecId.discipline ||
          spec == HeroSpecId.fire) {
        expect(
          identityHit.length,
          greaterThanOrEqualTo(3),
          reason: '$spec kept $identityHit of $must from $ids',
        );
      }
      // Catalog-order take(4) used to bury late unlocks — signatures must win a slot.
      final hasIdentityOrSignature = visible.any(
        (d) =>
            KitHudChips.identityIds.contains(d.id) ||
            d.tier == AbilityCastTier.signature,
      );
      expect(hasIdentityOrSignature, isTrue, reason: '$spec $ids');
    }
  });

  test('PROT Block stays over catalog-first passives when capped', () {
    final all = ClassKits.hudAbilitiesAtSpec(HeroSpecId.protection, 15);
    final naive = all.take(4).map((d) => d.id).toSet();
    final visible = KitHudChips.prioritize(
      all,
      spatial: hero(HeroSpecId.protection),
      resource: 100,
      hasShield: true,
      maxChips: 4,
    ).map((d) => d.id).toSet();
    // Identity should improve on naive catalog slice.
    expect(
      visible.contains(AbilityId.shieldBlock) ||
          visible.contains(AbilityId.shieldSlam) ||
          visible.contains(AbilityId.thunderClap),
      isTrue,
    );
    expect(visible, isNot(equals(naive)));
  });

  test('starter kits reserve three identity chips', () {
    expect(KitHudChips.identityReserveFor(HeroSpecId.protection), 3);
    expect(KitHudChips.identityReserveFor(HeroSpecId.discipline), 3);
    expect(KitHudChips.identityReserveFor(HeroSpecId.fire), 3);
    expect(KitHudChips.identityReserveFor(HeroSpecId.combat), 2);
  });
}
