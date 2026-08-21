import 'dart:math';

import '../models/dungeon_def.dart';
import '../models/dungeon_room.dart';
import '../models/enemy.dart';
import '../models/hero.dart';
import '../models/loot.dart';
import '../models/stats.dart';
import 'dungeon_generator.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'keystone.dart';

/// How hard a room is, who stands in it, and what killing it is worth.
///
/// One combat wave per floor: the budget decides total enemy attack/HP/gold,
/// then the roster spends that budget on archetypes with zone-flavoured names.
/// [SpatialCombat] stays the authority on the fight itself.
abstract final class EncounterFactory {
  /// Combat budget for a room: total effective attack/HP/gold the enemy
  /// group should add up to. Tuned so fresh parties barely scrape early floors.
  ///
  /// Mid-game pressure: [ascensionLevel] and [gearPressure] scale threat so
  /// filling empty slots does not trivialize the same floors.
  static ({int attack, int hp, int gold}) roomCombatBudget(
    DungeonRoom room, {
    String? dungeonId,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
  }) {
    final level = room.globalBattleNumber;
    final isBoss = room.type == RoomType.boss;
    final isElite = room.type == RoomType.elite;
    final diff = DungeonGenerator.getDifficultyMultiplier(room.type);
    final zone = DungeonCatalog.byId(dungeonId ?? 'sandy').number;
    // Bosses use a gentler zone ramp — late zones were spike-wiping.
    final zoneMult = 1.0 + zone * (isBoss ? 0.22 : 0.28);
    final hm = hardmodeLevel.clamp(0, Keystone.maxLevel);
    // Key 20 ≈ old HM+10 (10× threat). See [Keystone.threatMul].
    final hmThreat = Keystone.threatMul(hm);
    final hmGold = Keystone.goldMul(hm);
    final alThreatRaw = 1.0 + ascensionLevel.clamp(0, 40) * 0.08;
    // Fresh post-ascend (gear wiped) — soften AL threat until kit rebuilds.
    final freshAscendEase = gearPressure <= 1.08 && ascensionLevel > 0
        ? 0.65
        : 1.0;
    final alThreat = alThreatRaw * freshAscendEase;
    // Fresh early floors: don't let gear-pressure spike packs before F5.
    // AL0 boss: keep mild pressure so farmed loot helps heroes more than enemies.
    final gp = appliedGearPressure(
      gearPressure,
      level: level,
      ascensionLevel: ascensionLevel,
    );
    final threat = hmThreat * alThreat;
    // Early attrition ramp: F1–F3 clearable for fresh parties; first AL0 boss
    // must be beatable after a short Sandy farm (LIGHT), not MID-only.
    final earlyEase = switch (level) {
      1 => 0.94,
      2 => 0.90,
      3 => 0.86,
      4 => 0.92,
      5 when ascensionLevel == 0 => 0.72,
      5 || 6 when freshAscendEase < 1.0 => 0.94,
      _ => 1.0,
    };

    // Attrition curve: packs hurt over time, not via one-shots.
    // Extra quadratic after F2 so geared mid-run parties still feel pressure.
    final curve = level + ((level * level) ~/ 12);
    final midFloor = max(0, level - 2);
    final midHpBump = midFloor * midFloor * 12;
    // First Sandy boss: softer flats so AUTO-equipped F1–4 loot is enough.
    final firstSandyBoss = isBoss && ascensionLevel == 0 && level <= 5;
    final bossFlatHp = firstSandyBoss ? 280 : (isBoss ? 600 : 0);
    final bossFlatAtk = firstSandyBoss ? 10 : (isBoss ? 22 : 0);
    final attack =
        ((((42 + bossFlatAtk + (isElite ? 10 : 0)) + curve * 5.5) *
                    diff *
                    zoneMult *
                    earlyEase) *
                threat *
                (1.0 + (gp - 1.0) * 0.7))
            .round();
    final hp =
        ((((380 + level * 62 + (level ~/ 2) * 55 + midHpBump) +
                        bossFlatHp +
                        (isElite ? 180 : 0)) *
                    diff *
                    zoneMult *
                    earlyEase) *
                threat *
                gp)
            .round();
    final gold =
        (((12 + level * 2.5) *
                    (isBoss ? 3.4 : 1.0) *
                    diff *
                    zoneMult *
                    (1.0 + ascensionLevel.clamp(0, 20) * 0.025)) *
                hmGold)
            .round();

    return (attack: attack, hp: hp, gold: gold);
  }

  /// Slice of [partyGearPressure] that actually scales this floor.
  ///
  /// Early Sandy floors only take a fraction of loot-threat so picking up
  /// ~10 upgrades helps F3 instead of scaling packs into a wipe wall
  /// (GEAR10 was 0% F3 while a naked party still cleared ~30%).
  static double appliedGearPressure(
    double gearPressure, {
    required int level,
    int ascensionLevel = 0,
  }) {
    final gpRaw = gearPressure.clamp(1.0, 2.5);
    return switch ((level, ascensionLevel)) {
      (final l, _) when l <= 4 => 1.0 + (gpRaw - 1.0) * (0.10 + l * 0.06),
      (5, 0) => 1.0 + (gpRaw - 1.0) * 0.4,
      _ => gpRaw,
    };
  }

  /// How much equipped loot should pull dungeon threat.
  /// Starters barely register; ~8–12 real upgrades is where pressure bites.
  static double partyGearPressure(GameState state) {
    var meaningful = 0;
    var primaryScore = 0;
    for (final hero in state.heroes) {
      for (final item in hero.equipped.values) {
        // Ignore class starters / fill-ins — only real drops pull threat.
        if (item.id.startsWith('start_') || item.id.contains('_fill')) {
          continue;
        }
        // Apex kept through Ascend must not cancel fresh-AL threat ease.
        if (item.isApex) continue;
        final primary =
            item.strengthBonus +
            item.agilityBonus +
            item.staminaBonus +
            item.intellectBonus +
            item.spiritBonus +
            item.spellPowerBonus;
        if (primary >= 4 || item.rarity.index >= LootRarity.uncommon.index) {
          meaningful++;
          primaryScore += primary;
        }
      }
    }
    // ~4 pieces ≈ mild; ~10 pieces ≈ +70–100% HP threat.
    final pieceRamp = max(0, meaningful - 2) * 0.085;
    final scoreRamp = (primaryScore * 0.0028).clamp(0.0, 1.15);
    return (1.0 + pieceRamp + scoreRamp).clamp(1.0, 2.85);
  }

  /// XP required to go from [level] → level+1.
  static int xpPoolForLevel(int level) {
    final L = max(1, level);
    return 24 + (L * 16) + ((L * L) ~/ 2);
  }

  /// Combat XP granted for defeating one enemy.
  static int xpForEnemy(EnemyUnit enemy) {
    var xp = 5 + enemy.level + (enemy.level ~/ 3);
    xp += switch (enemy.role) {
      EnemyRole.boss => 28,
      EnemyRole.elite => 10,
      EnemyRole.normal => 0,
    };
    xp += switch (enemy.archetype) {
      EnemyArchetype.tank => 3,
      EnemyArchetype.glass => 2,
      EnemyArchetype.ranged => 2,
      EnemyArchetype.support => 1,
      EnemyArchetype.swarm => 0,
      EnemyArchetype.brute => 1,
    };
    return xp;
  }

  /// Awards [amount] XP to every hero (living or downed); levels up when pools fill.
  /// Heroes 3+ levels behind party mean get a soft catch-up bonus.
  static GameState awardPartyXp(GameState state, int amount) {
    if (amount <= 0) return state;
    final boosted =
        amount +
        (amount * (state.sanctuaryXpBonusPercent + state.petXpFindPercent)) ~/
            100;
    final meanLevel = state.heroes.isEmpty
        ? 1
        : max(
            1,
            state.heroes.fold<int>(0, (s, h) => s + h.level) ~/
                state.heroes.length,
          );
    final heroes = <PartyHero>[];
    var leveled = false;
    for (final hero in state.heroes) {
      final gain = hero.level + 3 < meanLevel
          ? (boosted * 1.4).round()
          : boosted;
      var level = hero.level;
      var xp = hero.xp + gain;
      var hp = hero.currentHp;
      var guard = 0;
      while (guard < 40) {
        guard++;
        final need = xpPoolForLevel(level);
        if (xp < need) break;
        xp -= need;
        level += 1;
        leveled = true;
        final grown = hero.copyWith(level: level);
        if (hero.isAlive) {
          hp = min(
            state.effectiveHeroMaxHp(grown),
            hp + 5 + state.vitalityBonus ~/ 4,
          );
        }
      }
      heroes.add(hero.copyWith(level: level, xp: xp, currentHp: hp));
    }
    final next = state.copyWith(heroes: heroes, lastUpdated: DateTime.now());
    return leveled ? next : next;
  }

  static GameState awardEnemyKillXp(GameState state, EnemyUnit enemy) =>
      awardPartyXp(state, xpForEnemy(enemy));

  /// Builds the enemy group for a room. Treasure rooms have no enemies.
  /// [threatScale] < 1 softens packs (used for AFK spatial sim).
  /// Pass [fromState] to apply AL + gear-pressure scaling automatically.
  static List<EnemyUnit> createEnemyGroup(
    DungeonRoom room, {
    String? dungeonId,
    bool bossRush = false,
    double threatScale = 1.0,
    int hardmodeLevel = 0,
    int ascensionLevel = 0,
    double gearPressure = 1.0,
    GameState? fromState,
  }) {
    if (room.type == RoomType.treasure || room.enemyCount == 0) {
      return <EnemyUnit>[];
    }

    final id = dungeonId ?? fromState?.dungeonId ?? 'sandy';
    final hm = fromState != null
        ? Keystone.combatLevel(fromState, fallback: hardmodeLevel)
        : hardmodeLevel.clamp(0, Keystone.maxLevel);
    final al = fromState?.ascensionLevel ?? ascensionLevel;
    final affixes = fromState != null && fromState.keystoneRunActive
        ? fromState.keystoneRunAffixes
        : const <String>[];
    final rush =
        (fromState?.challengeBossRush ?? bossRush) ||
        affixes.contains('boss_rush');
    final glassWeek = affixes.contains('glass');
    final swarmWeek = affixes.contains('swarm');
    final eliteWeek = affixes.contains('elite');
    final fortuneWeek = affixes.contains('fortune');
    final ironWeek = affixes.contains('iron');
    final fortified = affixes.contains('fortified');
    final tyrannical = affixes.contains('tyrannical');
    final level = room.globalBattleNumber;
    final gp = appliedGearPressure(
      fromState != null ? partyGearPressure(fromState) : gearPressure,
      level: level,
      ascensionLevel: al,
    );
    var budget = roomCombatBudget(
      room,
      dungeonId: id,
      hardmodeLevel: hm,
      ascensionLevel: al,
      gearPressure: fromState != null
          ? partyGearPressure(fromState)
          : gearPressure,
    );
    // Keystone affixes (Mythic+-style) — only during an active key run.
    if (eliteWeek) {
      budget = (
        attack: (budget.attack * 1.15).round(),
        hp: (budget.hp * 1.2).round(),
        gold: (budget.gold * 1.1).round(),
      );
    }
    if (ironWeek) {
      budget = (
        attack: (budget.attack * 1.1).round(),
        hp: (budget.hp * 1.25).round(),
        gold: (budget.gold * 1.2).round(),
      );
    }
    if (fortuneWeek) {
      budget = (
        attack: budget.attack,
        hp: budget.hp,
        gold: (budget.gold * 1.15).round(),
      );
    }
    final isBossRoomEarly = room.type == RoomType.boss;
    if (fortified && !isBossRoomEarly) {
      budget = (
        attack: (budget.attack * 1.22).round(),
        hp: (budget.hp * 1.28).round(),
        gold: budget.gold,
      );
    }
    if (tyrannical && isBossRoomEarly) {
      budget = (
        attack: (budget.attack * 1.32).round(),
        hp: (budget.hp * 1.4).round(),
        gold: (budget.gold * 1.1).round(),
      );
    }
    // Key densifies packs; Swarm multiplies count before key density.
    final baseCount = max(
      1,
      (room.enemyCount * (swarmWeek ? 1.35 : 1.0)).round(),
    );
    final count = min(
      80,
      max(1, (baseCount * Keystone.densityMul(hm)).round()),
    );
    // Full density keep: each body still carries HM-scaled HP/ATK (not diluted).
    final density = count / baseCount;
    var packAttack = (budget.attack * density).round();
    var packHp = (budget.hp * density).round();
    var packGold =
        (budget.gold *
                (1.0 + (density - 1.0) * Keystone.densityGoldShare))
            .round();
    // 5-man parties hit harder — scale threat so early floors stay fair.
    final partySize = fromState?.heroes.length ?? 4;
    if (partySize >= 5) {
      packAttack = (packAttack * 1.12).round();
      packHp = (packHp * 1.18).round();
    }
    if (fromState?.inGauntlet ?? false) {
      final threat = GameLogic.gauntletThreatMul(room.floorNumber);
      packAttack = max(1, (packAttack * threat).round());
      packHp = max(1, (packHp * threat).round());
      // Gold mul applied once on clear via goldGain — not here.
    }
    final dungeon = DungeonCatalog.byId(id);
    final bossName = dungeon.bossName;
    final zone = dungeon.number;
    final rng = Random(level * 9173 + id.hashCode + room.type.index * 41);
    final isBossRoom = isBossRoomEarly;
    final pickType = eliteWeek && !isBossRoom ? RoomType.elite : room.type;

    final archetypes = <EnemyArchetype>[
      for (var i = 0; i < count; i++)
        rush && !(isBossRoom && i == 0)
            ? (i == 0
                  ? EnemyArchetype.tank
                  : _pickArchetype(RoomType.elite, isBossUnit: false, rng: rng))
            : _pickArchetype(
                pickType,
                isBossUnit: isBossRoom && i == 0,
                rng: rng,
              ),
    ];

    // Weight shares by archetype (tanks eat HP budget, glass eats ATK).
    final rawShares = <double>[
      for (final a in archetypes) _archetypeBudgetWeight(a),
    ];
    if (room.type == RoomType.boss && rawShares.isNotEmpty) {
      // AL0 first boss: less of the pack budget locked in the boss body.
      // Mid/late zones: soften the 2.4× spike that wiped AL3–4 parties.
      final bossShare = (al == 0 && level <= 5)
          ? 1.55
          : (zone >= 3 ? 2.05 : 2.4);
      rawShares[0] *= bossShare;
    }
    final shareSum = rawShares.fold<double>(0, (s, v) => s + v);
    final shares = rawShares.map((w) => w / shareSum).toList();

    final group = <EnemyUnit>[];
    var hpLeft = packHp;
    var attackLeft = packAttack;
    var goldLeft = packGold;

    // Front-load threat: early indices (first chambers) eat more of the budget
    // so gated maps still hurt before the whole pack wakes.
    final frontWeights = <double>[
      for (var i = 0; i < count; i++) shares[i] * (1.55 - (i / count) * 0.9),
    ];
    final frontSum = frontWeights.fold<double>(0, (s, v) => s + v);
    final adjShares = frontWeights.map((w) => w / frontSum).toList();

    // Absolute floor so a single woken mob is never free.
    // Early floors ease the floor so fresh parties aren't deleted by min-stats.
    final earlyMinEase = switch (level) {
      1 => 0.52,
      2 => 0.60,
      3 => 0.68,
      4 => 0.80,
      5 when al == 0 => 0.78,
      _ => 1.0,
    };
    final minHp = max(
      (55 * earlyMinEase).round().clamp(28, 110),
      ((90 + level * 42 + (isBossRoom ? 140 : 0)) *
              (0.75 + gp * 0.25) *
              earlyMinEase)
          .round(),
    );
    final minAtk = max(
      (12 * earlyMinEase).round().clamp(6, 28),
      ((24 + level * 8 + (isBossRoom ? 12 : 0)) *
              (0.85 + (gp - 1.0) * 0.4) *
              earlyMinEase)
          .round(),
    );

    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final archetype = archetypes[i];
      final skew = _archetypeStatSkew(archetype);
      final baseHp = isLast ? hpLeft : max(1, (packHp * adjShares[i]).round());
      final baseAtk = isLast
          ? max(1, attackLeft)
          : max(1, (packAttack * adjShares[i]).round());
      final gold = isLast
          ? max(0, goldLeft)
          : (packGold * adjShares[i]).round();
      hpLeft -= baseHp;
      attackLeft -= baseAtk;
      goldLeft -= gold;

      // Boss Rush: every non-boss pack fights like an elite pull.
      final rushMult = rush && !(isBossRoom && i == 0) ? 1.6 : 1.0;
      final hpRaw = max(
        (minHp * threatScale).round(),
        (baseHp * skew.hp * rushMult * threatScale).round(),
      );
      final atkRaw = max(
        (minAtk * threatScale).round(),
        (baseAtk * skew.atk * rushMult * threatScale).round(),
      );
      final hp = glassWeek ? max(1, (hpRaw * 0.75).round()) : hpRaw;
      final attack = glassWeek ? max(1, (atkRaw * 1.2).round()) : atkRaw;
      // DEF scales hard so fights aren't melted by raw ATK.
      final partyLevel = max(1, level);
      final isBossUnit = isBossRoom && i == 0;
      final role = isBossUnit
          ? EnemyRole.boss
          : (rush ||
                eliteWeek ||
                room.type == RoomType.boss ||
                room.type == RoomType.elite)
          ? EnemyRole.elite
          : EnemyRole.normal;
      final defense =
          ((skew.def +
                      (partyLevel ~/ 3) +
                      (isBossUnit ? 6 : 0) +
                      (role == EnemyRole.elite ? 2 : 0) +
                      (rush && !isBossUnit ? 2 : 0)) *
                  (0.7 + gp * 0.3))
              .round();

      final namingType = (rush && !isBossUnit) || (eliteWeek && !isBossUnit)
          ? RoomType.elite
          : room.type;

      group.add(
        EnemyUnit(
          name: _enemyNameFor(
            namingType,
            isBossUnit: isBossUnit,
            bossName: bossName,
            archetype: archetype,
            dungeonId: id,
            index: i,
          ),
          level: level,
          currentHp: hp,
          stats: Stats.enemy(attack: attack, defense: defense, maxHp: hp),
          rewardGold: rush ? (gold * 3) ~/ 2 : gold,
          role: role,
          archetype: archetype,
        ),
      );
    }

    return group;
  }

  static EnemyArchetype _pickArchetype(
    RoomType type, {
    required bool isBossUnit,
    required Random rng,
  }) {
    if (isBossUnit) return EnemyArchetype.tank;
    if (type == RoomType.elite) {
      return switch (rng.nextInt(5)) {
        0 => EnemyArchetype.tank,
        1 => EnemyArchetype.ranged,
        2 => EnemyArchetype.glass,
        3 => EnemyArchetype.support,
        _ => EnemyArchetype.brute,
      };
    }
    return switch (rng.nextInt(12)) {
      0 || 1 => EnemyArchetype.swarm,
      2 || 3 => EnemyArchetype.brute,
      4 || 5 => EnemyArchetype.tank,
      6 || 7 => EnemyArchetype.ranged,
      8 || 9 => EnemyArchetype.glass,
      _ => EnemyArchetype.support,
    };
  }

  static double _archetypeBudgetWeight(EnemyArchetype a) => switch (a) {
    EnemyArchetype.swarm => 0.55,
    EnemyArchetype.brute => 1.0,
    EnemyArchetype.tank => 1.45,
    EnemyArchetype.ranged => 0.85,
    EnemyArchetype.glass => 0.65,
    EnemyArchetype.support => 0.7,
  };

  static ({double hp, double atk, int def}) _archetypeStatSkew(
    EnemyArchetype a,
  ) => switch (a) {
    EnemyArchetype.swarm => (hp: 0.7, atk: 0.95, def: 1),
    EnemyArchetype.brute => (hp: 1.15, atk: 1.15, def: 2),
    EnemyArchetype.tank => (hp: 1.7, atk: 0.8, def: 7),
    EnemyArchetype.ranged => (hp: 0.85, atk: 1.25, def: 2),
    EnemyArchetype.glass => (hp: 0.55, atk: 1.55, def: 0),
    EnemyArchetype.support => (hp: 0.9, atk: 0.9, def: 2),
  };

  static String _enemyNameFor(
    RoomType type, {
    required bool isBossUnit,
    required String bossName,
    required EnemyArchetype archetype,
    required String dungeonId,
    required int index,
  }) {
    if (isBossUnit) {
      return bossName;
    }
    if (type == RoomType.elite) {
      if (dungeonId == 'goblin') {
        return switch (archetype) {
          EnemyArchetype.tank => 'Stash Bulwark',
          EnemyArchetype.ranged => 'Raid Slinger',
          EnemyArchetype.glass => 'Coin Cutter',
          EnemyArchetype.support => 'Hex Hag',
          EnemyArchetype.swarm => 'Raid Pack',
          EnemyArchetype.brute => 'Club Champion',
        };
      }
      return switch (archetype) {
        EnemyArchetype.tank => 'Bulwark Golem',
        EnemyArchetype.ranged => 'Hex Cultist',
        EnemyArchetype.glass => 'Blood Stalker',
        EnemyArchetype.support => 'Rift Adept',
        EnemyArchetype.swarm => 'Pack Alpha',
        EnemyArchetype.brute => 'Elite Brute',
      };
    }
    if (type == RoomType.boss) {
      if (dungeonId == 'goblin') {
        return switch (archetype) {
          EnemyArchetype.ranged => 'Lord Slinger',
          EnemyArchetype.tank => 'Lord Guard',
          EnemyArchetype.support => 'Lord Hexer',
          EnemyArchetype.glass => 'Lord Blade',
          EnemyArchetype.swarm => 'Lord Pack',
          EnemyArchetype.brute => 'Lord Thug',
        };
      }
      return switch (archetype) {
        EnemyArchetype.ranged => 'Warden Archer',
        EnemyArchetype.tank => 'Warden Shield',
        EnemyArchetype.support => 'Warden Adept',
        EnemyArchetype.glass => 'Warden Blade',
        EnemyArchetype.swarm => 'Warden Pack',
        EnemyArchetype.brute => 'Warden Guard',
      };
    }
    return _zoneArchetypeName(dungeonId, archetype, index);
  }

  static String _zoneArchetypeName(
    String dungeonId,
    EnemyArchetype archetype,
    int index,
  ) {
    final table = switch (dungeonId) {
      'sandy' => const {
        EnemyArchetype.swarm: ['Cave Slime', 'Sand Mite', 'Drip Ooze'],
        EnemyArchetype.brute: ['Cave Brute', 'Rock Crab'],
        EnemyArchetype.tank: ['Shellback', 'Stone Maw'],
        EnemyArchetype.ranged: ['Spit Bat', 'Cavern Spitter'],
        EnemyArchetype.glass: ['Sand Skitter', 'Glass Skitter'],
        EnemyArchetype.support: ['Mire Shaman', 'Glow Cultist'],
      },
      'goblin' => const {
        EnemyArchetype.swarm: ['Goblin Scrapper', 'Hideout Runt', 'Pest'],
        EnemyArchetype.brute: ['Goblin Thug', 'Clubber'],
        EnemyArchetype.tank: ['Hideout Guard', 'Scrap Shield'],
        EnemyArchetype.ranged: ['Goblin Slinger', 'Dart Rascal'],
        EnemyArchetype.glass: ['Cutthroat', 'Knife Kin'],
        EnemyArchetype.support: ['Hex Witch', 'Totem Caller'],
      },
      'king' => const {
        EnemyArchetype.swarm: ['Fort Rat', 'Keep Gnawer'],
        EnemyArchetype.brute: ['Fort Sentry', 'Hall Guard'],
        EnemyArchetype.tank: ['Iron Ward', 'Gate Knight'],
        EnemyArchetype.ranged: ['Crossbowman', 'Tower Archer'],
        EnemyArchetype.glass: ['Royal Assassin', 'Blade Page'],
        EnemyArchetype.support: ['Court Mage', 'Banner Cleric'],
      },
      'underworld' => const {
        EnemyArchetype.swarm: ['Imp Swarm', 'Ash Tick'],
        EnemyArchetype.brute: ['Underworld Imp', 'Bone Brute'],
        EnemyArchetype.tank: ['Obsidian Golem', 'Pit Guard'],
        EnemyArchetype.ranged: ['Soul Spitter', 'Hex Spider'],
        EnemyArchetype.glass: ['Shade Stalker', 'Wisp Blade'],
        EnemyArchetype.support: ['Cult Chanter', 'Rift Adept'],
      },
      'dead' => const {
        EnemyArchetype.swarm: ['Risen Husk', 'Bone Swarm'],
        EnemyArchetype.brute: ['Grave Knight', 'Crypt Brute'],
        EnemyArchetype.tank: ['Tomb Shield', 'Ossuary Guard'],
        EnemyArchetype.ranged: ['Wailing Ghost', 'Bone Archer'],
        EnemyArchetype.glass: ['Specter Blade', 'Pale Reaper'],
        EnemyArchetype.support: ['Necro Acolyte', 'Death Chanter'],
      },
      'hell' => const {
        EnemyArchetype.swarm: ['Hellspawn', 'Cinder Rat'],
        EnemyArchetype.brute: ['Infernal Brute', 'Flame Guard'],
        EnemyArchetype.tank: ['Molten Golem', 'Ash Colossus'],
        EnemyArchetype.ranged: ['Fire Cultist', 'Ember Archer'],
        EnemyArchetype.glass: ['Flame Assassin', 'Cinder Blade'],
        EnemyArchetype.support: ['Hell Chanter', 'Rift Priest'],
      },
      'crystal' => const {
        EnemyArchetype.swarm: ['Frost Wisp', 'Rime Bat'],
        EnemyArchetype.brute: ['Glacial Brute', 'Shard Brawler'],
        EnemyArchetype.tank: ['Crystal Golem', 'Frozen Bulwark'],
        EnemyArchetype.ranged: ['Ice Caster', 'Frost Slinger'],
        EnemyArchetype.glass: ['Splinter Blade', 'Shatter Fang'],
        EnemyArchetype.support: ['Rime Chanter', 'Frost Adept'],
      },
      'tide' => const {
        EnemyArchetype.swarm: ['Brine Mite', 'Reef Tick'],
        EnemyArchetype.brute: ['Tide Brute', 'Coral Crusher'],
        EnemyArchetype.tank: ['Shell Leviathan', 'Barnacle Guard'],
        EnemyArchetype.ranged: ['Spume Spitter', 'Salt Slinger'],
        EnemyArchetype.glass: ['Razor Eel', 'Needle Urchin'],
        EnemyArchetype.support: ['Depth Chanter', 'Tide Adept'],
      },
      'ember' => const {
        EnemyArchetype.swarm: ['Ash Mite', 'Cinder Tick'],
        EnemyArchetype.brute: ['Vault Brute', 'Slag Brawler'],
        EnemyArchetype.tank: ['Basalt Golem', 'Ember Bulwark'],
        EnemyArchetype.ranged: ['Spark Caster', 'Cinder Slinger'],
        EnemyArchetype.glass: ['Char Blade', 'Soot Fang'],
        EnemyArchetype.support: ['Ash Chanter', 'Ember Adept'],
      },
      'grove' => const {
        EnemyArchetype.swarm: ['Moss Slime', 'Root Tick', 'Leaf Mite'],
        EnemyArchetype.brute: ['Grove Brute', 'Timber Crusher'],
        EnemyArchetype.tank: ['Hollow Guard', 'Bark Bulwark'],
        EnemyArchetype.ranged: ['Spore Bat', 'Canopy Spitter'],
        EnemyArchetype.glass: ['Thorn Skitter', 'Bramble Fang'],
        EnemyArchetype.support: ['Wyrd Chanter', 'Grove Adept'],
      },
      'storm' => const {
        EnemyArchetype.swarm: ['Gale Mite', 'Storm Tick', 'Spark Bat'],
        EnemyArchetype.brute: ['Storm Brute', 'Thunder Crusher'],
        EnemyArchetype.tank: ['Gale Bulwark', 'Storm Guard'],
        EnemyArchetype.ranged: ['Volt Spitter', 'Gale Slinger'],
        EnemyArchetype.glass: ['Lightning Fang', 'Zephyr Blade'],
        EnemyArchetype.support: ['Storm Chanter', 'Tempest Adept'],
      },
      'rime' => const {
        EnemyArchetype.swarm: ['Rime Mite', 'Frost Tick', 'Glass Flea'],
        EnemyArchetype.brute: ['Rime Brute', 'Frost Crusher'],
        EnemyArchetype.tank: ['Glass Bulwark', 'Rime Guard'],
        EnemyArchetype.ranged: ['Shard Slinger', 'Rime Spitter'],
        EnemyArchetype.glass: ['Glass Fang', 'Frost Blade'],
        EnemyArchetype.support: ['Glacier Chanter', 'Stillfrost Adept'],
      },
      'fen' => const {
        EnemyArchetype.swarm: ['Bile Slime', 'Fen Tick', 'Spore Flea'],
        EnemyArchetype.brute: ['Fen Brute', 'Mire Crusher'],
        EnemyArchetype.tank: ['Bog Bulwark', 'Fen Guard'],
        EnemyArchetype.ranged: ['Bile Spitter', 'Fen Slinger'],
        EnemyArchetype.glass: ['Rot Fang', 'Mire Blade'],
        EnemyArchetype.support: ['Fen Chanter', 'Mire Adept'],
      },
      'brass' => const {
        EnemyArchetype.swarm: ['Cog Mite', 'Rust Tick', 'Brass Flea'],
        EnemyArchetype.brute: ['Vault Bruiser', 'Cog Crusher'],
        EnemyArchetype.tank: ['Brass Bulwark', 'Cog Guard'],
        EnemyArchetype.ranged: ['Spark Spitter', 'Coil Slinger'],
        EnemyArchetype.glass: ['Razor Cog', 'Spring Fang'],
        EnemyArchetype.support: ['Clock Chanter', 'Brass Adept'],
      },
      'veil' => const {
        EnemyArchetype.swarm: ['Dust Moth', 'Veil Mite', 'Silk Flea'],
        EnemyArchetype.brute: ['Silk Bruiser', 'Veil Crusher'],
        EnemyArchetype.tank: ['Cocoon Guard', 'Veil Bulwark'],
        EnemyArchetype.ranged: ['Dust Spitter', 'Silk Slinger'],
        EnemyArchetype.glass: ['Wing Fang', 'Veil Blade'],
        EnemyArchetype.support: ['Moth Chanter', 'Veil Adept'],
      },
      _ => const {
        EnemyArchetype.swarm: ['Cave Slime', 'Sand Mite'],
        EnemyArchetype.brute: ['Cave Brute', 'Rock Crab'],
        EnemyArchetype.tank: ['Shellback', 'Stone Maw'],
        EnemyArchetype.ranged: ['Spit Bat', 'Cavern Spitter'],
        EnemyArchetype.glass: ['Needle Rat', 'Glass Skitter'],
        EnemyArchetype.support: ['Mire Shaman', 'Glow Cultist'],
      },
    };
    final names = table[archetype]!;
    return names[index % names.length];
  }
}
