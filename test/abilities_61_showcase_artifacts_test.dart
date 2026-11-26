import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/spell_bolt_style.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';

import 'abilities_61_render_test.dart' show abilities61RenderIds;
import 'shell_golden_harness.dart';

/// Regression: contact tiles must not layer default weapon bolts / slash worms.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  /// Lower-left worm from [_paintSlash] at default showcase life.
  const meleeNoLowerLeftWorm = <AbilityId>{
    AbilityId.executeFury,
    AbilityId.hammerOfJusticeHoly,
    AbilityId.hammerOfJusticeRet,
    AbilityId.claw,
    AbilityId.kidneyShotAssa,
    AbilityId.adrenalineRush,
    AbilityId.revealingStrike,
    AbilityId.secretTechnique,
    AbilityId.maim,
    AbilityId.soulReaper,
  };

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

  test('slash worm suppressed for bespoke melee signatures', () {
    for (final id in meleeNoLowerLeftWorm) {
      expect(
        SpellShapePaint.suppressesGenericWeaponSlash(id),
        isTrue,
        reason: '$id',
      );
    }
    expect(SpellShapePaint.suppressesGenericWeaponSlash(AbilityId.colossusSmash), isFalse);
  });

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

  test('melee tiles keep lower-left corner free of slash-worm pixels', () async {
    const tileW = 172.0;
    const tileH = 160.0;
  const lives = <double>[0.28, 0.34];
    for (final id in meleeNoLowerLeftWorm) {
      final def = ClassKits.defFor(id)!;
      for (final life in lives) {
        final rgba = await _renderShowcaseRgba(def, tileW, tileH, life);
        final hot = _countSlashWormPixels(rgba, tileW.round(), tileH.round());
        expect(
          hot,
          lessThan(12),
          reason: '$id life=$life lower-left slash worm pixels=$hot',
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

Future<Uint8List> _renderShowcaseRgba(
  ClassAbilityDef def,
  double w,
  double h,
  double life,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(6)),
    Paint()..color = const Color(0xFF231A28),
  );
  SpellShapePaint.paintAbilityShowcase(
    canvas,
    tileRect: Rect.fromLTWH(0, 0, w, h),
    def: def,
    life: life,
  );
  final image = await recorder.endRecording().toImage(w.round(), h.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Pixels in the bottom-left ROI that match the generic weapon slash stroke.
int _countSlashWormPixels(Uint8List rgba, int w, int h) {
  final xMax = (w * 0.38).floor();
  final yMin = (h * 0.55).floor();
  var n = 0;
  for (var y = yMin; y < h; y++) {
    for (var x = 0; x < xMax; x++) {
      final i = (y * w + x) * 4;
      final a = rgba[i + 3];
      if (a < 40) continue;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final luma = (r * 30 + g * 59 + b * 11) ~/ 100;
      if (luma < 95) continue;
      final beigeWeapon =
          r > 180 && g > 150 && b > 70 && b < 200 && (r - b).abs() < 120;
      final purpleShadow = r > 120 && b > 150 && g < 180 && r < 220;
      if (beigeWeapon || purpleShadow) {
        n++;
      }
    }
  }
  return n;
}