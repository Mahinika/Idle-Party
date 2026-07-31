import '../models/achievement_def.dart';
import '../models/dungeon_def.dart';
import '../models/enemy.dart';
import '../models/loot.dart';
import '../models/pet.dart';
import 'game_state.dart';

/// Free, offline meta systems: daily run seeding, local achievements,
/// codex discovery tracking, and the in-app changelog. No servers, no
/// monetization — everything here is a pure function over [GameState].
abstract final class MetaSystems {
  /// Current build's changelog version. Bump alongside [changelog] entries.
  static const String currentVersion = '1.3.0';

  static const List<String> changelog = <String>[
    'Meta depth: prestige shop, sanctuary XP/prestige, relic tiers, weekly contracts.',
    'Expanded pet roster (12 species), rarity merges, bonding, and frames.',
    'Codex milestone claims, ascend titles, zone trophies, and Will ranks.',
    'Dozens of new local achievements across zones, hardmode, gold, and pets.',
    'Light story layer: dungeon blurbs, enter/clear/ascend flavor, intro will.',
    'Smarter Auto Equip: BiS slot fill, 2H net score, party conflict resolution.',
    'Loot Sprite pet: gold find + loot find passives that scale with level.',
    'Achievements and ascend milestones grant essence rewards.',
    'Challenge clears: +2e per active toggle; Daily Run clear awards +25e.',
    'Auto Equip / Sell Junk report what they did via toasts.',
    'Offline AFK copy clarifies abstract combat (not live spatial).',
    'Codex monsters show sprites; difficulty CI gates for attrition balance.',
    'Rich offline progress summary dialog on return to the hub.',
    'Save up to 3 named gear loadouts and swap them instantly.',
    'Boss Rush and No-Flask challenge toggles before entering a dungeon.',
    'Daily Run: a free seeded challenge floor with one reward per day.',
    'Ascend milestones strip on the hub screen.',
    'A 7th dungeon, the Crystal Spire, joins the world path.',
    'Colorblind-friendly combat floater palette option.',
    'UI text scale and colorblind mode settings.',
    'Export / import your save as clipboard JSON.',
    'Local achievements and a monster/item codex.',
    'Keyboard shortcuts: Space (God Hand), Esc (close), B (bag), H (hub).',
  ];

  // —— Daily run ——————————————————————————————————————————————

  /// Stable `yyyy-mm-dd` key for the UTC calendar date of [utc].
  static String dailyDateKey(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Deterministic seed for a given UTC date — same calendar date always
  /// yields the same seed. Derived from the date string's hash (stable,
  /// content-based) rather than raw integer math so it can't overflow
  /// differently across the VM vs. web (dart2js) number representations.
  static int dailySeed(DateTime utc) {
    final key = dailyDateKey(utc);
    return key.hashCode & 0x3fffffff;
  }

  /// Stable day-of-epoch counter (UTC), used to rotate the daily dungeon.
  static int _epochDay(DateTime utc) =>
      DateTime.utc(utc.year, utc.month, utc.day).millisecondsSinceEpoch ~/
      86400000;

  /// Rotates through the dungeon catalog by day-of-epoch so every unlocked
  /// (or not) zone gets a turn as the free Daily Run.
  static String dailyDungeonId(DateTime utc) {
    final all = DungeonCatalog.all;
    if (all.isEmpty) return 'sandy';
    final index = _epochDay(utc) % all.length;
    return all[index].id;
  }

  /// Whether today's Daily Run has already been claimed on [state].
  static bool isDailyClaimedToday(GameState state, {DateTime? now}) {
    final t = now ?? DateTime.now().toUtc();
    return state.lastDailyDate == dailyDateKey(t) && state.dailyClaimed;
  }

  // —— Collection score ——————————————————————————————————————

  /// Will-rank collection score (achievements, pets, relics, codex, trophies).
  static int collectionScore(GameState state) =>
      state.achievements.length * 2 +
      state.ownedPets.length +
      state.unlockedRelics.length * 3 +
      (state.codexEnemies.length + state.codexItems.length) ~/ 2 +
      state.metaDepth.zoneTrophies.length * 3 +
      state.metaDepth.titles.length;

  // —— Achievements ————————————————————————————————————————————

  static final Map<String, bool Function(GameState)> _conditions =
      <String, bool Function(GameState)>{
    'first_floor': (s) =>
        s.highestFloorCleared >= 1 || s.metaDepth.lifetimeFloorClears >= 1,
    'first_boss': (s) =>
        s.bossVictories >= 1 || s.metaDepth.lifetimeBossKills >= 1,
    'first_ascend': (s) =>
        s.ascensionLevel >= 1 || s.metaDepth.lifetimeAscends >= 1,
    'clear_goblin': (s) => s.highestDungeonCleared >= 1,
    'hatch_pet': (s) =>
        s.ownedPets.isNotEmpty || s.metaDepth.lifetimePetHatches >= 1,
    'daily_clear': (s) => s.dailyClaimed,
    'full_party': (s) => s.heroes.length >= 4,
    'clear_sandy': (s) => s.highestDungeonCleared >= 0,
    'clear_king': (s) => s.highestDungeonCleared >= 2,
    'clear_underworld': (s) => s.highestDungeonCleared >= 3,
    'clear_dead': (s) => s.highestDungeonCleared >= 4,
    'clear_hell': (s) => s.highestDungeonCleared >= 5,
    'clear_crystal': (s) => s.highestDungeonCleared >= 6,
    'hm_1': (s) => s.hardmodeLevel >= 1,
    'hm_5': (s) => s.hardmodeLevel >= 5,
    'hm_10': (s) => s.hardmodeLevel >= 10,
    'gold_10k': (s) => s.lifetimeGoldEarned >= 10000,
    'gold_100k': (s) => s.lifetimeGoldEarned >= 100000,
    'gold_1m': (s) => s.lifetimeGoldEarned >= 1000000,
    'codex_10': (s) =>
        s.codexEnemies.length + s.codexItems.length >= 10,
    'codex_25': (s) =>
        s.codexEnemies.length + s.codexItems.length >= 25,
    'codex_50': (s) =>
        s.codexEnemies.length + s.codexItems.length >= 50,
    'pets_3': (s) => s.ownedPets.length >= 3,
    'pet_merge': (s) => s.metaDepth.lifetimePetMerges >= 1,
    'pet_legendary': (s) =>
        s.ownedPets.any((p) => p.rarity == PetRarity.legendary),
    'favorite_pet': (s) => s.metaDepth.favoritePetSpecies.isNotEmpty,
    'ascend_streak_3': (s) => s.metaDepth.ascendStreak >= 3,
    'al_5': (s) => s.ascensionLevel >= 5,
    'al_10': (s) => s.ascensionLevel >= 10,
    'casts_100': (s) => s.metaDepth.lifetimeAbilityCasts >= 100,
    'floors_50': (s) => s.metaDepth.lifetimeFloorClears >= 50,
    'relic_all': (s) =>
        s.hasRelic('war_banner') &&
        s.hasRelic('iron_ward') &&
        s.hasRelic('phoenix_ember'),
    'sanctuary_12': (s) =>
        s.sanctuaryGoldLevel >= 12 ||
        s.sanctuaryPowerLevel >= 12 ||
        s.sanctuaryVitalityLevel >= 12 ||
        s.metaDepth.sanctuaryXpLevel >= 12,
    'god_hand_5': (s) => s.godHandLevel >= 5,
    'weekly_clear': (s) => s.metaDepth.weeklyClaimed,
    'hidden_egg': (s) => s.metaDepth.lifetimePetHatches >= 10,
  };

  /// Pure: adds any newly-met achievement ids and grants their essence reward.
  /// Never removes an id, so it's safe to call repeatedly.
  static GameState evaluateAchievements(GameState state) {
    final before = state.achievements.toSet();
    List<String>? unlocked;
    var essenceGain = 0;
    for (final entry in _conditions.entries) {
      if (!before.contains(entry.key) && entry.value(state)) {
        unlocked ??= List<String>.from(state.achievements);
        unlocked.add(entry.key);
        essenceGain += AchievementCatalog.byId(entry.key)?.essenceReward ?? 0;
      }
    }
    if (unlocked == null) return state;
    return state.copyWith(
      achievements: unlocked,
      essence: state.essence + essenceGain,
    );
  }

  /// Ascension levels that grant a one-time milestone essence bonus.
  static const List<int> ascendMilestones = <int>[1, 3, 5, 10, 15, 20];

  static int ascendMilestoneEssence(int level) => 2 + level;

  /// Essence for newly crossed AL milestones when going from [fromLevel] → [toLevel].
  static int ascendMilestoneReward(int fromLevel, int toLevel) {
    var total = 0;
    for (final m in ascendMilestones) {
      if (fromLevel < m && toLevel >= m) {
        total += ascendMilestoneEssence(m);
      }
    }
    return total;
  }

  /// Extra essence on floor clear while challenge toggles / hardmode are on.
  static int challengeClearEssenceBonus(GameState state) {
    var bonus = 0;
    if (state.challengeBossRush) bonus += 2;
    if (state.challengeNoFlask) bonus += 2;
    bonus += state.hardmodeLevel.clamp(0, state.effectiveMaxHardmode);
    return bonus;
  }

  // —— Codex —————————————————————————————————————————————————

  /// Registers every enemy currently on the floor as "discovered".
  static GameState registerEnemyEncounters(
    GameState state,
    List<EnemyUnit> enemies,
  ) {
    if (enemies.isEmpty) return state;
    Set<String>? known;
    for (final enemy in enemies) {
      if (!state.codexEnemies.contains(enemy.name)) {
        known ??= Set<String>.from(state.codexEnemies);
        known.add(enemy.name);
      }
    }
    if (known == null) return state;
    final list = known.toList()..sort();
    return state.copyWith(codexEnemies: list);
  }

  /// Registers every dropped equipment piece's display name as "discovered".
  static GameState registerItemDrops(
    GameState state,
    List<LootDrop> drops,
  ) {
    if (drops.isEmpty) return state;
    Set<String>? known;
    for (final drop in drops) {
      final item = drop.equipment;
      final key = item != null ? item.name : drop.name;
      if (!state.codexItems.contains(key)) {
        known ??= Set<String>.from(state.codexItems);
        known.add(key);
      }
    }
    if (known == null) return state;
    final list = known.toList()..sort();
    return state.copyWith(codexItems: list);
  }
}
