import 'dart:math';

import 'package:idle_party/core/game_state.dart';
import 'package:idle_party/models/dungeon_def.dart';

/// Mythic+-style keystone runs: level, affixes, idle-friendly timer, upgrade.
abstract final class Keystone {
  static const int maxLevel = 20;
  static const int minActiveLevel = 1;

  /// Pool for the week's primary affix (also used as secondary at higher keys).
  static const List<String> weeklyPool = <String>[
    'glass',
    'swarm',
    'elite',
    'fortune',
    'iron',
  ];

  /// AL-gated key cap (0 = off). AL0 → 3, grows to [maxLevel].
  static int maxForAl(int ascensionLevel) =>
      min(maxLevel, max(2, 3 + ascensionLevel));

  /// Threat / pack density vs old HM+10 ≈ 10× at key 20.
  static double threatMul(int key) => 1.0 + key.clamp(0, maxLevel) * 0.45;

  /// Combat gold tracks threat so KEY is not a gold/hour tax.
  /// iLvl remains the extra prize (`lootItemLevelBonus`).
  static double goldMul(int key) => threatMul(key);

  static double densityMul(int key) => 1.0 + key.clamp(0, maxLevel) * 0.45;

  /// Extra KEY bodies pay this slice of density into pack gold (1.0 = full).
  static const double densityGoldShare = 0.85;

  /// Phone line: `gold ×5.5` on KEY +10.
  static String goldMulLabel(int key) {
    final m = goldMul(key);
    if (m <= 1.01) return 'gold ×1';
    final text = (m * 10).round() % 10 == 0
        ? m.toStringAsFixed(0)
        : m.toStringAsFixed(1);
    return 'gold ×$text';
  }

  /// Legendary direct-drop chance contribution (key 20 ≈ old HM+10).
  static double legendaryChance(int key) =>
      0.004 + key.clamp(0, maxLevel) * 0.0055;

  static double rarityBump(int key) => key.clamp(0, maxLevel) * 0.02;

  /// Honest loot jump: KEY +10 is +20 iLvl, not a +2 crumb.
  static int lootItemLevelBonus(int key) => key.clamp(0, maxLevel) * 2;

  /// Idle-friendly par: ~2 min/floor + 20s/key/floor (offline counts).
  static int parTimeMs({required int bossFloor, required int key}) {
    if (key <= 0) return 0;
    final floors = max(1, bossFloor);
    final perFloorMs = 120000 + key.clamp(0, maxLevel) * 20000;
    return floors * perFloorMs;
  }

  static int bossFloorForAl(int ascensionLevel) =>
      DungeonCatalog.bossFloor(ascensionLevel);

  /// Affixes locked at run start from key level + ISO week + personal extras.
  static List<String> affixesFor({
    required int key,
    required String weeklyModifier,
    required String weeklyKey,
    bool personalBossRush = false,
    bool personalNoFlask = false,
  }) {
    if (key <= 0) return const <String>[];
    final out = <String>[];
    final weekHash = weeklyKey.hashCode & 0x7fffffff;
    final primary = weeklyModifier.isNotEmpty
        ? weeklyModifier
        : weeklyPool[weekHash % weeklyPool.length];
    out.add(primary);

    if (key >= 4) {
      out.add(weekHash.isEven ? 'fortified' : 'tyrannical');
    }
    if (key >= 7) {
      final secondary = weeklyPool[(weekHash ~/ 7) % weeklyPool.length];
      if (secondary != primary) {
        out.add(secondary);
      } else {
        out.add(weeklyPool[(weekHash ~/ 7 + 1) % weeklyPool.length]);
      }
    }
    if (key >= 10) out.add('no_flask');
    if (key >= 12) out.add('boss_rush');
    if (key >= 15 && !out.contains('iron')) out.add('iron');

    if (personalBossRush && !out.contains('boss_rush')) {
      out.add('boss_rush');
    }
    if (personalNoFlask && !out.contains('no_flask')) {
      out.add('no_flask');
    }
    return List<String>.unmodifiable(out);
  }

  /// Preview affixes for hub UI (preference dial, not an active run).
  static List<String> previewAffixes(GameState state) {
    final key = state.hardmodeLevel.clamp(0, maxForAl(state.ascensionLevel));
    return affixesFor(
      key: key,
      weeklyModifier: state.metaDepth.weeklyModifier,
      weeklyKey: state.metaDepth.weeklyKey,
      personalBossRush: state.challengeBossRush,
      personalNoFlask: state.challengeNoFlask,
    );
  }

  /// Combat key level for minting packs (locked run, else 0 outside keystone).
  static int combatLevel(GameState? state, {int fallback = 0}) {
    if (state == null) return fallback.clamp(0, maxLevel);
    if (state.inGauntlet) return 0;
    if (state.keystoneRunActive) {
      return state.keystoneRunLevel.clamp(0, maxLevel);
    }
    return 0;
  }

  static bool flasksDisabled(GameState state) {
    if (state.challengeNoFlask) return true;
    if (state.keystoneRunActive &&
        state.keystoneRunAffixes.contains('no_flask')) {
      return true;
    }
    return false;
  }

  static bool hasAffix(GameState? state, String id) {
    if (state == null || !state.keystoneRunActive) return false;
    return state.keystoneRunAffixes.contains(id);
  }

  static String label(String affix) => switch (affix) {
    'glass' => 'Glass',
    'swarm' => 'Swarm',
    'elite' => 'Elite',
    'fortune' => 'Fortune',
    'iron' => 'Iron',
    'fortified' => 'Fortified',
    'tyrannical' => 'Tyrannical',
    'boss_rush' => 'Boss Rush',
    'no_flask' => 'No Flask',
    _ => affix,
  };

  static String blurb(String affix) => switch (affix) {
    'glass' => 'Fragile foes, hit harder',
    'swarm' => 'More enemies',
    'elite' => 'Tougher packs',
    'fortune' => 'More gold',
    'iron' => 'Harder, richer',
    'fortified' => 'Trash packs tougher',
    'tyrannical' => 'Bosses tougher',
    'boss_rush' => 'Elite-heavy pulls',
    'no_flask' => 'Flasks disabled',
    _ => affix,
  };

  static String formatTimer(int ms) {
    final totalSec = max(0, ms) ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Essence for claiming daily vault (scales with today's best timed key).
  static int dailyVaultEssence(int bestTimedKey) =>
      14 + bestTimedKey.clamp(0, maxLevel) * 3;

  /// Extra essence when timing a keystone boss clear.
  static int timedClearBonus(int key) => 4 + key.clamp(0, maxLevel) * 2;
}
