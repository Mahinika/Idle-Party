import 'dart:math';

import '../models/dungeon_room.dart';
import '../models/enemy.dart';

/// Chamber job for a pack slot — first fight swarm, mid backline, last elites.
enum PackJob { swarm, backline, elite, mixed }

/// Zone-flavoured enemy names, mix weights, and pack jobs.
///
/// Combat authority stays in [SpatialCombat]; this only decides roster identity
/// before `build`/`step`. Original Idle Party names — not dumps.
abstract final class EnemyFlavor {
  /// Which job this body plays, matching spawn order (chamber 1 → 2 → 3).
  static PackJob packJobFor({
    required int index,
    required int count,
    required RoomType type,
    bool isBossUnit = false,
  }) {
    if (isBossUnit) return PackJob.elite;
    if (type == RoomType.boss) return PackJob.mixed;
    if (count <= 1) return PackJob.mixed;
    final third = count / 3.0;
    if (index < third) return PackJob.swarm;
    if (index < third * 2) return PackJob.backline;
    return PackJob.elite;
  }

  /// Weighted archetype for this slot (zone mix × pack job).
  static EnemyArchetype pickArchetype({
    required RoomType type,
    required bool isBossUnit,
    required String dungeonId,
    required int index,
    required int count,
    required Random rng,
  }) {
    if (isBossUnit) return EnemyArchetype.tank;
    final job = packJobFor(
      index: index,
      count: count,
      type: type,
      isBossUnit: false,
    );
    final weights = <EnemyArchetype, double>{
      for (final a in EnemyArchetype.values)
        a: _zoneWeight(dungeonId, a) * _jobMul(job, a, eliteRoom: type == RoomType.elite),
    };
    return _weightedPick(weights, rng);
  }

  static String trashName(
    String dungeonId,
    EnemyArchetype archetype,
    int index,
  ) {
    final names = _trashNames[dungeonId]?[archetype] ?? _trashNames['sandy']![archetype]!;
    return names[index % names.length];
  }

  static String eliteName(String dungeonId, EnemyArchetype archetype) {
    return _eliteNames[dungeonId]?[archetype] ??
        _eliteNames['sandy']![archetype]!;
  }

  /// Named adds around a zone boss (not the boss body).
  static String addName(String dungeonId, EnemyArchetype archetype) {
    return _addNames[dungeonId]?[archetype] ?? _addNames['sandy']![archetype]!;
  }

  /// Gauntlet every-5 bosses cycle shipped-cave tells (Spire art stays).
  /// F5 = SHARD, F10 = WAVE, then the rest of the 15-zone roster.
  static const List<String> gauntletTellCycle = <String>[
    'crystal',
    'tide',
    'brass',
    'goblin',
    'king',
    'underworld',
    'dead',
    'hell',
    'ember',
    'grove',
    'storm',
    'rime',
    'fen',
    'veil',
    'sandy',
  ];

  /// Which cave's tell the Gauntlet boss on [floor] uses (boss every 5).
  static String gauntletBossDungeonId(int floor) {
    final bossIndex = max(1, floor ~/ 5);
    return gauntletTellCycle[(bossIndex - 1) % gauntletTellCycle.length];
  }

  static String gauntletBossTell(int floor) =>
      bossTell(gauntletBossDungeonId(floor));

  /// Trash support tell — same heal, zone-readable label.
  static String supportTell(String dungeonId) => switch (dungeonId) {
    'sandy' => 'MEND',
    'goblin' => 'TOTEM',
    'king' => 'BANNER',
    'underworld' => 'RITE',
    'dead' => 'DRAIN',
    'hell' => 'RITE',
    'crystal' => 'MEND',
    'tide' => 'TIDE',
    'ember' => 'STIR',
    'grove' => 'GROW',
    'storm' => 'CHARGE',
    'rime' => 'MEND',
    'fen' => 'OOZE',
    'brass' => 'OIL',
    'veil' => 'WEAVE',
    _ => 'MEND',
  };

  /// Trash ranged tell — same slow chip, zone-readable label.
  static String rangedTell(String dungeonId) => switch (dungeonId) {
    'sandy' => 'SPIT',
    'goblin' => 'HEX',
    'king' => 'MARK',
    'underworld' => 'CURSE',
    'dead' => 'WANE',
    'hell' => 'HEX',
    'crystal' => 'PING',
    'tide' => 'NET',
    'ember' => 'CINDER',
    'grove' => 'SPORE',
    'storm' => 'JOLT',
    'rime' => 'CHILL',
    'fen' => 'MUCK',
    'brass' => 'LOCK',
    'veil' => 'WEB',
    _ => 'HEX',
  };

  /// Combat floater for that zone's unique boss tell.
  static String bossTell(String dungeonId) => switch (dungeonId) {
    'sandy' => 'SLAM',
    'goblin' => 'RALLY',
    'king' => 'DECREE',
    'underworld' => 'BEAM',
    'dead' => 'FADE',
    'hell' => 'TENTACLE',
    'crystal' => 'SHARD',
    'tide' => 'WAVE',
    'ember' => 'IGNITE',
    'grove' => 'ROOT',
    'storm' => 'BOLT',
    'rime' => 'FROST',
    'fen' => 'SPIT',
    'brass' => 'WIND-UP',
    'veil' => 'SILK',
    _ => 'PULSE',
  };

  static double _zoneWeight(String dungeonId, EnemyArchetype a) {
    final row = _zoneMix[dungeonId] ?? _zoneMix['sandy']!;
    return row[a]!.toDouble();
  }

  static double _jobMul(
    PackJob job,
    EnemyArchetype a, {
    required bool eliteRoom,
  }) {
    if (job == PackJob.mixed) return 1.0;
    var swarm = a == EnemyArchetype.swarm
        ? 3.2
        : a == EnemyArchetype.brute
        ? 2.2
        : 0.35;
    var back = a == EnemyArchetype.ranged
        ? 3.2
        : a == EnemyArchetype.support
        ? 2.2
        : a == EnemyArchetype.glass
        ? 1.4
        : 0.35;
    var elite = a == EnemyArchetype.tank
        ? 2.8
        : a == EnemyArchetype.brute
        ? 2.2
        : a == EnemyArchetype.glass
        ? 1.6
        : 0.4;
    if (eliteRoom && job == PackJob.swarm) {
      // Elite first room still hits hard — brutes/glass, not filler mites.
      swarm = a == EnemyArchetype.brute
          ? 2.6
          : a == EnemyArchetype.glass
          ? 2.2
          : a == EnemyArchetype.swarm
          ? 1.2
          : 0.45;
    }
    return switch (job) {
      PackJob.swarm => swarm,
      PackJob.backline => back,
      PackJob.elite => elite,
      PackJob.mixed => 1.0,
    };
  }

  static EnemyArchetype _weightedPick(
    Map<EnemyArchetype, double> weights,
    Random rng,
  ) {
    var sum = 0.0;
    for (final w in weights.values) {
      sum += w;
    }
    if (sum <= 0) return EnemyArchetype.brute;
    var roll = rng.nextDouble() * sum;
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return EnemyArchetype.brute;
  }

  /// Mix weights per zone (higher = more of that body).
  static const Map<String, Map<EnemyArchetype, int>> _zoneMix = {
    'sandy': {
      EnemyArchetype.swarm: 3,
      EnemyArchetype.brute: 3,
      EnemyArchetype.tank: 2,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 1,
    },
    'goblin': {
      EnemyArchetype.swarm: 3,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 1,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 2,
      EnemyArchetype.support: 2,
    },
    'king': {
      EnemyArchetype.swarm: 1,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 3,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 2,
    },
    'underworld': {
      EnemyArchetype.swarm: 2,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 1,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 2,
      EnemyArchetype.support: 3,
    },
    'dead': {
      EnemyArchetype.swarm: 2,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 2,
      EnemyArchetype.ranged: 1,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 3,
    },
    'hell': {
      EnemyArchetype.swarm: 1,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 4,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 3,
    },
    'crystal': {
      EnemyArchetype.swarm: 1,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 3,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 2,
      EnemyArchetype.support: 1,
    },
    'tide': {
      EnemyArchetype.swarm: 2,
      EnemyArchetype.brute: 1,
      EnemyArchetype.tank: 1,
      EnemyArchetype.ranged: 4,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 2,
    },
    'ember': {
      EnemyArchetype.swarm: 2,
      EnemyArchetype.brute: 4,
      EnemyArchetype.tank: 1,
      EnemyArchetype.ranged: 1,
      EnemyArchetype.glass: 4,
      EnemyArchetype.support: 1,
    },
    'grove': {
      EnemyArchetype.swarm: 4,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 2,
      EnemyArchetype.ranged: 1,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 4,
    },
    'storm': {
      EnemyArchetype.swarm: 2,
      EnemyArchetype.brute: 1,
      EnemyArchetype.tank: 1,
      EnemyArchetype.ranged: 3,
      EnemyArchetype.glass: 3,
      EnemyArchetype.support: 1,
    },
    'rime': {
      EnemyArchetype.swarm: 1,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 3,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 1,
    },
    'fen': {
      EnemyArchetype.swarm: 4,
      EnemyArchetype.brute: 2,
      EnemyArchetype.tank: 1,
      EnemyArchetype.ranged: 2,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 2,
    },
    'brass': {
      EnemyArchetype.swarm: 1,
      EnemyArchetype.brute: 3,
      EnemyArchetype.tank: 4,
      EnemyArchetype.ranged: 1,
      EnemyArchetype.glass: 1,
      EnemyArchetype.support: 1,
    },
    'veil': {
      EnemyArchetype.swarm: 1,
      EnemyArchetype.brute: 1,
      EnemyArchetype.tank: 1,
      EnemyArchetype.ranged: 3,
      EnemyArchetype.glass: 4,
      EnemyArchetype.support: 2,
    },
  };

  static const Map<String, Map<EnemyArchetype, List<String>>> _trashNames = {
    'sandy': {
      EnemyArchetype.swarm: ['Cave Slime', 'Sand Mite', 'Drip Ooze'],
      EnemyArchetype.brute: ['Cave Brute', 'Rock Crab'],
      EnemyArchetype.tank: ['Shellback', 'Stone Maw'],
      EnemyArchetype.ranged: ['Spit Bat', 'Cavern Spitter'],
      EnemyArchetype.glass: ['Sand Skitter', 'Glass Skitter'],
      EnemyArchetype.support: ['Mire Shaman', 'Glow Cultist'],
    },
    'goblin': {
      EnemyArchetype.swarm: ['Goblin Scrapper', 'Hideout Runt', 'Pest'],
      EnemyArchetype.brute: ['Goblin Thug', 'Clubber'],
      EnemyArchetype.tank: ['Hideout Guard', 'Scrap Shield'],
      EnemyArchetype.ranged: ['Goblin Slinger', 'Dart Rascal'],
      EnemyArchetype.glass: ['Cutthroat', 'Knife Kin'],
      EnemyArchetype.support: ['Hex Witch', 'Totem Caller'],
    },
    'king': {
      EnemyArchetype.swarm: ['Fort Rat', 'Keep Gnawer'],
      EnemyArchetype.brute: ['Fort Sentry', 'Hall Guard'],
      EnemyArchetype.tank: ['Iron Ward', 'Gate Knight'],
      EnemyArchetype.ranged: ['Crossbowman', 'Tower Archer'],
      EnemyArchetype.glass: ['Royal Assassin', 'Blade Page'],
      EnemyArchetype.support: ['Court Mage', 'Banner Cleric'],
    },
    'underworld': {
      EnemyArchetype.swarm: ['Imp Swarm', 'Ash Tick'],
      EnemyArchetype.brute: ['Underworld Imp', 'Bone Brute'],
      EnemyArchetype.tank: ['Obsidian Golem', 'Pit Guard'],
      EnemyArchetype.ranged: ['Soul Spitter', 'Hex Spider'],
      EnemyArchetype.glass: ['Shade Stalker', 'Wisp Blade'],
      EnemyArchetype.support: ['Cult Chanter', 'Rift Adept'],
    },
    'dead': {
      EnemyArchetype.swarm: ['Risen Husk', 'Bone Swarm'],
      EnemyArchetype.brute: ['Grave Knight', 'Crypt Brute'],
      EnemyArchetype.tank: ['Tomb Shield', 'Ossuary Guard'],
      EnemyArchetype.ranged: ['Wailing Ghost', 'Bone Archer'],
      EnemyArchetype.glass: ['Specter Blade', 'Pale Reaper'],
      EnemyArchetype.support: ['Necro Acolyte', 'Death Chanter'],
    },
    'hell': {
      EnemyArchetype.swarm: ['Hellspawn', 'Cinder Rat'],
      EnemyArchetype.brute: ['Infernal Brute', 'Flame Guard'],
      EnemyArchetype.tank: ['Molten Golem', 'Ash Colossus'],
      EnemyArchetype.ranged: ['Fire Cultist', 'Ember Archer'],
      EnemyArchetype.glass: ['Flame Assassin', 'Cinder Blade'],
      EnemyArchetype.support: ['Hell Chanter', 'Rift Priest'],
    },
    'crystal': {
      EnemyArchetype.swarm: ['Frost Wisp', 'Rime Bat'],
      EnemyArchetype.brute: ['Glacial Brute', 'Shard Brawler'],
      EnemyArchetype.tank: ['Crystal Golem', 'Frozen Bulwark'],
      EnemyArchetype.ranged: ['Ice Caster', 'Frost Slinger'],
      EnemyArchetype.glass: ['Splinter Blade', 'Shatter Fang'],
      EnemyArchetype.support: ['Rime Chanter', 'Frost Adept'],
    },
    'tide': {
      EnemyArchetype.swarm: ['Brine Mite', 'Reef Tick'],
      EnemyArchetype.brute: ['Tide Brute', 'Coral Crusher'],
      EnemyArchetype.tank: ['Shell Leviathan', 'Barnacle Guard'],
      EnemyArchetype.ranged: ['Spume Spitter', 'Salt Slinger'],
      EnemyArchetype.glass: ['Razor Eel', 'Needle Urchin'],
      EnemyArchetype.support: ['Depth Chanter', 'Tide Adept'],
    },
    'ember': {
      EnemyArchetype.swarm: ['Ash Mite', 'Cinder Tick'],
      EnemyArchetype.brute: ['Vault Brute', 'Slag Brawler'],
      EnemyArchetype.tank: ['Basalt Golem', 'Ember Bulwark'],
      EnemyArchetype.ranged: ['Spark Caster', 'Cinder Slinger'],
      EnemyArchetype.glass: ['Char Blade', 'Soot Fang'],
      EnemyArchetype.support: ['Ash Chanter', 'Ember Adept'],
    },
    'grove': {
      EnemyArchetype.swarm: ['Moss Slime', 'Root Tick', 'Leaf Mite'],
      EnemyArchetype.brute: ['Grove Brute', 'Timber Crusher'],
      EnemyArchetype.tank: ['Hollow Guard', 'Bark Bulwark'],
      EnemyArchetype.ranged: ['Spore Bat', 'Canopy Spitter'],
      EnemyArchetype.glass: ['Thorn Skitter', 'Bramble Fang'],
      EnemyArchetype.support: ['Wyrd Chanter', 'Grove Adept'],
    },
    'storm': {
      EnemyArchetype.swarm: ['Gale Mite', 'Storm Tick', 'Spark Bat'],
      EnemyArchetype.brute: ['Storm Brute', 'Thunder Crusher'],
      EnemyArchetype.tank: ['Gale Bulwark', 'Storm Guard'],
      EnemyArchetype.ranged: ['Volt Spitter', 'Gale Slinger'],
      EnemyArchetype.glass: ['Lightning Fang', 'Zephyr Blade'],
      EnemyArchetype.support: ['Storm Chanter', 'Tempest Adept'],
    },
    'rime': {
      EnemyArchetype.swarm: ['Rime Mite', 'Frost Tick', 'Glass Flea'],
      EnemyArchetype.brute: ['Rime Brute', 'Frost Crusher'],
      EnemyArchetype.tank: ['Glass Bulwark', 'Rime Guard'],
      EnemyArchetype.ranged: ['Shard Slinger', 'Rime Spitter'],
      EnemyArchetype.glass: ['Glass Fang', 'Frost Blade'],
      EnemyArchetype.support: ['Glacier Chanter', 'Stillfrost Adept'],
    },
    'fen': {
      EnemyArchetype.swarm: ['Bile Slime', 'Fen Tick', 'Spore Flea'],
      EnemyArchetype.brute: ['Fen Brute', 'Mire Crusher'],
      EnemyArchetype.tank: ['Bog Bulwark', 'Fen Guard'],
      EnemyArchetype.ranged: ['Bile Spitter', 'Fen Slinger'],
      EnemyArchetype.glass: ['Rot Fang', 'Mire Blade'],
      EnemyArchetype.support: ['Fen Chanter', 'Mire Adept'],
    },
    'brass': {
      EnemyArchetype.swarm: ['Cog Mite', 'Rust Tick', 'Brass Flea'],
      EnemyArchetype.brute: ['Vault Bruiser', 'Cog Crusher'],
      EnemyArchetype.tank: ['Brass Bulwark', 'Cog Guard'],
      EnemyArchetype.ranged: ['Spark Spitter', 'Coil Slinger'],
      EnemyArchetype.glass: ['Razor Cog', 'Spring Fang'],
      EnemyArchetype.support: ['Clock Chanter', 'Brass Adept'],
    },
    'veil': {
      EnemyArchetype.swarm: ['Dust Moth', 'Veil Mite', 'Silk Flea'],
      EnemyArchetype.brute: ['Silk Bruiser', 'Veil Crusher'],
      EnemyArchetype.tank: ['Cocoon Guard', 'Veil Bulwark'],
      EnemyArchetype.ranged: ['Dust Spitter', 'Silk Slinger'],
      EnemyArchetype.glass: ['Wing Fang', 'Veil Blade'],
      EnemyArchetype.support: ['Moth Chanter', 'Veil Adept'],
    },
  };

  static const Map<String, Map<EnemyArchetype, String>> _eliteNames = {
    'sandy': {
      EnemyArchetype.tank: 'Hatch Bulwark',
      EnemyArchetype.ranged: 'Burrow Spitter',
      EnemyArchetype.glass: 'Sand Razor',
      EnemyArchetype.support: 'Cave Hexer',
      EnemyArchetype.swarm: 'Mite Alpha',
      EnemyArchetype.brute: 'Kraken Kin',
    },
    'goblin': {
      EnemyArchetype.tank: 'Stash Bulwark',
      EnemyArchetype.ranged: 'Raid Slinger',
      EnemyArchetype.glass: 'Coin Cutter',
      EnemyArchetype.support: 'Hex Hag',
      EnemyArchetype.swarm: 'Raid Pack',
      EnemyArchetype.brute: 'Club Champion',
    },
    'king': {
      EnemyArchetype.tank: 'Throne Ward',
      EnemyArchetype.ranged: 'Keep Marksman',
      EnemyArchetype.glass: 'Crown Blade',
      EnemyArchetype.support: 'Court Hexer',
      EnemyArchetype.swarm: 'Hall Swarm',
      EnemyArchetype.brute: 'Gate Champion',
    },
    'underworld': {
      EnemyArchetype.tank: 'Pit Colossus',
      EnemyArchetype.ranged: 'Eye Cultist',
      EnemyArchetype.glass: 'Shade Razor',
      EnemyArchetype.support: 'Shrine Chanter',
      EnemyArchetype.swarm: 'Imp Tide',
      EnemyArchetype.brute: 'Cyclops Kin',
    },
    'dead': {
      EnemyArchetype.tank: 'Ossuary Ward',
      EnemyArchetype.ranged: 'Wail Caller',
      EnemyArchetype.glass: 'Pale Razor',
      EnemyArchetype.support: 'Grave Hexer',
      EnemyArchetype.swarm: 'Bone Tide',
      EnemyArchetype.brute: 'Crypt Champion',
    },
    'hell': {
      EnemyArchetype.tank: 'Ash Colossus',
      EnemyArchetype.ranged: 'Cinder Cultist',
      EnemyArchetype.glass: 'Infernal Razor',
      EnemyArchetype.support: 'Gate Priest',
      EnemyArchetype.swarm: 'Spawn Tide',
      EnemyArchetype.brute: 'Flame Champion',
    },
    'crystal': {
      EnemyArchetype.tank: 'Shard Ward',
      EnemyArchetype.ranged: 'Spire Caster',
      EnemyArchetype.glass: 'Splinter Razor',
      EnemyArchetype.support: 'Frost Hexer',
      EnemyArchetype.swarm: 'Wisp Tide',
      EnemyArchetype.brute: 'Glacier Champion',
    },
    'tide': {
      EnemyArchetype.tank: 'Reef Ward',
      EnemyArchetype.ranged: 'Brine Caller',
      EnemyArchetype.glass: 'Razor Eel Alpha',
      EnemyArchetype.support: 'Depth Hexer',
      EnemyArchetype.swarm: 'Tide Swarm',
      EnemyArchetype.brute: 'Coral Champion',
    },
    'ember': {
      EnemyArchetype.tank: 'Slag Ward',
      EnemyArchetype.ranged: 'Spark Caller',
      EnemyArchetype.glass: 'Char Razor',
      EnemyArchetype.support: 'Ash Hexer',
      EnemyArchetype.swarm: 'Cinder Swarm',
      EnemyArchetype.brute: 'Vault Champion',
    },
    'grove': {
      EnemyArchetype.tank: 'Heartwood Ward',
      EnemyArchetype.ranged: 'Spore Caller',
      EnemyArchetype.glass: 'Thorn Razor',
      EnemyArchetype.support: 'Wyrd Hexer',
      EnemyArchetype.swarm: 'Root Swarm',
      EnemyArchetype.brute: 'Timber Champion',
    },
    'storm': {
      EnemyArchetype.tank: 'Gale Ward',
      EnemyArchetype.ranged: 'Volt Caller',
      EnemyArchetype.glass: 'Zephyr Razor',
      EnemyArchetype.support: 'Tempest Hexer',
      EnemyArchetype.swarm: 'Spark Swarm',
      EnemyArchetype.brute: 'Thunder Champion',
    },
    'rime': {
      EnemyArchetype.tank: 'Stillfrost Ward',
      EnemyArchetype.ranged: 'Shard Caller',
      EnemyArchetype.glass: 'Glass Razor',
      EnemyArchetype.support: 'Glacier Hexer',
      EnemyArchetype.swarm: 'Rime Swarm',
      EnemyArchetype.brute: 'Frost Champion',
    },
    'fen': {
      EnemyArchetype.tank: 'Bog Ward',
      EnemyArchetype.ranged: 'Bile Caller',
      EnemyArchetype.glass: 'Rot Razor',
      EnemyArchetype.support: 'Mire Hexer',
      EnemyArchetype.swarm: 'Spore Swarm',
      EnemyArchetype.brute: 'Hydra Kin',
    },
    'brass': {
      EnemyArchetype.tank: 'Cog Ward',
      EnemyArchetype.ranged: 'Coil Caller',
      EnemyArchetype.glass: 'Spring Razor',
      EnemyArchetype.support: 'Clock Hexer',
      EnemyArchetype.swarm: 'Cog Swarm',
      EnemyArchetype.brute: 'Mainspring Kin',
    },
    'veil': {
      EnemyArchetype.tank: 'Cocoon Ward',
      EnemyArchetype.ranged: 'Silk Caller',
      EnemyArchetype.glass: 'Wing Razor',
      EnemyArchetype.support: 'Moth Hexer',
      EnemyArchetype.swarm: 'Dust Swarm',
      EnemyArchetype.brute: 'Monarch Kin',
    },
  };

  static const Map<String, Map<EnemyArchetype, String>> _addNames = {
    'sandy': {
      EnemyArchetype.ranged: 'Hatch Spitter',
      EnemyArchetype.tank: 'Hatch Guard',
      EnemyArchetype.support: 'Hatch Adept',
      EnemyArchetype.glass: 'Hatch Blade',
      EnemyArchetype.swarm: 'Hatch Pack',
      EnemyArchetype.brute: 'Hatch Thug',
    },
    'goblin': {
      EnemyArchetype.ranged: 'Lord Slinger',
      EnemyArchetype.tank: 'Lord Guard',
      EnemyArchetype.support: 'Lord Hexer',
      EnemyArchetype.glass: 'Lord Blade',
      EnemyArchetype.swarm: 'Lord Pack',
      EnemyArchetype.brute: 'Lord Thug',
    },
    'king': {
      EnemyArchetype.ranged: 'Throne Archer',
      EnemyArchetype.tank: 'Throne Guard',
      EnemyArchetype.support: 'Throne Adept',
      EnemyArchetype.glass: 'Throne Blade',
      EnemyArchetype.swarm: 'Throne Pack',
      EnemyArchetype.brute: 'Throne Thug',
    },
    'underworld': {
      EnemyArchetype.ranged: 'Eye Spitter',
      EnemyArchetype.tank: 'Eye Guard',
      EnemyArchetype.support: 'Eye Adept',
      EnemyArchetype.glass: 'Eye Blade',
      EnemyArchetype.swarm: 'Eye Pack',
      EnemyArchetype.brute: 'Eye Thug',
    },
    'dead': {
      EnemyArchetype.ranged: 'Pale Archer',
      EnemyArchetype.tank: 'Pale Guard',
      EnemyArchetype.support: 'Pale Adept',
      EnemyArchetype.glass: 'Pale Blade',
      EnemyArchetype.swarm: 'Pale Pack',
      EnemyArchetype.brute: 'Pale Thug',
    },
    'hell': {
      EnemyArchetype.ranged: 'Gate Archer',
      EnemyArchetype.tank: 'Gate Guard',
      EnemyArchetype.support: 'Gate Adept',
      EnemyArchetype.glass: 'Gate Blade',
      EnemyArchetype.swarm: 'Gate Pack',
      EnemyArchetype.brute: 'Gate Thug',
    },
    'crystal': {
      EnemyArchetype.ranged: 'Spire Archer',
      EnemyArchetype.tank: 'Spire Guard',
      EnemyArchetype.support: 'Spire Adept',
      EnemyArchetype.glass: 'Spire Blade',
      EnemyArchetype.swarm: 'Spire Pack',
      EnemyArchetype.brute: 'Spire Thug',
    },
    'tide': {
      EnemyArchetype.ranged: 'Leviathan Spitter',
      EnemyArchetype.tank: 'Leviathan Guard',
      EnemyArchetype.support: 'Leviathan Adept',
      EnemyArchetype.glass: 'Leviathan Blade',
      EnemyArchetype.swarm: 'Leviathan Pack',
      EnemyArchetype.brute: 'Leviathan Thug',
    },
    'ember': {
      EnemyArchetype.ranged: 'Sovereign Spark',
      EnemyArchetype.tank: 'Sovereign Guard',
      EnemyArchetype.support: 'Sovereign Adept',
      EnemyArchetype.glass: 'Sovereign Blade',
      EnemyArchetype.swarm: 'Sovereign Pack',
      EnemyArchetype.brute: 'Sovereign Thug',
    },
    'grove': {
      EnemyArchetype.ranged: 'Root Spitter',
      EnemyArchetype.tank: 'Root Guard',
      EnemyArchetype.support: 'Root Adept',
      EnemyArchetype.glass: 'Root Blade',
      EnemyArchetype.swarm: 'Root Pack',
      EnemyArchetype.brute: 'Root Thug',
    },
    'storm': {
      EnemyArchetype.ranged: 'Tyrant Bolt',
      EnemyArchetype.tank: 'Tyrant Guard',
      EnemyArchetype.support: 'Tyrant Adept',
      EnemyArchetype.glass: 'Tyrant Blade',
      EnemyArchetype.swarm: 'Tyrant Pack',
      EnemyArchetype.brute: 'Tyrant Thug',
    },
    'rime': {
      EnemyArchetype.ranged: 'Colossus Shard',
      EnemyArchetype.tank: 'Colossus Guard',
      EnemyArchetype.support: 'Colossus Adept',
      EnemyArchetype.glass: 'Colossus Blade',
      EnemyArchetype.swarm: 'Colossus Pack',
      EnemyArchetype.brute: 'Colossus Thug',
    },
    'fen': {
      EnemyArchetype.ranged: 'Hydra Spitter',
      EnemyArchetype.tank: 'Hydra Guard',
      EnemyArchetype.support: 'Hydra Adept',
      EnemyArchetype.glass: 'Hydra Blade',
      EnemyArchetype.swarm: 'Hydra Pack',
      EnemyArchetype.brute: 'Hydra Thug',
    },
    'brass': {
      EnemyArchetype.ranged: 'Spring Coil',
      EnemyArchetype.tank: 'Spring Guard',
      EnemyArchetype.support: 'Spring Adept',
      EnemyArchetype.glass: 'Spring Blade',
      EnemyArchetype.swarm: 'Spring Pack',
      EnemyArchetype.brute: 'Spring Thug',
    },
    'veil': {
      EnemyArchetype.ranged: 'Monarch Silk',
      EnemyArchetype.tank: 'Monarch Guard',
      EnemyArchetype.support: 'Monarch Adept',
      EnemyArchetype.glass: 'Monarch Blade',
      EnemyArchetype.swarm: 'Monarch Pack',
      EnemyArchetype.brute: 'Monarch Thug',
    },
  };
}
