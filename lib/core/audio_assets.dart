import '../models/loot.dart';
import '../models/spell_bolt_style.dart';
import 'combat_feel.dart';

/// Which cave bed and air a dungeon uses.
enum ZoneMood { warm, dark, ice, wet, storm }

/// Asset paths for Idle Party audio (core-safe — no ui/ imports).
///
/// Combat SFX are mastered CC0 recordings. Menu and loot stay owned synth.
/// Each place has several CC0 or owned songs and does not loop one file.
/// `music/dungeon.mp3` stays on disk as the spare and is not played.
abstract final class AudioAssets {
  static const customSfxRoot = 'assets/custom/audio/sfx';
  static const ambienceRoot = 'assets/custom/audio/ambience';
  static const musicRoot = 'assets/custom/audio/music';

  static const hubAmbience = '$ambienceRoot/hub.ogg';
  static const hubMusic = '$musicRoot/hub.ogg';

  /// Spare from before the zone beds. Not in [allCatalogPaths].
  static const legacyDungeonMusic = '$musicRoot/dungeon.mp3';

  static const bossMusic = '$musicRoot/boss.ogg';
  static const bossFairy = '$musicRoot/boss_fairy.ogg';
  static const resolveMusic = '$musicRoot/resolve.ogg';
  static const downMusic = '$musicRoot/down.ogg';
  static const hubTown = '$musicRoot/hub_town.ogg';
  static const hubMystical = '$musicRoot/hub_mystical.ogg';
  static const darkDungeon = '$musicRoot/dark_dungeon.ogg';
  static const darkWhispers = '$musicRoot/dark_whispers.ogg';
  static const iceRealm = '$musicRoot/ice_realm.ogg';
  static const iceCrystal = '$musicRoot/ice_crystal.ogg';

  /// Hub songs. Heavenly Loop stays; the others are CC0 town themes.
  static const List<String> hubTracks = <String>[
    hubMusic,
    hubTown,
    hubMystical,
  ];

  /// Boss bed, then a second CC0 fight. Boss still loops until the fight ends.
  static const List<String> bossTracks = <String>[bossMusic, bossFairy];

  static const maxCatalogBytes = 25 * 1024 * 1024;

  static ZoneMood moodForDungeon(String dungeonId) => switch (dungeonId) {
    'king' || 'underworld' || 'dead' || 'hell' || 'fen' => ZoneMood.dark,
    'crystal' || 'rime' => ZoneMood.ice,
    'tide' || 'grove' => ZoneMood.wet,
    'ember' || 'brass' || 'storm' || 'veil' => ZoneMood.storm,
    _ => ZoneMood.warm,
  };

  static String dungeonMusic(ZoneMood mood) =>
      '$musicRoot/bed_${mood.name}.ogg';

  /// Songs for one cave mood. The owned bed stays. Later songs are CC0.
  /// A cave never plays the same song twice in a row.
  static List<String> dungeonTracks(ZoneMood mood) => switch (mood) {
    ZoneMood.warm => <String>[dungeonMusic(mood), hubTown, hubMystical],
    ZoneMood.dark => <String>[dungeonMusic(mood), darkDungeon, darkWhispers],
    ZoneMood.ice => <String>[dungeonMusic(mood), iceRealm, iceCrystal],
    ZoneMood.wet => <String>[dungeonMusic(mood), darkWhispers],
    ZoneMood.storm => <String>[dungeonMusic(mood), darkDungeon],
  };

  static String dungeonAmbience(ZoneMood mood) =>
      '$ambienceRoot/${mood.name}.ogg';

  static List<String> _letters(String stem, String letters) => <String>[
    for (final letter in letters.split(''))
      '$customSfxRoot/${stem}_$letter.ogg',
  ];

  static List<String> _one(String stem) => <String>['$customSfxRoot/$stem.ogg'];

  /// Play id → one or more variant paths (combat picks random).
  static final Map<String, List<String>> sfxVariants = <String, List<String>>{
    'ui_tap': _one('ui_tap'),
    'ui_tab': _one('ui_tab'),
    'ui_confirm': _one('ui_confirm'),
    'ui_back': _one('ui_back'),
    'ui_deny': _one('ui_deny'),
    'hit_blade': _letters('hit_blade', 'abcdef'),
    'hit_axe': _letters('hit_axe', 'abcdef'),
    'hit_blunt': _letters('hit_blunt', 'abcdef'),
    'hit_dagger': _letters('hit_dagger', 'abcdef'),
    'hit_fist': _letters('hit_fist', 'abcdef'),
    'hit_bow': _letters('hit_bow', 'abcd'),
    'swish_melee': _letters('swish_melee', 'abc'),
    'swish_bow': _letters('swish_bow', 'abc'),
    'mat_flesh': _one('mat_flesh'),
    'mat_bone': _one('mat_bone'),
    'mat_wet': _one('mat_wet'),
    'mat_stone': _one('mat_stone'),
    'crit': _letters('crit', 'abcd'),
    'kill': _letters('kill', 'abcd'),
    'loot': _one('loot'),
    'loot_rare': _one('loot_rare'),
    'loot_epic': _one('loot_epic'),
    'loot_legendary': _one('loot_legendary'),
    'gold': _one('gold'),
    'equip': _one('equip'),
    'forge_up': _one('forge_up'),
    'achievement': _one('achievement'),
    'ascend': _one('ascend'),
    'flask': _one('flask'),
    'level': _one('level'),
    'clear': _one('clear'),
    'unlock': _one('unlock'),
    'boss': _one('boss'),
    'wipe': _one('wipe'),
    'enemy_hit': _letters('enemy_hit', 'abc'),
    'hero_down': _one('hero_down'),
    'heal': _letters('heal', 'ab'),
    'shield': _letters('shield', 'ab'),
    'boss_tell': _letters('boss_tell', 'ab'),
    'enrage': _letters('enrage', 'ab'),
    'enemy_die_flesh': _letters('enemy_die_flesh', 'abc'),
    'enemy_die_bone': _letters('enemy_die_bone', 'abc'),
    'enemy_die_stone': _letters('enemy_die_stone', 'abc'),
    'spell_fire': _letters('spell_fire', 'abcdef'),
    'spell_frost': _letters('spell_frost', 'abcdef'),
    'spell_holy': _letters('spell_holy', 'abcdef'),
    'spell_shadow': _letters('spell_shadow', 'abcdef'),
    'spell_arcane': _letters('spell_arcane', 'abcdef'),
    'spell_nature': _letters('spell_nature', 'abcdef'),
    'spell_lightning': _letters('spell_lightning', 'abcdef'),
    'spell_demon': _letters('spell_demon', 'abcdef'),
    'spell_poison': _letters('spell_poison', 'abcdef'),
    'bow_release': _letters('bow_release', 'abcd'),
    'cast_fire': _letters('cast_fire', 'abc'),
    'cast_frost': _letters('cast_frost', 'abc'),
    'cast_holy': _letters('cast_holy', 'abc'),
    'cast_shadow': _letters('cast_shadow', 'abc'),
    'cast_arcane': _letters('cast_arcane', 'abc'),
    'cast_nature': _letters('cast_nature', 'abc'),
    'cast_lightning': _letters('cast_lightning', 'abc'),
    'cast_demon': _letters('cast_demon', 'abc'),
    'cast_poison': _letters('cast_poison', 'abc'),
  };

  /// Arrow release and spell casts. Not combat impacts — own rate limit.
  static const Set<String> launchIds = <String>{
    'bow_release',
    'cast_fire',
    'cast_frost',
    'cast_holy',
    'cast_shadow',
    'cast_arcane',
    'cast_nature',
    'cast_lightning',
    'cast_demon',
    'cast_poison',
  };

  /// Hero projectile leaving the hand. Null for a plain weapon bolt.
  static String? launchIdFor(SpellBoltStyle style) => switch (style) {
    SpellBoltStyle.arrow => 'bow_release',
    SpellBoltStyle.fire => 'cast_fire',
    SpellBoltStyle.frost => 'cast_frost',
    SpellBoltStyle.holy => 'cast_holy',
    SpellBoltStyle.shadow => 'cast_shadow',
    SpellBoltStyle.arcane => 'cast_arcane',
    SpellBoltStyle.nature => 'cast_nature',
    SpellBoltStyle.lightning => 'cast_lightning',
    SpellBoltStyle.demon => 'cast_demon',
    SpellBoltStyle.poison => 'cast_poison',
    SpellBoltStyle.weapon => null,
  };

  /// Combat feel ids that share combat-mix gates (weapon + spell + crit/kill).
  static const Set<String> combatFeelIds = <String>{
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

  /// Body cues (hero hurt, death, tell). Own limiter, not the weapon hammer.
  static const Set<String> bodyCueIds = <String>{
    'enemy_hit',
    'hero_down',
    'heal',
    'shield',
    'boss_tell',
    'enrage',
    'enemy_die_flesh',
    'enemy_die_bone',
    'enemy_die_stone',
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

  static const Set<String> lootIds = <String>{
    'loot',
    'loot_rare',
    'loot_epic',
    'loot_legendary',
  };

  static String lootIdFor(LootRarity rarity) => switch (rarity) {
    LootRarity.rare => 'loot_rare',
    LootRarity.epic => 'loot_epic',
    LootRarity.legendary => 'loot_legendary',
    LootRarity.common || LootRarity.uncommon => 'loot',
  };

  static String enemyDieId(CombatHitMaterial material) => switch (material) {
    CombatHitMaterial.stone => 'enemy_die_stone',
    CombatHitMaterial.bone => 'enemy_die_bone',
    CombatHitMaterial.flesh || CombatHitMaterial.wet => 'enemy_die_flesh',
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
      null => 'hit_blade',
    };
  }

  static final List<String> allCatalogPaths = <String>{
    for (final variants in sfxVariants.values) ...variants,
    hubAmbience,
    for (final mood in ZoneMood.values) dungeonAmbience(mood),
    ...hubTracks,
    for (final mood in ZoneMood.values) ...dungeonTracks(mood),
    ...bossTracks,
    resolveMusic,
    downMusic,
  }.toList();
}
