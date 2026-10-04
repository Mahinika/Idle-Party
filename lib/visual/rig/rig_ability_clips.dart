import 'rig_clips.dart';

/// Warrior ability poses, keyed by the ability's Dart name.
/// Other classes fall back to the attack or cast clip.
abstract final class RigAbilityClips {
  static const defensiveStance = RigClip(
    name: 'defensiveStance',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.35, bones: {'torso': 4, 'upper_l': -28, 'fore_l': -18, 'upper_r': 16, 'fore_r': 12, 'sword': -8, 'thigh_l': 8, 'thigh_r': -8}),
      RigKey(1.0, bones: {'torso': 4, 'upper_l': -28, 'fore_l': -18, 'upper_r': 16, 'fore_r': 12, 'sword': -8, 'thigh_l': 8, 'thigh_r': -8}),
    ],
  );

  static const charge = RigClip(
    name: 'charge',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.25, rootX: 6, rootY: 2, bones: {'torso': -14, 'upper_l': -36, 'fore_l': -10, 'upper_r': 22, 'sword': 12, 'thigh_l': 28, 'shin_l': -30, 'thigh_r': -8}),
      RigKey(0.55, rootX: 16, rootY: 0, bones: {'torso': -8, 'upper_l': -20, 'upper_r': -16, 'sword': -36, 'thigh_l': -6, 'thigh_r': 24, 'shin_r': 18}),
      RigKey(1.0),
    ],
  );

  static const shieldBlock = RigClip(
    name: 'shieldBlock',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.3, bones: {'torso': 6, 'upper_l': -42, 'fore_l': -24, 'head': -4}),
      RigKey(1.0, bones: {'torso': 6, 'upper_l': -42, 'fore_l': -24, 'head': -4}),
    ],
  );

  static const thunderClap = RigClip(
    name: 'thunderClap',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.35, bones: {'upper_l': 46, 'fore_l': 16, 'upper_r': -46, 'fore_r': -16, 'torso': -4}),
      RigKey(0.55, rootX: 0, rootY: 3, bones: {'upper_l': -18, 'fore_l': -20, 'upper_r': 18, 'fore_r': 20, 'torso': 6}),
      RigKey(1.0),
    ],
  );

  static const devastate = RigClip(
    name: 'devastate',
    length: 0.75,
    keys: [
      RigKey(0.0),
      RigKey(0.28, bones: {'torso': 8, 'upper_r': 22, 'fore_r': -20, 'sword': -16}),
      RigKey(0.48, bones: {'torso': -14, 'upper_r': -18, 'fore_r': -6, 'sword': -48}),
      RigKey(1.0),
    ],
  );

  static const taunt = RigClip(
    name: 'taunt',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.4, rootX: 0, rootY: -2, bones: {'torso': -6, 'head': -6, 'upper_l': 34, 'upper_r': -34, 'fore_l': 10, 'fore_r': -10}),
      RigKey(1.0, rootX: 0, rootY: -2, bones: {'torso': -6, 'head': -6, 'upper_l': 34, 'upper_r': -34}),
    ],
  );

  static const demoralizingShout = RigClip(
    name: 'demoralizingShout',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.35, bones: {'torso': 8, 'head': 8, 'upper_l': 20, 'upper_r': -20}),
      RigKey(0.6, rootX: 0, rootY: 2, bones: {'torso': 12, 'head': 10, 'upper_l': -10, 'upper_r': 10}),
      RigKey(1.0),
    ],
  );

  static const shieldSlam = RigClip(
    name: 'shieldSlam',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.25, bones: {'upper_l': 30, 'fore_l': 20}),
      RigKey(0.45, rootX: 4, rootY: 1, bones: {'torso': -8, 'upper_l': -40, 'fore_l': -16}),
      RigKey(1.0),
    ],
  );

  static const commandingShout = RigClip(
    name: 'commandingShout',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.4, rootX: 0, rootY: -3, bones: {'torso': -8, 'head': -8, 'upper_l': 40, 'upper_r': -20, 'sword': 10}),
      RigKey(1.0, rootX: 0, rootY: -3, bones: {'torso': -8, 'upper_l': 40, 'upper_r': -20}),
    ],
  );

  static const revenge = RigClip(
    name: 'revenge',
    length: 0.65,
    keys: [
      RigKey(0.0),
      RigKey(0.3, bones: {'upper_l': -34, 'fore_l': -12, 'upper_r': 14, 'sword': -10}),
      RigKey(0.5, bones: {'torso': -8, 'upper_l': -16, 'upper_r': -20, 'sword': -42}),
      RigKey(1.0),
    ],
  );

  static const shockwave = RigClip(
    name: 'shockwave',
    length: 0.75,
    keys: [
      RigKey(0.0),
      RigKey(0.3, rootX: 0, rootY: -2, bones: {'upper_l': 40, 'upper_r': -40}),
      RigKey(0.5, rootX: 0, rootY: 6, bones: {'torso': 8, 'upper_l': 8, 'upper_r': -8, 'thigh_l': 14, 'thigh_r': -14}),
      RigKey(1.0),
    ],
  );

  static const lastStand = RigClip(
    name: 'lastStand',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.4, rootX: 0, rootY: 4, bones: {'torso': 8, 'upper_l': -36, 'fore_l': -20, 'thigh_l': 16, 'thigh_r': -16, 'shin_l': -12, 'shin_r': 12}),
      RigKey(1.0, rootX: 0, rootY: 4, bones: {'torso': 8, 'upper_l': -36, 'fore_l': -20, 'thigh_l': 16, 'thigh_r': -16}),
    ],
  );

  static const shieldWall = RigClip(
    name: 'shieldWall',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.35, rootX: 0, rootY: 5, bones: {'torso': 12, 'head': 6, 'upper_l': -48, 'fore_l': -28, 'upper_r': 24, 'sword': 8}),
      RigKey(1.0, rootX: 0, rootY: 5, bones: {'torso': 12, 'upper_l': -48, 'fore_l': -28, 'upper_r': 24}),
    ],
  );

  static const armsStance = RigClip(
    name: 'armsStance',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.4, bones: {'torso': -4, 'upper_r': -12, 'fore_r': -8, 'sword': -6, 'upper_l': 8}),
      RigKey(1.0, bones: {'torso': -4, 'upper_r': -12, 'fore_r': -8, 'sword': -6}),
    ],
  );

  static const mortalStrike = RigClip(
    name: 'mortalStrike',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.3, bones: {'torso': 10, 'upper_r': 28, 'fore_r': -24, 'sword': -8}),
      RigKey(0.5, bones: {'torso': -16, 'upper_r': -24, 'fore_r': -4, 'sword': -56}),
      RigKey(1.0),
    ],
  );

  static const overpower = RigClip(
    name: 'overpower',
    length: 0.55,
    keys: [
      RigKey(0.0),
      RigKey(0.25, bones: {'torso': 6, 'upper_r': 16, 'sword': -12}),
      RigKey(0.45, bones: {'torso': -10, 'upper_r': -14, 'sword': -36}),
      RigKey(1.0),
    ],
  );

  static const rend = RigClip(
    name: 'rend',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.3, bones: {'torso': 6, 'upper_r': 18, 'sword': 20}),
      RigKey(0.55, bones: {'torso': -10, 'upper_r': -22, 'sword': -30}),
      RigKey(1.0),
    ],
  );

  static const sweepingStrikes = RigClip(
    name: 'sweepingStrikes',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.3, bones: {'torso': 12, 'upper_r': 24, 'sword': 28, 'upper_l': -10}),
      RigKey(0.6, bones: {'torso': -14, 'upper_r': -26, 'sword': -34, 'upper_l': 16}),
      RigKey(1.0),
    ],
  );

  static const bladestorm = RigClip(
    name: 'bladestorm',
    length: 0.9,
    keys: [
      RigKey(0.0, bones: {'upper_r': -12, 'upper_l': 12, 'sword': -8}),
      RigKey(0.25, bones: {'torso': 14, 'upper_r': -28, 'upper_l': 22, 'sword': 22}),
      RigKey(0.5, bones: {'torso': -14, 'upper_r': 16, 'upper_l': -24, 'sword': -30}),
      RigKey(0.75, bones: {'torso': 14, 'upper_r': -28, 'upper_l': 22, 'sword': 22}),
      RigKey(1.0, bones: {'sword': -8, 'upper_r': -8}),
    ],
  );

  static const armsExecute = RigClip(
    name: 'armsExecute',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.35, rootX: 0, rootY: -3, bones: {'torso': 12, 'upper_r': 34, 'fore_r': -30, 'sword': 6}),
      RigKey(0.55, rootX: 0, rootY: 4, bones: {'torso': -18, 'upper_r': -28, 'sword': -62}),
      RigKey(1.0),
    ],
  );

  static const armsRally = RigClip(
    name: 'armsRally',
    length: 0.75,
    keys: [
      RigKey(0.0),
      RigKey(0.4, rootX: 0, rootY: -4, bones: {'torso': -10, 'head': -10, 'upper_l': 36, 'upper_r': -30}),
      RigKey(1.0, rootX: 0, rootY: -2, bones: {'torso': -6, 'upper_l': 28, 'upper_r': -22}),
    ],
  );

  static const berserkerStance = RigClip(
    name: 'berserkerStance',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.4, bones: {'torso': -10, 'head': -4, 'upper_r': -20, 'sword': -18, 'upper_l': 22, 'fore_l': 12}),
      RigKey(1.0, bones: {'torso': -10, 'upper_r': -20, 'sword': -18, 'upper_l': 22}),
    ],
  );

  static const bloodthirst = RigClip(
    name: 'bloodthirst',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.22, bones: {'torso': 6, 'upper_r': 16, 'fore_r': -8, 'sword': -10}),
      RigKey(0.42, bones: {'torso': -8, 'upper_r': -10, 'fore_r': -4, 'sword': -36}),
      RigKey(0.62, bones: {'torso': 4, 'upper_r': 10, 'sword': -8}),
      RigKey(0.85, bones: {'torso': -6, 'upper_r': -8, 'sword': -32}),
      RigKey(1.0),
    ],
  );

  static const whirlwind = RigClip(
    name: 'whirlwind',
    length: 0.85,
    keys: [
      RigKey(0.0, bones: {'upper_l': 16, 'upper_r': -16, 'sword': -6}),
      RigKey(0.35, bones: {'torso': 12, 'upper_l': 32, 'upper_r': -32, 'sword': 18}),
      RigKey(0.7, bones: {'torso': -12, 'upper_l': -8, 'upper_r': 20, 'sword': -36}),
      RigKey(1.0),
    ],
  );

  static const ragingBlow = RigClip(
    name: 'ragingBlow',
    length: 0.7,
    keys: [
      RigKey(0.0),
      RigKey(0.2, bones: {'torso': 8, 'upper_r': 18, 'sword': -6}),
      RigKey(0.4, bones: {'torso': -10, 'upper_r': -16, 'sword': -40}),
      RigKey(0.58, bones: {'torso': 6, 'upper_r': 12, 'sword': -8}),
      RigKey(0.8, bones: {'torso': -12, 'upper_r': -18, 'sword': -46}),
      RigKey(1.0),
    ],
  );

  static const enrageBuff = RigClip(
    name: 'enrageBuff',
    length: 0.6,
    keys: [
      RigKey(0.0),
      RigKey(0.4, bones: {'torso': -8, 'upper_l': 16, 'upper_r': -18, 'sword': -8, 'head': -4}),
      RigKey(0.7, bones: {'torso': -4, 'upper_l': 10, 'upper_r': -10}),
      RigKey(1.0),
    ],
  );

  static const deathWish = RigClip(
    name: 'deathWish',
    length: 0.75,
    keys: [
      RigKey(0.0),
      RigKey(0.4, bones: {'torso': -12, 'head': -6, 'upper_r': 20, 'sword': 16, 'upper_l': -16}),
      RigKey(1.0, bones: {'torso': -12, 'upper_r': 20, 'sword': 16, 'upper_l': -16}),
    ],
  );

  static const furyExecute = RigClip(
    name: 'furyExecute',
    length: 0.85,
    keys: [
      RigKey(0.0),
      RigKey(0.15, bones: {'torso': 6, 'upper_r': 14, 'sword': -4}),
      RigKey(0.3, bones: {'torso': -6, 'upper_r': -8, 'sword': -34}),
      RigKey(0.45, bones: {'torso': 4, 'upper_r': 8, 'sword': -8}),
      RigKey(0.6, bones: {'torso': -8, 'upper_r': -12, 'sword': -40}),
      RigKey(0.75, bones: {'torso': 4, 'upper_r': 8, 'sword': -6}),
      RigKey(0.9, bones: {'torso': -12, 'upper_r': -16, 'sword': -50}),
      RigKey(1.0),
    ],
  );

  static const enragedRegeneration = RigClip(
    name: 'enragedRegeneration',
    length: 0.9,
    keys: [
      RigKey(0.0),
      RigKey(0.4, rootX: 0, rootY: 5, bones: {'torso': 10, 'upper_l': -20, 'upper_r': 18, 'thigh_l': 18, 'thigh_r': -18}),
      RigKey(0.75, rootX: 0, rootY: -2, bones: {'torso': -4, 'upper_l': 12, 'upper_r': -12}),
      RigKey(1.0),
    ],
  );

  static const furyRecklessness = RigClip(
    name: 'furyRecklessness',
    length: 0.8,
    keys: [
      RigKey(0.0),
      RigKey(0.25, bones: {'torso': 8, 'upper_r': 20, 'sword': 24, 'upper_l': 24}),
      RigKey(0.5, bones: {'torso': -12, 'upper_r': -22, 'sword': -40, 'upper_l': -10}),
      RigKey(0.75, bones: {'torso': 6, 'sword': 18, 'upper_r': 12}),
      RigKey(1.0),
    ],
  );

  static RigClip? forName(String? name) => switch (name) {
    'defensiveStance' => defensiveStance,
    'charge' => charge,
    'shieldBlock' => shieldBlock,
    'thunderClap' => thunderClap,
    'devastate' => devastate,
    'taunt' => taunt,
    'demoralizingShout' => demoralizingShout,
    'shieldSlam' => shieldSlam,
    'commandingShout' => commandingShout,
    'revenge' => revenge,
    'shockwave' => shockwave,
    'lastStand' => lastStand,
    'shieldWall' => shieldWall,
    'armsStance' => armsStance,
    'mortalStrike' => mortalStrike,
    'overpower' => overpower,
    'rend' => rend,
    'sweepingStrikes' => sweepingStrikes,
    'bladestorm' => bladestorm,
    'armsExecute' => armsExecute,
    'armsRally' => armsRally,
    'berserkerStance' => berserkerStance,
    'bloodthirst' => bloodthirst,
    'whirlwind' => whirlwind,
    'ragingBlow' => ragingBlow,
    'enrageBuff' => enrageBuff,
    'deathWish' => deathWish,
    'furyExecute' => furyExecute,
    'enragedRegeneration' => enragedRegeneration,
    'furyRecklessness' => furyRecklessness,
    _ => null,
  };

  /// How long a named pose should stay up. Zero when this ability has no clip.
  static double holdFor(String? name) => forName(name)?.length ?? 0;
}
