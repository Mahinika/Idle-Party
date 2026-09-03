import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/hero.dart';
import 'package:idle_party/models/loot.dart';
import 'package:idle_party/visual/body_family.dart';
import 'package:idle_party/visual/character_layer.dart';
import 'package:idle_party/visual/equipment_visual_resolver.dart';
import 'package:idle_party/visual/hero_anim_state.dart';
import 'package:idle_party/visual/owned_gear_assets.dart';

void main() {
  test('factory stamps visualSetId', () {
    final sword = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.rare,
      battleNumber: 5,
      bias: HeroRole.warrior,
    );
    expect(sword.visualSetId, isNotNull);
    expect(
      EquipmentVisualResolver.catalog.containsKey(sword.visualSetId),
      isTrue,
    );
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
    );
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

    test('staff_frostfire is shared set and returns variant path', () {
      expect(OwnedGearAssets.isSharedSet('staff_frostfire'), isTrue);
      final path = OwnedGearAssets.pathFor(
        visualSetId: 'staff_frostfire',
        family: BodyFamily.mage,
        anim: HeroAnimKind.attack,
      );
      expect(path, 'assets/custom/char/gear/staff_frostfire_attack.png');
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
    test('factory does not overwrite pre-set visualSetId', () {
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 5,
        bias: HeroRole.warrior,
      ).copyWith(visualSetId: 'sword_thunderfury');
      // resolveId should preserve the override
      expect(EquipmentVisualResolver.resolveId(item), 'sword_thunderfury');
    });

    test('factory derives visualSetId when none is set', () {
      // Create a weapon with explicit weaponType=sword and cleared visualSetId.
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.common,
        battleNumber: 1,
        bias: HeroRole.warrior,
      ).copyWith(weaponType: WeaponType.sword, clearVisualSetId: true);
      // resolveId from slot+weaponType should give sword_t*
      expect(EquipmentVisualResolver.resolveId(item), startsWith('sword_'));
    });

    test('createEquipment stamps a catalog-valid visualSetId by default', () {
      final item = GameLogic.createEquipment(
        slot: EquipmentSlot.weapon,
        rarity: LootRarity.rare,
        battleNumber: 5,
        bias: HeroRole.warrior,
      );
      // Default stamp stays a catalog id (not a variant)
      expect(EquipmentVisualResolver.catalog.containsKey(item.visualSetId), isTrue);
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
