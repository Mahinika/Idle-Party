import '../models/loot.dart';
import '../models/spell_bolt_style.dart';

/// Asset paths for Idle Party audio (core-safe — no ui/ imports).
///
/// SFX: Idle Party soft procedural one-shots under [customSfxRoot] (see
/// `tool/generate_soft_sfx.py` + `tool/generate_combat_spell_sfx.py`).
/// Hit families ship 3 variants (`_a/_b/_c`) for combat mix.
/// Kenney RPG Audio (CC0) remains under [sfxRoot] as reference only.
/// Ambience: Idle Party procedural pads under [ambienceRoot].
/// Music: owned / CC0 loops under [musicRoot].
abstract final class AudioAssets {
  static const sfxRoot = 'assets/kenney/audio/sfx';
  static const customSfxRoot = 'assets/custom/audio/sfx';
  static const ambienceRoot = 'assets/custom/audio/ambience';
  static const musicRoot = 'assets/custom/audio/music';

  static const ui = '$customSfxRoot/ui.wav';
  static const hitA = '$customSfxRoot/hit_a.wav';
  static const hitB = '$customSfxRoot/hit_b.wav';
  static const hitC = '$customSfxRoot/hit_c.wav';
  static const hitBladeA = '$customSfxRoot/hit_blade_a.wav';
  static const hitBladeB = '$customSfxRoot/hit_blade_b.wav';
  static const hitBladeC = '$customSfxRoot/hit_blade_c.wav';
  static const hitAxeA = '$customSfxRoot/hit_axe_a.wav';
  static const hitAxeB = '$customSfxRoot/hit_axe_b.wav';
  static const hitAxeC = '$customSfxRoot/hit_axe_c.wav';
  static const hitBluntA = '$customSfxRoot/hit_blunt_a.wav';
  static const hitBluntB = '$customSfxRoot/hit_blunt_b.wav';
  static const hitBluntC = '$customSfxRoot/hit_blunt_c.wav';
  static const hitDaggerA = '$customSfxRoot/hit_dagger_a.wav';
  static const hitDaggerB = '$customSfxRoot/hit_dagger_b.wav';
  static const hitDaggerC = '$customSfxRoot/hit_dagger_c.wav';
  static const hitFistA = '$customSfxRoot/hit_fist_a.wav';
  static const hitFistB = '$customSfxRoot/hit_fist_b.wav';
  static const hitFistC = '$customSfxRoot/hit_fist_c.wav';
  static const hitBowA = '$customSfxRoot/hit_bow_a.wav';
  static const hitBowB = '$customSfxRoot/hit_bow_b.wav';
  static const hitBowC = '$customSfxRoot/hit_bow_c.wav';
  static const crit = '$customSfxRoot/crit.wav';
  static const kill = '$customSfxRoot/kill.wav';
  static const loot = '$customSfxRoot/loot.wav';
  static const flask = '$customSfxRoot/flask.wav';
  static const level = '$customSfxRoot/level.wav';
  static const clear = '$customSfxRoot/clear.wav';
  static const unlock = '$customSfxRoot/unlock.wav';
  static const boss = '$customSfxRoot/boss.wav';
  static const wipe = '$customSfxRoot/wipe.wav';

  static const spellFire = '$customSfxRoot/spell_fire.wav';
  static const spellFrost = '$customSfxRoot/spell_frost.wav';
  static const spellHoly = '$customSfxRoot/spell_holy.wav';
  static const spellShadow = '$customSfxRoot/spell_shadow.wav';
  static const spellArcane = '$customSfxRoot/spell_arcane.wav';
  static const spellNature = '$customSfxRoot/spell_nature.wav';
  static const spellLightning = '$customSfxRoot/spell_lightning.wav';

  static const hubAmbience = '$ambienceRoot/hub.wav';
  static const dungeonAmbience = '$ambienceRoot/dungeon.wav';

  static const hubMusic = '$musicRoot/hub.ogg';
  static const dungeonMusic = '$musicRoot/dungeon.mp3';

  /// Play id → one or more variant paths (combat picks random).
  static const Map<String, List<String>> sfxVariants = <String, List<String>>{
    'ui': <String>[ui],
    'hit': <String>[hitA, hitB, hitC],
    'hit_blade': <String>[hitBladeA, hitBladeB, hitBladeC],
    'hit_axe': <String>[hitAxeA, hitAxeB, hitAxeC],
    'hit_blunt': <String>[hitBluntA, hitBluntB, hitBluntC],
    'hit_dagger': <String>[hitDaggerA, hitDaggerB, hitDaggerC],
    'hit_fist': <String>[hitFistA, hitFistB, hitFistC],
    'hit_bow': <String>[hitBowA, hitBowB, hitBowC],
    'crit': <String>[crit],
    'kill': <String>[kill],
    'loot': <String>[loot],
    'flask': <String>[flask],
    'level': <String>[level],
    'clear': <String>[clear],
    'unlock': <String>[unlock],
    'boss': <String>[boss],
    'wipe': <String>[wipe],
    'spell_fire': <String>[spellFire],
    'spell_frost': <String>[spellFrost],
    'spell_holy': <String>[spellHoly],
    'spell_shadow': <String>[spellShadow],
    'spell_arcane': <String>[spellArcane],
    'spell_nature': <String>[spellNature],
    'spell_lightning': <String>[spellLightning],
  };

  /// First variant path per id (compat / single-source lookups).
  static final Map<String, String> sfxById = <String, String>{
    for (final e in sfxVariants.entries) e.key: e.value.first,
  };

  /// Combat feel ids that share combat-mix gates (weapon + spell + crit/kill).
  static const Set<String> combatFeelIds = <String>{
    'hit',
    'hit_blade',
    'hit_axe',
    'hit_blunt',
    'hit_dagger',
    'hit_fist',
    'hit_bow',
    'spell_fire',
    'spell_frost',
    'spell_holy',
    'spell_shadow',
    'spell_arcane',
    'spell_nature',
    'spell_lightning',
    'crit',
    'kill',
  };

  static const Set<String> meleeFeelIds = <String>{
    'hit',
    'hit_blade',
    'hit_axe',
    'hit_blunt',
    'hit_dagger',
    'hit_fist',
  };

  static const Set<String> bowFeelIds = <String>{'hit_bow'};

  static const Set<String> spellFeelIds = <String>{
    'spell_fire',
    'spell_frost',
    'spell_holy',
    'spell_shadow',
    'spell_arcane',
    'spell_nature',
    'spell_lightning',
  };

  static const Set<String> priorityFeelIds = <String>{'crit', 'kill'};

  /// Map equipped weapon + optional bolt style → play id.
  static String combatHitId({
    WeaponType? weaponType,
    SpellBoltStyle? style,
    bool ranged = false,
  }) {
    final bolt = style;
    if (bolt != null) {
      switch (bolt) {
        case SpellBoltStyle.fire:
          return 'spell_fire';
        case SpellBoltStyle.frost:
          return 'spell_frost';
        case SpellBoltStyle.holy:
          return 'spell_holy';
        case SpellBoltStyle.shadow:
          return 'spell_shadow';
        case SpellBoltStyle.arcane:
          return 'spell_arcane';
        case SpellBoltStyle.nature:
          return 'spell_nature';
        case SpellBoltStyle.lightning:
          return 'spell_lightning';
        case SpellBoltStyle.arrow:
          return 'hit_bow';
        case SpellBoltStyle.weapon:
          break;
      }
    }
    if (ranged ||
        weaponType == WeaponType.bow ||
        weaponType == WeaponType.crossbow ||
        weaponType == WeaponType.gun ||
        weaponType == WeaponType.thrown) {
      return 'hit_bow';
    }
    return switch (weaponType) {
      WeaponType.axe => 'hit_axe',
      WeaponType.mace || WeaponType.staff || WeaponType.polearm => 'hit_blunt',
      WeaponType.dagger => 'hit_dagger',
      WeaponType.fist => 'hit_fist',
      WeaponType.wand => 'spell_arcane',
      WeaponType.sword ||
      WeaponType.bow ||
      WeaponType.crossbow ||
      WeaponType.gun ||
      WeaponType.thrown ||
      null =>
        'hit_blade',
    };
  }

  static final List<String> allCatalogPaths = <String>[
    for (final variants in sfxVariants.values) ...variants,
    hubAmbience,
    dungeonAmbience,
    hubMusic,
    dungeonMusic,
  ];
}
