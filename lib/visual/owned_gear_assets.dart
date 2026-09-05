import '../models/loot.dart';
import 'body_family.dart';
import 'equipment_model_catalog.dart';
import 'hero_anim_state.dart';

/// Owned 128×128 paper-doll overlay paths (`assets/custom/char/`).
///
/// Family armor lives under `<family>/gear/`. Weapons and shields are shared
/// under `char/gear/` so every body holds the same sword.
abstract final class OwnedGearAssets {
  static const String root = 'assets/custom/char';

  static const List<String> kAnims = ['idle', 'walk', 'attack'];

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

  /// Rogue mail overlays (derived from leather extracts).
  static const List<String> kRogueMailSetIds = [
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

  /// Healer plate overlays (derived from cloth extracts — Holy Pala etc.).
  static const List<String> kHealerPlateSetIds = [
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

  static String animFile(HeroAnimKind kind) => switch (kind) {
    HeroAnimKind.walk || HeroAnimKind.hit => 'walk',
    HeroAnimKind.attack || HeroAnimKind.cast => 'attack',
    _ => 'idle',
  };

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
    return switch (family) {
      BodyFamily.rogue when armorType == ArmorType.mail => 'mail',
      BodyFamily.healer when armorType == ArmorType.plate => 'plate',
      _ => null,
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
    final a = animFile(anim);
    var fileStem = shippedFileStem(visualSetId);
    if (isSharedSet(visualSetId)) {
      return sharedGear(fileStem, a);
    }
    fileStem = materialFileStem(
      fileStem,
      family: family,
      armorType: armorType,
    );
    return familyGear(family, fileStem, a);
  }

  /// Precache list: overlays + BAG `*_icon` crops (boots icons included).
  static List<String> get allAssetPaths {
    final out = <String>{};
    for (final family in BodyFamily.values) {
      for (final id in kFamilySetIds) {
        for (final anim in kAnims) {
          out.add(familyGear(family, id, anim));
        }
        out.add(familyGear(family, id, 'idle').replaceFirst('_idle.png', '_icon.png'));
      }
      out.add('$root/${family.name}/gear/boots_t0_icon.png');
      out.add('$root/${family.name}/gear/boots_t2_icon.png');
    }
    for (final id in kRogueMailSetIds) {
      for (final anim in kAnims) {
        out.add(familyGear(BodyFamily.rogue, id, anim));
      }
      out.add(
        familyGear(BodyFamily.rogue, id, 'idle').replaceFirst('_idle.png', '_icon.png'),
      );
    }
    out.add('$root/rogue/gear/boots_mail_t0_icon.png');
    out.add('$root/rogue/gear/boots_mail_t2_icon.png');
    for (final id in kHealerPlateSetIds) {
      for (final anim in kAnims) {
        out.add(familyGear(BodyFamily.healer, id, anim));
      }
      out.add(
        familyGear(
          BodyFamily.healer,
          id,
          'idle',
        ).replaceFirst('_idle.png', '_icon.png'),
      );
    }
    out.add('$root/healer/gear/boots_plate_t0_icon.png');
    out.add('$root/healer/gear/boots_plate_t2_icon.png');
    for (final id in kSharedSetIds) {
      for (final anim in kAnims) {
        out.add(sharedGear(id, anim));
      }
      out.add(sharedGear(id, 'idle').replaceFirst('_idle.png', '_icon.png'));
    }
    for (final id in EquipmentModelCatalog.authoredSharedIds) {
      for (final anim in kAnims) {
        out.add(sharedGear(id, anim));
      }
      out.add(sharedGear(id, 'idle').replaceFirst('_idle.png', '_icon.png'));
    }
    return out.toList(growable: false);
  }

  /// If [path] is missing, try the idle clip of the same set.
  static String idleFallback(String path) =>
      path.replaceFirst(RegExp(r'_(walk|attack)\.png$'), '_idle.png');

  /// Tight 64×64 crop (`*_icon.png`) of the same overlay the doll uses.
  /// Jewelry / flask / shoulder / waist stay Kenney. Boots use a foot-band crop.
  ///
  /// Prefer [EquipmentVisualResolver.ownedIconPathFor] from UI — it stamps
  /// missing [visualSetId] the same way the doll does.
  static String? iconPathFor(EquipmentItem item, {BodyFamily? family}) {
    final fam = family ?? BodyFamilyCatalog.familyForAffinity(item.affinity);
    if (item.slot == EquipmentSlot.boots) {
      final id = item.visualSetId;
      final tier = () {
        if (id == null || id.isEmpty) return 0;
        final m = RegExp(r'_t(\d+)$').firstMatch(id);
        if (m != null) return int.parse(m.group(1)!);
        if (id.startsWith('legs_t')) {
          return int.tryParse(id.substring('legs_t'.length)) ?? 0;
        }
        return 0;
      }();
      final bootTier = tier >= 2 ? 2 : 0;
      final mat = materialSuffix(fam, item.armorType);
      final mid = mat == null ? '' : '${mat}_';
      return '$root/${fam.name}/gear/boots_${mid}t${bootTier}_icon.png';
    }
    var id = item.visualSetId;
    if (id == null || id.isEmpty || id == 'none') {
      final stem = EquipmentModelCatalog.weaponArtStem(item.weaponType);
      if (stem == null) return null;
      if (item.slot != EquipmentSlot.weapon &&
          item.slot != EquipmentSlot.ranged &&
          !(item.slot == EquipmentSlot.offHand &&
              item.offHandKind == OffHandKind.weapon)) {
        return null;
      }
      id = '${stem}_t0';
    } else {
      final expected = EquipmentModelCatalog.weaponArtStem(item.weaponType);
      if (expected != null &&
          (item.slot == EquipmentSlot.weapon ||
              item.slot == EquipmentSlot.ranged ||
              (item.slot == EquipmentSlot.offHand &&
                  item.offHandKind == OffHandKind.weapon)) &&
          EquipmentModelCatalog.baseToken(id) != expected) {
        id = '${expected}_t0';
      }
    }
    final stem = EquipmentModelCatalog.baseToken(id);
    if (stem == 'shoulder' || stem == 'waist') return null;
    final idle = pathFor(
      visualSetId: id,
      family: fam,
      anim: HeroAnimKind.idle,
      armorType: item.armorType,
    );
    if (idle == null) return null;
    return idle.replaceFirst('_idle.png', '_icon.png');
  }
}
