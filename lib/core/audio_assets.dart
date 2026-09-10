import '../models/loot.dart';
import '../models/spell_bolt_style.dart';

/// Asset paths for Idle Party audio (core-safe — no ui/ imports).
///
/// SFX: Idle Party soft procedural one-shots under [customSfxRoot] (see
/// `tool/generate_soft_sfx.py` + `tool/generate_combat_spell_sfx.py`).
/// Hit families ship 5 variants (`_a`…`_e`) plus swish/material layers.
/// Kenney RPG Audio (CC0) remains under [sfxRoot] as reference only.
abstract final class AudioAssets {
  static const sfxRoot = 'assets/kenney/audio/sfx';
  static const customSfxRoot = 'assets/custom/audio/sfx';
  static const ambienceRoot = 'assets/custom/audio/ambience';
  static const musicRoot = 'assets/custom/audio/music';

  static const ui = '$customSfxRoot/ui.wav';
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
  static const spellDemon = '$customSfxRoot/spell_demon.wav';
  static const spellPoison = '$customSfxRoot/spell_poison.wav';

  static const matFlesh = '$customSfxRoot/mat_flesh.wav';
  static const matBone = '$customSfxRoot/mat_bone.wav';
  static const matWet = '$customSfxRoot/mat_wet.wav';
  static const matStone = '$customSfxRoot/mat_stone.wav';

  static const hubAmbience = '$ambienceRoot/hub.wav';
  static const dungeonAmbience = '$ambienceRoot/dungeon.wav';
  static const hubMusic = '$musicRoot/hub.ogg';
  static const dungeonMusic = '$musicRoot/dungeon.mp3';

  static List<String> _hitVariants(String stem) => <String>[
    for (final letter in <String>['a', 'b', 'c', 'd', 'e'])
      '$customSfxRoot/${stem}_$letter.wav',
  ];

  static List<String> _triple(String stem) => <String>[
    for (final letter in <String>['a', 'b', 'c'])
      '$customSfxRoot/${stem}_$letter.wav',
  ];

  /// Play id → one or more variant paths (combat picks random).
  static final Map<String, List<String>> sfxVariants = <String, List<String>>{
    'ui': <String>[ui],
    'hit': _hitVariants('hit'),
    'hit_blade': _hitVariants('hit_blade'),
    'hit_axe': _hitVariants('hit_axe'),
    'hit_blunt': _hitVariants('hit_blunt'),
    'hit_dagger': _hitVariants('hit_dagger'),
    'hit_fist': _hitVariants('hit_fist'),
    'hit_bow': _hitVariants('hit_bow'),
    'swish_melee': _triple('swish_melee'),
    'swish_bow': _triple('swish_bow'),
    'mat_flesh': <String>[matFlesh],
    'mat_bone': <String>[matBone],
    'mat_wet': <String>[matWet],
    'mat_stone': <String>[matStone],
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
    'spell_demon': <String>[spellDemon],
    'spell_poison': <String>[spellPoison],
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
    'spell_demon',
    'spell_poison',
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
    'spell_demon',
    'spell_poison',
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
        case SpellBoltStyle.demon:
          return 'spell_demon';
        case SpellBoltStyle.poison:
          return 'spell_poison';
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
