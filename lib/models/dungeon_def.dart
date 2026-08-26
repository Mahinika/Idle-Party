/// Dungeon catalog for Idle Party (original names/layout — Kenney art only).
enum DungeonLayoutKind { cave, hideout, fort, arena }

class DungeonDef {
  const DungeonDef({
    required this.number,
    required this.id,
    required this.name,
    required this.layout,
    required this.bossId,
    required this.bossName,
    this.unlockPrice = 0,
    this.blurb = '',
  });

  final int number;
  final String id;
  final String name;
  final DungeonLayoutKind layout;
  final String bossId;
  final String bossName;
  final int unlockPrice;

  /// Short hub flavor line (also mirrored in [StoryLore.dungeonBlurb]).
  final String blurb;
}

abstract final class DungeonCatalog {
  static const List<DungeonDef> all = <DungeonDef>[
    DungeonDef(
      number: 0,
      id: 'sandy',
      name: 'Sandy Caverns',
      layout: DungeonLayoutKind.cave,
      bossId: 'kraken',
      bossName: 'Earth Kraken',
      unlockPrice: 0,
      blurb: 'Sand beasts and buried hatches — the earth still stirs below.',
    ),
    DungeonDef(
      number: 1,
      id: 'goblin',
      name: "Goblin's Hideout",
      layout: DungeonLayoutKind.hideout,
      bossId: 'hobgoblin',
      bossName: 'Hobgoblin Lord',
      unlockPrice: 5000,
      blurb: 'Raiders nest on stolen stashes — watch the chests.',
    ),
    DungeonDef(
      number: 2,
      id: 'king',
      name: "King's Fort",
      layout: DungeonLayoutKind.fort,
      bossId: 'king',
      bossName: 'Corrupt King',
      unlockPrice: 20000,
      blurb: 'A throne bent toward the same light that calls downward.',
    ),
    DungeonDef(
      number: 3,
      id: 'underworld',
      name: 'Underworld',
      layout: DungeonLayoutKind.cave,
      bossId: 'eyes',
      bossName: 'Beholder',
      unlockPrice: 50000,
      blurb: 'Eyes open in the dark between kingdoms.',
    ),
    DungeonDef(
      number: 4,
      id: 'dead',
      name: 'City of Dead',
      layout: DungeonLayoutKind.arena,
      bossId: 'no_one',
      bossName: 'The No-One',
      unlockPrice: 100000,
      blurb: 'A city that forgot its living names — grave goods still wait.',
    ),
    DungeonDef(
      number: 5,
      id: 'hell',
      name: "Hell's Gate",
      layout: DungeonLayoutKind.fort,
      bossId: 'chtulu',
      bossName: 'Cthulhu',
      unlockPrice: 200000,
      blurb: 'The gate that should never have been named.',
    ),
    DungeonDef(
      number: 6,
      id: 'crystal',
      name: 'Crystal Spire',
      layout: DungeonLayoutKind.arena,
      bossId: 'crystal_warden',
      bossName: 'Crystal Warden',
      unlockPrice: 400000,
      blurb: 'The Spire remembers every will that climbed it.',
    ),
    DungeonDef(
      number: 7,
      id: 'tide',
      name: 'Sunken Tidehold',
      layout: DungeonLayoutKind.fort,
      bossId: 'tide_leviathan',
      bossName: 'Tide Leviathan',
      unlockPrice: 750000,
      blurb: 'Flooded vaults and salt pressure seal a hold that should have drowned.',
    ),
    DungeonDef(
      number: 8,
      id: 'ember',
      name: 'Ashen Vault',
      layout: DungeonLayoutKind.fort,
      bossId: 'cinder_sovereign',
      bossName: 'Cinder Sovereign',
      unlockPrice: 1200000,
      blurb: 'A vault of cooled fire that still answers to a crown.',
    ),
    DungeonDef(
      number: 9,
      id: 'grove',
      name: 'Hollow Grove',
      layout: DungeonLayoutKind.cave,
      bossId: 'grove_wyrd',
      bossName: 'Wyrd Root',
      unlockPrice: 1800000,
      blurb: 'Root fences drink the dark between Tidehold and the Ashen Vault.',
    ),
    DungeonDef(
      number: 10,
      id: 'storm',
      name: 'Stormwake Hollow',
      layout: DungeonLayoutKind.arena,
      bossId: 'storm_tyrant',
      bossName: 'Storm Tyrant',
      unlockPrice: 2600000,
      blurb: 'Wind tears the last gate — lightning remembers every will.',
    ),
    DungeonDef(
      number: 11,
      id: 'rime',
      name: 'Rimeglass Rift',
      layout: DungeonLayoutKind.cave,
      bossId: 'rime_colossus',
      bossName: 'Rime Colossus',
      unlockPrice: 3600000,
      blurb: 'After the gale: a quiet rift of glass and killing cold.',
    ),
    DungeonDef(
      number: 12,
      id: 'fen',
      name: 'Blightfen Mire',
      layout: DungeonLayoutKind.cave,
      bossId: 'fen_hydra',
      bossName: 'Fen Hydra',
      unlockPrice: 5000000,
      blurb: 'The ice thaws into a poisoned mire. Something wet still hunts.',
    ),
    DungeonDef(
      number: 13,
      id: 'brass',
      name: 'Brassvault Deep',
      layout: DungeonLayoutKind.fort,
      bossId: 'brass_mainspring',
      bossName: 'The Mainspring',
      unlockPrice: 7000000,
      blurb: 'Buried clockwork vaults — something still ticks in the dark.',
    ),
    DungeonDef(
      number: 14,
      id: 'veil',
      name: 'Mothveil Hollow',
      layout: DungeonLayoutKind.cave,
      bossId: 'veil_monarch',
      bossName: 'The Pale Monarch',
      unlockPrice: 10000000,
      blurb:
          'Silk dust hangs where the clockwork ends. Wings beat in the dark.',
    ),
  ];

  static DungeonDef byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return all.first;
  }

  /// Party mean level to unlock this zone (zone 0 = 1, last zone = 100).
  /// Even steps across [1 .. 100] for the catalog order.
  static int unlockHeroLevel(DungeonDef def) {
    if (def.number <= 0) return 1;
    const cap = 100;
    final last = all.length - 1;
    if (last <= 0) return 1;
    return 1 + ((def.number * (cap - 1)) / last).round();
  }

  /// Unlocked by clearing the previous zone **or** reaching [unlockHeroLevel].
  /// [partyLevel] is the active party's mean hero level.
  static bool isUnlocked(
    String id,
    int partyLevel,
    int highestDungeon,
  ) {
    final def = byId(id);
    if (def.number == 0) return true;
    return highestDungeon >= def.number - 1 ||
        partyLevel >= unlockHeroLevel(def);
  }

  /// Boss appears on floor (5 + ascension level).
  static int bossFloor(int ascensionLevel) => 5 + ascensionLevel;
}
