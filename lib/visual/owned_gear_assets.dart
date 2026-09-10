import '../models/loot.dart';
import 'body_family.dart';
import 'equipment_model_catalog.dart';
import 'hero_anim_state.dart';

/// Owned 128×128 paper-doll overlay paths (`assets/custom/char/`).
///
/// Family armor lives under `<family>/gear/`. Weapons and shields are shared
/// under `char/gear/` so every body holds the same sword.
///
/// **Model:** undertunic bodies have idle/walk/attack clips
/// ([BodyFamilyCatalog]). Equipped overlays always resolve to `*_idle.png`
/// — dungeon walk/attack poses the body only; grip anchors swing weapons.
abstract final class OwnedGearAssets {
  static const String root = 'assets/custom/char';

  /// Shipped overlay clips (idle only). Body clips live on [BodyFamilyCatalog].
  static const List<String> kOverlayAnims = ['idle'];

  /// Family-aligned armor silhouettes we ship (rarity tints in paint).
  /// Tier silhouettes stay for old saves; named models come from the catalog.
  static const List<String> kFamilySetIds = [
    'helm_t0',
    'helm_t2',
    'chest_t0',
    'chest_t2',
    'legs_t0',
    'legs_t2',
    'cloak_t0',
    'cloak_t2',
    'hands_t0',
    'hands_t2',
  ];

  /// Mail overlay stems (rogue / mage / healer mail wearers).
  static const List<String> kMailArmorSetIds = [
    'helm_mail_t0',
    'helm_mail_t2',
    'chest_mail_t0',
    'chest_mail_t2',
    'legs_mail_t0',
    'legs_mail_t2',
    'cloak_mail_t0',
    'cloak_mail_t2',
    'hands_mail_t0',
    'hands_mail_t2',
  ];

  /// Plate overlay stems (healer holy).
  static const List<String> kPlateArmorSetIds = [
    'helm_plate_t0',
    'helm_plate_t2',
    'chest_plate_t0',
    'chest_plate_t2',
    'legs_plate_t0',
    'legs_plate_t2',
    'cloak_plate_t0',
    'cloak_plate_t2',
    'hands_plate_t0',
    'hands_plate_t2',
  ];

  /// Leather overlay stems (druid on non-rogue bodies).
  static const List<String> kLeatherArmorSetIds = [
    'helm_leather_t0',
    'helm_leather_t2',
    'chest_leather_t0',
    'chest_leather_t2',
    'legs_leather_t0',
    'legs_leather_t2',
    'cloak_leather_t0',
    'cloak_leather_t2',
    'hands_leather_t0',
    'hands_leather_t2',
  ];

  /// Rogue mail overlays (hunter / enhancement shaman).
  static const List<String> kRogueMailSetIds = kMailArmorSetIds;

  /// Healer plate overlays (Holy Paladin).
  static const List<String> kHealerPlateSetIds = kPlateArmorSetIds;

  /// Mage mail overlays (Elemental Shaman).
  static const List<String> kMageMailSetIds = kMailArmorSetIds;

  /// Healer mail overlays (Resto Shaman).
  static const List<String> kHealerMailSetIds = kMailArmorSetIds;

  /// Druid leather on non-rogue bodies.
  static const List<String> kMageLeatherSetIds = kLeatherArmorSetIds;
  static const List<String> kWarriorLeatherSetIds = kLeatherArmorSetIds;
  static const List<String> kHealerLeatherSetIds = kLeatherArmorSetIds;

  /// Shared hand items (one art + rarity tint).
  static const List<String> kSharedSetIds = [
    'sword_t0',
    'staff_t0',
    'dagger_t0',
    'mace_t0',
    'axe_t0',
    'bow_t0',
    'shield_t0',
    'frill_t0',
  ];

  static const Set<String> _sharedStems = {
    'sword',
    'staff',
    'dagger',
    'mace',
    'axe',
    'bow',
    'shield',
    'frill',
  };

  static bool isCatalogTierId(String visualSetId) =>
      RegExp(r'^(.+)_t\d+$').hasMatch(visualSetId);

  static String familyGear(BodyFamily family, String setId, String anim) =>
      '$root/${family.name}/gear/${setId}_$anim.png';

  static String sharedGear(String setId, String anim) =>
      '$root/gear/${setId}_$anim.png';

  /// Map any catalog id onto a shipped PNG id (t0/t2 silhouettes).
  static String silhouetteId(String visualSetId) {
    // Material forms: chest_mail_t0 / helm_plate_t2
    final mat = RegExp(
      r'^(helm|chest|legs|cloak|hands)_(mail|plate)_t(\d+)$',
    ).firstMatch(visualSetId);
    if (mat != null) {
      final slot = mat.group(1)!;
      final material = mat.group(2)!;
      final t = int.parse(mat.group(3)!);
      return t >= 2 ? '${slot}_${material}_t2' : '${slot}_${material}_t0';
    }
    final m = RegExp(r'^(.+)_t(\d+)$').firstMatch(visualSetId);
    if (m == null) return visualSetId;
    final stem = m.group(1)!;
    final t = int.parse(m.group(2)!);
    if (stem == 'chest' ||
        stem == 'legs' ||
        stem == 'helm' ||
        stem == 'cloak' ||
        stem == 'hands') {
      return t >= 2 ? '${stem}_t2' : '${stem}_t0';
    }
    return '${stem}_t0';
  }

  /// Non-native material folder stem for [family] + [armorType], else null.
  ///
  /// Native looks keep unprefixed `chest_t0` files (zero churn). Cross-material
  /// (rogue mail, healer plate) uses derived `*_mail_*` / `*_plate_*` PNGs.
  static String? materialSuffix(BodyFamily family, ArmorType? armorType) {
    if (armorType == null) return null;
    final native = switch (family) {
      BodyFamily.warrior => ArmorType.plate,
      BodyFamily.rogue => ArmorType.leather,
      BodyFamily.mage || BodyFamily.healer => ArmorType.cloth,
    };
    if (armorType == native) return null;
    return switch (armorType) {
      ArmorType.mail => 'mail',
      ArmorType.plate => 'plate',
      ArmorType.leather => 'leather',
      ArmorType.cloth => null,
    };
  }

  /// Apply material suffix to a native silhouette id (`chest_t0` → `chest_mail_t0`).
  static String materialFileStem(
    String silhouetteId, {
    required BodyFamily family,
    ArmorType? armorType,
  }) {
    final suffix = materialSuffix(family, armorType);
    if (suffix == null) return silhouetteId;
    final m = RegExp(
      r'^(helm|chest|legs|cloak|hands)_t([02])$',
    ).firstMatch(silhouetteId);
    if (m == null) return silhouetteId;
    return '${m.group(1)!}_${suffix}_t${m.group(2)!}';
  }

  /// Whether [visualSetId] belongs to the shared (non-family) weapon/shield
  /// set. Works for both catalog ids (`sword_t0`) and named variants
  /// (`sword_thunderfury`) by extracting the base token before `_`.
  static bool isSharedSet(String visualSetId) {
    // Classic catalog form: sword_t0, staff_t2, etc.
    final catalogMatch = RegExp(r'^(.+)_t\d+$').firstMatch(visualSetId);
    if (catalogMatch != null) {
      return _sharedStems.contains(catalogMatch.group(1));
    }
    // Named variant form: sword_thunderfury, staff_frostfire, etc.
    // The base token is everything before the first underscore.
    final base = visualSetId.split('_').first;
    return _sharedStems.contains(base);
  }

  /// PNG stem on disk: extract tiers, authored weapons, or `{base}_t0` for
  /// legacy generated names (old saves may still hold `shield_stormwall`).
  static String shippedFileStem(String visualSetId) {
    if (isCatalogTierId(visualSetId)) return silhouetteId(visualSetId);
    if (EquipmentModelCatalog.authoredSharedIds.contains(visualSetId)) {
      return visualSetId;
    }
    final base = EquipmentModelCatalog.baseToken(visualSetId);
    if (_sharedStems.contains(base) ||
        EquipmentModelCatalog.familyBases.contains(base)) {
      return '${base}_t0';
    }
    return visualSetId;
  }

  /// Overlay path for [visualSetId]. Always `*_idle.png` — [anim] is kept for
  /// call-site symmetry with body clips but does not change the PNG stem.
  static String? pathFor({
    required String visualSetId,
    required BodyFamily family,
    required HeroAnimKind anim,
    ArmorType? armorType,
  }) {
    if (visualSetId.isEmpty || visualSetId == 'none') return null;
    final stem = visualSetId.split('_').first;
    // Shoulders / belt fold into chest+legs art — no extra owned PNG.
    if (stem == 'shoulder' || stem == 'waist') return null;
    // Ignore [anim]: walk/attack only change BodyFamilyCatalog body clips.
    const overlayAnim = 'idle';
    var fileStem = shippedFileStem(visualSetId);
    if (isSharedSet(visualSetId)) {
      return sharedGear(fileStem, overlayAnim);
    }
    fileStem = materialFileStem(
      fileStem,
      family: family,
      armorType: armorType,
    );
    return familyGear(family, fileStem, overlayAnim);
  }

  /// Overlays the doll actually paints (no BAG `*_icon` crops).
  ///
  /// The dungeon precaches this — [allAssetPaths] would also decode ~97 icon
  /// textures that only GEAR/BAG ever draw.
  static List<String> get dollOverlayPaths => [
    for (final path in allAssetPaths)
      if (path.endsWith('_idle.png')) path,
  ];

  /// Every owned overlay + BAG `*_icon` crop (boots icons included).
  ///
  /// Bodies precache via [BodyFamilyCatalog.allAssetPaths]. Walk/attack use
  /// the same idle gear overlays on poser body clips.
  static List<String> get allAssetPaths {
    final out = <String>{};
    for (final family in BodyFamily.values) {
      for (final id in kFamilySetIds) {
        out.add(familyGear(family, id, 'idle'));
        out.add(familyGear(family, id, 'idle').replaceFirst('_idle.png', '_icon.png'));
      }
      out.add('$root/${family.name}/gear/boots_t0_icon.png');
      out.add('$root/${family.name}/gear/boots_t2_icon.png');
    }
    void addMaterialSet(BodyFamily family, List<String> ids, String bootMat) {
      for (final id in ids) {
        out.add(familyGear(family, id, 'idle'));
        out.add(
          familyGear(family, id, 'idle').replaceFirst('_idle.png', '_icon.png'),
        );
      }
      out.add('$root/${family.name}/gear/boots_${bootMat}_t0_icon.png');
      out.add('$root/${family.name}/gear/boots_${bootMat}_t2_icon.png');
    }

    addMaterialSet(BodyFamily.rogue, kRogueMailSetIds, 'mail');
    addMaterialSet(BodyFamily.healer, kHealerPlateSetIds, 'plate');
    addMaterialSet(BodyFamily.mage, kMageMailSetIds, 'mail');
    addMaterialSet(BodyFamily.healer, kHealerMailSetIds, 'mail');
    addMaterialSet(BodyFamily.mage, kMageLeatherSetIds, 'leather');
    addMaterialSet(BodyFamily.warrior, kWarriorLeatherSetIds, 'leather');
    addMaterialSet(BodyFamily.healer, kHealerLeatherSetIds, 'leather');
    for (final id in kSharedSetIds) {
      out.add(sharedGear(id, 'idle'));
      out.add(sharedGear(id, 'idle').replaceFirst('_idle.png', '_icon.png'));
    }
    for (final id in EquipmentModelCatalog.authoredSharedIds) {
      out.add(sharedGear(id, 'idle'));
      out.add(sharedGear(id, 'idle').replaceFirst('_idle.png', '_icon.png'));
    }
    return out.toList(growable: false);
  }

  /// If [path] is missing, try the idle clip of the same set.
  static String idleFallback(String path) =>
      path.replaceFirst(RegExp(r'_(walk|attack)\.png$'), '_idle.png');
}
