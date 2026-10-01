import 'dart:math' as math;

import '../hero_anim_state.dart';
import 'rig_clips.dart';
import 'rig_pose.dart';

/// Limb poses step at 16 fps. World movement stays smooth outside this sampler.
abstract final class RigSampler {
  static const fps = 16;

  static RigSample sample(
    HeroAnimPose anim, {
    String? abilityName,
  }) {
    final clip = RigClips.forAbility(abilityName) ?? RigClips.forKind(anim.kind);
    final time = _quantized(clip, anim.progress);
    final pose = RigClips.sample(clip, time.seconds);
    if (!anim.blocking || clip.name == 'block') {
      return RigSample(pose, time.step, clip.name);
    }
    final block = RigClips.block;
    final held = RigClips.sample(block, block.length);
    return RigSample(_add(pose, held), time.step, clip.name);
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
