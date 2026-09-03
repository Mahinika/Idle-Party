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
    final m = RegExp(r'^(.+)_t(\d+)$').firstMatch(visualSetId);
    if (m == null) return visualSetId;
    final stem = m.group(1)!;
    final t = int.parse(m.group(2)!);
    if (stem == 'chest' || stem == 'legs' || stem == 'helm' || stem == 'cloak') {
      return t >= 2 ? '${stem}_t2' : '${stem}_t0';
    }
    return '${stem}_t0';
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
  }) {
    if (visualSetId.isEmpty || visualSetId == 'none') return null;
    final stem = visualSetId.split('_').first;
    // Shoulders / belt fold into chest+legs art — no extra owned PNG.
    if (stem == 'shoulder' || stem == 'waist') return null;
    final a = animFile(anim);
    final fileStem = shippedFileStem(visualSetId);
    if (isSharedSet(visualSetId)) {
      return sharedGear(fileStem, a);
    }
    return familyGear(family, fileStem, a);
  }

  /// Precache list (idle/walk/attack × extract tiers + authored weapons only).
  static List<String> get allAssetPaths {
    final out = <String>{};
    for (final family in BodyFamily.values) {
      for (final id in kFamilySetIds) {
        for (final anim in kAnims) {
          out.add(familyGear(family, id, anim));
        }
      }
    }
    for (final id in kSharedSetIds) {
      for (final anim in kAnims) {
        out.add(sharedGear(id, anim));
      }
    }
    for (final id in EquipmentModelCatalog.authoredSharedIds) {
      for (final anim in kAnims) {
        out.add(sharedGear(id, anim));
      }
    }
    return out.toList(growable: false);
  }

  /// If [path] is missing, try the idle clip of the same set.
  static String idleFallback(String path) =>
      path.replaceFirst(RegExp(r'_(walk|attack)\.png$'), '_idle.png');

  /// Tight 64×64 crop (`*_icon.png`) of the same overlay the doll uses.
  /// Hands / jewelry / flask / folded slots stay Kenney.
  static String? iconPathFor(EquipmentItem item, {BodyFamily? family}) {
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
    if (stem == 'hands' || stem == 'shoulder' || stem == 'waist') return null;
    final fam = family ?? BodyFamilyCatalog.familyForAffinity(item.affinity);
    final idle = pathFor(
      visualSetId: id,
      family: fam,
      anim: HeroAnimKind.idle,
    );
    if (idle == null) return null;
    return idle.replaceFirst('_idle.png', '_icon.png');
  }
}
