import 'dart:math';

import '../models/loot.dart';

/// Named visual models per base item type (WoW-style display ids).
///
/// Base token = first segment of [visualSetId] (`sword_thunderfury` → `sword`).
/// Catalog ids (`sword_t0`) stay as the default / common silhouette.
///
/// Armor: only family `*_t0` / `*_t2` extracts (rarity tint for variety).
/// Weapons: `*_t0` plus a few authored models — no ImageDraw mass variants.
abstract final class EquipmentModelCatalog {
  /// Shared weapons / off-hands under `assets/custom/char/gear/`.
  static const List<String> sharedBases = [
    'sword',
    'staff',
    'dagger',
    'mace',
    'axe',
    'bow',
    'shield',
    'frill',
  ];

  /// Family armor under `assets/custom/char/<family>/gear/`.
  static const List<String> familyBases = [
    'helm',
    'chest',
    'legs',
    'cloak',
    'hands',
  ];

  /// Authored weapon models kept in the loot pool (plus each base `*_t0`).
  static const Set<String> authoredSharedIds = {
    'sword_thunderfury',
    'sword_warglaive',
  };

  static const Map<String, List<String>> variants = {
    'sword': ['sword_t0', 'sword_thunderfury', 'sword_warglaive'],
    'staff': ['staff_t0'],
    'dagger': ['dagger_t0'],
    'mace': ['mace_t0'],
    'axe': ['axe_t0'],
    'bow': ['bow_t0'],
    'shield': ['shield_t0'],
    'frill': ['frill_t0'],
    'helm': ['helm_t0', 'helm_t2'],
    'chest': ['chest_t0', 'chest_t2'],
    'legs': ['legs_t0', 'legs_t2'],
    'cloak': ['cloak_t0', 'cloak_t2'],
    'hands': ['hands_t0'],
  };

  /// Art stem for a weapon type (loot + paint must agree).
  static String? weaponArtStem(WeaponType? wt) => switch (wt) {
    WeaponType.staff || WeaponType.wand => 'staff',
    WeaponType.dagger || WeaponType.fist => 'dagger',
    WeaponType.mace => 'mace',
    WeaponType.axe || WeaponType.polearm => 'axe',
    WeaponType.bow || WeaponType.crossbow || WeaponType.gun => 'bow',
    WeaponType.thrown => 'dagger',
    WeaponType.sword => 'sword',
    null => null,
  };

  static String baseToken(String visualSetId) {
    final m = RegExp(r'^(.+)_t\d+$').firstMatch(visualSetId);
    if (m != null) return m.group(1)!;
    return visualSetId.split('_').first;
  }

  static List<String> variantsFor(String baseOrId) {
    final base = baseToken(baseOrId);
    return variants[base] ?? const <String>[];
  }

  /// Whether [base] is family armor (extract tiers only — no named loot models).
  static bool isFamilyBase(String baseOrId) =>
      familyBases.contains(baseToken(baseOrId));

  /// Pick a model for loot. [resolvedBaseId] is e.g. `sword_t2` / `helm_t0`.
  ///
  /// Armor always stays on the resolved tier silhouette. Shared weapons pick
  /// from the short authored pool (`*_t0` + thunderfury / warglaive).
  static String pickVariant(
    String resolvedBaseId,
    Random rng, {
    int rarityTier = 0,
  }) {
    final base = baseToken(resolvedBaseId);
    if (isFamilyBase(base)) {
      return resolvedBaseId;
    }
    final list = variantsFor(resolvedBaseId);
    if (list.isEmpty) return resolvedBaseId;
    if (list.length == 1) return list.first;

    if (rarityTier >= 2 && rng.nextDouble() < 0.45) {
      final authored = list.where((id) => id != '${base}_t0').toList();
      if (authored.isNotEmpty) {
        return authored[rng.nextInt(authored.length)];
      }
    }
    return list[rng.nextInt(list.length)];
  }

  static Iterable<String> get allSharedVariantIds sync* {
    for (final base in sharedBases) {
      yield* variants[base] ?? const <String>[];
    }
  }

  /// Precache / catalog: only extract tiers, not legacy generated names.
  static Iterable<String> get allFamilyVariantIds sync* {
    for (final base in familyBases) {
      yield* variants[base] ?? const <String>[];
    }
  }
}
