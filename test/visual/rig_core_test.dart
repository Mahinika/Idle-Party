import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/rig/rig_clips.dart';
import 'package:idle_party/visual/rig/rig_data.dart';
import 'package:idle_party/visual/rig/rig_part_cache.dart';
import 'package:idle_party/visual/rig/rig_pose.dart';
import 'package:idle_party/visual/rig/rig_sampler.dart';

void main() {
  late RigData warrior;

  setUpAll(() {
    final raw = File('assets/custom/rig/warrior.json').readAsStringSync();
    warrior = RigData.parse('warrior', jsonDecode(raw) as Map<String, dynamic>);
  });

  test('a one-pixel hole in gear fills and a face window stays open', () {
    final bytes = Uint8List(5 * 5 * 4);
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 5; x++) {
        final index = (y * 5 + x) * 4;
        final hole = x == 2 && y == 2;
        if (hole) continue;
        bytes[index] = 40;
        bytes[index + 1] = 44;
        bytes[index + 2] = 48;
        bytes[index + 3] = 255;
      }
    }
    expect(RigPartCache.sealBytes(bytes, 5, 5), isTrue);
    expect(bytes[(2 * 5 + 2) * 4 + 3], 255);
    final open = Uint8List(7 * 7 * 4);
    for (var y = 0; y < 7; y++) {
      for (var x = 0; x < 7; x++) {
        final index = (y * 7 + x) * 4;
        final window = x >= 2 && x <= 4 && y >= 2 && y <= 4;
        if (window) continue;
        open[index + 3] = 255;
      }
    }
    expect(RigPartCache.sealBytes(open, 7, 7), isFalse);
    expect(open[(3 * 7 + 3) * 4 + 3], 0);
  });

  test('a one-pixel line grows a second pixel and a face window stays open', () {
    final line = Uint8List(5 * 5 * 4);
    for (var y = 1; y <= 3; y++) {
      final index = (y * 5 + 2) * 4;
      line[index + 3] = 255;
    }
    expect(RigPartCache.thickenLines(line, 5, 5), isTrue);
    var solid = 0;
    for (var i = 3; i < line.length; i += 4) {
      if (line[i] == 255) solid++;
    }
    expect(solid, greaterThan(3));

    final open = Uint8List(7 * 7 * 4);
    for (var y = 0; y < 7; y++) {
      for (var x = 0; x < 7; x++) {
        final window = x >= 2 && x <= 4 && y >= 2 && y <= 4;
        if (window) continue;
        open[(y * 7 + x) * 4 + 3] = 255;
      }
    }
    RigPartCache.thickenLines(open, 7, 7);
    expect(open[(3 * 7 + 3) * 4 + 3], 0);
  });

  test('a two-pixel weapon gap joins and a wide gap stays open', () {
    final close = Uint8List(16 * 16 * 4);
    void dot(Uint8List bytes, int x, int y) {
      final index = (y * 16 + x) * 4;
      bytes[index + 3] = 255;
    }

    for (var i = 0; i < 8; i++) {
      dot(close, i, 2);
    }
    for (var i = 0; i < 8; i++) {
      dot(close, 2 + i, 4);
    }
    expect(RigPartCache.joinGaps(close, 16, 16), isTrue);
    expect(close[(3 * 16 + 1) * 4 + 3], 255);

    final wide = Uint8List(16 * 16 * 4);
    for (var i = 0; i < 8; i++) {
      dot(wide, i, 0);
      dot(wide, i, 6);
    }
    expect(RigPartCache.joinGaps(wide, 16, 16), isFalse);
  });

  test('every part mask covers its opaque pixels and parents come first', () {
    expect(warrior.bones['torso']!.parent, 'root');
    expect(warrior.order.indexOf('root'), lessThan(warrior.order.indexOf('torso')));
    expect(warrior.order.indexOf('upper_r'), lessThan(warrior.order.indexOf('fore_r')));
    expect(warrior.handBones['main'], 'upper_r');
    var covered = 0;
    for (final mask in warrior.masks.values) {
      covered += mask.where((v) => v != 0).length;
    }
    expect(covered, greaterThan(10000));
  });

  test('solver matches the baked rest and a turned right arm', () {
    final rest = RigSolver.world(warrior, RigPose.rest);
    expect(rest['root']!.x, closeTo(64, 0.01));
    expect(rest['torso']!.y, closeTo(93, 0.01));
    expect(rest['upper_r']!.x, closeTo(107.52, 0.01));

    final turned = RigSolver.world(warrior, const RigPose(angles: {
      'upper_r': -30,
      'fore_r': 20,
      'thigh_l': 34,
    }));
    expect(turned['upper_r']!.x, closeTo(107.52, 0.01));
    expect(turned['upper_r']!.deg, closeTo(-30, 0.01));
    expect(turned['fore_r']!.x, closeTo(116.6076, 0.02));
    expect(turned['fore_r']!.y, closeTo(72.3003, 0.02));
    expect(turned['fore_r']!.deg, closeTo(-10, 0.01));
    expect(turned['hand_r']!.x, closeTo(120.0774, 0.02));
    expect(turned['hand_r']!.y, closeTo(81.8427, 0.02));
    expect(turned['thigh_l']!.deg, closeTo(34, 0.01));
    expect(turned['head']!.x, closeTo(64, 0.01));
  });

  test('clip sampling holds the ends and the middle of a swing', () {
    final start = RigClips.sample(RigClips.attack, 0);
    expect(start.angles, isEmpty);
    final end = RigClips.sample(RigClips.attack, RigClips.attack.length);
    expect(end.angles['torso'] ?? 0, closeTo(0, 0.01));
    final mid = RigClips.sample(RigClips.attack, RigClips.attack.length * 0.45);
    expect(mid.angles['sword']!, lessThan(0));
    expect(mid.angles['torso']!, isNot(0));
  });

  test('16 fps quantization repeats the same step inside one frame', () {
    const early = HeroAnimPose(kind: HeroAnimKind.walk, frame: 0, progress: 0.02);
    const later = HeroAnimPose(kind: HeroAnimKind.walk, frame: 0, progress: 0.04);
    final a = RigSampler.sample(early);
    final b = RigSampler.sample(later);
    expect(a.stepIndex, b.stepIndex);
    expect(a.pose.rootY, b.pose.rootY);

    const far = HeroAnimPose(kind: HeroAnimKind.walk, frame: 1, progress: 0.5);
    final c = RigSampler.sample(far);
    expect(c.stepIndex, greaterThan(a.stepIndex));
  });

  test('a block pulls the shield arm in over the walk', () {
    const walking = HeroAnimPose(kind: HeroAnimKind.walk, frame: 0, progress: 0);
    const raised = HeroAnimPose(
      kind: HeroAnimKind.walk,
      frame: 0,
      progress: 0,
      blocking: true,
    );
    final plain = RigSampler.sample(walking);
    final posed = RigSampler.sample(raised);
    expect(posed.pose.angles['upper_l']!, lessThan(plain.pose.angles['upper_l']! - 20));
    expect(posed.pose.angles['fore_l']!, lessThan(plain.pose.angles['fore_l']! - 10));
  });

  test('a named ability replaces the plain attack clip', () {
    const swing = HeroAnimPose(kind: HeroAnimKind.attack, frame: 0, progress: 0.5);
    const strike = HeroAnimPose(
      kind: HeroAnimKind.attack,
      frame: 0,
      progress: 0.5,
      abilityName: 'mortalStrike',
    );
    final plain = RigSampler.sample(swing);
    final named = RigSampler.sample(strike, abilityName: strike.abilityName);
    expect(named.clip, 'mortalStrike');
    expect(named.pose.angles['sword']!, lessThan(plain.pose.angles['sword'] ?? 0));
  });
}
