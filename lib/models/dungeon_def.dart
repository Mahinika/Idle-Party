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
  });

  final int number;
  final String id;
  final String name;
  final DungeonLayoutKind layout;
  final String bossId;
  final String bossName;
  final int unlockPrice;
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
    ),
    DungeonDef(
      number: 1,
      id: 'goblin',
      name: "Goblin's Hideout",
      layout: DungeonLayoutKind.hideout,
      bossId: 'hobgoblin',
      bossName: 'Hobgoblin Lord',
      unlockPrice: 5000,
    ),
    DungeonDef(
      number: 2,
      id: 'king',
      name: "King's Fort",
      layout: DungeonLayoutKind.fort,
      bossId: 'king',
      bossName: 'Corrupt King',
      unlockPrice: 20000,
    ),
    DungeonDef(
      number: 3,
      id: 'underworld',
      name: 'Underworld',
      layout: DungeonLayoutKind.hideout,
      bossId: 'eyes',
      bossName: 'Beholder',
      unlockPrice: 50000,
    ),
    DungeonDef(
      number: 4,
      id: 'dead',
      name: 'City of Dead',
      layout: DungeonLayoutKind.fort,
      bossId: 'no_one',
      bossName: 'The No-One',
      unlockPrice: 100000,
    ),
    DungeonDef(
      number: 5,
      id: 'hell',
      name: "Hell's Gate",
      layout: DungeonLayoutKind.cave,
      bossId: 'chtulu',
      bossName: 'Chtulu',
      unlockPrice: 200000,
    ),
    DungeonDef(
      number: 6,
      id: 'crystal',
      name: 'Crystal Spire',
      layout: DungeonLayoutKind.arena,
      bossId: 'crystal_warden',
      bossName: 'Crystal Warden',
      unlockPrice: 400000,
    ),
  ];

  static DungeonDef byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return all.first;
  }

  static bool isUnlocked(String id, int goldEarnedLifetime, int highestDungeon) {
    final def = byId(id);
    if (def.number == 0) return true;
    // Unlock by clearing previous dungeon index OR paying price once gold allows.
    return highestDungeon >= def.number - 1 || goldEarnedLifetime >= def.unlockPrice;
  }

  /// Boss appears on floor (5 + ascension level).
  static int bossFloor(int ascensionLevel) => 5 + ascensionLevel;
}
