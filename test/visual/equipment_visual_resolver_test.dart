import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/character_layer.dart';
import 'package:idle_party/visual/equipment_model_catalog.dart';
import 'package:idle_party/visual/equipment_visual_resolver.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/owned_gear_assets.dart';

void main() {
  test('factory stamps visualSetId from model catalog', () {
    final sword = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    expect(sword.visualSetId, isNotNull);
    final id = sword.visualSetId!;
    final base = EquipmentModelCatalog.baseToken(id);
    expect(EquipmentModelCatalog.variantsFor(base), contains(id));
    expect(EquipmentVisualResolver.defFor(id), isNotNull);
  });

  test('factory pickVariant can differ across rolls for swords', () {
    final ids = <String>{};
    for (var i = 0; i < 40; i++) {
      ids.add(
        EquipmentModelCatalog.pickVariant(
          'sword_t0',
          Random(i),
          rarityTier: 3,
        ),
      );
    }
    expect(ids.length, greaterThan(1), reason: 'authored sword pool should vary');
    expect(ids, contains('sword_t0'));
  });

  test('model catalog is short: tiers + authored weapons', () {
    expect(EquipmentModelCatalog.variantsFor('sword'), [
      'sword_t0',
      'sword_thunderfury',
      'sword_warglaive',
    ]);
    expect(EquipmentModelCatalog.variantsFor('staff'), ['staff_t0']);
    expect(EquipmentModelCatalog.variantsFor('helm'), ['helm_t0', 'helm_t2']);
    expect(EquipmentModelCatalog.variantsFor('hands'), ['hands_t0']);
    for (final base in EquipmentModelCatalog.familyBases) {
      expect(
        EquipmentModelCatalog.pickVariant('${base}_t0', Random(1)),
        '${base}_t0',
      );
    }
  });

  test('family armor path uses extract tier id', () {
    final path = OwnedGearAssets.pathFor(
      visualSetId: 'helm_t0',
      family: BodyFamily.warrior,
      anim: HeroAnimKind.idle,
    );
    expect(path, 'assets/custom/char/warrior/gear/helm_t0_idle.png');
  });

  test('legacy named id still resolves head layer via base-token', () {
    final def = EquipmentVisualResolver.defFor('helm_spiked');
    expect(def, isNotNull);
    expect(def!.layer, CharacterLayerId.head);
  });

  test('hunter bow and mage staff resolve weapon families', () {
    final bow = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.rogue,
    ).copyWith(weaponType: WeaponType.bow, clearVisualSetId: true);
    expect(EquipmentVisualResolver.resolveId(bow), startsWith('bow_'));
    expect(
      EquipmentVisualResolver.defForItem(bow)?.layer.name,
      'mainHand',
    );

    final staff = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 4,
      bias: HeroRole.mage,
    ).copyWith(weaponType: WeaponType.staff, clearVisualSetId: true);
    expect(EquipmentVisualResolver.resolveId(staff), startsWith('staff_'));
  });

  test('mage loot is always a two-hand staff', () {
    for (var i = 0; i < 20; i++) {
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 5 + i,
        bias: HeroRole.mage,
      );
      expect(item.weaponType, WeaponType.staff);
      expect(item.handed, WeaponHanded.twoHand);
      expect(item.visualSetId, startsWith('staff_'));
    }
  });

  test('thrown resolves to dagger art, not a bow', () {
    final item = GameLogic.createEquipment(
      slot: EquipmentSlot.ranged,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.warrior,
    ).copyWith(weaponType: WeaponType.thrown, visualSetId: 'bow_longshot');
    expect(EquipmentVisualResolver.resolveId(item), 'dagger_t0');
    expect(
      OwnedGearAssets.iconPathFor(item),
      'assets/custom/char/gear/dagger_t0_icon.png',
    );
  });

  test('explicit visualSetId wins over derive', () {
    final item = GameLogic.createEquipment(
      slot: EquipmentSlot.head,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.warrior,
    ).copyWith(visualSetId: 'helm_t3');
    expect(EquipmentVisualResolver.resolveId(item), 'helm_t3');
  });

  test('catalog covers sword/shield tiers', () {
    expect(EquipmentVisualResolver.catalog['sword_t0'], isNotNull);
    expect(EquipmentVisualResolver.catalog['shield_t2'], isNotNull);
    expect(EquipmentVisualResolver.catalog['bow_t1']!.useAnchor, isTrue);
  });

  test('owned asset path is family 128 overlay, never Kenney atlas', () {
    final helm = GameLogic.createEquipment(
      slot: EquipmentSlot.head,
      rarity: LootRarity.common,
      battleNumber: 1,
      bias: HeroRole.warrior,
    ).copyWith(visualSetId: 'helm_t0');
    final path = EquipmentVisualResolver.ownedAssetForItem(
      helm,
      family: BodyFamily.warrior,
      anim: HeroAnimKind.idle,
    );
    expect(path, 'assets/custom/char/warrior/gear/helm_t0_idle.png');
    expect(path, isNot(contains('kenney')));
  });

  test('jewelry resolves to none and has no owned path', () {
    final ring = GameLogic.createEquipment(
      slot: EquipmentSlot.ring,
      rarity: LootRarity.rare,
      battleNumber: 3,
      bias: HeroRole.warrior,
    );
    expect(EquipmentVisualResolver.resolveId(ring), 'none');
    expect(
      EquipmentVisualResolver.ownedAssetForItem(
        ring,
        family: BodyFamily.warrior,
        anim: HeroAnimKind.idle,
      ),
      isNull,
    );
  });

  // ── Weapon model variants (WoW-like per-item models) ──────────────────────

  group('base-token fallback (variant visualSetId)', () {
    test('sword_thunderfury resolves mainHand layer via base-token', () {
      final def = EquipmentVisualResolver.defFor('sword_thunderfury');
      expect(def, isNotNull, reason: 'variant should fall back to sword_t0 def');
      expect(def!.layer, CharacterLayerId.mainHand);
      expect(def.useAnchor, isTrue);
      expect(def.anchor, 'mainHand');
    });

    test('staff_frostfire resolves mainHand layer via base-token', () {
      final def = EquipmentVisualResolver.defFor('staff_frostfire');
      expect(def, isNotNull);
      expect(def!.layer, CharacterLayerId.mainHand);
    });

    test('shield_stormwall resolves offHand layer via base-token', () {
      final def = EquipmentVisualResolver.defFor('shield_stormwall');
      expect(def, isNotNull);
      expect(def!.layer, CharacterLayerId.offHand);
    });

    test('exact catalog ids still work (no regression)', () {
      final sword = EquipmentVisualResolver.defFor('sword_t0');
      expect(sword, isNotNull);
      expect(sword!.layer, CharacterLayerId.mainHand);
      final helm = EquipmentVisualResolver.defFor('helm_t2');
      expect(helm, isNotNull);
      expect(helm!.layer, CharacterLayerId.head);
    });

    test('unknown base-token returns null', () {
      expect(EquipmentVisualResolver.defFor('unicorn_legendary'), isNull);
    });
  });

  group('OwnedGearAssets variant-stem path', () {
    test('sword_thunderfury is shared set', () {
      expect(OwnedGearAssets.isSharedSet('sword_thunderfury'), isTrue);
    });

    test('sword_thunderfury pathFor returns variant-stem path', () {
      final path = OwnedGearAssets.pathFor(
        visualSetId: 'sword_thunderfury',
        family: BodyFamily.warrior,
        anim: HeroAnimKind.idle,
      );
      expect(path, 'assets/custom/char/gear/sword_thunderfury_idle.png');
    });

    test('sword_t0 pathFor unchanged (no regression)', () {
      final path = OwnedGearAssets.pathFor(
        visualSetId: 'sword_t0',
        family: BodyFamily.warrior,
        anim: HeroAnimKind.idle,
      );
      expect(path, 'assets/custom/char/gear/sword_t0_idle.png');
    });

    test('iconPathFor maps legacy named shield to shield_t0 crop', () {
      final item = EquipmentItem(
        id: 'sh',
        name: 'Test Shield',
        slot: EquipmentSlot.offHand,
        rarity: LootRarity.common,
        itemLevel: 5,
        offHandKind: OffHandKind.shield,
        visualSetId: 'shield_stormwall',
      );
      expect(
        OwnedGearAssets.iconPathFor(item),
        'assets/custom/char/gear/shield_t0_icon.png',
      );
    });

    test('iconPathFor uses cropped helm overlay for family armor', () {
      final helm = EquipmentItem(
        id: 'h',
        name: 'Helm',
        slot: EquipmentSlot.head,
        rarity: LootRarity.common,
        itemLevel: 5,
        visualSetId: 'helm_t0',
        affinity: 'warrior',
      );
      expect(
        OwnedGearAssets.iconPathFor(helm),
        'assets/custom/char/warrior/gear/helm_t0_icon.png',
      );
    });

    test('iconPathFor skips hands overlays', () {
      final gloves = EquipmentItem(
        id: 'g',
        name: 'Gloves',
        slot: EquipmentSlot.hands,
        rarity: LootRarity.common,
        itemLevel: 5,
        visualSetId: 'hands_gauntlets',
        affinity: 'warrior',
      );
      expect(OwnedGearAssets.iconPathFor(gloves), isNull);
    });

    test('staff_t0 is shared set and returns path', () {
      expect(OwnedGearAssets.isSharedSet('staff_t0'), isTrue);
      final path = OwnedGearAssets.pathFor(
        visualSetId: 'staff_t0',
        family: BodyFamily.mage,
        anim: HeroAnimKind.attack,
      );
      expect(path, 'assets/custom/char/gear/staff_t0_attack.png');
    });

    test('helm_t0 family path unchanged (no regression)', () {
      final path = OwnedGearAssets.pathFor(
        visualSetId: 'helm_t0',
        family: BodyFamily.warrior,
        anim: HeroAnimKind.idle,
      );
      expect(path, 'assets/custom/char/warrior/gear/helm_t0_idle.png');
    });
  });

  group('equipment_factory preserves visualSetId override', () {
    test('authored sword id is kept when weapon stem matches', () {
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 5,
        bias: HeroRole.warrior,
      ).copyWith(
        weaponType: WeaponType.sword,
        visualSetId: 'sword_thunderfury',
      );
      expect(EquipmentVisualResolver.resolveId(item), 'sword_thunderfury');
    });

    test('mismatched stem is coerced to weapon art', () {
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 5,
        bias: HeroRole.warrior,
      ).copyWith(
        weaponType: WeaponType.mace,
        visualSetId: 'sword_thunderfury',
      );
      expect(EquipmentVisualResolver.resolveId(item), 'mace_t0');
    });

    test('factory derives visualSetId when none is set', () {
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.common,
        battleNumber: 1,
        bias: HeroRole.warrior,
      ).copyWith(weaponType: WeaponType.sword, clearVisualSetId: true);
      expect(EquipmentVisualResolver.resolveId(item), startsWith('sword_'));
    });

    test('createEquipment stamps a model-catalog visualSetId by default', () {
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 5,
        bias: HeroRole.warrior,
      );
      final id = item.visualSetId!;
      final base = EquipmentModelCatalog.baseToken(id);
      expect(EquipmentModelCatalog.variantsFor(base), contains(id));
    });
  });

  test('shoulders and belts have no owned overlay path', () {
    final shoulder = GameLogic.createEquipment(
      slot: EquipmentSlot.shoulder,
      rarity: LootRarity.rare,
      battleNumber: 8,
      bias: HeroRole.warrior,
    );
    final belt = GameLogic.createEquipment(
      slot: EquipmentSlot.waist,
      rarity: LootRarity.uncommon,
      battleNumber: 4,
      bias: HeroRole.warrior,
    );
    expect(shoulder.visualSetId, startsWith('shoulder_'));
    expect(belt.visualSetId, startsWith('waist_'));
    expect(
      EquipmentVisualResolver.ownedAssetForItem(
        shoulder,
        family: BodyFamily.warrior,
        anim: HeroAnimKind.idle,
      ),
      isNull,
    );
    expect(
      EquipmentVisualResolver.ownedAssetForItem(
        belt,
        family: BodyFamily.warrior,
        anim: HeroAnimKind.idle,
      ),
      isNull,
    );
  });
}
