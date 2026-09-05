import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/gear/drop_tables.dart';

void main() {
  setUp(DropTables.resetToDefaults);

  test('defaults match shipped magic numbers', () {
    final d = DropTablesData.defaults;
    expect(d.killLoot.skipChanceMax, 0.55);
    expect(d.killLoot.hmSkipFactor, 0.012);
    expect(d.killLoot.secondDropMinBattle, 4);
    expect(d.killLoot.secondHighCap, 0.55);
    expect(d.killLoot.secondLowCap, 0.28);
    expect(d.roomChest.gearChance, 0.42);
    expect(d.floorClear.goldPouchEvery, 4);
    expect(d.floorClear.relicEvery, 9);
    expect(d.finalize.softCap, 5);
    expect(d.rarityForBattle.epicEvery, 12);
    expect(d.offHandTargetWeight.shield, 2);
  });

  test('fromJson merges partial overrides', () {
    final parsed = DropTablesData.fromJson({
      'roomChest': {'gearChance': 0.5},
      'finalize': {'softCap': 6},
    });
    expect(parsed.roomChest.gearChance, 0.5);
    expect(parsed.finalize.softCap, 6);
    expect(parsed.killLoot.secondDropMinBattle, 4);
  });

  test('resetToDefaults restores embedded defaults', () {
    DropTables.resetToDefaults();
    expect(DropTables.current.finalize.softCap, 5);
    expect(DropTables.current.killLoot.skipChanceMax, 0.55);
  });
}
