import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/spell_bolt_style.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';

import 'abilities_61_render_test.dart' show abilities61RenderIds;

/// Regression: contact tiles must not layer default weapon bolts / smear lines.
void main() {
  const noTravelBolt = <AbilityId>{
    AbilityId.claw,
    AbilityId.executeFury,
    AbilityId.hammerOfJusticeHoly,
    AbilityId.hammerOfJusticeRet,
    AbilityId.kidneyShotAssa,
    AbilityId.adrenalineRush,
    AbilityId.revealingStrike,
    AbilityId.secretTechnique,
    AbilityId.maim,
    AbilityId.colossusSmash,
    AbilityId.armsCharge,
    AbilityId.dieByTheSword,
    AbilityId.lightOfDawn,
    AbilityId.wordOfGloryProt,
    AbilityId.wordOfGloryRet,
    AbilityId.prayerOfMendingHoly,
    AbilityId.healingSurge,
    AbilityId.stampede,
    AbilityId.forceOfNature,
    AbilityId.shadowfiendDisc,
    AbilityId.shadowfiendShadow,
    AbilityId.summonInfernal,
    AbilityId.fireElemental,
    AbilityId.healingTideTotem,
    AbilityId.earthbindTotem,
    AbilityId.manaTideTotem,
    AbilityId.innervateDruid,
    AbilityId.entanglingRoots,
    AbilityId.powerWordBarrier,
    AbilityId.ironbark,
    AbilityId.halo,
    AbilityId.consecrationRet,
    AbilityId.holyWordSanctify,
    AbilityId.soulReaper,
    AbilityId.darkTransformation,
    AbilityId.darkSoul,
    AbilityId.howlOfTerror,
    AbilityId.piercingHowl,
    AbilityId.ardentDefender,
  };

  test('all 61 abilities reject default showcase travel bolt', () {
    expect(abilities61RenderIds.length, 61);
    for (final id in abilities61RenderIds) {
      final def = ClassKits.defFor(id)!;
      final genericWeaponFallback =
          def.boltStyle == SpellBoltStyle.weapon &&
          (def.effect == AbilityEffectKind.damage ||
              def.effect == AbilityEffectKind.aoe);
      if (genericWeaponFallback) {
        expect(
          SpellShapePaint.showcaseWantsTravelBolt(def),
          isFalse,
          reason: '$id must not paint default weapon worm on contact sheet',
        );
      } else if (SpellShapePaint.showcaseWantsTravelBolt(def)) {
        expect(
          SpellShapePaint.hasCustomBoltLabel(def.shortLabel),
          isTrue,
          reason: '$id may only show travel bolt with a custom shape',
        );
      }
    }
  });

  test('melee and body abilities never use default weapon showcase bolt', () {
    for (final id in noTravelBolt) {
      final def = ClassKits.defFor(id)!;
      expect(
        SpellShapePaint.showcaseWantsTravelBolt(def),
        isFalse,
        reason: '$id must not paint default weapon capsule on contact sheet',
      );
    }
  });

  test('ranged abilities with custom bolt labels may show travel bolt', () {
    for (final id in <AbilityId>{
      AbilityId.arcaneBarrage,
      AbilityId.killShotMm,
      AbilityId.killShotBm,
      AbilityId.wildfireBomb,
      AbilityId.crashLightning,
      AbilityId.starsurge,
      AbilityId.holyFire,
      AbilityId.meteor,
      AbilityId.frozenOrb,
    }) {
      final def = ClassKits.defFor(id)!;
      expect(SpellShapePaint.showcaseWantsTravelBolt(def), isTrue, reason: '$id');
      expect(SpellShapePaint.hasCustomBoltLabel(def.shortLabel), isTrue);
    }
  });
}