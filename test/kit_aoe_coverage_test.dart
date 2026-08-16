import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

void main() {
  test('every combat spec has pack tools (AoE or cleave buff or party heal)', () {
    const healSpecs = {
      HeroSpecId.discipline,
      HeroSpecId.holyPriest,
      HeroSpecId.holyPaladin,
      HeroSpecId.restorationDruid,
      HeroSpecId.restorationShaman,
    };

    for (final spec in HeroSpecId.values) {
      final kit = ClassKits.forSpec(spec);
      expect(kit, isNotEmpty, reason: '$spec empty kit');
      final hasAoe = kit.any((d) => d.effect == AbilityEffectKind.aoe);
      final hasCleaveBuff = kit.any(
        (d) =>
            d.effect == AbilityEffectKind.selfBuff &&
            (d.id == AbilityId.bladeFlurry ||
                d.id == AbilityId.sweepingStrikes ||
                d.name.toLowerCase().contains('flurry') ||
                d.name.toLowerCase().contains('sweep')),
      );
      final hasPartyHeal = kit.any(
        (d) =>
            d.effect == AbilityEffectKind.heal &&
            (d.id == AbilityId.circleOfHealing ||
                d.id == AbilityId.holyPriestNova ||
                d.id == AbilityId.healingRain ||
                d.id == AbilityId.wildGrowth ||
                d.id == AbilityId.chainHeal ||
                d.id == AbilityId.tranquility ||
                d.id == AbilityId.spiritLink ||
                d.id == AbilityId.divineHymn ||
                d.name.toLowerCase().contains('circle') ||
                d.name.toLowerCase().contains('rain') ||
                d.name.toLowerCase().contains('nova')),
      );

      if (healSpecs.contains(spec)) {
        final hasHeal = kit.any((d) => d.effect == AbilityEffectKind.heal);
        expect(
          hasAoe || hasPartyHeal || hasHeal,
          isTrue,
          reason: '$spec healer needs heals and/or Consecration-style AoE',
        );
      } else {
        expect(
          hasAoe || hasCleaveBuff,
          isTrue,
          reason: '$spec DPS/tank needs an AoE or cleave window',
        );
      }
    }
  });

  test('new pack AoEs resolve themed bolt styles', () {
    final cases = <(AbilityId, HeroSpecId, SpellBoltStyle)>[
      (AbilityId.seedOfCorruption, HeroSpecId.affliction, SpellBoltStyle.shadow),
      (AbilityId.fanOfKnives, HeroSpecId.assassination, SpellBoltStyle.weapon),
      (AbilityId.fanOfKnivesSub, HeroSpecId.subtlety, SpellBoltStyle.shadow),
      (AbilityId.mindSear, HeroSpecId.shadow, SpellBoltStyle.shadow),
      (AbilityId.feralSwipe, HeroSpecId.feral, SpellBoltStyle.weapon),
      (AbilityId.consecrationHoly, HeroSpecId.holyPaladin, SpellBoltStyle.holy),
      (AbilityId.blizzard, HeroSpecId.frostMage, SpellBoltStyle.frost),
      (AbilityId.rainOfFire, HeroSpecId.destruction, SpellBoltStyle.fire),
      (AbilityId.multiShotSurv, HeroSpecId.survival, SpellBoltStyle.arrow),
    ];
    for (final (id, spec, want) in cases) {
      final def = ClassKits.defFor(id)!;
      final hero = SpatialActor(
        id: 'h',
        name: 'T',
        team: SpatialTeam.hero,
        x: 0,
        y: 0,
        hp: 100,
        maxHp: 100,
        attack: 10,
        defense: 1,
        moveSpeed: 1,
        attackRange: 1.2,
        attackCooldown: 1,
        heroRole: HeroSpecs.def(spec).gearAffinity,
        heroSpecId: spec,
      );
      expect(
        SpatialCombat.boltStyleForAbility(hero, def: def),
        want,
        reason: '$id',
      );
      expect(def.effect, AbilityEffectKind.aoe);
    }
  });
}
