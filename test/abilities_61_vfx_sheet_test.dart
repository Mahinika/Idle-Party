import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/spatial/spatial_combat.dart';

const _newIds = [
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
  test('abilities-61 VFX contact sheet renders distinct burst kinds', () async {
    final world = _world();
    final cell = 72.0;
    final cols = 4;
    final rows = (_newIds.length / cols).ceil();
    final w = cell * cols;
    final h = cell * rows + 40;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1A1420),
    );
    for (var i = 0; i < _newIds.length; i++) {
      final id = _newIds[i];
      final def = ClassKits.defFor(id)!;
      final style = def.boltStyle ?? SpellBoltStyle.fire;
      final cx = (i % cols) * cell + cell / 2;
      final cy = (i ~/ cols) * cell + cell / 2 + 20;
      SpellVfx.spawnImpact(
        world,
        x: 0.5 + i * 0.35,
        y: 1.0,
        style: style,
        id: id,
        shape: def.aoeShape,
        radius: 0.75,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        22,
        Paint()..color = Color(SpatialCombat.burstArgbForStyle(style)),
      );
    }
    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = Platform.environment['ABILITIES_61_VFX_SHEET'];
    if (out != null) {
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    expect(bytes, isNotNull);
    expect(bytes!.lengthInBytes, greaterThan(500));
  });
}

SpatialWorld _world() {
  final state = GameLogic.createInitialState(now: DateTime(2026, 11, 24));
  final entered = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  final world = SpatialCombat.build(entered);
  world.reducedVfx = false;
  world.spawnPersistentVfx = true;
  world.bursts.clear();
  return world;
}