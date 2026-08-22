@Tags(['sim'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gear/drop_tables.dart';
import 'package:idle_party/core/loot_pipeline.dart';
import 'package:idle_party/models/dungeon_room.dart';
import 'package:idle_party/models/enemy.dart';

void main() {
  setUp(DropTables.resetToDefaults);

  test('kill loot second-drop rate tracks drop table caps', () {
    final party = GameLogic.createInitialState().heroes;
    var secondHits = 0;
    const trials = 800;
    const battle = 10;
    for (var seed = 0; seed < trials; seed++) {
      GameLogic.random = Random(seed);
      final drops = LootPipeline.rollKillLoot(
        battle,
        party: party,
        dungeonId: 'sandy',
        enemyRole: EnemyRole.normal,
      );
      if (drops.length > 1 && drops[1].isEquipment) {
        secondHits++;
      }
    }
    final kill = DropTables.current.killLoot;
    final expected =
        (kill.secondHighBase * kill.roleSecondMul.normal).clamp(0.0, kill.secondHighCap);
    final observed = secondHits / trials;
    expect(observed, closeTo(expected, 0.08));
  });

  test('floor clear pouch cadence follows table', () {
    final drops = LootPipeline.rollFloorClearLoot(
      12,
      roomType: RoomType.normal,
    );
    expect(
      drops.any((d) => d.name.toLowerCase().contains('gold pouch')),
      isTrue,
    );
    final noPouch = LootPipeline.rollFloorClearLoot(
      13,
      roomType: RoomType.normal,
    );
    expect(
      noPouch.any((d) => d.name.toLowerCase().contains('gold pouch')),
      isFalse,
    );
  });
}
