import '../models/hero_spec.dart';
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

  /// Apply material suffix to a native cut (`chest_t0` → `chest_mail_t0`,
  /// `chest_short` → `chest_mail_short`).
  static String materialFileStem(
    String silhouetteId, {
    required BodyFamily family,
    ArmorType? armorType,
  }) {
    final suffix = materialSuffix(family, armorType);
    if (suffix == null) return silhouetteId;
    final m = armorCutPattern.firstMatch(silhouetteId);
    if (m != null) return '${m.group(1)!}_${suffix}_${m.group(2)!}';
    return silhouetteId;
  }

  /// Classes with their own helm and chest look on a shared body.
  static const Map<HeroClassId, String> kClassMarks = {
    HeroClassId.paladin: 'paladin',
    HeroClassId.deathKnight: 'deathknight',
    HeroClassId.warlock: 'warlock',
  };

  static const List<String> kClassMarkSlots = ['helm', 'chest'];

  /// `helm_t0` → `helm_paladin_t0` when that class shares the body. Native
  /// cuts only — mail, plate, and leather keep their material piece.
  static String? classFileStem(
    String silhouetteId, {
    required BodyFamily family,
    HeroClassId? heroClass,
  }) {
    if (heroClass == null) return null;
    final onFamily = switch (heroClass) {
      HeroClassId.paladin || HeroClassId.deathKnight =>
        family == BodyFamily.warrior,
      HeroClassId.warlock => family == BodyFamily.mage,
      _ => false,
    };
    final mark = kClassMarks[heroClass];
    if (!onFamily || mark == null) return null;
    final m = armorCutPattern.firstMatch(silhouetteId);
    if (m == null || !kClassMarkSlots.contains(m.group(1))) return null;
    return '${m.group(1)!}_${mark}_${m.group(2)!}';
  }

  /// Plain (t0), late (t2), and the two authored styles every armor slot has.
  static const List<String> kArmorCuts = ['t0', 't2', 'short', 'broad'];

  static const List<String> kArmorSlots = [
    'helm',
    'chest',
    'legs',
    'cloak',
    'hands',
  ];

  static final RegExp armorCutPattern = RegExp(
    r'^(helm|chest|legs|cloak|hands)_(t0|t2|short|broad)$',
  );

  static final RegExp _legacyCutPattern = RegExp(
    r'^(helm|chest|legs|cloak|hands)_(?:v(\d{2})|(wide|slim))$',
  );

  /// Short or broad — authored styles that keep their own palette.
  static bool isArmorStyleId(String visualSetId) {
    final m = armorCutPattern.firstMatch(legacyArmorCut(visualSetId));
    return m != null && (m.group(2) == 'short' || m.group(2) == 'broad');
  }

  /// Old saves stamped twenty `vNN` cuts or `wide`/`slim`. Spread them over
  /// the four cuts so a bag of old loot still looks varied.
  static String legacyArmorCut(String visualSetId) {
    final m = _legacyCutPattern.firstMatch(visualSetId);
    if (m == null) return visualSetId;
    final slot = m.group(1)!;
    final shape = m.group(3);
    if (shape != null) return shape == 'wide' ? '${slot}_broad' : '${slot}_short';
    final n = int.parse(m.group(2)!);
    return '${slot}_${kArmorCuts[(n ~/ 5).clamp(0, 3)]}';
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

  /// PNG stem on disk: extract tiers, authored styles, authored weapons, or
  /// `{base}_t0` for legacy generated names (old saves may still hold
  /// `shield_stormwall`).
  static String shippedFileStem(String visualSetId) {
    final cut = legacyArmorCut(visualSetId);
    if (armorCutPattern.hasMatch(cut)) return cut;
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
    HeroClassId? heroClass,
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
    final classStem = classFileStem(
      fileStem,
      family: family,
      heroClass: heroClass,
    );
    return familyGear(family, classStem ?? fileStem, overlayAnim);
  }

  /// Overlays the doll actually paints (no BAG `*_icon` crops).
  ///
  /// The dungeon precaches this — [allAssetPaths] would also decode the icon
  /// textures that only GEAR/BAG ever draw.
  static List<String> get dollOverlayPaths => [
    for (final path in allAssetPaths)
      if (path.endsWith('_idle.png')) path,
  ];

  /// Non-native materials each body ships (matches the gear build manifest).
  static const Map<BodyFamily, List<String>> kFamilyMaterials = {
    BodyFamily.warrior: ['leather'],
    BodyFamily.rogue: ['mail'],
    BodyFamily.healer: ['plate', 'mail', 'leather'],
    BodyFamily.mage: ['mail', 'leather'],
  };

  static const Map<BodyFamily, List<String>> kFamilyClassMarks = {
    BodyFamily.warrior: ['paladin', 'deathknight'],
    BodyFamily.mage: ['warlock'],
  };

  /// Every owned overlay + BAG `*_icon` crop (boots icons included).
  ///
  /// Bodies precache via [BodyFamilyCatalog.allAssetPaths]. Walk/attack use
  /// the same idle gear overlays on poser body clips. Short and broad borrow
  /// the plain cut's BAG icon, so only t0/t2 ship icons.
  static List<String> get allAssetPaths {
    final out = <String>{};
    String icon(BodyFamily family, String stem) =>
        '$root/${family.name}/gear/${stem}_icon.png';
    for (final family in BodyFamily.values) {
      final looks = ['', for (final m in kFamilyMaterials[family]!) '${m}_'];
      for (final look in looks) {
        for (final slot in kArmorSlots) {
          for (final cut in kArmorCuts) {
            final stem = '${slot}_$look$cut';
            out.add(familyGear(family, stem, 'idle'));
            if (cut == 't0' || cut == 't2') out.add(icon(family, stem));
          }
        }
        out.add(icon(family, 'boots_${look}t0'));
        out.add(icon(family, 'boots_${look}t2'));
      }
      for (final mark in kFamilyClassMarks[family] ?? const <String>[]) {
        for (final slot in kClassMarkSlots) {
          for (final cut in kArmorCuts) {
            out.add(familyGear(family, '${slot}_${mark}_$cut', 'idle'));
          }
        }
      }
    }
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
