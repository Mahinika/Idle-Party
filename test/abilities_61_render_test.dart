import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';

// Keep in sync with test/abilities_61_test.dart
const _newIds = <AbilityId>[
  AbilityId.colossusSmash,
  AbilityId.dieByTheSword,
  AbilityId.armsCharge,
  AbilityId.executeFury,
  AbilityId.piercingHowl,
  AbilityId.lightOfDawn,
  AbilityId.hammerOfJusticeHoly,
  AbilityId.ardentDefender,
  AbilityId.wordOfGloryProt,
  AbilityId.consecrationRet,
  AbilityId.hammerOfJusticeRet,
  AbilityId.wordOfGloryRet,
  AbilityId.stampede,
  AbilityId.killShotBm,
  AbilityId.claw,
  AbilityId.killShotMm,
  AbilityId.bindingShot,
  AbilityId.wildfireBomb,
  AbilityId.harpoonSurvival,
  AbilityId.kidneyShotAssa,
  AbilityId.crimsonVial,
  AbilityId.adrenalineRush,
  AbilityId.revealingStrike,
  AbilityId.secretTechnique,
  AbilityId.powerWordBarrier,
  AbilityId.halo,
  AbilityId.shadowfiendDisc,
  AbilityId.holyFire,
  AbilityId.holyWordSanctify,
  AbilityId.prayerOfMendingHoly,
  AbilityId.shadowWordDeath,
  AbilityId.shadowfiendShadow,
  AbilityId.frozenOrb,
  AbilityId.breathOfSindragosa,
  AbilityId.empowerRuneWeapon,
  AbilityId.soulReaper,
  AbilityId.darkTransformation,
  AbilityId.fireElemental,
  AbilityId.crashLightning,
  AbilityId.healingSurge,
  AbilityId.healingTideTotem,
  AbilityId.earthbindTotem,
  AbilityId.manaTideTotem,
  AbilityId.arcaneBarrage,
  AbilityId.prismaticBarrier,
  AbilityId.evocation,
  AbilityId.meteor,
  AbilityId.iceBarrierFrost,
  AbilityId.frostMageConeOfCold,
  AbilityId.darkSoul,
  AbilityId.howlOfTerror,
  AbilityId.callDreadstalkers,
  AbilityId.soulFireDemo,
  AbilityId.summonInfernal,
  AbilityId.shadowburn,
  AbilityId.starsurge,
  AbilityId.forceOfNature,
  AbilityId.maim,
  AbilityId.ironbark,
  AbilityId.innervateDruid,
  AbilityId.entanglingRoots,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('61 abilities contact sheet uses SpellShapePaint', () async {
    expect(_newIds.length, 61);
    const tileW = 184.0;
    const tileH = 196.0;
    const cols = 7;
    final rows = (_newIds.length / cols).ceil();
    final w = (tileW * cols).round();
    final h = (tileH * rows + 24).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintDungeonBackdrop(canvas, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    for (var i = 0; i < _newIds.length; i++) {
      final id = _newIds[i];
      final def = ClassKits.defFor(id)!;
      final col = i % cols;
      final row = i ~/ cols;
      final rect = Rect.fromLTWH(
        col * tileW + 6,
        row * tileH + 8,
        tileW - 12,
        tileH - 36,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(6)),
        Paint()..color = const Color(0xFF231A28),
      );
      SpellShapePaint.paintAbilityShowcase(canvas, tileRect: rect, def: def);
      final tp = TextPainter(
        text: TextSpan(
          text: def.name,
          style: const TextStyle(color: Color(0xFFE8D8C8), fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: tileW - 8);
      tp.paint(
        canvas,
        Offset(col * tileW + 4, row * tileH + tileH - 28),
      );
    }

    final bytes = await _pngFromRecorder(recorder, w, h);
    expect(bytes.lengthInBytes, greaterThan(8000));

    if (Platform.environment['RENDER_ABILITIES_61'] == '1') {
      final dir = Directory('docs/design/abilities-61/rendered');
      dir.createSync(recursive: true);
      File('${dir.path}/contact_sheet_61.png').writeAsBytesSync(bytes);
    }
  });

  test('in-context fight frames show several new spell shapes', () async {
    const scenes = <({String file, List<AbilityId> picks})>[
      (
        file: 'fight_mage_elemental.png',
        picks: [
          AbilityId.meteor,
          AbilityId.arcaneBarrage,
          AbilityId.frozenOrb,
          AbilityId.prismaticBarrier,
        ],
      ),
      (
        file: 'fight_hunter_holy.png',
        picks: [
          AbilityId.stampede,
          AbilityId.killShotMm,
          AbilityId.bindingShot,
          AbilityId.holyFire,
        ],
      ),
      (
        file: 'fight_mixed_endgame.png',
        picks: [
          AbilityId.crashLightning,
          AbilityId.summonInfernal,
          AbilityId.entanglingRoots,
          AbilityId.starsurge,
          AbilityId.secretTechnique,
        ],
      ),
      (
        file: 'fight_tank_support.png',
        picks: [
          AbilityId.dieByTheSword,
          AbilityId.colossusSmash,
          AbilityId.powerWordBarrier,
          AbilityId.empowerRuneWeapon,
        ],
      ),
    ];

    const w = 1080;
    const h = 2340;

    if (Platform.environment['RENDER_ABILITIES_61'] == '1') {
      final dir = Directory('docs/design/abilities-61/rendered');
      dir.createSync(recursive: true);
      for (final scene in scenes) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        _paintFightFrame(canvas, Size(w.toDouble(), h.toDouble()));
        final placements = _scatterPlacements(scene.picks.length, w, h);
        for (var i = 0; i < scene.picks.length; i++) {
          final def = ClassKits.defFor(scene.picks[i])!;
          final rect = Rect.fromCenter(
            center: placements[i],
            width: 220,
            height: 200,
          );
          SpellShapePaint.paintAbilityShowcase(canvas, tileRect: rect, def: def);
        }
        final bytes = await _pngFromRecorder(recorder, w, h);
        File('${dir.path}/${scene.file}').writeAsBytesSync(bytes);
      }
    }

    expect(scenes.length, 4);
  });
}

void _paintDungeonBackdrop(Canvas canvas, Rect full) {
  canvas.drawRect(
    full,
    Paint()..color = const Color(0xFF141018),
  );
  const step = 32.0;
  final grid = Paint()
    ..color = const Color(0xFF2A2030)
    ..strokeWidth = 1;
  for (var x = 0.0; x < full.width; x += step) {
    canvas.drawLine(Offset(x, 0), Offset(x, full.height), grid);
  }
  for (var y = 0.0; y < full.height; y += step) {
    canvas.drawLine(Offset(0, y), Offset(full.width, y), grid);
  }
}

void _paintFightFrame(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  canvas.drawRect(rect, Paint()..color = const Color(0xFF0E0A10));
  final floor = Paint()..color = const Color(0xFF1E1618);
  canvas.drawRect(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45), floor);
  final vignette = Paint()
    ..shader = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.35),
      size.width * 0.55,
      [
        const Color(0x33403020),
        const Color(0x00000000),
      ],
    );
  canvas.drawRect(rect, vignette);
}

List<Offset> _scatterPlacements(int n, int w, int h) {
  final xs = [0.28, 0.72, 0.38, 0.62, 0.5];
  final ys = [0.32, 0.38, 0.52, 0.48, 0.42];
  return List.generate(
    n,
    (i) => Offset(w * xs[i % xs.length], h * ys[i % ys.length]),
  );
}

Future<Uint8List> _pngFromRecorder(
  ui.PictureRecorder recorder,
  int w,
  int h,
) async {
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}