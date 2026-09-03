import 'dart:math';

/// Named visual models per base item type (WoW-style display ids).
///
/// Base token = first segment of [visualSetId] (`sword_thunderfury` → `sword`).
/// Catalog ids (`sword_t0`) stay as the default / common silhouette.
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

  static const Map<String, List<String>> variants = {
    'sword': [
      'sword_t0',
      'sword_thunderfury',
      'sword_warglaive',
      'sword_emberfang',
      'sword_crystalblade',
      'sword_boneedge',
      'sword_runebane',
      'sword_ashcleaver',
      'sword_frostbite',
      'sword_nightreaver',
      'sword_sunflare',
      'sword_voidspike',
    ],
    'staff': [
      'staff_t0',
      'staff_frostfire',
      'staff_oakroot',
      'staff_arcspire',
      'staff_shadowcrook',
      'staff_emberwand',
      'staff_tidebranch',
      'staff_crystalrod',
      'staff_bonespine',
      'staff_sunshaft',
      'staff_voidpillar',
      'staff_stormreed',
    ],
    'dagger': [
      'dagger_t0',
      'dagger_shadowfang',
      'dagger_venomtip',
      'dagger_quicksteel',
      'dagger_bonepin',
      'dagger_emberknife',
      'dagger_frostneedle',
      'dagger_crystalspike',
      'dagger_nightshiv',
      'dagger_sunblade',
      'dagger_voidrazor',
      'dagger_tideedge',
    ],
    'mace': [
      'mace_t0',
      'mace_ironmaul',
      'mace_skullcrush',
      'mace_emberhammer',
      'mace_frostgavel',
      'mace_crystalhead',
      'mace_boneclub',
      'mace_sunmace',
      'mace_voidmallet',
      'mace_tidecrusher',
      'mace_runebreaker',
      'mace_stormflail',
    ],
    'axe': [
      'axe_t0',
      'axe_warcleave',
      'axe_bloodbite',
      'axe_emberhatchet',
      'axe_frostchop',
      'axe_crystaledge',
      'axe_bonesaw',
      'axe_sunaxe',
      'axe_voidhook',
      'axe_tidebite',
      'axe_runesplitter',
      'axe_stormcleaver',
    ],
    'bow': [
      'bow_t0',
      'bow_longshot',
      'bow_shadowstring',
      'bow_emberarc',
      'bow_frostlimb',
      'bow_crystalbow',
      'bow_bonebow',
      'bow_sunarc',
      'bow_voidstring',
      'bow_tidebow',
      'bow_runebow',
      'bow_stormshaft',
    ],
    'shield': [
      'shield_t0',
      'shield_stormwall',
      'shield_ironbulwark',
      'shield_emberguard',
      'shield_frostplate',
      'shield_crystalward',
      'shield_boneguard',
      'shield_sunshield',
      'shield_voidaegis',
      'shield_tidewall',
      'shield_runeguard',
      'shield_towerkite',
    ],
    'frill': [
      'frill_t0',
      'frill_tome',
      'frill_orb',
      'frill_idol',
      'frill_embercharm',
      'frill_frostsigil',
      'frill_crystalbauble',
      'frill_bonerelic',
      'frill_suncharm',
      'frill_voidtotem',
      'frill_tidecharm',
      'frill_runestone',
    ],
    'helm': [
      'helm_t0',
      'helm_spiked',
      'helm_visor',
      'helm_horns',
      'helm_cowl',
      'helm_crown',
      'helm_mask',
      'helm_plume',
      'helm_winged',
      'helm_banded',
      'helm_crest',
      'helm_hooded',
    ],
    'chest': [
      'chest_t0',
      'chest_plated',
      'chest_studded',
      'chest_robe',
      'chest_scale',
      'chest_chain',
      'chest_vest',
      'chest_tabard',
      'chest_lamellar',
      'chest_cuirass',
      'chest_mantle',
      'chest_brigandine',
    ],
    'legs': [
      'legs_t0',
      'legs_plated',
      'legs_padded',
      'legs_skirt',
      'legs_scale',
      'legs_chain',
      'legs_wraps',
      'legs_greaves',
      'legs_tassets',
      'legs_hose',
      'legs_kilt',
      'legs_cuisses',
    ],
    'cloak': [
      'cloak_t0',
      'cloak_cape',
      'cloak_mantle',
      'cloak_shawl',
      'cloak_winged',
      'cloak_ragged',
      'cloak_fur',
      'cloak_silk',
      'cloak_tabard',
      'cloak_hooded',
      'cloak_banner',
      'cloak_veil',
    ],
    'hands': [
      'hands_t0',
      'hands_gauntlets',
      'hands_gloves',
      'hands_wraps',
      'hands_bracers',
      'hands_claws',
      'hands_mitts',
      'hands_studded',
      'hands_scale',
      'hands_chain',
      'hands_silk',
      'hands_bone',
    ],
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

  /// Pick a model for loot. [resolvedBaseId] is e.g. `sword_t2` / `helm_t0`.
  ///
  /// Lower rarity prefers early catalog entries (`*_t0` + simple names);
  /// rare+ draws from the full pool with a lean toward later entries.
  static String pickVariant(
    String resolvedBaseId,
    Random rng, {
    int rarityTier = 0,
  }) {
    final list = variantsFor(resolvedBaseId);
    if (list.isEmpty) return resolvedBaseId;
    if (list.length == 1) return list.first;

    if (rarityTier <= 0) {
      if (rng.nextDouble() < 0.55) return list.first;
      return list[rng.nextInt(list.length.clamp(1, 4))];
    }
    if (rarityTier == 1) {
      return list[rng.nextInt(list.length.clamp(1, 6))];
    }
    if (rng.nextDouble() < 0.35) {
      final start = list.length ~/ 2;
      return list[start + rng.nextInt(list.length - start)];
    }
    return list[rng.nextInt(list.length)];
  }

  static Iterable<String> get allSharedVariantIds sync* {
    for (final base in sharedBases) {
      yield* variants[base] ?? const <String>[];
    }
  }

  static Iterable<String> get allFamilyVariantIds sync* {
    for (final base in familyBases) {
      yield* variants[base] ?? const <String>[];
    }
  }
}
