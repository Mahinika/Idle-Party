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
}
