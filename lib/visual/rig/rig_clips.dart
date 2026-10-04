import 'rig_pose.dart';
import '../hero_anim_state.dart';

class RigKey {
  const RigKey(this.t, {this.rootX = 0, this.rootY = 0, this.bones = const {}});

  final double t;
  final double rootX;
  final double rootY;
  final Map<String, double> bones;
}

class RigClip {
  const RigClip({
    required this.name,
    required this.length,
    required this.keys,
    this.loop = false,
  });

  final String name;
  final double length;
  final bool loop;
  final List<RigKey> keys;
}

/// Body clips. Weapon keys (`sword`, `shield`) are extra grip rotation, not bones.
abstract final class RigClips {
  static const idle = RigClip(
    name: 'idle',
    length: 1.6,
    loop: true,
    keys: [
      RigKey(0),
      RigKey(0.5, rootY: -1, bones: {'torso': 1.5, 'head': -1}),
      RigKey(1, bones: {'torso': 0}),
    ],
  );

  /// Front-view stride. Knees keep one bend (left shin stays ≤ 0, right ≥ 0)
  /// so a step does not snap into a backward kick. Length is 12 frames at 16 fps.
  static const walk = RigClip(
    name: 'walk',
    length: 0.75,
    loop: true,
    keys: [
      // Left foot out, weight on the right, right arm forward.
      RigKey(0, rootX: 1.2, rootY: 1, bones: {
        'torso': -2.5,
        'head': 2,
        'thigh_l': 18,
        'shin_l': -16,
        'foot_l': 8,
        'thigh_r': 5,
        'shin_r': 4,
        'foot_r': -2,
        'upper_l': -8,
        'fore_l': 6,
        'upper_r': -18,
        'fore_r': -8,
        'pauldron_l': -2,
        'pauldron_r': -4,
      }),
      // Left knee tucks under, body rises, arms pass the hips.
      RigKey(0.25, rootX: 0.4, rootY: -1, bones: {
        'torso': -1,
        'head': 1,
        'thigh_l': 6,
        'shin_l': -22,
        'foot_l': 6,
        'thigh_r': 0,
        'shin_r': 8,
        'foot_r': 0,
        'upper_l': -2,
        'fore_l': 2,
        'upper_r': -4,
        'fore_r': -2,
        'pauldron_l': 0,
        'pauldron_r': -1,
      }),
      // Right foot out. Mirror of the first contact.
      RigKey(0.5, rootX: -1.2, rootY: 1, bones: {
        'torso': 2.5,
        'head': -2,
        'thigh_l': -5,
        'shin_l': -4,
        'foot_l': 2,
        'thigh_r': -18,
        'shin_r': 16,
        'foot_r': -8,
        'upper_l': 18,
        'fore_l': 8,
        'upper_r': 8,
        'fore_r': -6,
        'pauldron_l': 4,
        'pauldron_r': 2,
      }),
      // Right knee tucks under.
      RigKey(0.75, rootX: -0.4, rootY: -1, bones: {
        'torso': 1,
        'head': -1,
        'thigh_l': 0,
        'shin_l': -8,
        'foot_l': 0,
        'thigh_r': -6,
        'shin_r': 22,
        'foot_r': -6,
        'upper_l': 4,
        'fore_l': 2,
        'upper_r': 2,
        'fore_r': -2,
        'pauldron_l': 1,
        'pauldron_r': 0,
      }),
    ],
  );

  static const attack = RigClip(
    name: 'attack',
    length: 0.45,
    keys: [
      RigKey(0),
      RigKey(0.35, bones: {'torso': 6, 'upper_r': 18, 'fore_r': -26, 'sword': -18}),
      RigKey(0.55, rootY: 1, bones: {
        'torso': -12,
        'upper_r': -12,
        'fore_r': -8,
        'sword': -40,
      }),
      RigKey(1),
    ],
  );

  static const cast = RigClip(
    name: 'cast',
    length: 0.6,
    keys: [
      RigKey(0),
      RigKey(0.4, rootY: -4, bones: {
        'torso': -6,
        'head': -4,
        'upper_l': 36,
        'upper_r': -36,
        'fore_l': 18,
        'fore_r': -18,
      }),
      RigKey(1),
    ],
  );

  static const hit = RigClip(
    name: 'hit',
    length: 0.28,
    keys: [
      RigKey(0),
      RigKey(0.25, rootX: -3, bones: {'torso': -10, 'head': -6}),
      RigKey(1),
    ],
  );

  static const death = RigClip(
    name: 'death',
    length: 0.6,
    keys: [
      RigKey(0),
      RigKey(1, rootY: 16, bones: {
        'torso': 70,
        'head': 12,
        'thigh_l': 18,
        'thigh_r': -18,
        'upper_l': 20,
        'upper_r': -20,
      }),
    ],
  );

  static const victory = RigClip(
    name: 'victory',
    length: 0.8,
    loop: true,
    keys: [
      RigKey(0),
      RigKey(0.5, rootY: -3, bones: {'upper_r': -28, 'sword': -10, 'head': -4}),
      RigKey(1),
    ],
  );

  static const block = RigClip(
    name: 'block',
    length: 0.2,
    keys: [
      RigKey(0),
      RigKey(1, bones: {'torso': 6, 'upper_l': -42, 'fore_l': -24, 'head': -4}),
    ],
  );

  static RigClip forKind(HeroAnimKind kind) => switch (kind) {
    HeroAnimKind.walk => walk,
    HeroAnimKind.attack => attack,
    HeroAnimKind.cast => cast,
    HeroAnimKind.hit => hit,
    HeroAnimKind.death => death,
    HeroAnimKind.victory => victory,
    HeroAnimKind.idle => idle,
  };

  static RigPose sample(RigClip clip, double seconds) {
    final length = clip.length <= 0 ? 0.01 : clip.length;
    final u = clip.loop ? (seconds % length) / length : (seconds / length).clamp(0.0, 1.0);
    final keys = clip.keys;
    if (u <= keys.first.t) return _pose(keys.first);
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (a.t <= u && u <= b.t) return _blend(a, b, u);
    }
    if (clip.loop && keys.last.t < 1) {
      return _blend(keys.last, keys.first, u, wrap: true);
    }
    return _pose(keys.last);
  }

  static RigPose _pose(RigKey key) => RigPose(
    angles: key.bones,
    rootX: key.rootX,
    rootY: key.rootY,
  );

  static RigPose _blend(RigKey a, RigKey b, double u, {bool wrap = false}) {
    final t1 = b.t + (wrap ? 1 : 0);
    final span = t1 - a.t;
    final f = span <= 0 ? 0.0 : _smooth((u - a.t) / span);
    final names = {...a.bones.keys, ...b.bones.keys};
    return RigPose(
      angles: {for (final name in names) name: _lerp(a.bones[name] ?? 0, b.bones[name] ?? 0, f)},
      rootX: _lerp(a.rootX, b.rootX, f),
      rootY: _lerp(a.rootY, b.rootY, f),
    );
  }

  static double _smooth(double f) => f * f * (3 - 2 * f);

  static double _lerp(double a, double b, double f) => a + (b - a) * f;
}
