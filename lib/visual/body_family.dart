import '../models/hero.dart';
import 'hero_anim_state.dart';

/// Owned denser body families (Phase 3). Maps gear affinity → atlas folder.
enum BodyFamily { warrior, healer, mage, rogue }

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
      // No hit clip: stay on idle. The walk stride read as a phantom step.
      HeroAnimKind.hit => hitAsset ?? idleAsset,
      HeroAnimKind.death => deathAsset ?? idleAsset,
      HeroAnimKind.victory => idleAsset,
      HeroAnimKind.idle => idleAsset,
    };
    return path ?? idleAsset;
  }

  /// Cloth-only mask used for spec color. Skin, hair and facial ink stay out.
  String tintMaskAssetFor(HeroAnimKind kind) =>
      tintMaskForBodyAsset(assetFor(kind));

  /// Family default `body_idle.png` → `body_tint_idle.png`.
  /// Race undertunic `nightelf_m_body_idle.png` → `nightelf_m_body_tint_idle.png`.
  static String tintMaskForBodyAsset(String bodyAsset) {
    if (bodyAsset.contains('_body_')) {
      return bodyAsset.replaceFirst('_body_', '_body_tint_');
    }
    return bodyAsset.replaceFirst('/body_', '/body_tint_');
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

  static BodyFamilyDef defForHero(PartyHero hero) => defFor(familyFor(hero));

  /// Authored race undertunics — all Cataclysm races × both sexes × families.
  /// Pose stays family-anchored so gear overlays still fit.
  static final List<({BodyFamily family, HeroRace race, HeroSex sex})>
      authoredRaceLooks = [
    for (final family in BodyFamily.values)
      for (final race in HeroRace.values)
        for (final sex in HeroSex.values)
          (family: family, race: race, sex: sex),
  ];

  static bool hasAuthoredRaceBody(PartyHero hero) {
    final family = familyFor(hero);
    return authoredRaceLooks.any(
      (look) =>
          look.family == family &&
          look.race == hero.race &&
          look.sex == hero.sex,
    );
  }

  /// Race undertunic next to the family body, or null to use the family clip.
  static String? raceBodyAsset(PartyHero hero, HeroAnimKind kind) {
    if (!hasAuthoredRaceBody(hero)) return null;
    final fallback = defForHero(hero).assetFor(kind);
    const needle = '/body_';
    final at = fallback.lastIndexOf(needle);
    if (at < 0) return null;
    final dir = fallback.substring(0, at);
    final rest = fallback.substring(at + needle.length);
    return '$dir/${hero.race.assetKey}_${hero.sex.assetKey}_body_$rest';
  }

  static String assetFor(PartyHero hero, HeroAnimKind kind) =>
      raceBodyAsset(hero, kind) ?? defForHero(hero).assetFor(kind);

  static String tintMaskAssetFor(PartyHero hero, HeroAnimKind kind) =>
      BodyFamilyDef.tintMaskForBodyAsset(assetFor(hero, kind));

  /// All PNG paths that dungeon loaders should precache.
  static List<String> get allAssetPaths {
    final out = <String>{};
    void addClip(String? path) {
      if (path == null) return;
      out.add(path);
      out.add(BodyFamilyDef.tintMaskForBodyAsset(path));
    }

    for (final def in catalog.values) {
      addClip(def.idleAsset);
      addClip(def.walkAsset);
      addClip(def.attackAsset);
      addClip(def.castAsset);
      addClip(def.hitAsset);
      addClip(def.deathAsset);
    }
    for (final look in authoredRaceLooks) {
      for (final anim in const ['idle', 'walk', 'attack']) {
        addClip(
          'assets/custom/char/${look.family.name}/'
          '${look.race.assetKey}_${look.sex.assetKey}_body_$anim.png',
        );
      }
    }
    return out.toList(growable: false);
  }

  static final Map<BodyFamily, BodyFamilyDef>
  catalog = Map<BodyFamily, BodyFamilyDef>.unmodifiable({
    BodyFamily.warrior: BodyFamilyDef(
      id: BodyFamily.warrior,
      folder: 'warrior',
      idleAsset: BodyFamilyDef._path(BodyFamily.warrior, 'body_idle.png'),
      walkAsset: BodyFamilyDef._path(BodyFamily.warrior, 'body_walk.png'),
      attackAsset: BodyFamilyDef._path(BodyFamily.warrior, 'body_attack.png'),
    ),
    BodyFamily.healer: BodyFamilyDef(
      id: BodyFamily.healer,
      folder: 'healer',
      idleAsset: BodyFamilyDef._path(BodyFamily.healer, 'body_idle.png'),
      walkAsset: BodyFamilyDef._path(BodyFamily.healer, 'body_walk.png'),
      attackAsset: BodyFamilyDef._path(BodyFamily.healer, 'body_attack.png'),
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
      attackAsset: BodyFamilyDef._path(BodyFamily.rogue, 'body_attack.png'),
    ),
  });
}
