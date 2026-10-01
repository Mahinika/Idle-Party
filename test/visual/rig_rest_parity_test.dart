import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/starter_gear.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/character_visual_painter.dart';
import 'package:idle_party/visual/character_visual_pose.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/rig/hero_rig_painter.dart';
import 'package:idle_party/visual/rig/rig_data.dart';

const _idle = HeroAnimPose(kind: HeroAnimKind.idle, frame: 0);

Future<ui.Image> _png(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Map<String, ui.Image>> _imagesFor(CharacterVisualPose pose) async {
  final paths = <String>{
    if (pose.bodyTintAsset != null) pose.bodyTintAsset!,
    for (final layer in pose.layers) ...[
      if (layer.ownedAsset != null) layer.ownedAsset!,
      if (layer.dyeMaskAsset != null) layer.dyeMaskAsset!,
    ],
  };
  final out = <String, ui.Image>{};
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    out[path] = await _png(path);
  }
  return out;
}

Future<int> _diff(ui.Image a, ui.Image b) async {
  final left = (await a.toByteData())!;
  final right = (await b.toByteData())!;
  var count = 0;
  for (var i = 0; i < left.lengthInBytes; i += 4) {
    final da = (left.getUint8(i) - right.getUint8(i)).abs();
    final db = (left.getUint8(i + 1) - right.getUint8(i + 1)).abs();
    final dc = (left.getUint8(i + 2) - right.getUint8(i + 2)).abs();
    final dd = (left.getUint8(i + 3) - right.getUint8(i + 3)).abs();
    if (da + db + dc + dd > 12) count++;
  }
  return count;
}

ui.Image _shot(void Function(ui.Canvas canvas) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(256, 256);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('warrior rest matches the paper doll', () async {
    await _expectRest(
      family: BodyFamily.warrior,
      spec: HeroSpecId.protection,
      role: HeroRole.warrior,
    );
  });

  test('rogue rest matches the paper doll', () async {
    await _expectRest(
      family: BodyFamily.rogue,
      spec: HeroSpecId.assassination,
      role: HeroRole.rogue,
    );
  });
}

Future<void> _expectRest({
  required BodyFamily family,
  required HeroSpecId spec,
  required HeroRole role,
}) async {
  final rig = RigData.parse(
    family.name,
    jsonDecode(File('assets/custom/rig/${family.name}.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final naked = PartyHero.starting(
    name: 'Aegis',
    specId: spec,
    stats: PartyHero.startingStatsForSpec(spec),
  );
  final chest = GameLogic.createEquipment(
    slot: EquipmentSlot.chest,
    rarity: LootRarity.common,
    battleNumber: 1,
    bias: role,
  ).copyWith(visualSetId: 'chest_broad');
  final legs = GameLogic.createEquipment(
    slot: EquipmentSlot.legs,
    rarity: LootRarity.common,
    battleNumber: 1,
    bias: role,
  ).copyWith(visualSetId: 'legs_short');
  final heroes = {
    'empty': naked,
    'starter': naked.copyWith(equipped: StarterGear.forSpec(spec)),
    'broad': naked.copyWith(equipped: {EquipmentSlot.chest: chest, EquipmentSlot.legs: legs}),
  };
  final bodyPath = BodyFamilyCatalog.catalog[family]!.idleAsset;
  final body = await _png(bodyPath);
  for (final entry in heroes.entries) {
    final pose = CharacterVisualPose.resolve(hero: entry.value, anim: _idle, owned: true);
    final images = await _imagesFor(pose);
    await HeroRigPainter.warm(
      rig: rig,
      bodyImage: body,
      bodyKey: bodyPath,
      images: images,
      pose: pose,
    );
    const center = ui.Offset(128, 128);
    final doll = _shot(
      (canvas) => CharacterVisualPainter.paintOwnedHero(
        canvas,
        center,
        128,
        body: body,
        images: images,
        pose: pose,
      ),
    );
    final rigged = _shot(
      (canvas) => HeroRigPainter.paint(
        canvas,
        center,
        128,
        bodyImage: body,
        bodyKey: bodyPath,
        images: images,
        pose: pose,
        rig: rig,
        heroId: '${family.name}-${entry.key}',
      ),
    );
    final delta = await _diff(doll, rigged);
    expect(delta, lessThanOrEqualTo(8), reason: '${family.name} ${entry.key}');
  }
}
