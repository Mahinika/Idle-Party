import 'dart:convert';

import 'package:flutter/services.dart';

/// One family's cutout skeleton. Parts may overlap at the joint pad.
class RigBone {
  const RigBone({required this.name, required this.parent, required this.restX, required this.restY});

  final String name;
  final String? parent;
  final double restX;
  final double restY;
}

class RigData {
  RigData({
    required this.family,
    required this.bones,
    required this.order,
    required this.masks,
    required this.drawOrder,
    required this.rigidLayers,
    required this.handBones,
  });

  final String family;
  final Map<String, RigBone> bones;

  /// Parents before children.
  final List<String> order;
  final Map<String, Uint8List> masks;
  final List<String> drawOrder;
  final Map<String, String> rigidLayers;
  final Map<String, String> handBones;

  static const canvas = 128;
  static const frame = 256;
  static const origin = 64.0;

  bool contains(int x, int y, String part) {
    if (x < 0 || y < 0 || x >= canvas || y >= canvas) return false;
    final mask = masks[part];
    if (mask == null) return false;
    return mask[y * canvas + x] != 0;
  }

  String? partAt(int x, int y) {
    if (x < 0 || y < 0 || x >= canvas || y >= canvas) return null;
    for (final name in drawOrder) {
      if (contains(x, y, name)) return name;
    }
    return null;
  }

  static Future<RigData> loadAsset(String family) async {
    final raw = await rootBundle.loadString('assets/custom/rig/$family.json');
    return parse(family, jsonDecode(raw) as Map<String, dynamic>);
  }

  static RigData parse(String family, Map<String, dynamic> json) {
    final boneJson = json['bones'] as Map<String, dynamic>;
    final bones = <String, RigBone>{};
    for (final entry in boneJson.entries) {
      final row = entry.value as Map<String, dynamic>;
      final rest = (row['rest'] as List).cast<num>();
      bones[entry.key] = RigBone(
        name: entry.key,
        parent: row['parent'] as String?,
        restX: rest[0].toDouble(),
        restY: rest[1].toDouble(),
      );
    }
    final order = _order(bones);
    final partJson = json['parts'] as Map<String, dynamic>;
    final masks = <String, Uint8List>{
      for (final entry in partJson.entries) entry.key: _mask(entry.value as List),
    };
    final rigid = (json['rigidLayers'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    final hands = (json['handBones'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    return RigData(
      family: family,
      bones: bones,
      order: order,
      masks: masks,
      drawOrder: (json['drawOrder'] as List).cast<String>(),
      rigidLayers: rigid,
      handBones: hands,
    );
  }

  static List<String> _order(Map<String, RigBone> bones) {
    final out = <String>[];
    void visit(String name) {
      if (out.contains(name)) return;
      final parent = bones[name]?.parent;
      if (parent != null) visit(parent);
      out.add(name);
    }

    for (final name in bones.keys) {
      visit(name);
    }
    return out;
  }

  static Uint8List _mask(List rows) {
    final mask = Uint8List(canvas * canvas);
    for (final row in rows) {
      final nums = (row as List).cast<num>();
      final y = nums[0].toInt();
      for (var i = 1; i + 1 < nums.length; i += 2) {
        final x0 = nums[i].toInt();
        final x1 = nums[i + 1].toInt();
        for (var x = x0; x <= x1; x++) {
          mask[y * canvas + x] = 1;
        }
      }
    }
    return mask;
  }
}
