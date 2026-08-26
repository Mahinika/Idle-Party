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
      blurb:
          'Shell kin and buried hatches — the Earth Kraken still pulls the sand.',
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
      blurb:
          'Corrupt banners and king-mites — the throne still wears its soldiers.',
    ),
    DungeonDef(
      number: 3,
      id: 'underworld',
      name: 'Underworld',
      layout: DungeonLayoutKind.cave,
      bossId: 'eyes',
      bossName: 'Beholder',
      unlockPrice: 50000,
      blurb:
          'Shrine eyes and cyclops sentries — the Beholder watches between kingdoms.',
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
      bossId: 'cthulhu',
      bossName: 'Cthulhu',
      unlockPrice: 200000,
      blurb:
          'Cult swarms serve the gate — Cthulhu answers below the fire.',
    ),
    DungeonDef(
      number: 6,
      id: 'crystal',
      name: 'Crystal Spire',
      layout: DungeonLayoutKind.arena,
      bossId: 'crystal_warden',
      bossName: 'Crystal Warden',
      unlockPrice: 400000,
      blurb: 'The Spire remembers every climb — endless for those who will it.',
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
      // Hideout warren — distinct chamber footprint from King's Fort.
      layout: DungeonLayoutKind.hideout,
      bossId: 'cinder_sovereign',
      bossName: 'Cinder Sovereign',
      unlockPrice: 1200000,
      blurb: 'Cooled-fire vaults and anvil heat that still answers a crown.',
    ),
    DungeonDef(
      number: 9,
      id: 'grove',
      name: 'Hollow Grove',
      layout: DungeonLayoutKind.cave,
      bossId: 'grove_wyrd',
      bossName: 'Wyrd Root',
      unlockPrice: 1800000,
      blurb:
          'Root fences and grove-slime — Wyrd Root drinks between Tidehold and Ashen.',
    ),
    DungeonDef(
      number: 10,
      id: 'storm',
      name: 'Stormwake Hollow',
      layout: DungeonLayoutKind.arena,
      bossId: 'storm_tyrant',
      bossName: 'Storm Tyrant',
      unlockPrice: 2600000,
      blurb:
          'Lightning traps and wraith packs — the Storm Tyrant rides the gale.',
    ),
    DungeonDef(
      number: 11,
      id: 'rime',
      name: 'Rimeglass Rift',
      // Open arena rift — glass chasm, not a tight cave crawl.
      layout: DungeonLayoutKind.arena,
      bossId: 'rime_colossus',
      bossName: 'Rime Colossus',
      unlockPrice: 3600000,
      blurb: 'After the gale: an open rift of glass pillars and killing cold.',
    ),
    DungeonDef(
      number: 12,
      id: 'fen',
      name: 'Blightfen Mire',
      // Open arena bog — traps in the wet, not a narrow cave.
      layout: DungeonLayoutKind.arena,
      bossId: 'fen_hydra',
      bossName: 'Fen Hydra',
      unlockPrice: 5000000,
      blurb:
          'Open poison bog — slime kin and many-headed hunger still hunt the fen.',
    ),
    DungeonDef(
      number: 13,
      id: 'brass',
      name: 'Brassvault Deep',
      layout: DungeonLayoutKind.fort,
      bossId: 'brass_mainspring',
      bossName: 'The Mainspring',
      unlockPrice: 7000000,
      blurb: 'Clockwork vaults tick behind brass stools and anvils — count the beats.',
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
          'Silk fences and moth swarms — wings beat where the clockwork ends.',
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
