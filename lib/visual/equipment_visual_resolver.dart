import 'dart:math';

import 'package:flutter/material.dart';

import '../models/hero_spec.dart';
import '../models/loot.dart';
import 'body_family.dart';
import 'character_layer.dart';
import 'equipment_model_catalog.dart';
import 'hero_anim_state.dart';
import 'owned_gear_assets.dart';

/// Catalog entry: which layer a visual set paints on + Kenney atlas cell
/// and/or optional icon overlay path key.
class EquipmentVisualDef {
  const EquipmentVisualDef({
    required this.id,
    required this.layer,
    this.atlasCol,
    this.atlasRow,
    this.iconKey,
    this.useAnchor = false,
    this.anchor,
  });

  final String id;
  final CharacterLayerId layer;

  /// Kenney Roguelike Characters cell (when set).
  final int? atlasCol;
  final int? atlasRow;

  /// Optional [KenneyAssets]/CustomAssets icon key for overlay draws.
  final String? iconKey;

  /// When true, paint via [anchor] instead of full-body tile stack.
  final bool useAnchor;

  /// Anchor for overlays (mainHand / offHand / head).
  final String? anchor;
}

/// Resolves [EquipmentItem] → visual set id and catalog def.
abstract final class EquipmentVisualResolver {
  /// Derive a stable visual set id without requiring per-drop art.
  ///
  /// A stamped [EquipmentItem.visualSetId] wins only when its art stem matches
  /// the item's slot/type. Stale loot (e.g. a chest stamped as `helm_*`, or a
  /// thrown weapon stamped as `bow_*`) remaps so save, BAG and doll agree.
  static String resolveId(EquipmentItem item) {
    final derived = _derivedId(item);
    final vis = item.visualSetId;
    if (vis != null && vis.isNotEmpty) {
      if (derived == 'none') return derived;
      final actualStem = EquipmentModelCatalog.baseToken(vis);
      final expectedStem = EquipmentModelCatalog.baseToken(derived);
      if (actualStem == expectedStem) return vis;
      // Old saves stamped the borrowed picture (a wand that still says staff).
      final legacy = EquipmentModelCatalog.legacyArtStem(item.weaponType);
      if (legacy != null && actualStem == legacy) return vis;
      // A mismatched named hand model cannot be trusted; every shared family
      // has a guaranteed t0 asset. Armor can keep its derived t0/t2 silhouette.
      if (EquipmentModelCatalog.sharedBases.contains(expectedStem)) {
        return '${expectedStem}_t0';
      }
    }
    return derived;
  }

  static String _derivedId(EquipmentItem item) {
    final tier = item.rarity.index.clamp(0, 3);
    return switch (item.slot) {
      EquipmentSlot.weapon || EquipmentSlot.ranged =>
        _weaponId(item.weaponType, tier),
      EquipmentSlot.offHand => _offHandId(item, tier),
      EquipmentSlot.head => 'helm_t$tier',
      EquipmentSlot.chest => 'chest_t$tier',
      EquipmentSlot.cloak => 'cloak_t$tier',
      EquipmentSlot.boots || EquipmentSlot.legs => 'legs_t$tier',
      EquipmentSlot.hands || EquipmentSlot.wrist => 'hands_t$tier',
      EquipmentSlot.shoulder => 'shoulder_t$tier',
      EquipmentSlot.waist => 'waist_t$tier',
      _ => 'none',
    };
  }

  static String _weaponId(WeaponType? wt, int tier) {
    final base = EquipmentModelCatalog.weaponArtStem(wt) ?? 'sword';
    return '${base}_t$tier';
  }

  static String _offHandId(EquipmentItem item, int tier) {
    if (item.offHandKind == OffHandKind.weapon) {
      return _weaponId(item.weaponType, tier);
    }
    if (item.offHandKind == OffHandKind.frill) return 'frill_t$tier';
    return 'shield_t$tier';
  }

  /// Returns the catalog entry for [visualSetId].
  ///
  /// If [visualSetId] is not in the catalog (e.g. a named variant like
  /// `sword_thunderfury`), falls back to the base-token entry
  /// (`sword_t0`) so the layer and anchor rules are inherited
  /// automatically — only the PNG will differ.
  static EquipmentVisualDef? defFor(String visualSetId) {
    if (catalog.containsKey(visualSetId)) return catalog[visualSetId];
    // Variant model: derive layer/anchor from base weapon/item type.
    // e.g. "sword_thunderfury" → base "sword" → catalog["sword_t0"]
    final base = EquipmentModelCatalog.baseToken(visualSetId);
    return catalog['${base}_t0'];
  }

  static EquipmentVisualDef? defForItem(EquipmentItem item) =>
      defFor(resolveId(item));

  /// Readable wash for generic catalog ids. Named models (`sword_emberfang`)
  /// and t2 armor keep their authored palette — a global gold filter made
  /// every late-game doll orange.
  ///
  /// Uncommon cools t0 steel; epic/legendary warms the overlay so GEAR and
  /// dungeon can tell a green from a purple without reading the slot border.
  /// Armor t2, short, and broad cuts keep their own palette.
  static Color? rarityTint(String visualSetId, {int? rarityTier}) {
    if (EquipmentModelCatalog.authoredFamilyIds.contains(visualSetId) ||
        EquipmentModelCatalog.authoredSharedIds.contains(visualSetId)) {
      return null;
    }
    final id = OwnedGearAssets.legacyArmorCut(visualSetId);
    if (OwnedGearAssets.isArmorStyleId(id)) return null;
    final m = RegExp(r'_t(\d+)$').firstMatch(id);
    if (m == null) return null;
    if (m.group(1) == '2' && EquipmentModelCatalog.isFamilyBase(id)) {
      return null;
    }
    final t = rarityTier ?? int.parse(m.group(1)!);
    return switch (t) {
      // Common reads as pale steel; uncommon is a stronger cool wash.
      0 => const Color(0xFFD4E2F4),
      1 => const Color(0xFFB8D0F5),
      2 => null,
      3 => const Color(0xFFFFE2A8),
      _ => const Color(0xFFFFCC77),
    };
  }

  /// Curated cloth-trim dyes (Diablo-style: few colors, not a random rainbow).
  static const List<Color> clothDyes = [
    Color(0xFF4A6FA5), // steel blue
    Color(0xFF8B5A2B), // bronze brown
    Color(0xFF8B3A3A), // crimson
    Color(0xFF3D6B4F), // forest
    Color(0xFF5A4A7A), // void purple
    Color(0xFF6B5A3A), // sand
  ];

  /// Stable dye pick for chest cloth/trim. Null when no dye mask applies.
  static Color? clothDyeFor(EquipmentItem item) {
    if (item.slot != EquipmentSlot.chest && item.slot != EquipmentSlot.cloak) {
      return null;
    }
    // Skip named / empty. Cloak uses its own overlay without a dye mask yet.
    if (item.slot == EquipmentSlot.cloak) return null;
    final i = item.id.hashCode.abs() % clothDyes.length;
    return clothDyes[i];
  }

  static String? ownedAssetForItem(
    EquipmentItem item, {
    required BodyFamily family,
    required HeroAnimKind anim,
  }) => OwnedGearAssets.pathFor(
    visualSetId: resolveId(item),
    family: family,
    anim: anim,
    armorType: item.armorType,
  );

  /// BAG/GEAR slot icon: same [resolveId] as the doll, then `*_icon.png`.
  static String? ownedIconPathFor(
    EquipmentItem item, {
    BodyFamily? family,
    HeroClassId? heroClass,
  }) {
    final fam = family ?? BodyFamilyCatalog.familyForAffinity(item.affinity);
    if (item.slot == EquipmentSlot.boots) {
      final id = resolveId(item);
      final m = RegExp(r'_t(\d+)$').firstMatch(id);
      final tier = m != null ? int.parse(m.group(1)!) : 0;
      final bootTier = tier >= 2 ? 2 : 0;
      final mat = OwnedGearAssets.materialSuffix(fam, item.armorType);
      final mid = mat == null ? '' : '${mat}_';
      return '${OwnedGearAssets.root}/${fam.name}/gear/boots_${mid}t${bootTier}_icon.png';
    }
    final id = resolveId(item);
    if (id == 'none') return null;
    final stem = EquipmentModelCatalog.baseToken(id);
    if (stem == 'waist') return null;
    final idle = OwnedGearAssets.pathFor(
      visualSetId: id,
      family: fam,
      anim: HeroAnimKind.idle,
      armorType: item.armorType,
      heroClass: heroClass,
    );
    if (idle == null) return null;
    return idle.replaceFirst('_idle.png', '_icon.png');
  }

  /// Stable seed so the same item id always picks the same look.
  ///
  /// Dart does not promise [String.hashCode] stays stable across runtimes.
  static int stableSeed(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Whether [lookId]'s art stem matches [item]'s slot / weapon type.
  static bool lookMatchesItem(EquipmentItem item, String lookId) {
    final derived = _derivedId(item);
    if (derived == 'none') return false;
    return EquipmentModelCatalog.baseToken(lookId) ==
        EquipmentModelCatalog.baseToken(derived);
  }

  /// Catalog look for [item] — same rules as dungeon drops.
  static String pickLookId(EquipmentItem item, Random rng) {
    final baseId = _derivedId(item);
    if (baseId == 'none') return 'none';
    final stem = EquipmentModelCatalog.baseToken(baseId);
    if (EquipmentModelCatalog.sharedBases.contains(stem) ||
        EquipmentModelCatalog.familyBases.contains(stem)) {
      return EquipmentModelCatalog.pickVariant(
        baseId,
        rng,
        rarityTier: item.rarity.index,
      );
    }
    return OwnedGearAssets.silhouetteId(baseId);
  }

  /// Stamp a catalog look. Keeps an existing id when its stem still matches.
  static EquipmentItem stampLook(EquipmentItem item, Random rng) {
    final existing = item.visualSetId;
    if (existing != null &&
        existing.isNotEmpty &&
        lookMatchesItem(item, existing)) {
      return item;
    }
    final id = pickLookId(item, rng);
    if (id == 'none') {
      return existing == null ? item : item.copyWith(clearVisualSetId: true);
    }
    return item.copyWith(visualSetId: id);
  }

  /// Persist the same validated id used by BAG and the doll.
  ///
  /// Fills missing looks once (stable on [EquipmentItem.id]), repairs stale
  /// cross-slot ids from old saves, and clears jewelry/consumable ids.
  static EquipmentItem normalizeVisualSetId(EquipmentItem item) {
    final existing = item.visualSetId;
    if (existing == null || existing.isEmpty) {
      return stampLook(item, Random(stableSeed(item.id)));
    }
    final id = resolveId(item);
    if (id == 'none') {
      return item.copyWith(clearVisualSetId: true);
    }
    if (item.visualSetId == id) return item;
    return item.copyWith(visualSetId: id);
  }

  /// Built-in catalog (Dart v1). New items point at these ids.
  static final Map<String, EquipmentVisualDef> catalog =
      Map<String, EquipmentVisualDef>.unmodifiable({
        for (var t = 0; t <= 3; t++) ...{
          'helm_t$t': EquipmentVisualDef(
            id: 'helm_t$t',
            layer: CharacterLayerId.head,
            atlasCol: 28,
            atlasRow: t >= 2 ? 6 : 0,
          ),
          'helm_short': const EquipmentVisualDef(
            id: 'helm_short',
            layer: CharacterLayerId.head,
            atlasCol: 28,
            atlasRow: 0,
          ),
          'helm_broad': const EquipmentVisualDef(
            id: 'helm_broad',
            layer: CharacterLayerId.head,
            atlasCol: 28,
            atlasRow: 6,
          ),
          'helm_ironcrown': const EquipmentVisualDef(
            id: 'helm_ironcrown',
            layer: CharacterLayerId.head,
            atlasCol: 28,
            atlasRow: 6,
          ),
          'helm_visored': const EquipmentVisualDef(
            id: 'helm_visored',
            layer: CharacterLayerId.head,
            atlasCol: 28,
            atlasRow: 0,
          ),
          'helm_wingcrest': const EquipmentVisualDef(
            id: 'helm_wingcrest',
            layer: CharacterLayerId.head,
            atlasCol: 28,
            atlasRow: 6,
          ),
          'shoulder_short': const EquipmentVisualDef(
            id: 'shoulder_short',
            layer: CharacterLayerId.shoulders,
            atlasCol: 10,
            atlasRow: 2,
          ),
          'shoulder_broad': const EquipmentVisualDef(
            id: 'shoulder_broad',
            layer: CharacterLayerId.shoulders,
            atlasCol: 10,
            atlasRow: 4,
          ),
          'chest_t$t': EquipmentVisualDef(
            id: 'chest_t$t',
            layer: CharacterLayerId.torso,
            atlasCol: t >= 2 ? 10 : 6,
            atlasRow: t >= 2 ? 5 : t.clamp(0, 4),
          ),
          'cloak_t$t': EquipmentVisualDef(
            id: 'cloak_t$t',
            layer: CharacterLayerId.cape,
            atlasCol: t >= 2 ? 10 : 6,
            atlasRow: t >= 2 ? 5 : t.clamp(0, 4),
          ),
          'legs_t$t': EquipmentVisualDef(
            id: 'legs_t$t',
            layer: CharacterLayerId.legs,
            atlasCol: 3,
            atlasRow: switch (t) {
              0 => 1,
              1 => 2,
              2 => 3,
              _ => 0,
            },
          ),
          'hands_t$t': EquipmentVisualDef(
            id: 'hands_t$t',
            layer: CharacterLayerId.gloves,
            atlasCol: 6,
            atlasRow: t.clamp(0, 4),
          ),
          'shoulder_t$t': EquipmentVisualDef(
            id: 'shoulder_t$t',
            layer: CharacterLayerId.shoulders,
            atlasCol: 10,
            atlasRow: t.clamp(0, 4),
          ),
          'waist_t$t': EquipmentVisualDef(
            id: 'waist_t$t',
            layer: CharacterLayerId.legs,
            atlasCol: 3,
            atlasRow: 2,
          ),
          'shield_t$t': EquipmentVisualDef(
            id: 'shield_t$t',
            layer: CharacterLayerId.offHand,
            // Prefer readable round/kite shields — avoid patterned tiles that
            // read as checker noise when scaled onto denser bodies.
            atlasCol: switch (t) {
              0 => 33,
              1 => 37,
              2 => 37,
              _ => 39,
            },
            atlasRow: switch (t) {
              0 => 1,
              1 => 1,
              2 => 1,
              _ => 7,
            },
            useAnchor: true,
            anchor: 'offHand',
          ),
          'frill_t$t': EquipmentVisualDef(
            id: 'frill_t$t',
            layer: CharacterLayerId.offHand,
            atlasCol: 42,
            atlasRow: 0,
            useAnchor: true,
            anchor: 'offHand',
          ),
          'sword_t$t': EquipmentVisualDef(
            id: 'sword_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: switch (t) {
              0 => 42,
              1 => 44,
              2 => 46,
              _ => 47,
            },
            atlasRow: 4,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'sword',
          ),
          'staff_t$t': EquipmentVisualDef(
            id: 'staff_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: switch (t) {
              0 => 42,
              1 => 44,
              2 => 46,
              _ => 47,
            },
            atlasRow: 0,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'staff',
          ),
          'dagger_t$t': EquipmentVisualDef(
            id: 'dagger_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 48 + t.clamp(0, 3),
            atlasRow: 0,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'dagger',
          ),
          'mace_t$t': EquipmentVisualDef(
            id: 'mace_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 50 + t.clamp(0, 3),
            atlasRow: 4,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'mace',
          ),
          'axe_t$t': EquipmentVisualDef(
            id: 'axe_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 48 + t.clamp(0, 3),
            atlasRow: 4,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'axe',
          ),
          'wand_t$t': EquipmentVisualDef(
            id: 'wand_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 42,
            atlasRow: 0,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'staff',
          ),
          'gun_t$t': EquipmentVisualDef(
            id: 'gun_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 54,
            atlasRow: 0,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'bow',
          ),
          'crossbow_t$t': EquipmentVisualDef(
            id: 'crossbow_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 54,
            atlasRow: 4,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'bow',
          ),
          'polearm_t$t': EquipmentVisualDef(
            id: 'polearm_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 48,
            atlasRow: 4,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'axe',
          ),
          'fist_t$t': EquipmentVisualDef(
            id: 'fist_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 48,
            atlasRow: 0,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'dagger',
          ),
          'thrown_t$t': EquipmentVisualDef(
            id: 'thrown_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: 48,
            atlasRow: 0,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'dagger',
          ),
          'bow_t$t': EquipmentVisualDef(
            id: 'bow_t$t',
            layer: CharacterLayerId.mainHand,
            atlasCol: t >= 2 ? 54 : 54 + (t % 2),
            atlasRow: t >= 2 ? 4 : 0,
            useAnchor: true,
            anchor: 'mainHand',
            iconKey: 'bow',
          ),
        },
      });
}
