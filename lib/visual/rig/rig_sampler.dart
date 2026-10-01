import 'dart:math' as math;

import '../hero_anim_state.dart';
import 'rig_ability_clips.dart';
import 'rig_clips.dart';
import 'rig_pose.dart';

/// Limb poses step at 16 fps. World movement stays smooth outside this sampler.
abstract final class RigSampler {
  static const fps = 16;

  /// Robes keep the legs quiet so the hem does not kick open.
  static const robeLegLimit = 12.0;

  static const _robeLegs = [
    'thigh_l',
    'thigh_r',
    'shin_l',
    'shin_r',
    'foot_l',
    'foot_r',
  ];

  static RigSample sample(
    HeroAnimPose anim, {
    String? abilityName,
    bool robe = false,
  }) {
    final clip = RigAbilityClips.forName(abilityName) ?? RigClips.forKind(anim.kind);
    final time = _quantized(clip, anim.progress);
    var pose = RigClips.sample(clip, time.seconds);
    if (anim.blocking && clip.name != 'block') {
      final block = RigClips.block;
      pose = _add(pose, RigClips.sample(block, block.length));
    }
    if (robe) pose = _quietLegs(pose);
    return RigSample(pose, time.step, clip.name);
  }

  static RigPose _quietLegs(RigPose pose) {
    final angles = Map<String, double>.from(pose.angles);
    for (final name in _robeLegs) {
      final value = angles[name];
      if (value == null) continue;
      angles[name] = value.clamp(-robeLegLimit, robeLegLimit);
    }
    return RigPose(angles: angles, rootX: pose.rootX, rootY: pose.rootY);
  }

  static ({double seconds, int step}) _quantized(RigClip clip, double progress) {
    final length = clip.length <= 0 ? 0.01 : clip.length;
    final seconds = (progress.clamp(0.0, 1.0)) * length;
    final step = (seconds * fps).floor();
    final snapped = math.min(step / fps, length);
    return (seconds: snapped, step: step);
  }

  static RigPose _add(RigPose a, RigPose b) {
    final angles = Map<String, double>.from(a.angles);
    for (final entry in b.angles.entries) {
      angles[entry.key] = (angles[entry.key] ?? 0) + entry.value;
    }
    return RigPose(
      angles: angles,
      rootX: a.rootX + b.rootX,
      rootY: a.rootY + b.rootY,
    );
  }
}

class RigSample {
  const RigSample(this.pose, this.stepIndex, this.clip);

  final RigPose pose;
  final int stepIndex;
  final String clip;
}
