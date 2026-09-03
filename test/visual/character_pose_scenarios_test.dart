import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/hero_spec.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/visual/anchor_table.dart';
import 'package:idle_party/visual/character_layer.dart';
import 'package:idle_party/visual/character_visual_painter.dart';
import 'package:idle_party/visual/character_visual_pose.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/owned_gear_assets.dart';

PartyHero nakedWarrior() => PartyHero.starting(
  name: 'Aegis',
  specId: HeroSpecId.protection,
  stats: PartyHero.startingStatsForSpec(HeroSpecId.protection),
);

HeroAnimPose get idle =>
    const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0);

void main() {
  test('naked warrior = body + hair only', () {
    final pose = CharacterVisualPose.resolve(
      hero: nakedWarrior(),
      anim: idle,
    );
    expect(pose.layers.length, 2);
    expect(pose.layers.map((l) => l.id), [
      CharacterLayerId.body,
      CharacterLayerId.hair,
    ]);
  });

  test('+ helmet adds head and drops hair', () {
    final helm = GameLogic.createEquipment(
      slot: EquipmentSlot.head,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    final hero = nakedWarrior().copyWith(
      equipped: {EquipmentSlot.head: helm},
    );
    final pose = CharacterVisualPose.resolve(hero: hero, anim: idle);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.head), isTrue);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.hair), isFalse);
  });

  test('+ sword adds anchored mainHand', () {
    final sword = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    final hero = nakedWarrior().copyWith(
      equipped: {EquipmentSlot.weapon: sword},
    );
    final pose = CharacterVisualPose.resolve(hero: hero, anim: idle);
    final hand = pose.layers.where((l) => l.id == CharacterLayerId.mainHand);
    expect(hand, isNotEmpty);
    expect(hand.first.anchored, isTrue);
    expect(hand.first.anchorId, AnchorId.mainHand);
  });

  test('helmet + sword both present', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.head: GameLogic.createEquipment(
          slot: EquipmentSlot.head,
          rarity: LootRarity.common,
          battleNumber: 3,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.common,
          battleNumber: 3,
          bias: HeroRole.warrior,
        ),
      },
    );
    final pose = CharacterVisualPose.resolve(hero: hero, anim: idle);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.head), isTrue);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.mainHand), isTrue);
  });

  test('armor + sword + shield', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.chest: GameLogic.createEquipment(
          slot: EquipmentSlot.chest,
          rarity: LootRarity.rare,
          battleNumber: 8,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.rare,
          battleNumber: 8,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.offHand: GameLogic.createEquipment(
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.uncommon,
          battleNumber: 8,
          bias: HeroRole.warrior,
        ),
      },
    );
    final pose = CharacterVisualPose.resolve(hero: hero, anim: idle);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.torso), isTrue);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.mainHand), isTrue);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.offHand), isTrue);
  });

  test('hunter bow and mage staff weapon layers', () {
    final hunter = PartyHero.starting(
      name: 'Hunt',
      specId: HeroSpecId.beastMastery,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.beastMastery),
    ).copyWith(
      equipped: {
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.uncommon,
          battleNumber: 4,
          bias: HeroRole.rogue,
        ).copyWith(weaponType: WeaponType.bow, visualSetId: 'bow_t1'),
      },
    );
    final hPose = CharacterVisualPose.resolve(hero: hunter, anim: idle);
    expect(hPose.layers.any((l) => l.id == CharacterLayerId.mainHand), isTrue);

    final mage = PartyHero.starting(
      name: 'Arc',
      specId: HeroSpecId.arcane,
      stats: PartyHero.startingStatsForSpec(HeroSpecId.arcane),
    ).copyWith(
      equipped: {
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.rare,
          battleNumber: 4,
          bias: HeroRole.mage,
        ).copyWith(weaponType: WeaponType.staff, visualSetId: 'staff_t2'),
      },
    );
    final mPose = CharacterVisualPose.resolve(hero: mage, anim: idle);
    expect(mPose.layers.any((l) => l.id == CharacterLayerId.mainHand), isTrue);
  });

  test('attack pose adds mainHand swing rotation', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ),
      },
    );
    final attack = CharacterVisualPose.resolve(
      hero: hero,
      anim: const HeroAnimPose(
        kind: HeroAnimKind.attack,
        frame: 1,
        progress: 0.4,
      ),
    );
    expect(attack.mainHandExtraRotation, isNot(0));
    final idlePose = CharacterVisualPose.resolve(hero: hero, anim: idle);
    expect(idlePose.mainHandExtraRotation, 0);
  });

  test('anchors flip x and negate rotation', () {
    final a = AnchorTables.lookup(
      anim: HeroAnimKind.idle,
      frame: 0,
      id: AnchorId.mainHand,
    );
    final f = AnchorTables.lookup(
      anim: HeroAnimKind.idle,
      frame: 0,
      id: AnchorId.mainHand,
      flipX: true,
    );
    expect(f.x, -a.x);
    expect(f.rotation, -a.rotation);
  });

  test('pose cache hits on identical inputs', () {
    CharacterVisualPoseCache.clear();
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ),
      },
    );
    final a = CharacterVisualPoseCache.resolve(
      heroId: 'h1',
      hero: hero,
      anim: idle,
    );
    final b = CharacterVisualPoseCache.resolve(
      heroId: 'h1',
      hero: hero,
      anim: idle,
    );
    expect(identical(a, b), isTrue);

    final flipped = CharacterVisualPoseCache.resolve(
      heroId: 'h1',
      hero: hero,
      anim: idle,
      flipX: true,
    );
    expect(identical(a, flipped), isFalse);
    expect(flipped.layerOrder.first, CharacterLayerId.cape);
  });

  test('attack wind-up uses different draw order than swing', () {
    final windup = layerOrderFor(HeroAnimKind.attack, frame: 0);
    final swing = layerOrderFor(HeroAnimKind.attack, frame: 1);
    expect(windup, isNot(equals(swing)));
    expect(
      windup.indexOf(CharacterLayerId.mainHand) <
          windup.indexOf(CharacterLayerId.head),
      isTrue,
    );
  });

  test('gear overlay set excludes body layers', () {
    expect(
      CharacterVisualPainter.kGearOverlayLayers.contains(CharacterLayerId.body),
      isFalse,
    );
    expect(
      CharacterVisualPainter.kGearOverlayLayers,
      containsAll([
        CharacterLayerId.head,
        CharacterLayerId.mainHand,
        CharacterLayerId.offHand,
      ]),
    );
  });

  test('owned denser overlays are 128 paper-doll layers', () {
    expect(
      CharacterVisualPainter.kOwnedGearOverlayLayers,
      containsAll([
        CharacterLayerId.head,
        CharacterLayerId.torso,
        CharacterLayerId.mainHand,
        CharacterLayerId.offHand,
      ]),
    );
    expect(
      CharacterVisualPainter.kOwnedGearOverlayLayers.contains(
        CharacterLayerId.body,
      ),
      isFalse,
    );
  });

  test('owned denser anchors sit lower on hands than kenney', () {
    final kenney = AnchorTables.lookup(
      anim: HeroAnimKind.idle,
      frame: 0,
      id: AnchorId.mainHand,
      profile: BodyAnchorProfile.kenney,
    );
    final owned = AnchorTables.lookup(
      anim: HeroAnimKind.idle,
      frame: 0,
      id: AnchorId.mainHand,
      profile: BodyAnchorProfile.owned,
    );
    expect(owned.y, greaterThan(kenney.y));
    expect(
      AnchorTables.lookup(
        anim: HeroAnimKind.idle,
        frame: 0,
        id: AnchorId.head,
        profile: BodyAnchorProfile.owned,
      ).y,
      lessThan(-0.3),
    );
  });

  test('owned common chest paints torso overlay on undertunic', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.chest: GameLogic.createEquipment(
          slot: EquipmentSlot.chest,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ).copyWith(visualSetId: 'chest_t0'),
        EquipmentSlot.head: GameLogic.createEquipment(
          slot: EquipmentSlot.head,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ).copyWith(visualSetId: 'helm_t0'),
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ).copyWith(visualSetId: 'sword_t0'),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    expect(pose.layers.any((l) => l.id == CharacterLayerId.torso), isTrue);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.head), isTrue);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.mainHand), isTrue);
    final torso = pose.layers.firstWhere((l) => l.id == CharacterLayerId.torso);
    expect(torso.ownedAsset, contains('chest_t0_idle.png'));
    expect(torso.ownedAsset, contains('/warrior/gear/'));
    final helm = pose.layers.firstWhere((l) => l.id == CharacterLayerId.head);
    expect(helm.ownedAsset, contains('helm_t0_idle.png'));
  });

  test('owned empty chest is undertunic body only', () {
    final pose = CharacterVisualPose.resolve(
      hero: nakedWarrior(),
      anim: idle,
      owned: true,
    );
    expect(pose.layers.map((l) => l.id), [CharacterLayerId.body]);
  });

  test('owned cloak paints cape overlay', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.cloak: GameLogic.createEquipment(
          slot: EquipmentSlot.cloak,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ).copyWith(visualSetId: 'cloak_t0'),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    expect(pose.layers.any((l) => l.id == CharacterLayerId.cape), isTrue);
    final cape = pose.layers.firstWhere((l) => l.id == CharacterLayerId.cape);
    expect(cape.ownedAsset, contains('cloak_t0_idle.png'));
    expect(cape.ownedAsset, contains('/warrior/gear/'));
  });

  test('owned shoulders do not add a body layer', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.shoulder: GameLogic.createEquipment(
          slot: EquipmentSlot.shoulder,
          rarity: LootRarity.rare,
          battleNumber: 8,
          bias: HeroRole.warrior,
        ),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    expect(pose.layers.map((l) => l.id), [CharacterLayerId.body]);
  });

  test('owned rare chest uses t2 overlay path', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.chest: GameLogic.createEquipment(
          slot: EquipmentSlot.chest,
          rarity: LootRarity.rare,
          battleNumber: 10,
          bias: HeroRole.warrior,
        ).copyWith(visualSetId: 'chest_t2'),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    final torso = pose.layers.where((l) => l.id == CharacterLayerId.torso);
    expect(torso, isNotEmpty);
    expect(torso.first.ownedAsset, contains('chest_t2_idle.png'));
  });

  test('owned two-hand weapon hides off-hand overlay', () {
    final twoHand = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.warrior,
    ).copyWith(handed: WeaponHanded.twoHand, visualSetId: 'sword_t1');
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.weapon: twoHand,
        EquipmentSlot.offHand: GameLogic.createEquipment(
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.uncommon,
          battleNumber: 4,
          bias: HeroRole.warrior,
        ),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    expect(pose.layers.any((l) => l.id == CharacterLayerId.mainHand), isTrue);
    expect(pose.layers.any((l) => l.id == CharacterLayerId.offHand), isFalse);
  });

  test('owned and kenney poses share equip hash', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ),
      },
    );
    final k = CharacterVisualPose.resolve(hero: hero, anim: idle);
    final o = CharacterVisualPose.resolve(hero: hero, anim: idle, owned: true);
    expect(k.equipHash, o.equipHash);
  });

  test('owned rare gloves overlay uses hands_t0 art', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.hands: GameLogic.createEquipment(
          slot: EquipmentSlot.hands,
          rarity: LootRarity.rare,
          battleNumber: 10,
          bias: HeroRole.warrior,
        ).copyWith(visualSetId: 'hands_t2'),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    final gloves = pose.layers.where((l) => l.id == CharacterLayerId.gloves);
    expect(gloves, isNotEmpty);
    expect(gloves.first.ownedAsset, contains('hands_t0_idle.png'));
    expect(gloves.first.tint, isNotNull);
  });

  test('owned jewelry is not a body layer', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.ring: GameLogic.createEquipment(
          slot: EquipmentSlot.ring,
          rarity: LootRarity.rare,
          battleNumber: 6,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.neck: GameLogic.createEquipment(
          slot: EquipmentSlot.neck,
          rarity: LootRarity.rare,
          battleNumber: 6,
          bias: HeroRole.warrior,
        ),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    expect(pose.layers.map((l) => l.id), [CharacterLayerId.body]);
  });

  test('GEAR idle and dungeon idle share the same owned overlay paths', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.head: GameLogic.createEquipment(
          slot: EquipmentSlot.head,
          rarity: LootRarity.uncommon,
          battleNumber: 4,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.uncommon,
          battleNumber: 4,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.offHand: GameLogic.createEquipment(
          slot: EquipmentSlot.offHand,
          rarity: LootRarity.uncommon,
          battleNumber: 4,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.chest: GameLogic.createEquipment(
          slot: EquipmentSlot.chest,
          rarity: LootRarity.rare,
          battleNumber: 12,
          bias: HeroRole.warrior,
        ),
      },
    );
    final gearIdle = CharacterVisualPose.resolve(
      hero: hero,
      anim: idle,
      owned: true,
    );
    final dungeonIdle = CharacterVisualPose.resolve(
      hero: hero,
      anim: const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0),
      owned: true,
    );
    expect(
      gearIdle.layers.map((l) => l.ownedAsset).toList(),
      dungeonIdle.layers.map((l) => l.ownedAsset).toList(),
    );
  });

  test('owned walk pose uses walk overlay files, not Kenney cells', () {
    final hero = nakedWarrior().copyWith(
      equipped: {
        EquipmentSlot.head: GameLogic.createEquipment(
          slot: EquipmentSlot.head,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ),
        EquipmentSlot.weapon: GameLogic.createEquipment(
          slot: EquipmentSlot.weapon,
          rarity: LootRarity.common,
          battleNumber: 2,
          bias: HeroRole.warrior,
        ),
      },
    );
    final pose = CharacterVisualPose.resolve(
      hero: hero,
      anim: const HeroAnimPose(kind: HeroAnimKind.walk, frame: 0),
      owned: true,
    );
    for (final layer in pose.layers.where((l) => l.id != CharacterLayerId.body)) {
      expect(layer.ownedAsset, isNotNull);
      expect(layer.ownedAsset, isNot(contains('kenney')));
      expect(layer.ownedAsset, contains('_walk.png'));
    }
  });

  test('owned gear path list is unique and includes shared sword', () {
    final paths = OwnedGearAssets.allAssetPaths;
    expect(paths.toSet().length, paths.length);
    expect(paths, contains('assets/custom/char/gear/sword_t0_idle.png'));
    expect(
      paths,
      contains('assets/custom/char/warrior/gear/helm_t0_idle.png'),
    );
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
