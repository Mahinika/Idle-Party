import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/gear/gear_cleanup.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/models/loot.dart';

void main() {
  test('new save seeds auto-sell after first equip', () {
    var state = GameLogic.createInitialState();
    expect(state.autoSellMaxPower, 0);

    final drop = GameLogic.createEquipment(
      slot: EquipmentSlot.weapon,
      rarity: LootRarity.uncommon,
      battleNumber: 2,
    );
    state = state.copyWith(gearStash: [drop]);
    state = GameLogic.equipFromStash(state, drop.id, heroIndex: 0);

    final ceiling = GearCleanup.recommendAutoSellCeiling(state);
    expect(ceiling, isNotNull);
    expect(state.autoSellMaxPower, ceiling);
    expect(state.autoSellMaxPower, greaterThan(0));
  });

  test('legacy save without field keeps auto-sell 48 default', () {
    final json = GameLogic.createInitialState().toJson()
      ..remove('autoSellMaxPower');
    final loaded = GameLogic.stateFromJson(json);
    expect(loaded.autoSellMaxPower, 48);
  });
}