import 'hero_anim_state.dart';

/// Logical draw layers for modular dungeon characters (back → front default).
enum CharacterLayerId {
  cape,
  body,
  legs,
  torso,
  gloves,
  hair,
  head,
  offHand,
  mainHand,
  effects,
}

/// Default back-to-front order when anim does not override.
const List<CharacterLayerId> kDefaultLayerOrder = <CharacterLayerId>[
  CharacterLayerId.cape,
  CharacterLayerId.body,
  CharacterLayerId.legs,
  CharacterLayerId.torso,
  CharacterLayerId.gloves,
  CharacterLayerId.hair,
  CharacterLayerId.head,
  CharacterLayerId.offHand,
  CharacterLayerId.mainHand,
  CharacterLayerId.effects,
];

/// Attack wind-up: weapon still behind torso/head silhouette.
const List<CharacterLayerId> kAttackWindupLayerOrder = <CharacterLayerId>[
  CharacterLayerId.cape,
  CharacterLayerId.body,
  CharacterLayerId.legs,
  CharacterLayerId.torso,
  CharacterLayerId.gloves,
  CharacterLayerId.mainHand,
  CharacterLayerId.hair,
  CharacterLayerId.head,
  CharacterLayerId.offHand,
  CharacterLayerId.effects,
];

/// Attack swing peak: main hand in front.
const List<CharacterLayerId> kAttackLayerOrder = <CharacterLayerId>[
  CharacterLayerId.cape,
  CharacterLayerId.body,
  CharacterLayerId.legs,
  CharacterLayerId.torso,
  CharacterLayerId.gloves,
  CharacterLayerId.hair,
  CharacterLayerId.head,
  CharacterLayerId.offHand,
  CharacterLayerId.mainHand,
  CharacterLayerId.effects,
];

/// Facing-left local order (canvas is mirrored; off-hand reads nearer).
const List<CharacterLayerId> kDefaultLayerOrderFlip = <CharacterLayerId>[
  CharacterLayerId.cape,
  CharacterLayerId.body,
  CharacterLayerId.legs,
  CharacterLayerId.torso,
  CharacterLayerId.gloves,
  CharacterLayerId.hair,
  CharacterLayerId.head,
  CharacterLayerId.mainHand,
  CharacterLayerId.offHand,
  CharacterLayerId.effects,
];

const List<CharacterLayerId> kAttackLayerOrderFlip = <CharacterLayerId>[
  CharacterLayerId.cape,
  CharacterLayerId.body,
  CharacterLayerId.legs,
  CharacterLayerId.torso,
  CharacterLayerId.gloves,
  CharacterLayerId.hair,
  CharacterLayerId.head,
  CharacterLayerId.mainHand,
  CharacterLayerId.offHand,
  CharacterLayerId.effects,
];

/// Draw order for [anim] / [frame] / [flipX].
List<CharacterLayerId> layerOrderFor(
  HeroAnimKind anim, {
  int frame = 0,
  bool flipX = false,
}) {
  if (anim == HeroAnimKind.attack) {
    if (frame == 0) {
      return flipX ? kDefaultLayerOrderFlip : kAttackWindupLayerOrder;
    }
    return flipX ? kAttackLayerOrderFlip : kAttackLayerOrder;
  }
  if (anim == HeroAnimKind.cast && frame == 1) {
    return flipX ? kAttackLayerOrderFlip : kAttackLayerOrder;
  }
  return flipX ? kDefaultLayerOrderFlip : kDefaultLayerOrder;
}
