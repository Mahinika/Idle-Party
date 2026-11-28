import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/spatial/combat_floater_layout.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/floater_paint.dart';

/// Renders lane + pill layout for fight documentation (not a committed golden).
Future<void> _paintFightToPng(String path, List<SpatialFloater> floaters) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const tile = 32.0;
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 360, 400),
    Paint()..color = const Color(0xFF1A1420),
  );
  paintFloaterLabels(
    canvas: canvas,
    tile: tile,
    originX: 24,
    originY: 40,
    floaters: floaters,
    visualFrame: 4,
    showBursts: true,
    showPriorityFloaters: true,
    inView: (_, _, {double pad = 0}) => true,
    minLabelTop: 0,
    maxLabelBottom: 9,
    viewWidthTiles: 10,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 400);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render lane layout sample for artifacts', () async {
    final floaters = [
      SpatialFloater(
        x: CombatFloaterLayout.laneLeftX,
        y: 0,
        text: 'V +14',
        argb: SpatialCombat.floaterHeal,
        life: 0.45,
        placement: CombatFloaterPlacement.gutterBeneficial,
        initialLife: 0.45,
      ),
      SpatialFloater(
        x: CombatFloaterLayout.laneRightX,
        y: 0,
        text: 'B 42',
        argb: SpatialCombat.floaterDamage,
        life: 0.35,
        placement: CombatFloaterPlacement.gutterHostile,
        initialLife: 0.35,
      ),
      SpatialFloater(
        x: CombatFloaterLayout.laneRightX,
        y: 0,
        text: 'B CRIT 88',
        argb: 0xFFFFC14A,
        life: 0.55,
        priority: 2,
        isCrit: true,
        placement: CombatFloaterPlacement.gutterHostile,
        initialLife: 0.55,
      ),
      SpatialFloater(
        x: 6,
        y: 5.4,
        text: 'DODGE',
        argb: 0xFF90E0A0,
        life: 0.35,
        priority: 2,
        placement: CombatFloaterPlacement.unitPill,
        initialLife: 0.35,
      ),
    ];
    await _paintFightToPng(
      '/opt/cursor/artifacts/combat-floater-after.png',
      floaters,
    );
    expect(File('/opt/cursor/artifacts/combat-floater-after.png').existsSync(), isTrue);
  }, skip: !Directory('/opt/cursor/artifacts').existsSync());
}