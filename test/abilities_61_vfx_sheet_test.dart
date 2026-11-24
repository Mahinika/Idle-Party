import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';

const _newIds = <AbilityId>[
  AbilityId.meteor,
  AbilityId.frozenOrb,
  AbilityId.arcaneBarrage,
  AbilityId.crashLightning,
  AbilityId.breathOfSindragosa,
  AbilityId.secretTechnique,
  AbilityId.starsurge,
  AbilityId.shadowWordDeath,
  AbilityId.holyFire,
  AbilityId.stampede,
  AbilityId.summonInfernal,
];

void main() {
  test('sample abilities painted via SpellShapePaint (not flat circles)', () async {
    const cell = 168.0;
    const cols = 4;
    final rows = (_newIds.length / cols).ceil();
    final w = cell * cols;
    final h = cell * rows;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1A1420),
    );
    for (var i = 0; i < _newIds.length; i++) {
      final id = _newIds[i];
      final def = ClassKits.defFor(id)!;
      final kind = SpellVfx.burstKindFor(
        style: def.boltStyle ?? SpellBoltStyle.fire,
        shape: def.aoeShape,
        id: id,
      );
      expect(
        kind,
        isNot(SpatialBurstKind.blast),
        reason: '$id should have a shaped burst, not generic blast disc',
      );
      final rect = Rect.fromLTWH(
        (i % cols) * cell + 8,
        (i ~/ cols) * cell + 8,
        cell - 16,
        cell - 16,
      );
      SpellShapePaint.paintAbilityShowcase(canvas, tileRect: rect, def: def);
    }
    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = Platform.environment['ABILITIES_61_VFX_SHEET'];
    if (out != null) {
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    expect(bytes, isNotNull);
    expect(bytes!.lengthInBytes, greaterThan(2000));
  });
}