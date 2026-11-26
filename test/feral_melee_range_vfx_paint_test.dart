import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/spell_bolt_style.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/spell_shape_paint.dart';

import 'shell_golden_harness.dart';

/// Root cause (sim, unchanged):
/// - `ability_effects.dart` `_castRoot` ~2325: melee casts still spawn a weapon
///   [SpatialCombat.addProjectile] when `actorDist > 2.0`.
/// - `_castRoot` ~2323 + `announce` ~2459: short disc burst spawns on the caster.
/// - `_castSingleTargetDamage` ~1425: `useBolt` when dist > 2.2 for kit damage.
/// Feral is melee (`hero_spec.dart` feral: `ranged: false`); paint hides travel bolts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShellGoldenFonts();
  });

  test('melee spec skips unpainted travel weapon bolt', () {
    final bolt = SpatialProjectile(
      x: 1,
      y: 1,
      vx: 2,
      vy: 0,
      damage: 12,
      team: SpatialTeam.hero,
      style: SpellBoltStyle.weapon,
      casterId: 'hero_0',
    );
    expect(
      SpellShapePaint.shouldSkipMeleeAbilityTravelBolt(
        projectile: bolt,
        casterRanged: false,
      ),
      isTrue,
    );
    expect(
      SpellShapePaint.shouldSkipMeleeAbilityTravelBolt(
        projectile: bolt,
        casterRanged: true,
      ),
      isFalse,
    );
    final labeled = SpatialProjectile(
      x: 1,
      y: 1,
      vx: 2,
      vy: 0,
      damage: 12,
      team: SpatialTeam.hero,
      style: SpellBoltStyle.weapon,
      label: 'Fire',
      casterId: 'hero_0',
    );
    expect(
      SpellShapePaint.shouldSkipMeleeAbilityTravelBolt(
        projectile: labeled,
        casterRanged: false,
      ),
      isFalse,
    );
  });

  test('compact caster burst replaces announce disc', () async {
    const tile = 48.0;
    final announceBurst = SpatialBurst(
      x: 0,
      y: 0,
      life: 0.22,
      argb: 0xFF80D0FF,
      radius: 0.55,
    );
    final w = 160;
    final h = 160;
    expect(SpellShapePaint.usesCompactCasterBurst(announceBurst), isTrue);
    final before = await _renderCasterOnly(w, h, announceBurst, useDisc: true, tile: tile);
    final after = await _renderCasterOnly(w, h, announceBurst, useDisc: false, tile: tile);
    final beforeMass = _discMassPixels(before, w, h);
    final afterMass = _discMassPixels(after, w, h);
    expect(beforeMass, greaterThan(afterMass + 80));
    expect(afterMass, lessThan(35));
    if (Platform.environment['RENDER_MELEE_SIG'] == '1') {
      final stripW = w * 2;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, stripW.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFF100C14),
      );
      final bPng = await _renderCasterPng(w, h, announceBurst, useDisc: true, tile: tile);
      final aPng = await _renderCasterPng(w, h, announceBurst, useDisc: false, tile: tile);
      final bCodec = await ui.instantiateImageCodec(bPng);
      final aCodec = await ui.instantiateImageCodec(aPng);
      final bImg = (await bCodec.getNextFrame()).image;
      final aImg = (await aCodec.getNextFrame()).image;
      canvas.drawImage(bImg, Offset.zero, Paint());
      canvas.drawImage(aImg, Offset(w.toDouble(), 0), Paint());
      bImg.dispose();
      aImg.dispose();
      final image = await recorder.endRecording().toImage(stripW, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final out = File('docs/design/abilities-61/rendered/feral_maim_caster_disc_before_after.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(data!.buffer.asUint8List());
    }
  });
}

Future<Uint8List> _renderCasterOnly(
  int w,
  int h,
  SpatialBurst cast, {
  required bool useDisc,
  required double tile,
}) async {
  Offset at(double tx, double ty) => Offset(w / 2 + tx * tile, h / 2 + ty * tile);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF231A28));
  final alpha = (cast.life / 0.55).clamp(0.0, 1.0);
  final c = at(cast.x, cast.y);
  final r = tile * cast.radius * (1.15 - alpha * 0.28);
  if (useDisc) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xAA100C08).withValues(alpha: alpha * 0.85));
    canvas.drawCircle(c, r * 0.82, Paint()..color = Color(cast.argb).withValues(alpha: alpha * 0.7));
    canvas.drawCircle(c, r * 0.42, Paint()..color = Colors.white.withValues(alpha: alpha * 0.9));
  } else {
    SpellShapePaint.paintWorldBurst(canvas, cast, tile, at);
  }
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _renderCasterPng(
  int w,
  int h,
  SpatialBurst cast, {
  required bool useDisc,
  required double tile,
}) async {
  Offset at(double tx, double ty) => Offset(w / 2 + tx * tile, h / 2 + ty * tile);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF231A28));
  final alpha = (cast.life / 0.55).clamp(0.0, 1.0);
  final c = at(cast.x, cast.y);
  final r = tile * cast.radius * (1.15 - alpha * 0.28);
  if (useDisc) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xAA100C08).withValues(alpha: alpha * 0.85));
    canvas.drawCircle(c, r * 0.82, Paint()..color = Color(cast.argb).withValues(alpha: alpha * 0.7));
    canvas.drawCircle(c, r * 0.42, Paint()..color = Colors.white.withValues(alpha: alpha * 0.9));
  } else {
    SpellShapePaint.paintWorldBurst(canvas, cast, tile, at);
  }
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

int _discMassPixels(Uint8List rgba, int w, int h) {
  var n = 0;
  final cx = w ~/ 2;
  final cy = h ~/ 2;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy);
      if (d2 > (w * 0.28) * (w * 0.28)) continue;
      final i = (y * w + x) * 4;
      if (rgba[i + 3] < 50) continue;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final luma = (r * 30 + g * 59 + b * 11) ~/ 100;
      if (luma > 85) n++;
    }
  }
  return n;
}