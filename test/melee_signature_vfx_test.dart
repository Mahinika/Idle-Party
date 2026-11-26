import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/spell_bolt_style.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';
import 'package:idle_party/ui/spell_vfx_palette.dart';

import 'shell_golden_harness.dart';

const _fourMelee = <AbilityId>[
  AbilityId.executeFury,
  AbilityId.kidneyShotAssa,
  AbilityId.revealingStrike,
  AbilityId.maim,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  test('four melee showcase signatures are pairwise distinct', () async {
    final hashes = <AbilityId, List<int>>{};
    final features = <AbilityId, _MeleeFeatures>{};
    for (final id in _fourMelee) {
      final def = ClassKits.defFor(id)!;
      final rgba = await _renderShowcase(def, life: 0.34);
      hashes[id] = _downsampleHash(rgba, 160, 160);
      features[id] = _measureFeatures(rgba, 160, 160);
    }
    for (var i = 0; i < _fourMelee.length; i++) {
      for (var j = i + 1; j < _fourMelee.length; j++) {
        final a = _fourMelee[i];
        final b = _fourMelee[j];
        expect(hashes[a], isNot(equals(hashes[b])), reason: '$a vs $b hash');
        expect(
          features[a]!.signaturePalette,
          isNot(equals(features[b]!.signaturePalette)),
          reason: '$a vs $b palette',
        );
      }
    }
    expect(features[AbilityId.executeFury]!.signaturePalette[0], greaterThan(8));
    expect(features[AbilityId.kidneyShotAssa]!.signaturePalette[1], greaterThan(6));
    expect(features[AbilityId.revealingStrike]!.signaturePalette[2], greaterThan(8));
    expect(features[AbilityId.maim]!.signaturePalette[3], greaterThan(10));
  });

  test('regenerate four melee strips when RENDER_MELEE_SIG', () async {
    if (Platform.environment['RENDER_MELEE_SIG'] != '1') return;
    const frameLives = <double>[0.08, 0.18, 0.32, 0.48, 0.68, 0.88];
    const frameSize = 128.0;
    final base = Directory('docs/design/abilities-61/rendered/anim');
    base.createSync(recursive: true);
    for (final id in _fourMelee) {
      final def = ClassKits.defFor(id)!;
      final frames = <Uint8List>[];
      for (final life in frameLives) {
        frames.add(await _renderShowcaseFrame(def, frameSize, life));
      }
      final stripW = (frameSize * frames.length).round();
      final stripRecorder = ui.PictureRecorder();
      final stripCanvas = Canvas(stripRecorder);
      stripCanvas.drawRect(
        Rect.fromLTWH(0, 0, stripW.toDouble(), frameSize),
        Paint()..color = const Color(0xFF141018),
      );
      for (var i = 0; i < frames.length; i++) {
        final codec = await ui.instantiateImageCodec(frames[i]);
        final img = (await codec.getNextFrame()).image;
        stripCanvas.drawImage(img, Offset(i * frameSize, 0), Paint());
        img.dispose();
      }
      File('${base.path}/${id.name}_strip.png').writeAsBytesSync(
        await _pngFromRecorder(stripRecorder, stripW, frameSize.round()),
      );
    }
  });

  test('before vs after comparison sheet', () async {
    const tile = 168.0;
    const gap = 12.0;
    const rowH = tile + 28;
    final w = (tile * 2 + gap * 3).round();
    final h = (_fourMelee.length * rowH).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF100C14),
    );

    for (var row = 0; row < _fourMelee.length; row++) {
      final id = _fourMelee[row];
      final def = ClassKits.defFor(id)!;
      final y = row * rowH + 8;
      final tileRect = Rect.fromLTWH(gap, y, tile, tile - 20);
      final afterRect = Rect.fromLTWH(gap * 2 + tile, y, tile, tile - 20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tileRect.inflate(2), const Radius.circular(6)),
        Paint()..color = const Color(0xFF231A28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(afterRect.inflate(2), const Radius.circular(6)),
        Paint()..color = const Color(0xFF231A28),
      );
      _paintLegacyMeleeOverlay(canvas, tileRect, id, def, life: 0.34);
      SpellShapePaint.paintAbilityShowcase(
        canvas,
        tileRect: afterRect,
        def: def,
        life: 0.34,
      );
    }

    final bytes = await _pngFromRecorder(recorder, w, h);
    expect(bytes.lengthInBytes, greaterThan(4000));
    if (Platform.environment['RENDER_MELEE_SIG'] == '1') {
      final out = File('docs/design/abilities-61/rendered/melee_four_before_after.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes);
    }
  });
}

Future<Uint8List> _renderShowcaseFrame(
  ClassAbilityDef def,
  double size,
  double life,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size, size), const Radius.circular(4)),
    Paint()..color = const Color(0xFF231A28),
  );
  SpellShapePaint.paintAbilityShowcase(
    canvas,
    tileRect: Rect.fromLTWH(8, 8, size - 16, size - 16),
    def: def,
    life: life,
  );
  return _pngFromRecorder(recorder, size.round(), size.round());
}

Future<Uint8List> _renderShowcase(ClassAbilityDef def, {required double life}) async {
  const w = 160.0;
  const h = 160.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, w, h), Radius.circular(6)),
    Paint()..color = const Color(0xFF231A28),
  );
  SpellShapePaint.paintAbilityShowcase(
    canvas,
    tileRect: const Rect.fromLTWH(0, 0, w, h),
    def: def,
    life: life,
  );
  final image = await recorder.endRecording().toImage(w.round(), h.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

List<int> _downsampleHash(Uint8List rgba, int w, int h) {
  const grid = 6;
  final out = <int>[];
  for (var gy = 0; gy < grid; gy++) {
    for (var gx = 0; gx < grid; gx++) {
      var sum = 0;
      var n = 0;
      final x0 = (gx * w / grid).floor();
      final x1 = ((gx + 1) * w / grid).floor();
      final y0 = (gy * h / grid).floor();
      final y1 = ((gy + 1) * h / grid).floor();
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          final i = (y * w + x) * 4;
          final a = rgba[i + 3];
          if (a < 30) continue;
          sum += (rgba[i] * 30 + rgba[i + 1] * 59 + rgba[i + 2] * 11) ~/ 100;
          n++;
        }
      }
      out.add(n == 0 ? 0 : sum ~/ n);
    }
  }
  return out;
}

class _MeleeFeatures {
  _MeleeFeatures({
    required this.signaturePalette,
    required this.verticalCleaveScore,
    required this.purpleLowScore,
    required this.diagonalCrossScore,
    required this.tripleRakeScore,
  });

  final List<int> signaturePalette;
  final int verticalCleaveScore;
  final int purpleLowScore;
  final int diagonalCrossScore;
  final int tripleRakeScore;
}

_MeleeFeatures _measureFeatures(Uint8List rgba, int w, int h) {
  var verticalCleave = 0;
  var purpleLow = 0;
  var diagonalCross = 0;
  var tripleRake = 0;
  var redBucket = 0;
  var purpleBucket = 0;
  var goldBucket = 0;
  var shredBucket = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final a = rgba[i + 3];
      if (a < 40) continue;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final luma = (r * 30 + g * 59 + b * 11) ~/ 100;
      if (luma < 70) continue;
      if (r > 170 && g < 130) redBucket++;
      if (b > 140 && r > 90 && g < 160) purpleBucket++;
      if (r > 180 && g > 150 && b < 140) goldBucket++;
      if (r > 140 && g < 100) shredBucket++;
      final nx = x / w;
      final ny = y / h;
      if (r > 195 && g < 90 && b < 90) {
        verticalCleave++;
      }
      if (b > 150 && r > 100 && g < 150 && nx < 0.6 && ny > 0.4) {
        purpleLow++;
      }
      if (luma > 110 && luma < 250 && nx > 0.4 && ny < 0.65) {
        diagonalCross++;
      }
      if (r > 150 && g < 95 && ny > 0.25) {
        tripleRake++;
      }
    }
  }
  return _MeleeFeatures(
    signaturePalette: [redBucket, purpleBucket, goldBucket, shredBucket],
    verticalCleaveScore: verticalCleave,
    purpleLowScore: purpleLow,
    diagonalCrossScore: diagonalCross,
    tripleRakeScore: tripleRake,
  );
}

/// Pre-signature overlay stack (main before feat/melee-signature-vfx).
void _paintLegacyMeleeOverlay(
  Canvas canvas,
  Rect tileRect,
  AbilityId id,
  ClassAbilityDef def, {
  required double life,
}) {
  final tile = tileRect.width / 3.2;
  final cx = tileRect.center.dx;
  final cy = tileRect.center.dy - tile * 0.15;
  final c = Offset(cx, cy);
  final r = tile * 0.95 * (0.85 + (1 - life) * 0.25);
  final alpha = (life / 0.55).clamp(0.0, 1.0);
  final ramp = SpellSchoolRamp.forStyle(def.boltStyle ?? SpellBoltStyle.weapon);
  switch (id) {
    case AbilityId.executeFury:
      _legacyImpactStar(canvas, c, r * 0.65, alpha, ramp, tile);
      _legacyBlood(canvas, c, r, alpha);
    case AbilityId.kidneyShotAssa:
    case AbilityId.maim:
      _legacyStunStars(canvas, c, r, alpha, tile);
      _legacyImpactStar(canvas, c, r * 0.55, alpha, ramp, tile);
    case AbilityId.revealingStrike:
      _legacyImpactStar(canvas, c, r * 0.75, alpha, ramp, tile);
    default:
      break;
  }
}

void _legacyImpactStar(
  Canvas canvas,
  Offset c,
  double r,
  double alpha,
  SpellSchoolRamp ramp,
  double tile,
) {
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    final len = i.isEven ? r : r * 0.45;
    canvas.drawLine(
      c,
      Offset(c.dx + math.cos(a) * len, c.dy + math.sin(a) * len),
      Paint()
        ..color = ramp.hot.withValues(alpha: alpha)
        ..strokeWidth = math.max(2.4, tile * 0.08)
        ..strokeCap = StrokeCap.round,
    );
  }
}

void _legacyStunStars(Canvas canvas, Offset c, double r, double alpha, double tile) {
  for (var i = 0; i < 4; i++) {
    final p = Offset(
      c.dx + math.cos(i * 1.57) * r * 0.62,
      c.dy + math.sin(i * 1.57) * r * 0.45 - r * 0.08,
    );
    for (var s = 0; s < 4; s++) {
      final a = s * math.pi / 2;
      canvas.drawLine(
        p,
        Offset(p.dx + math.cos(a) * r * 0.22, p.dy + math.sin(a) * r * 0.22),
        Paint()
          ..color = const Color(0xFFFFF6C0).withValues(alpha: alpha)
          ..strokeWidth = math.max(2.2, tile * 0.07)
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

void _legacyBlood(Canvas canvas, Offset c, double r, double alpha) {
  for (var i = 0; i < 5; i++) {
    final a = i * 1.25;
    canvas.drawCircle(
      Offset(c.dx + math.cos(a) * r * 0.55, c.dy + math.sin(a) * r * 0.35),
      r * 0.08,
      Paint()..color = const Color(0xFF901818).withValues(alpha: alpha * 0.85),
    );
  }
}

Future<Uint8List> _pngFromRecorder(ui.PictureRecorder recorder, int w, int h) async {
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}