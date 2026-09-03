import '../models/hero.dart';
import 'hero_anim_state.dart';

/// Owned denser body families (Phase 3). Maps gear affinity → atlas folder.
enum BodyFamily {
  warrior,
  healer,
  mage,
  rogue,
}

/// Catalog entry for one family's anim frames under `assets/custom/char/`.
class BodyFamilyDef {
  const BodyFamilyDef({
    required this.id,
    required this.folder,
    required this.idleAsset,
    this.walkAsset,
    this.attackAsset,
    this.castAsset,
    this.hitAsset,
    this.deathAsset,
  });

  final BodyFamily id;
  final String folder;
  final String idleAsset;
  final String? walkAsset;
  final String? attackAsset;
  final String? castAsset;
  final String? hitAsset;
  final String? deathAsset;

  /// Asset path for [kind]; falls back to idle when a clip is missing.
  String assetFor(HeroAnimKind kind) {
    final path = switch (kind) {
      HeroAnimKind.walk => walkAsset,
      HeroAnimKind.attack => attackAsset,
      HeroAnimKind.cast => castAsset ?? attackAsset,
      HeroAnimKind.hit => hitAsset ?? walkAsset,
      HeroAnimKind.death => deathAsset ?? idleAsset,
      HeroAnimKind.victory => idleAsset,
      HeroAnimKind.idle => idleAsset,
    };
    return path ?? idleAsset;
  }

  static String _path(BodyFamily id, String file) =>
      'assets/custom/char/${id.name}/$file';
}

/// Resolves [PartyHero] → owned denser body family + asset paths.
abstract final class BodyFamilyCatalog {
  static BodyFamily familyFor(PartyHero hero) =>
      familyForAffinity(hero.gearAffinity.name);

  static BodyFamily familyForAffinity(String? affinity) => switch (affinity) {
    'healer' => BodyFamily.healer,
    'mage' => BodyFamily.mage,
    'rogue' => BodyFamily.rogue,
    _ => BodyFamily.warrior,
  };

  static BodyFamilyDef defFor(BodyFamily family) => catalog[family]!;

  static BodyFamilyDef defForHero(PartyHero hero) =>
      defFor(familyFor(hero));

  static String assetFor(PartyHero hero, HeroAnimKind kind) =>
      defForHero(hero).assetFor(kind);

  /// All PNG paths that dungeon loaders should precache.
  static List<String> get allAssetPaths {
    final out = <String>{};
    for (final def in catalog.values) {
      out.add(def.idleAsset);
      if (def.walkAsset != null) out.add(def.walkAsset!);
      if (def.attackAsset != null) out.add(def.attackAsset!);
      if (def.castAsset != null) out.add(def.castAsset!);
      if (def.hitAsset != null) out.add(def.hitAsset!);
      if (def.deathAsset != null) out.add(def.deathAsset!);
    }
    return out.toList(growable: false);
  }

  static final Map<BodyFamily, BodyFamilyDef> catalog =
      Map<BodyFamily, BodyFamilyDef>.unmodifiable({
        BodyFamily.warrior: BodyFamilyDef(
          id: BodyFamily.warrior,
          folder: 'warrior',
          idleAsset: BodyFamilyDef._path(BodyFamily.warrior, 'body_idle.png'),
          walkAsset: BodyFamilyDef._path(BodyFamily.warrior, 'body_walk.png'),
          attackAsset: BodyFamilyDef._path(
            BodyFamily.warrior,
            'body_attack.png',
          ),
        ),
        BodyFamily.healer: BodyFamilyDef(
          id: BodyFamily.healer,
          folder: 'healer',
          idleAsset: BodyFamilyDef._path(BodyFamily.healer, 'body_idle.png'),
          walkAsset: BodyFamilyDef._path(BodyFamily.healer, 'body_walk.png'),
          attackAsset: BodyFamilyDef._path(
            BodyFamily.healer,
            'body_attack.png',
          ),
        ),
        BodyFamily.mage: BodyFamilyDef(
          id: BodyFamily.mage,
          folder: 'mage',
          idleAsset: BodyFamilyDef._path(BodyFamily.mage, 'body_idle.png'),
          walkAsset: BodyFamilyDef._path(BodyFamily.mage, 'body_walk.png'),
          attackAsset: BodyFamilyDef._path(BodyFamily.mage, 'body_attack.png'),
        ),
        BodyFamily.rogue: BodyFamilyDef(
          id: BodyFamily.rogue,
          folder: 'rogue',
          idleAsset: BodyFamilyDef._path(BodyFamily.rogue, 'body_idle.png'),
          walkAsset: BodyFamilyDef._path(BodyFamily.rogue, 'body_walk.png'),
          attackAsset: BodyFamilyDef._path(
            BodyFamily.rogue,
            'body_attack.png',
          ),
        ),
      });
}
