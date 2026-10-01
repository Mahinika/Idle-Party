import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/starter_gear.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/character_layer.dart';
import 'package:idle_party/visual/character_visual_pose.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/rig/hero_rig_painter.dart';
import 'package:idle_party/visual/rig/rig_clips.dart';
import 'package:idle_party/visual/rig/rig_data.dart';
import 'package:idle_party/visual/rig/rig_draw.dart';
import 'package:idle_party/visual/rig/rig_pose.dart';
import 'package:idle_party/visual/rig/rig_sampler.dart';

Future<ui.Image> _png(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('posed warrior grows no whiskers and keeps the sword grip', () async {
    final rig = RigData.parse(
      'warrior',
      jsonDecode(File('assets/custom/rig/warrior.json').readAsStringSync()) as Map<String, dynamic>,
    );
    final hero = PartyHero.starting(
      name: 'Aegis',
      specId: HeroSpecId.arms,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.arms),
    ).copyWith(equipped: StarterGear.forSpec(HeroSpecId.arms));
    final bodyPath = BodyFamilyCatalog.catalog[BodyFamily.warrior]!.idleAsset;
    final body = await _png(bodyPath);
    final idlePose = CharacterVisualPose.resolve(
      hero: hero,
      anim: const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0),
      owned: true,
    );
    final images = <String, ui.Image>{};
    for (final layer in idlePose.layers) {
      final path = layer.ownedAsset;
      if (path != null && File(path).existsSync()) images[path] = await _png(path);
    }
    final tint = idlePose.bodyTintAsset;
    if (tint != null && File(tint).existsSync()) images[tint] = await _png(tint);
    await HeroRigPainter.warm(
      rig: rig,
      bodyImage: body,
      bodyKey: bodyPath,
      images: images,
      pose: idlePose,
    );

    Future<ui.Image> shoot(HeroAnimPose anim) async {
      final framed = CharacterVisualPose.resolve(hero: hero, anim: anim, owned: true);
      void draw() {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        HeroRigPainter.paint(
          canvas,
          const ui.Offset(128, 128),
          128,
          bodyImage: body,
          bodyKey: bodyPath,
          images: images,
          pose: framed,
          rig: rig,
          heroId: 'clips',
        );
        recorder.endRecording().dispose();
      }

      draw();
      await HeroRigPainter.settle();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      HeroRigPainter.paint(
        canvas,
        const ui.Offset(128, 128),
        128,
        bodyImage: body,
        bodyKey: bodyPath,
        images: images,
        pose: framed,
        rig: rig,
        heroId: 'clips',
      );
      final picture = recorder.endRecording();
      final image = picture.toImageSync(256, 256);
      picture.dispose();
      return image;
    }

    final restMask = await _mask(await shoot(const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0)));
    for (final kind in HeroAnimKind.values) {
      final clip = RigClips.forKind(kind);
      final steps = (clip.length * RigSampler.fps).ceil().clamp(1, 24);
      for (var step = 0; step < steps; step++) {
        final shot = await shoot(HeroAnimPose(kind: kind, frame: 0, progress: step / steps));
        final islands = await _newIslands(shot, restMask);
        expect(islands, 0, reason: '${kind.name}@$step');
      }
    }

    const attack = HeroAnimPose(kind: HeroAnimKind.attack, frame: 0, progress: 0.45);
    final framed = CharacterVisualPose.resolve(hero: hero, anim: attack, owned: true);
    final sample = RigSampler.sample(attack);
    final world = RigSolver.world(rig, sample.pose);
    final grip = HeroRigDraw.gripPoint(rig, world, framed, offHand: false);
    final shot = await shoot(attack);
    final pixels = (await shot.toByteData())!;
    final x = grip.dx.round().clamp(0, 255);
    final y = grip.dy.round().clamp(0, 255);
    final index = (y * 256 + x) * 4;
    final weapon = framed.layers.firstWhere((layer) => layer.id == CharacterLayerId.mainHand);
    final source = images[weapon.ownedAsset]!;
    final raw = (await source.toByteData())!;
    const gripX = 95;
    const gripY = 87;
    final sourceIndex = (gripY * source.width + gripX) * 4;
    var expectR = raw.getUint8(sourceIndex);
    var expectG = raw.getUint8(sourceIndex + 1);
    var expectB = raw.getUint8(sourceIndex + 2);
    final wash = weapon.tint;
    if (wash != null) {
      expectR = (expectR * (wash.r * 255).round() / 255).round();
      expectG = (expectG * (wash.g * 255).round() / 255).round();
      expectB = (expectB * (wash.b * 255).round() / 255).round();
    }
    expect(pixels.getUint8(index), closeTo(expectR, 8), reason: 'grip red');
    expect(pixels.getUint8(index + 1), closeTo(expectG, 8), reason: 'grip green');
    expect(pixels.getUint8(index + 2), closeTo(expectB, 8), reason: 'grip blue');
    final boneName = rig.handBones['main']!;
    final bone = world[boneName]!;
    final restBone = rig.bones[boneName]!;
    final dx = grip.dx - RigData.origin - bone.x;
    final dy = grip.dy - RigData.origin - bone.y;
    final rad = -bone.deg * math.pi / 180;
    final c = math.cos(rad);
    final s = math.sin(rad);
    final lx = restBone.restX + c * dx - s * dy;
    final ly = restBone.restY + s * dx + c * dy;
    expect(
      rig.contains(lx.round(), ly.round(), boneName),
      isTrue,
      reason: 'grip left $boneName',
    );
  });

  test('posed rogue grows no whiskers', () async {
    await _expectNoNewIslands(BodyFamily.rogue, HeroSpecId.assassination);
  });

  test('posed mage grows no whiskers', () async {
    await _expectNoNewIslands(BodyFamily.mage, HeroSpecId.arcane);
  });
}

Future<void> _expectNoNewIslands(BodyFamily family, HeroSpecId spec) async {
  final rig = RigData.parse(
    family.name,
    jsonDecode(File('assets/custom/rig/${family.name}.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final hero = PartyHero.starting(
    name: 'Shade',
    specId: spec,
    stats: PartyHero.startingStatsForSpec(spec),
  ).copyWith(equipped: StarterGear.forSpec(spec));
  final bodyPath = BodyFamilyCatalog.catalog[family]!.idleAsset;
  final body = await _png(bodyPath);
  final idlePose = CharacterVisualPose.resolve(
    hero: hero,
    anim: const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0),
    owned: true,
  );
  final images = <String, ui.Image>{};
  for (final layer in idlePose.layers) {
    final path = layer.ownedAsset;
    if (path != null && File(path).existsSync()) images[path] = await _png(path);
  }
  final tint = idlePose.bodyTintAsset;
  if (tint != null && File(tint).existsSync()) images[tint] = await _png(tint);
  await HeroRigPainter.warm(
    rig: rig,
    bodyImage: body,
    bodyKey: bodyPath,
    images: images,
    pose: idlePose,
  );

  Future<ui.Image> shoot(HeroAnimPose anim) async {
    final framed = CharacterVisualPose.resolve(hero: hero, anim: anim, owned: true);
    void draw() {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      HeroRigPainter.paint(
        canvas,
        const ui.Offset(128, 128),
        128,
        bodyImage: body,
        bodyKey: bodyPath,
        images: images,
        pose: framed,
        rig: rig,
        heroId: '${family.name}-clips',
      );
      recorder.endRecording().dispose();
    }

    draw();
    await HeroRigPainter.settle();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    HeroRigPainter.paint(
      canvas,
      const ui.Offset(128, 128),
      128,
      bodyImage: body,
      bodyKey: bodyPath,
      images: images,
      pose: framed,
      rig: rig,
      heroId: '${family.name}-clips',
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(256, 256);
    picture.dispose();
    return image;
  }

  final restMask = await _mask(await shoot(const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0)));
  for (final kind in HeroAnimKind.values) {
    final clip = RigClips.forKind(kind);
    final steps = (clip.length * RigSampler.fps).ceil().clamp(1, 24);
    for (var step = 0; step < steps; step++) {
      final shot = await shoot(HeroAnimPose(kind: kind, frame: 0, progress: step / steps));
      final islands = await _newIslands(shot, restMask);
      expect(islands, 0, reason: '${family.name} ${kind.name}@$step');
    }
  }
}

Future<List<bool>> _mask(ui.Image image) async {
  final data = (await image.toByteData())!;
  image.dispose();
  return [for (var i = 0; i < 256 * 256; i++) data.getUint8(i * 4 + 3) > 40];
}

Future<int> _newIslands(ui.Image image, List<bool> rest) async {
  final data = (await image.toByteData())!;
  final on = List<bool>.filled(256 * 256, false);
  for (var i = 0; i < on.length; i++) {
    on[i] = data.getUint8(i * 4 + 3) > 40;
  }
  final seen = List<bool>.filled(on.length, false);
  var fresh = 0;
  for (var i = 0; i < on.length; i++) {
    if (!on[i] || seen[i]) continue;
    final stack = <int>[i];
    seen[i] = true;
    var area = 0;
    var minX = 999;
    var maxX = 0;
    var minY = 999;
    var maxY = 0;
    var overlapsRest = false;
    while (stack.isNotEmpty) {
      final here = stack.removeLast();
      area++;
      final x = here % 256;
      final y = here ~/ 256;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (rest[here]) overlapsRest = true;
      for (final next in [here - 1, here + 1, here - 256, here + 256]) {
        if (next < 0 || next >= on.length || seen[next] || !on[next]) continue;
        if ((next % 256 - x).abs() + (next ~/ 256 - y).abs() != 1) continue;
        seen[next] = true;
        stack.add(next);
      }
    }
    final span = math.min(maxX - minX, maxY - minY);
    if (!overlapsRest && span <= 4 && area < 40) fresh++;
  }
  return fresh;
}
