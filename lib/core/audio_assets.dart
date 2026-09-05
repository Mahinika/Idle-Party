import '../models/loot.dart';
import '../models/spell_bolt_style.dart';

/// Asset paths for Idle Party audio (core-safe — no ui/ imports).
///
/// SFX: Kenney RPG Audio (CC0) under [sfxRoot], plus owned spell chirps under
/// [customSfxRoot].
/// Ambience: Idle Party procedural pads under [ambienceRoot].
abstract final class AudioAssets {
  static const sfxRoot = 'assets/kenney/audio/sfx';
  static const customSfxRoot = 'assets/custom/audio/sfx';
  static const ambienceRoot = 'assets/custom/audio/ambience';

  static const ui = '$sfxRoot/ui.ogg';
  static const hit = '$sfxRoot/hit.ogg';
  static const hitBlade = '$sfxRoot/hit_blade.ogg';
  static const hitAxe = '$sfxRoot/hit_axe.ogg';
  static const hitBlunt = '$sfxRoot/hit_blunt.ogg';
  static const hitDagger = '$sfxRoot/hit_dagger.ogg';
  static const hitFist = '$sfxRoot/hit_fist.ogg';
  static const hitBow = '$sfxRoot/hit_bow.ogg';
  static const crit = '$sfxRoot/crit.ogg';
  static const kill = '$sfxRoot/kill.ogg';
  static const loot = '$sfxRoot/loot.ogg';
  static const lootB = '$sfxRoot/loot_b.ogg';
  static const flask = '$sfxRoot/flask.ogg';
  static const level = '$sfxRoot/level.ogg';
  static const clear = '$sfxRoot/clear.ogg';
  static const unlock = '$sfxRoot/unlock.ogg';
  static const boss = '$sfxRoot/boss.ogg';
  static const wipe = '$sfxRoot/wipe.ogg';

  static const spellFire = '$customSfxRoot/spell_fire.wav';
  static const spellFrost = '$customSfxRoot/spell_frost.wav';
  static const spellHoly = '$customSfxRoot/spell_holy.wav';
  static const spellShadow = '$customSfxRoot/spell_shadow.wav';
  static const spellArcane = '$customSfxRoot/spell_arcane.wav';
  static const spellNature = '$customSfxRoot/spell_nature.wav';
  static const spellLightning = '$customSfxRoot/spell_lightning.wav';

  static const hubAmbience = '$ambienceRoot/hub.wav';
  static const dungeonAmbience = '$ambienceRoot/dungeon.wav';

  /// Every SFX id used by [GameAudio.play] → asset path.
  static const Map<String, String> sfxById = <String, String>{
    'ui': ui,
    'hit': hit,
    'hit_blade': hitBlade,
    'hit_axe': hitAxe,
    'hit_blunt': hitBlunt,
    'hit_dagger': hitDagger,
    'hit_fist': hitFist,
    'hit_bow': hitBow,
    'crit': crit,
    'kill': kill,
    'loot': loot,
    'flask': flask,
    'level': level,
    'clear': clear,
    'unlock': unlock,
    'boss': boss,
    'wipe': wipe,
    'spell_fire': spellFire,
    'spell_frost': spellFrost,
    'spell_holy': spellHoly,
    'spell_shadow': spellShadow,
    'spell_arcane': spellArcane,
    'spell_nature': spellNature,
    'spell_lightning': spellLightning,
  };

  /// Combat feel ids that share a long per-clip cooldown (weapon + spell).
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

  static const List<String> allCatalogPaths = <String>[
    ui,
    hit,
    hitBlade,
    hitAxe,
    hitBlunt,
    hitDagger,
    hitFist,
    hitBow,
    crit,
    kill,
    loot,
    lootB,
    flask,
    level,
    clear,
    unlock,
    boss,
    wipe,
    spellFire,
    spellFrost,
    spellHoly,
    spellShadow,
    spellArcane,
    spellNature,
    spellLightning,
    hubAmbience,
    dungeonAmbience,
  ];
}
