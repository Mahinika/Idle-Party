import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/ui/decoded_image_cache.dart';
import 'package:idle_party/ui/shell/dev_gear_lookbook.dart';
import 'package:idle_party/visual/anchor_table.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/character_layer.dart';
import 'package:idle_party/visual/character_visual_painter.dart';
import 'package:idle_party/visual/character_visual_pose.dart';
import 'package:idle_party/visual/equipment_model_catalog.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/owned_gear_assets.dart';

/// Paints every lookbook doll with the game painter and counts pixels on
/// the result. Writes `measure.json` and one 128 px PNG per doll.
///
/// Call inside `tester.runAsync`. `tool/measure_lookbook.py` turns the
/// numbers into marks, flags, and the before/after picture.
Future<void> writeLookbookMeasure(
  String outDir,
  Map<String, dynamic> outfits,
) async {
  final images = await _loadAll();
  final dollDir = Directory('$outDir/dolls')..createSync(recursive: true);
  for (final old in dollDir.listSync().whereType<File>()) {
    old.deleteSync();
  }
  final heads = <String, _Head>{};
  final rows = <Map<String, dynamic>>[];
  for (final doll in _dolls(outfits)) {
    for (final poseName in doll.poses) {
      rows.add(
        await _measure(doll, poseName, images, heads, dollDir.path),
      );
    }
  }
  File('$outDir/measure.json').writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({'dolls': rows}),
  );
}

const _size = 128;
const _alpha = 40;
const _handR = 8;

const _poses = <String, HeroAnimPose>{
  'idle': HeroAnimPose(kind: HeroAnimKind.idle, frame: 0),
  'walk': HeroAnimPose(kind: HeroAnimKind.walk, frame: 1, progress: 0.25),
  'windup': HeroAnimPose(kind: HeroAnimKind.attack, frame: 0, progress: 0.3),
  'strike': HeroAnimPose(kind: HeroAnimKind.attack, frame: 1, progress: 0.6),
  'cast': HeroAnimPose(kind: HeroAnimKind.cast, frame: 1, progress: 0.5),
};

const _armorLayers = {
  CharacterLayerId.torso,
  CharacterLayerId.legs,
  CharacterLayerId.boots,
  CharacterLayerId.gloves,
};

class _Doll {
  const _Doll({
    required this.group,
    required this.family,
    required this.label,
    required this.pieces,
    required this.poses,
    this.offWeapon,
    this.material,
  });

  final String group;
  final BodyFamily family;
  final String label;
  final List<String> pieces;
  final List<String> poses;
  final String? offWeapon;
  final ArmorType? material;

  PartyHero hero() {
    final items = <EquipmentSlot, EquipmentItem>{};
    for (final id in pieces) {
      final item = gearLookbookItem(id, material);
      items[item.slot] = item;
    }
    if (offWeapon != null) {
      final item = gearLookbookItem(offWeapon!, null, asOffHand: true);
      items[item.slot] = item;
    }
    return PartyHero.starting(
      name: 'Measure',
      specId: gearLookbookSpec(family),
      id: 'measure-${family.name}-$label',
      equipped: items,
    );
  }
}

List<_Doll> _dolls(Map<String, dynamic> data) {
  final all = _poses.keys.toList();
  final families = (data['families'] as List).cast<String>();
  final armor = (data['armor'] as List).cast<String>();
  final layers = (data['layers'] as List).cast<String>();
  final dress = (data['dress'] as List).cast<String>();
  final weapons = (data['weapons'] as List).cast<String>();
  final familyWeapon = (data['familyWeapon'] as Map).cast<String, dynamic>();
  final pairs = (data['pair'] as Map).cast<String, dynamic>();
  final out = <_Doll>[];
  for (final name in families) {
    final family = BodyFamily.values.firstWhere((f) => f.name == name);
    _Doll outfit(String label, List<String> pieces, [String? offWeapon]) =>
        _Doll(
          group: 'outfit',
          family: family,
          label: label,
          pieces: pieces,
          poses: all,
          offWeapon: offWeapon,
        );
    final pair = (pairs[name] as Map).cast<String, dynamic>();
    out
      ..add(outfit('bare', const []))
      ..add(outfit('armor', armor))
      ..add(outfit('layers', layers))
      ..add(outfit('armed', [...layers, familyWeapon[name] as String]))
      ..add(
        outfit(
          'pair',
          [...layers, ...(pair['pieces'] as List).cast<String>()],
          pair['offHand'] as String?,
        ),
      );
    for (final id in weapons) {
      out.add(outfit(id, [...dress, id]));
    }
    for (final base in EquipmentModelCatalog.sharedBases) {
      for (final id in EquipmentModelCatalog.variants[base] ?? const []) {
        if (weapons.contains(id)) continue;
        out.add(
          _Doll(
            group: 'weapon',
            family: family,
            label: id,
            pieces: [...dress, id],
            poses: all,
          ),
        );
      }
    }
    final allowed =
        OwnedGearAssets.kFamilyMaterials[family] ?? const <String>[];
    final materials = <ArmorType?>[
      null,
      ...ArmorType.values.where((m) => allowed.contains(m.name)),
    ];
    for (final base in EquipmentModelCatalog.familyBases) {
      for (final id in EquipmentModelCatalog.variants[base] ?? const []) {
        for (final mat in materials) {
          out.add(
            _Doll(
              group: 'armor',
              family: family,
              label: mat == null ? id : '$id ${mat.name}',
              // Pauldrons are drawn to rest on a chest piece, not on the
              // thin undertunic.
              pieces: base == 'shoulder' ? ['chest_t0', id] : [id],
              poses: const ['idle', 'walk', 'strike'],
              material: mat,
            ),
          );
        }
      }
    }
  }
  return out;
}

Future<Map<String, ui.Image>> _loadAll() async {
  final paths = <String>{
    ...BodyFamilyCatalog.allAssetPaths,
    ...OwnedGearAssets.allAssetPaths,
  };
  final images = <String, ui.Image>{};
  await Future.wait(
    paths.map((path) async {
      try {
        images[path] = await DecodedImageCache.load(path, targetWidth: _size);
      } catch (_) {
        // Optional cuts (dye, race clips) are allowed to be missing.
      }
    }),
  );
  return images;
}

class _Render {
  _Render(this.rgba, this.side);

  final Uint8List rgba;
  final int side;

  bool on(int i) => rgba[i * 4 + 3] >= _alpha;
}

Future<_Render> _render(
  CharacterVisualPose pose,
  ui.Image body,
  Map<String, ui.Image> images, {
  Set<CharacterLayerId>? only,
  File? png,
  int pad = 0,
}) async {
  final side = _size + pad * 2;
  final recorder = ui.PictureRecorder();
  CharacterVisualPainter.paintOwnedHero(
    Canvas(recorder),
    Offset(side / 2, side / 2),
    _size.toDouble(),
    body: body,
    images: images,
    pose: pose,
    onlyLayers: only,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (png != null) {
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    png.writeAsBytesSync(encoded!.buffer.asUint8List());
  }
  image.dispose();
  return _Render(raw!.buffer.asUint8List(), side);
}

/// Hair and face pixels, plus the body silhouette, for one body and pose.
class _Head {
  _Head(this.hair, this.face, this.body);

  final Set<int> hair;
  final Set<int> face;
  final List<bool> body;
}

/// The head is the biggest patch of bare body (skin and hair, no cloth
/// mask) near the top. Hair is its crown; the face is the middle band,
/// inset from the cheeks. Works per clip, so a crouched or bobbing head
/// still gets its own mask.
Future<(Set<int>, Set<int>)> _headMasks(
  ui.Image body,
  ui.Image? tint,
  Offset step,
) async {
  final b = (await body.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  final t = tint == null
      ? null
      : (await tint.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
  final w = body.width;
  final h = body.height;
  bool bare(int i) => b[i * 4 + 3] >= _alpha && (t == null || t[i * 4 + 3] < _alpha);

  final seen = List<bool>.filled(w * h, false);
  var head = <int>[];
  for (var start = 0; start < w * h; start++) {
    if (seen[start] || !bare(start)) continue;
    final comp = <int>[start];
    seen[start] = true;
    for (var k = 0; k < comp.length; k++) {
      final x = comp[k] % w;
      final y = comp[k] ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          final yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
          final j = yy * w + xx;
          if (seen[j] || !bare(j)) continue;
          seen[j] = true;
          comp.add(j);
        }
      }
    }
    final top = comp.map((i) => i ~/ w).reduce(math.min);
    if (top < h / 2 && comp.length > head.length) head = comp;
  }
  if (head.isEmpty) return (<int>{}, <int>{});
  final y0 = head.map((i) => i ~/ w).reduce(math.min);
  final y1 = head.map((i) => i ~/ w).reduce(math.max);
  final span = math.max(1, y1 - y0);
  final crown = head.where((i) => i ~/ w <= y0 + span * 0.5).map((i) => i % w);
  final x0 = crown.reduce(math.min);
  final x1 = crown.reduce(math.max);
  final inset = (x1 - x0) * 0.22;
  final sx = step.dx.round();
  final sy = step.dy.round();
  final hair = <int>{};
  final face = <int>{};
  for (final i in head) {
    final x = i % w;
    final y = i ~/ w;
    final xx = x * _size ~/ w + sx;
    final yy = y * _size ~/ h + sy;
    if (xx < 0 || yy < 0 || xx >= _size || yy >= _size) continue;
    final j = yy * _size + xx;
    if (y <= y0 + span * 0.30) hair.add(j);
    if (y >= y0 + span * 0.36 &&
        y <= y0 + span * 0.72 &&
        x >= x0 + inset &&
        x <= x1 - inset) {
      face.add(j);
    }
  }
  return (hair, face);
}

Future<_Head> _headFor(
  PartyHero hero,
  String poseName,
  CharacterVisualPose pose,
  ui.Image body,
  Map<String, ui.Image> images,
  Map<String, _Head> cache,
) async {
  final key = '${BodyFamilyCatalog.familyFor(hero).name}/$poseName';
  final hit = cache[key];
  if (hit != null) return hit;
  final kind = pose.anim.kind;
  final (hair, face) = await _headMasks(
    body,
    images[BodyFamilyCatalog.tintMaskAssetFor(hero, kind)],
    CharacterVisualPainter.ownedStepOffset(pose, _size.toDouble()),
  );
  final silhouette = await _render(
    pose,
    body,
    images,
    only: {CharacterLayerId.body},
  );
  final head = _Head(hair, face, _mask(silhouette));
  cache[key] = head;
  return head;
}

bool _has(CharacterVisualPose pose, CharacterLayerId id) =>
    pose.orderedLayers().any((l) => l.id == id && l.ownedAsset != null);

Future<Map<String, dynamic>> _measure(
  _Doll doll,
  String poseName,
  Map<String, ui.Image> images,
  Map<String, _Head> heads,
  String dollDir,
) async {
  final hero = doll.hero();
  final anim = _poses[poseName]!;
  final pose = CharacterVisualPose.resolve(hero: hero, anim: anim, owned: true);
  final body = images[BodyFamilyCatalog.assetFor(hero, anim.kind)] ??
      images[BodyFamilyCatalog.assetFor(hero, HeroAnimKind.idle)]!;
  final file = '${doll.group}__${doll.family.name}__'
      '${doll.label.replaceAll(' ', '_')}__$poseName.png';
  await _render(pose, body, images, png: File('$dollDir/$file'));
  final head = await _headFor(hero, poseName, pose, body, images, heads);

  Future<_Render?> layer(Set<CharacterLayerId> ids) async {
    if (!ids.any((id) => _has(pose, id))) return null;
    return _render(pose, body, images, only: ids);
  }

  // A swung blade leaves the 128 body square. The grip check needs the
  // margin the dungeon canvas already has.
  const handPad = 48;
  Future<_Render?> handLayer(Set<CharacterLayerId> ids) async {
    if (!ids.any((id) => _has(pose, id))) return null;
    return _render(pose, body, images, only: ids, pad: handPad);
  }

  final main = await handLayer({CharacterLayerId.mainHand});
  final off = await handLayer({CharacterLayerId.offHand});
  final holdingHand = await _render(
    pose,
    body,
    images,
    only: {CharacterLayerId.body, CharacterLayerId.gloves},
  );
  final helm = await layer({CharacterLayerId.head});
  final shoulders = await layer({CharacterLayerId.shoulders});
  final armor = await layer(_armorLayers);
  final torso = await layer({CharacterLayerId.torso});

  const center = Offset(_size / 2, _size / 2);
  final handOrigin = Offset(handPad.toDouble(), handPad.toDouble());
  final mainFist = CharacterVisualPainter.ownedHandPoint(
    pose,
    center,
    _size.toDouble(),
    AnchorId.mainHand,
    gloveShift: CharacterVisualPainter.wornGloveShift(pose, offHand: false),
  ) + handOrigin;
  final offFist = CharacterVisualPainter.ownedHandPoint(
    pose,
    center,
    _size.toDouble(),
    AnchorId.offHand,
    gloveShift: CharacterVisualPainter.wornGloveShift(pose, offHand: true),
  ) + handOrigin;

  // A shield or tome is held in front of the body and may cover a cheek.
  // Blades and staves are counted apart from it.
  final offIsWeapon = doll.offWeapon != null;
  bool onBody(int i, _Render? layer) {
    if (layer == null) return false;
    if (layer.side == _size) return layer.on(i);
    final x = i % _size + handPad;
    final y = i ~/ _size + handPad;
    return layer.on(y * layer.side + x);
  }

  var face = 0;
  var shield = 0;
  for (final i in head.face) {
    final offOn = onBody(i, off);
    if (onBody(i, main) || (offIsWeapon && offOn)) face++;
    if (!offIsWeapon && offOn) shield++;
  }

  int nearFist(_Render r, Offset fist) {
    var n = 0;
    for (var i = 0; i < r.side * r.side; i++) {
      if (!r.on(i)) continue;
      final dx = i % r.side + 0.5 - fist.dx;
      final dy = i ~/ r.side + 0.5 - fist.dy;
      if (dx * dx + dy * dy <= _handR * _handR) n++;
    }
    return n;
  }
  final localMainFist = mainFist - handOrigin;
  final localOffFist = offFist - handOrigin;
  final mainContact = nearFist(holdingHand, localMainFist);
  final offContact = nearFist(holdingHand, localOffFist);

  double? hair;
  double? open;
  if (helm != null && head.hair.isNotEmpty && head.face.isNotEmpty) {
    hair = head.hair.where(helm.on).length / head.hair.length;
    open = head.face.where((i) => !helm.on(i)).length / head.face.length;
  }

  final piece = doll.pieces.isEmpty ? '' : doll.pieces.last;
  return {
    'name': '${doll.family.name} ${doll.label} $poseName',
    'group': doll.group,
    'family': doll.family.name,
    'label': doll.label,
    'base': EquipmentModelCatalog.baseToken(piece),
    'material': doll.material?.name,
    'pose': poseName,
    'file': 'dolls/$file',
    'face': face,
    'shield': off == null || offIsWeapon ? null : shield,
    'hand': main == null
        ? null
        : math.min(nearFist(main, mainFist), mainContact),
    'off': off == null
        ? null
        : math.min(nearFist(off, offFist), offContact),
    'hair': hair,
    'open': open,
    'touch': helm == null ? null : _touching(helm, head.body),
    'float': shoulders == null
        ? null
        : _apart(shoulders, [head.body, if (torso != null) _mask(torso)], 2),
    'spill': armor == null ? null : _apart(armor, [head.body], 4),
    'fist': [mainFist.dx - handPad, mainFist.dy - handPad],
    'offFist': [offFist.dx - handPad, offFist.dy - handPad],
  };
}

List<bool> _mask(_Render r) => List<bool>.generate(_size * _size, r.on);

/// Helm pixels that sit on or right next to the body. A hat on the hair
/// touches; a helm hanging above the head does not.
int _touching(_Render helm, List<bool> body) {
  var n = 0;
  for (var i = 0; i < _size * _size; i++) {
    if (!helm.on(i)) continue;
    final x = i % _size;
    final y = i ~/ _size;
    var near = false;
    for (var dy = -1; dy <= 1 && !near; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final xx = x + dx;
        final yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= _size || yy >= _size) continue;
        if (body[yy * _size + xx]) {
          near = true;
          break;
        }
      }
    }
    if (near) n++;
  }
  return n;
}

/// Share of [piece] pixels with nothing from [under] within [reach] px.
double? _apart(_Render piece, List<List<bool>> under, int reach) {
  var total = 0;
  var loose = 0;
  for (var i = 0; i < _size * _size; i++) {
    if (!piece.on(i)) continue;
    total++;
    final x = i % _size;
    final y = i ~/ _size;
    var near = false;
    for (var dy = -reach; dy <= reach && !near; dy++) {
      final yy = y + dy;
      if (yy < 0 || yy >= _size) continue;
      for (var dx = -reach; dx <= reach; dx++) {
        final xx = x + dx;
        if (xx < 0 || xx >= _size) continue;
        final j = yy * _size + xx;
        if (under.any((m) => m[j])) {
          near = true;
          break;
        }
      }
    }
    if (!near) loose++;
  }
  return total == 0 ? null : loose / total;
}
