import 'package:flutter/foundation.dart';

import 'chase_contract.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// Debug-only playtest lines for `flutter run` / `adb logcat`.
///
/// Filter: `[IP]` — never runs in release / Play builds.
abstract final class DebugPlayLog {
  static const prefix = '[IP]';

  /// Tests can capture lines without relying on `debugPrint`.
  static void Function(String line)? testSink;

  static String line(String kind, [String detail = '']) {
    final body = detail.isEmpty ? kind : '$kind · $detail';
    return '$prefix $body';
  }

  static void event(String kind, [String detail = '']) {
    if (!kDebugMode && testSink == null) return;
    final out = line(kind, detail);
    testSink?.call(out);
    if (kDebugMode) debugPrint(out);
  }

  static void nav(String where) => event('nav', where);

  static void toast(String message) => event('toast', message);

  static String bootDetail(GameState s) {
    final chase = ChaseContract.fromState(s);
    final where = s.inDungeon
        ? 'dungeon ${s.dungeonId} F${s.currentRoom.floorNumber}'
        : 'hub';
    return 'AL${s.ascensionLevel} · $where · '
        'gold ${s.gold} · e ${s.essence} · '
        'chase ${chase.title} · bag ${s.gearStash.length} · '
        'meanLv ${GameLogic.partyMeanLevel(s).toStringAsFixed(0)}';
  }

  /// Compact before→after. Empty when nothing playtest-useful changed.
  static String? stateDelta(GameState before, GameState after) {
    final bits = <String>[];
    void add(String label, Object a, Object b) {
      if (a != b) bits.add('$label $a→$b');
    }

    add('AL', before.ascensionLevel, after.ascensionLevel);
    add('gold', before.gold, after.gold);
    add('e', before.essence, after.essence);
    add('inDungeon', before.inDungeon, after.inDungeon);
    add('zone', before.dungeonId, after.dungeonId);
    add('F', before.currentRoom.floorNumber, after.currentRoom.floorNumber);
    add('KEY', before.hardmodeLevel, after.hardmodeLevel);
    add('bag', before.gearStash.length, after.gearStash.length);
    add('ATK', before.attackBonus, after.attackBonus);
    add('DEF', before.defenseBonus, after.defenseBonus);
    add('STA', before.vitalityBonus, after.vitalityBonus);
    add('wipeStreak', before.wipeStreakCount, after.wipeStreakCount);
    if (before.wipeAdviceLine != after.wipeAdviceLine &&
        after.wipeAdviceLine.isNotEmpty) {
      bits.add('wipe "${after.wipeAdviceLine}"');
    }
    add(
      'clearedF',
      before.highestFloorCleared,
      after.highestFloorCleared,
    );
    add(
      'clearedZ',
      before.highestDungeonCleared,
      after.highestDungeonCleared,
    );

    if (bits.isEmpty) return null;
    final goldOnly = bits.length == 1 && bits.first.startsWith('gold ');
    if (goldOnly) {
      final delta = after.gold - before.gold;
      if (delta.abs() < 25) return null;
    }
    return bits.join(' · ');
  }
}
