import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/ui/decoded_image_cache.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/character_visual_pose.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/rig/hero_rig_library.dart';
import 'package:idle_party/visual/rig/hero_rig_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('party skeleton is cut before the dungeon shows the doll', () async {
    final hero = PartyHero.starting(
      name: 'Aegis',
      specId: HeroSpecId.protection,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.protection),
    );
    await HeroRigPainter.warmParty([hero]);

    const idle = HeroAnimPose(kind: HeroAnimKind.idle, frame: 0);
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    final family = pose.bodyFamily;
    final rig = family == null ? null : HeroRigLibrary.peek(family);
    expect(rig, isNotNull);

    final paths = <String>{
      if (pose.bodyIdleAsset != null) pose.bodyIdleAsset!,
      BodyFamilyCatalog.assetFor(hero, HeroAnimKind.idle),
      if (pose.bodyTintAsset != null) pose.bodyTintAsset!,
      for (final layer in pose.orderedLayers()) ...[
        if (layer.ownedAsset != null) layer.ownedAsset!,
        if (layer.dyeMaskAsset != null) layer.dyeMaskAsset!,
      ],
    };
    final images = <String, ui.Image>{};
    for (final path in paths) {
      images[path] = await DecodedImageCache.load(path, targetWidth: 128);
    }
    final bodyKey = HeroRigPainter.rigBodyKey(pose, images);
    expect(bodyKey, isNotNull);
    expect(
      HeroRigPainter.ready(
        rig: rig!,
        bodyKey: bodyKey!,
        images: images,
        pose: pose,
      ),
      isTrue,
    );

    for (final kind in [HeroAnimKind.walk, HeroAnimKind.attack]) {
      final moving = CharacterVisualPose.resolve(
        hero: hero,
        anim: HeroAnimPose(kind: kind, frame: 0),
        owned: true,
      );
      for (final layer in moving.orderedLayers()) {
        final path = layer.ownedAsset;
        if (path == null || images.containsKey(path)) continue;
        try {
          images[path] = await DecodedImageCache.load(path, targetWidth: 128);
        } catch (_) {}
      }
      expect(
        HeroRigPainter.ready(
          rig: rig,
          bodyKey: bodyKey,
          images: images,
          pose: moving,
        ),
        isTrue,
        reason: '${kind.name} still needs a cut the idle warm did not make',
      );
    }
  });
}
