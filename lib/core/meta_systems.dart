import '../models/achievement_def.dart';
import '../models/dungeon_def.dart';
import '../models/enemy.dart';
import '../models/loot.dart';
import 'game_state.dart';

/// Free, offline meta systems: daily run seeding, local achievements,
/// codex discovery tracking, and the in-app changelog. No servers, no
/// monetization — everything here is a pure function over [GameState].
abstract final class MetaSystems {
  /// Current build's changelog version. Bump alongside [changelog] entries.
  static const String currentVersion = '1.1.2';

  static const List<String> changelog = <String>[
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

  // —— Achievements ————————————————————————————————————————————

  static final Map<String, bool Function(GameState)> _conditions =
      <String, bool Function(GameState)>{
    'first_floor': (s) => s.highestFloorCleared >= 1,
    'first_boss': (s) => s.bossVictories >= 1,
    'first_ascend': (s) => s.ascensionLevel >= 1,
    'clear_goblin': (s) => s.highestDungeonCleared >= 1,
    'hatch_pet': (s) => s.ownedPets.isNotEmpty,
    'daily_clear': (s) => s.dailyClaimed,
    'full_party': (s) => s.heroes.length >= 4,
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
    bonus += state.hardmodeLevel.clamp(0, 10);
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
