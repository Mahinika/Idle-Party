import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/class_ability.dart';
import 'package:idle_party/models/vfx_quality.dart';
import 'package:idle_party/spatial/spatial_combat.dart';
import 'package:idle_party/ui/ability_vfx_paint.dart';

void main() {
  test('cast glint ends while the lockout flash is still up', () {
    expect(
      AbilityVfxPaint.showCastGlint(quality: VfxQuality.full, castFlash: 0.35),
      isTrue,
    );
    expect(
      AbilityVfxPaint.showCastGlint(quality: VfxQuality.lite, castFlash: 0.21),
      isTrue,
    );
    expect(
      AbilityVfxPaint.showCastGlint(
        quality: VfxQuality.full,
        castFlash: SpellVfx.castGlintFloor,
      ),
      isFalse,
    );
    expect(
      AbilityVfxPaint.showCastGlint(
        quality: VfxQuality.minimal,
        castFlash: 0.35,
      ),
      isFalse,
    );
  });

  test('signature impact life, 2× steps, and a paused step stay bounded', () {
    final world = _world();
    world.reducedVfx = false;
    world.spawnPersistentVfx = true;
    final hero = world.heroes.first;
    hero.castFlash = 0.35;
    SpellVfx.spawnImpact(
      world,
      x: hero.x,
      y: hero.y,
      style: SpellBoltStyle.fire,
      id: AbilityId.pyroblast,
    );
    SpellVfx.spawnImpact(
      world,
      x: hero.x + 1,
      y: hero.y,
      style: SpellBoltStyle.fire,
      id: AbilityId.fireball,
    );
    expect(world.bursts, hasLength(2));
    final big = world.bursts.firstWhere((b) => b.crisp);
    final routine = world.bursts.firstWhere((b) => !b.crisp);
    expect(big.life, SpellVfx.bigImpactLife);
    expect(big.kind, SpatialBurstKind.flame);
    expect(routine.life, closeTo(0.52, 0.001));
    expect(routine.crisp, isFalse);
    expect(world.bursts.length, lessThanOrEqualTo(16));
    expect(world.spellSparks.length, lessThanOrEqualTo(SpellSparks.capFull));

    SpatialCombat.agePresentationForTest(world, 0);
    expect(
      world.bursts.firstWhere((b) => b.crisp).life,
      closeTo(SpellVfx.bigImpactLife, 0.001),
    );
    expect(hero.castFlash, 0.35);

    final once = _impactWorld();
    SpatialCombat.agePresentationForTest(once, 1 / 60);
    final twice = _impactWorld();
    SpatialCombat.agePresentationForTest(twice, 1 / 60);
    SpatialCombat.agePresentationForTest(twice, 1 / 60);
    final doubled = _impactWorld();
    SpatialCombat.agePresentationForTest(doubled, 2 / 60);
    double crispLife(SpatialWorld w) =>
        w.bursts.firstWhere((b) => b.crisp).life;
    expect(crispLife(once), closeTo(SpellVfx.bigImpactLife - 1 / 60, 0.002));
    expect(crispLife(twice), closeTo(crispLife(doubled), 0.002));
    expect(twice.bursts.where((b) => b.crisp).length, 1);
    expect(
      SpellVfx.castGlintVisible(
        reduceMotion: false,
        castFlash: twice.heroes.first.castFlash,
      ),
      isTrue,
    );

    SpatialCombat.agePresentationForTest(world, 0.2);
    expect(
      SpellVfx.castGlintVisible(reduceMotion: false, castFlash: hero.castFlash),
      isFalse,
    );
    expect(world.bursts.any((b) => b.crisp), isTrue);
  });

  test(
    'a cast release adds no extra white burst on Full, Lite, or Minimal',
    () {
      final world = _world();
      final hero = world.heroes.first;
      world.reducedVfx = false;
      world.spawnPersistentVfx = true;
      hero.castFlash = 0.35;
      SpellVfx.spawnCast(
        world,
        hero: hero,
        style: SpellBoltStyle.fire,
        id: AbilityId.pyroblast,
      );
      expect(world.bursts.length, lessThanOrEqualTo(2));
      expect(world.bursts.every((b) => !b.crisp), isTrue);
      expect(world.bursts.any((b) => b.argb == 0xFFFFFFFF), isFalse);
      expect(world.spellSparks.length, lessThanOrEqualTo(SpellSparks.capFull));

      world.bursts.clear();
      world.spellSparks.clear();
      world.reducedVfx = true;
      world.spawnPersistentVfx = true;
      SpellVfx.spawnImpact(
        world,
        x: hero.x,
        y: hero.y,
        style: SpellBoltStyle.holy,
        id: AbilityId.holyWrath,
      );
      expect(world.bursts, isEmpty);
      expect(world.spellSparks, isNotEmpty);
      expect(world.spellSparks.length, lessThanOrEqualTo(SpellSparks.capLite));

      world.bursts.clear();
      world.spellSparks.clear();
      world.spawnPersistentVfx = false;
      SpellVfx.spawnImpact(
        world,
        x: hero.x,
        y: hero.y,
        style: SpellBoltStyle.shadow,
        id: AbilityId.deathCoil,
      );
      expect(world.bursts, isEmpty);
      expect(world.spellSparks, isEmpty);
    },
  );

  test('hero and hostile bolt marks differ with color removed', () async {
    final hero = await _luma((canvas) {
      AbilityVfxPaint.paintBoltAllegiance(canvas, hero: true, thick: 6);
    });
    final foe = await _luma((canvas) {
      AbilityVfxPaint.paintBoltAllegiance(canvas, hero: false, thick: 6);
    });
    expect(hero.where((v) => v > 0).length, greaterThan(8));
    expect(foe.where((v) => v > 0).length, greaterThan(8));
    var differ = 0;
    for (var i = 0; i < hero.length; i++) {
      if ((hero[i] > 0) != (foe[i] > 0)) differ++;
    }
    expect(differ, greaterThan(12));

    final glint = await _luma((canvas) {
      AbilityVfxPaint.paintCastGlint(canvas, Offset.zero, 32, 0.35);
    });
    expect(glint.where((v) => v > 0).length, greaterThan(8));
    final quiet = await _luma((canvas) {
      AbilityVfxPaint.paintCastGlint(canvas, Offset.zero, 32, 0.1);
    });
    expect(quiet.every((v) => v == 0), isTrue);

    final core = await _rgba((canvas) {
      AbilityVfxPaint.paintCrispCore(canvas, Offset.zero, 10, 1);
    });
    final center = _at(core, 24, 24);
    final edge = _at(core, 4, 4);
    expect(center[3], greaterThan(200));
    expect(edge[3], 0);
    final sheet = Platform.environment['VFX_SHEET'];
    if (sheet != null) {
      await _writeSheet(sheet);
    }
  });
}

SpatialWorld _impactWorld() {
  final world = _world();
  world.reducedVfx = false;
  world.spawnPersistentVfx = true;
  final hero = world.heroes.first;
  hero.castFlash = 0.35;
  SpellVfx.spawnImpact(
    world,
    x: hero.x,
    y: hero.y,
    style: SpellBoltStyle.fire,
    id: AbilityId.pyroblast,
  );
  return world;
}

SpatialWorld _world() {
  final state = GameLogic.createInitialState(now: DateTime(2026, 9, 29));
  final entered = GameLogic.enterDungeon(state, dungeonId: 'sandy');
  final world = SpatialCombat.build(entered);
  final stepped = SpatialCombat.step(world, entered, dt: 0.01).world;
  stepped.bursts.clear();
  stepped.spellSparks.clear();
  return stepped;
}

Future<List<int>> _luma(void Function(Canvas canvas) paint) async {
  final rgba = await _rgba(paint);
  final out = <int>[];
  for (var i = 0; i < rgba.length; i += 4) {
    final a = rgba[i + 3];
    out.add(
      a > 20 ? (rgba[i] * 30 + rgba[i + 1] * 59 + rgba[i + 2] * 11) ~/ 100 : 0,
    );
  }
  return out;
}

Future<List<int>> _rgba(void Function(Canvas canvas) paint) async {
  const n = 48;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.translate(n / 2, n / 2);
  paint(canvas);
  final image = await recorder.endRecording().toImage(n, n);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

List<int> _at(List<int> rgba, int x, int y) {
  const n = 48;
  final i = (y * n + x) * 4;
  return rgba.sublist(i, i + 4);
}

Future<void> _writeSheet(String path) async {
  const w = 720;
  const h = 280;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF1A1420),
  );
  canvas.save();
  canvas.translate(80, 120);
  AbilityVfxPaint.paintCastGlint(canvas, Offset.zero, 64, 0.35);
  canvas.restore();

  for (final hero in [true, false]) {
    final ox = hero ? 300.0 : 530.0;
    canvas.save();
    canvas.translate(ox, 110);
    canvas.drawCircle(
      Offset.zero,
      18,
      Paint()..color = hero ? const Color(0xFFFFE08A) : const Color(0xFFFF6A4A),
    );
    AbilityVfxPaint.paintBoltAllegiance(canvas, hero: hero, thick: 8);
    canvas.restore();
    canvas.save();
    canvas.translate(ox, 190);
    canvas.drawCircle(
      Offset.zero,
      18,
      Paint()..color = const Color(0xFFB0B0B0),
    );
    AbilityVfxPaint.paintBoltAllegiance(canvas, hero: hero, thick: 8);
    canvas.restore();
  }
  canvas.save();
  canvas.translate(80, 220);
  canvas.drawCircle(Offset.zero, 22, Paint()..color = const Color(0xFFFF3C10));
  AbilityVfxPaint.paintCrispCore(canvas, Offset.zero, 16, 1);
  canvas.restore();

  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}
