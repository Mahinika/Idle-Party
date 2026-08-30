import '../models/loot.dart';
import 'character_layer.dart';

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
  static String resolveId(EquipmentItem item) {
    if (item.visualSetId != null && item.visualSetId!.isNotEmpty) {
      return item.visualSetId!;
    }
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
    final base = switch (wt) {
      WeaponType.staff || WeaponType.wand => 'staff',
      WeaponType.dagger || WeaponType.fist => 'dagger',
      WeaponType.mace => 'mace',
      WeaponType.axe || WeaponType.polearm => 'axe',
      WeaponType.bow ||
      WeaponType.crossbow ||
      WeaponType.gun ||
      WeaponType.thrown => 'bow',
      _ => 'sword',
    };
    return '${base}_t$tier';
  }

  static String _offHandId(EquipmentItem item, int tier) {
    if (item.offHandKind == OffHandKind.weapon) {
      return _weaponId(item.weaponType, tier);
    }
    if (item.offHandKind == OffHandKind.frill) return 'frill_t$tier';
    return 'shield_t$tier';
  }

  static EquipmentVisualDef? defFor(String visualSetId) =>
      catalog[visualSetId];

  static EquipmentVisualDef? defForItem(EquipmentItem item) =>
      defFor(resolveId(item));

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
          'chest_t$t': EquipmentVisualDef(
            id: 'chest_t$t',
            layer: CharacterLayerId.torso,
            atlasCol: t >= 2 ? 10 : 6,
            atlasRow: t >= 2 ? 5 : t.clamp(0, 4),
          ),
          'cloak_t$t': EquipmentVisualDef(
            id: 'cloak_t$t',
            layer: CharacterLayerId.torso,
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
            layer: CharacterLayerId.torso,
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
            atlasCol: switch (t) {
              0 => 33,
              1 => 37,
              2 => 37,
              _ => 39,
            },
            atlasRow: switch (t) {
              0 => 1,
              1 => 1,
              2 => 5,
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
