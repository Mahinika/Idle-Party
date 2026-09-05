/// Asset paths for Idle Party audio (core-safe — no ui/ imports).
///
/// SFX: Kenney RPG Audio (CC0) under [sfxRoot].
/// Ambience: Idle Party procedural pads under [ambienceRoot].
abstract final class AudioAssets {
  static const sfxRoot = 'assets/kenney/audio/sfx';
  static const ambienceRoot = 'assets/custom/audio/ambience';

  static const ui = '$sfxRoot/ui.ogg';
  static const hit = '$sfxRoot/hit.ogg';
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

  static const hubAmbience = '$ambienceRoot/hub.wav';
  static const dungeonAmbience = '$ambienceRoot/dungeon.wav';

  /// Every SFX id used by [GameAudio.play] → asset path.
  static const Map<String, String> sfxById = <String, String>{
    'ui': ui,
    'hit': hit,
    'crit': crit,
    'kill': kill,
    'loot': loot,
    'flask': flask,
    'level': level,
    'clear': clear,
    'unlock': unlock,
    'boss': boss,
    'wipe': wipe,
  };

  static const List<String> allCatalogPaths = <String>[
    ui,
    hit,
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
    hubAmbience,
    dungeonAmbience,
  ];
}
