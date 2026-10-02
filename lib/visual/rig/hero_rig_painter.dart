import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../body_family.dart';
import '../character_layer.dart';
import '../character_visual_painter.dart';
import '../character_visual_pose.dart';
import '../owned_gear_assets.dart';
import '../shadowform.dart';
import 'hero_rig_library.dart';
import 'rig_data.dart';
import 'rig_draw.dart';
import 'rig_part_cache.dart';
import 'rig_pose.dart';
import 'rig_sampler.dart';

/// Paints one hero into a 256 source image (1 pixel = 1 texel), then scales it up.
abstract final class HeroRigPainter {
  static const source = RigData.frame;

  static final Map<String, ui.Image> _frames = {};
  static final Map<String, String> _equip = {};
  static final Map<String, ui.Image> _solid = {};
  static final List<Future<void>> _strips = [];

  /// Race idle when that clip is loaded, otherwise the family idle.
  ///
  /// The bone map is the idle pose. A walk frame must not be cut with it,
  /// and the family human clip must not replace a chosen race.
  static String? pickRigBody({
    required String? raceIdle,
    required String? familyIdle,
    required bool Function(String path) loaded,
  }) {
    if (raceIdle != null && loaded(raceIdle)) return raceIdle;
    if (familyIdle != null && loaded(familyIdle)) return familyIdle;
    return null;
  }

  static String? rigBodyKey(
    CharacterVisualPose pose,
    Map<String, ui.Image> images,
  ) {
    final family = pose.bodyFamily;
    return pickRigBody(
      raceIdle: pose.bodyIdleAsset,
      familyIdle: family == null
          ? null
          : BodyFamilyCatalog.catalog[family]?.idleAsset,
      loaded: images.containsKey,
    );
  }

  /// Idle cloth mask for [bodyKey] when it is loaded. Spec color then stays
  /// on the same clip the bones were cut from.
  static String? tintForRigBody(
    CharacterVisualPose pose,
    String bodyKey,
    Map<String, ui.Image> images,
  ) {
    final idleTint = BodyFamilyDef.tintMaskForBodyAsset(bodyKey);
    if (images.containsKey(idleTint)) return idleTint;
    final posed = pose.bodyTintAsset;
    if (posed != null && images.containsKey(posed)) return posed;
    return null;
  }

  /// Waits until cached frames have dropped 1px rotation debris.
  static Future<void> settle() async {
    final pending = List<Future<void>>.of(_strips);
    _strips.clear();
    await Future.wait(pending);
  }

  static void paintOwned(
    ui.Canvas canvas,
    ui.Offset center,
    double size, {
    required ui.Image body,
    required Map<String, ui.Image> images,
    required CharacterVisualPose pose,
    double alpha = 1,
    String heroId = '',
  }) {
    final family = pose.bodyFamily;
    final rig = family == null ? null : HeroRigLibrary.peek(family);
    final idleKey = rigBodyKey(pose, images);
    final idle = idleKey == null ? null : images[idleKey];
    if (rig != null && idle != null && idleKey != null) {
      paint(
        canvas,
        center,
        size,
        bodyImage: idle,
        bodyKey: idleKey,
        images: images,
        pose: pose,
        rig: rig,
        alpha: alpha,
        heroId: heroId,
      );
      return;
    }
    CharacterVisualPainter.paintOwnedHero(
      canvas,
      center,
      size,
      body: body,
      images: images,
      pose: pose,
      alpha: alpha,
    );
  }

  static Future<void> warm({
    required RigData rig,
    required ui.Image bodyImage,
    required String bodyKey,
    required Map<String, ui.Image> images,
    required CharacterVisualPose pose,
  }) async {
    await _atlas(rig, bodyImage, RigPartCache.key(bodyKey, rig.family, 0, 1));
    final tintPath = tintForRigBody(pose, bodyKey, images);
    final tint = tintPath == null ? null : images[tintPath];
    if (tint != null && tintPath != null) {
      await _atlas(
        rig,
        tint,
        RigPartCache.key(
          tintPath,
          rig.family,
          0,
          OwnedGearAssets.undertunicShoeTop,
        ),
        cropBottom: OwnedGearAssets.undertunicShoeTop,
      );
    }
    for (final layer in pose.orderedLayers()) {
      final path = layer.ownedAsset;
      final image = path == null ? null : images[path];
      if (path == null || image == null) continue;
      final solid = await _solidOf(path, image);
      if (_weapon(layer) || layer.id == CharacterLayerId.cape) continue;
      await _atlas(
        rig,
        solid,
        RigPartCache.key(path, rig.family, layer.cropTop, 1),
        cropTop: layer.cropTop,
      );
      final dyePath = layer.dyeMaskAsset;
      final dye = dyePath == null ? null : images[dyePath];
      if (dyePath != null && dye != null) {
        final solidDye = await _solidOf(dyePath, dye);
        await _atlas(
          rig,
          solidDye,
          RigPartCache.key(dyePath, rig.family, 0, 1),
        );
      }
    }
  }

  /// Gear with soft edges or a one-pixel hole, keyed by asset path.
  static Future<ui.Image> _solidOf(String path, ui.Image image) async {
    final hit = _solid[path];
    if (hit != null) return hit;
    final sealed = await RigPartCache.solidImage(image);
    return _solid[path] ??= sealed;
  }

  static bool ready({
    required RigData rig,
    required String bodyKey,
    required Map<String, ui.Image> images,
    required CharacterVisualPose pose,
  }) {
    if (RigPartCache.peek(RigPartCache.key(bodyKey, rig.family, 0, 1)) ==
        null) {
      return false;
    }
    for (final layer in pose.orderedLayers()) {
      final path = layer.ownedAsset;
      if (path == null || images[path] == null) continue;
      if (_weapon(layer) || layer.id == CharacterLayerId.cape) continue;
      final key = RigPartCache.key(path, rig.family, layer.cropTop, 1);
      if (RigPartCache.peek(key) == null) return false;
    }
    return true;
  }

  static void paint(
    ui.Canvas canvas,
    ui.Offset center,
    double size, {
    required ui.Image bodyImage,
    required String bodyKey,
    required Map<String, ui.Image> images,
    required CharacterVisualPose pose,
    required RigData rig,
    double alpha = 1,
    String heroId = '',
  }) {
    if (!size.isFinite ||
        size <= 0 ||
        !center.dx.isFinite ||
        !center.dy.isFinite) {
      return;
    }
    if (!ready(rig: rig, bodyKey: bodyKey, images: images, pose: pose)) {
      warm(
        rig: rig,
        bodyImage: bodyImage,
        bodyKey: bodyKey,
        images: images,
        pose: pose,
      );
      CharacterVisualPainter.paintOwnedHero(
        canvas,
        center,
        size,
        body: bodyImage,
        images: images,
        pose: pose,
        alpha: alpha,
      );
      return;
    }
    final frame = _frame(
      rig: rig,
      bodyKey: bodyKey,
      images: images,
      pose: pose,
      heroId: heroId,
    );
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..isAntiAlias = false
      ..color = ui.Color.fromRGBO(255, 255, 255, alpha);
    if (pose.shadowform) paint.colorFilter = Shadowform.wash;
    canvas.save();
    if (pose.flipX) {
      canvas.translate(center.dx, center.dy);
      canvas.scale(-1, 1);
      canvas.translate(-center.dx, -center.dy);
    }
    final dst = ui.Rect.fromCenter(
      center: center,
      width: size * 2,
      height: size * 2,
    );
    canvas.drawImageRect(
      frame,
      ui.Rect.fromLTWH(0, 0, source.toDouble(), source.toDouble()),
      dst,
      paint,
    );
    canvas.restore();
  }

  /// Grip point on screen, after the rig and the facing flip.
  static ui.Offset handPoint({
    required ui.Offset center,
    required double size,
    required CharacterVisualPose pose,
    required RigData rig,
    bool offHand = false,
  }) {
    final sample = RigSampler.sample(
      pose.anim,
      abilityName: pose.anim.abilityName,
      robe: rig.bones.containsKey('skirt'),
    );
    final world = RigSolver.world(rig, sample.pose);
    final point = HeroRigDraw.gripPoint(rig, world, pose, offHand: offHand);
    final scale = size / RigData.canvas;
    var dx = (point.dx - (RigData.origin + RigData.canvas / 2)) * scale;
    final dy = (point.dy - (RigData.origin + RigData.canvas / 2)) * scale;
    if (pose.flipX) dx = -dx;
    return ui.Offset(center.dx + dx, center.dy + dy);
  }

  static ui.Image _frame({
    required RigData rig,
    required String bodyKey,
    required Map<String, ui.Image> images,
    required CharacterVisualPose pose,
    required String heroId,
  }) {
    final sample = RigSampler.sample(
      pose.anim,
      abilityName: pose.anim.abilityName,
      robe: rig.bones.containsKey('skirt'),
    );
    final hash = pose.equipHash;
    if (_equip[heroId] != hash) {
      _frames.removeWhere((key, image) {
        if (!key.startsWith('$heroId|')) return false;
        image.dispose();
        return true;
      });
      _equip[heroId] = hash;
    }
    final cacheKey =
        '$heroId|$hash|$bodyKey|${sample.clip}|${sample.stepIndex}|${pose.bodyTint}|${pose.anim.blocking}';
    final cached = _frames[cacheKey];
    if (cached != null) return cached;
    final world = RigSolver.world(rig, sample.pose);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    _drawStack(canvas, rig, world, sample.pose, pose, bodyKey, images);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(source, source);
    picture.dispose();
    _frames[cacheKey] = image;
    _strips.add(_strip(cacheKey, image));
    return image;
  }

  static Future<void> _strip(String key, ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null || _frames[key] != image) return;
    final bytes = data.buffer.asUint8List();
    final closed = _closeCracks(bytes, source);
    final kill = _slivers(bytes, source);
    if (!closed && kill.isEmpty) return;
    for (final index in kill) {
      bytes[index * 4 + 3] = 0;
    }
    final clean = await _decode(bytes, source, source);
    if (_frames[key] != image) {
      clean.dispose();
      return;
    }
    _frames[key] = clean;
  }

  static Future<ui.Image> _decode(Uint8List pixels, int width, int height) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  /// Fills a one-pixel crack a rotation leaves inside the plate.
  ///
  /// A clear pixel is filled only when three neighbors on the cross are
  /// already solid, so the gap between an arm and the chest stays open.
  static bool _closeCracks(Uint8List bytes, int size) {
    var changed = false;
    for (var pass = 0; pass < 2; pass++) {
      final prior = Uint8List.fromList(bytes);
      var step = false;
      for (var y = 1; y < size - 1; y++) {
        for (var x = 1; x < size - 1; x++) {
          final index = (y * size + x) * 4;
          if (prior[index + 3] > 40) continue;
          final cols = <int>[];
          for (final next in [index - 4, index + 4, index - size * 4, index + size * 4]) {
            if (prior[next + 3] <= 40) continue;
            cols.add(next);
          }
          if (cols.length < 3) continue;
          cols.sort((a, b) {
            final la = prior[a] + prior[a + 1] + prior[a + 2];
            final lb = prior[b] + prior[b + 1] + prior[b + 2];
            return la.compareTo(lb);
          });
          final pick = cols[cols.length ~/ 2];
          bytes[index] = prior[pick];
          bytes[index + 1] = prior[pick + 1];
          bytes[index + 2] = prior[pick + 2];
          bytes[index + 3] = 255;
          step = true;
        }
      }
      if (!step) break;
      changed = true;
    }
    return changed;
  }

  /// Connected specks a rotation leaves behind. The plate itself is never this small.
  static List<int> _slivers(Uint8List bytes, int size) {
    final count = size * size;
    final on = List<bool>.filled(count, false);
    for (var i = 0; i < count; i++) {
      on[i] = bytes[i * 4 + 3] > 40;
    }
    final seen = List<bool>.filled(count, false);
    final kill = <int>[];
    for (var i = 0; i < count; i++) {
      if (!on[i] || seen[i]) continue;
      final cells = <int>[i];
      seen[i] = true;
      var cursor = 0;
      var minX = size;
      var maxX = 0;
      var minY = size;
      var maxY = 0;
      while (cursor < cells.length) {
        final here = cells[cursor++];
        final x = here % size;
        final y = here ~/ size;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        for (final next in [here - 1, here + 1, here - size, here + size]) {
          if (next < 0 || next >= count || seen[next] || !on[next]) continue;
          if ((next % size - x).abs() + (next ~/ size - y).abs() != 1) continue;
          seen[next] = true;
          cells.add(next);
        }
      }
      final span = (maxX - minX) < (maxY - minY) ? maxX - minX : maxY - minY;
      if (span <= 4 && cells.length < 40) kill.addAll(cells);
    }
    return kill;
  }

  static void _drawStack(
    ui.Canvas canvas,
    RigData rig,
    Map<String, RigWorld> world,
    RigPose rigPose,
    CharacterVisualPose pose,
    String bodyKey,
    Map<String, ui.Image> images,
  ) {
    final bodyAtlas = RigPartCache.peek(
      RigPartCache.key(bodyKey, rig.family, 0, 1),
    );
    final tintPath = tintForRigBody(pose, bodyKey, images);
    final tintAtlas = tintPath == null
        ? null
        : RigPartCache.peek(
            RigPartCache.key(
              tintPath,
              rig.family,
              0,
              OwnedGearAssets.undertunicShoeTop,
            ),
          );
    for (final layer in pose.orderedLayers()) {
      if (layer.id != CharacterLayerId.cape) continue;
      final image = _gearImage(layer.ownedAsset, images);
      if (image == null) continue;
      HeroRigDraw.rigid(
        canvas,
        image,
        world,
        rig,
        rig.rigidLayers['cape'] ?? 'torso',
        layer.tint,
      );
    }
    for (final part in rig.drawOrder) {
      if (bodyAtlas != null)
        HeroRigDraw.part(canvas, bodyAtlas, part, world, null);
      if (tintAtlas != null && pose.bodyTint != null) {
        HeroRigDraw.part(canvas, tintAtlas, part, world, pose.bodyTint);
      }
      for (final layer in pose.orderedLayers()) {
        if (HeroRigDraw.isWeapon(layer) || layer.id == CharacterLayerId.cape)
          continue;
        if (layer.id == CharacterLayerId.body) continue;
        final path = layer.ownedAsset;
        final atlas = path == null
            ? null
            : RigPartCache.peek(
                RigPartCache.key(path, rig.family, layer.cropTop, 1),
              );
        if (atlas != null)
          HeroRigDraw.part(canvas, atlas, part, world, layer.tint);
        final dyePath = layer.dyeMaskAsset;
        final dye = dyePath == null
            ? null
            : RigPartCache.peek(RigPartCache.key(dyePath, rig.family, 0, 1));
        if (dye != null && layer.dyeTint != null) {
          HeroRigDraw.part(canvas, dye, part, world, layer.dyeTint);
        }
      }
    }
    for (final layer in pose.orderedLayers()) {
      if (!HeroRigDraw.isWeapon(layer)) continue;
      final image = _gearImage(layer.ownedAsset, images);
      if (image == null || layer.ownedAsset == null) continue;
      HeroRigDraw.weapon(canvas, image, layer, rig, world, rigPose, pose);
    }
  }

  static ui.Image? _gearImage(String? path, Map<String, ui.Image> images) {
    if (path == null) return null;
    return _solid[path] ?? images[path];
  }

  static bool _weapon(ResolvedLayer layer) =>
      layer.id == CharacterLayerId.mainHand ||
      layer.id == CharacterLayerId.offHand;

  static Future<RigAtlas> _atlas(
    RigData rig,
    ui.Image image,
    String cacheKey, {
    double cropTop = 0,
    double cropBottom = 1,
  }) {
    return RigPartCache.cut(
      image: image,
      rig: rig,
      cacheKey: cacheKey,
      cropTop: cropTop,
      cropBottom: cropBottom,
    );
  }
}
