import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/game_logic.dart';

/// FORGE ×10: up to ten buys per tap at the same per-buy price as ×1.
void main() {
  final seeded = GameLogic.createInitialState(now: DateTime(2026, 8, 21));

  test('×10 equals ten ×1 buys in a row, gold and bonus alike', () {
    final state = seeded.copyWith(gold: 100000);
    for (final type in PartyUpgradeType.values) {
      var one = state;
      for (var i = 0; i < 10; i++) {
        one = GameLogic.upgradeWithSpendMode(
          one,
          type: type,
          mode: ForgeGoldSpendMode.one,
        );
      }
      final ten = GameLogic.upgradeWithSpendMode(
        state,
        type: type,
        mode: ForgeGoldSpendMode.x10,
      );
      expect(ten.gold, one.gold, reason: '$type gold');
      expect(GameLogic.forgeTrackTier(ten, type), 10, reason: '$type tier');
      expect(
        GameLogic.forgeTrackTier(ten, type),
        GameLogic.forgeTrackTier(one, type),
      );
      final preview = GameLogic.previewForgeGoldSpend(
        state,
        type,
        ForgeGoldSpendMode.x10,
      );
      expect(preview.buys, 10);
      expect(preview.spent, state.gold - ten.gold);
    }
  });

  test('×10 never charges more per buy than ×1', () {
    final state = seeded.copyWith(gold: 100000);
    var cur = state;
    var expectedSpend = 0;
    for (var i = 0; i < 10; i++) {
      expectedSpend += GameLogic.upgradeCostFor(cur, PartyUpgradeType.attack);
      cur = GameLogic.upgradeWithSpendMode(
        cur,
        type: PartyUpgradeType.attack,
        mode: ForgeGoldSpendMode.one,
      );
    }
    final preview = GameLogic.previewForgeGoldSpend(
      state,
      PartyUpgradeType.attack,
      ForgeGoldSpendMode.x10,
    );
    expect(preview.spent, expectedSpend);
  });

  test('a short wallet buys what it can and stops', () {
    var cur = seeded;
    var gold = 0;
    for (var i = 0; i < 3; i++) {
      final cost = GameLogic.upgradeCostFor(cur, PartyUpgradeType.defense);
      gold += cost;
      cur = GameLogic.upgradeWithSpendMode(
        cur.copyWith(gold: cur.gold + cost),
        type: PartyUpgradeType.defense,
        mode: ForgeGoldSpendMode.one,
      );
    }
    final state = seeded.copyWith(gold: gold);
    final preview = GameLogic.previewForgeGoldSpend(
      state,
      PartyUpgradeType.defense,
      ForgeGoldSpendMode.x10,
    );
    expect(preview.buys, 3);
    expect(preview.spent, gold);
    final next = GameLogic.upgradeWithSpendMode(
      state,
      type: PartyUpgradeType.defense,
      mode: ForgeGoldSpendMode.x10,
    );
    expect(next.gold, 0);
    expect(GameLogic.forgeTrackTier(next, PartyUpgradeType.defense), 3);
  });

  test('×10 is off when one buy is out of reach', () {
    final cost = GameLogic.upgradeCostFor(seeded, PartyUpgradeType.attack);
    final state = seeded.copyWith(gold: cost - 1);
    expect(
      GameLogic.canForgeGoldSpend(
        state,
        PartyUpgradeType.attack,
        ForgeGoldSpendMode.x10,
      ),
      isFalse,
    );
    final same = GameLogic.upgradeWithSpendMode(
      state,
      type: PartyUpgradeType.attack,
      mode: ForgeGoldSpendMode.x10,
    );
    expect(same.gold, state.gold);
    expect(same.attackBonus, state.attackBonus);
  });

  test('×10 is on once one buy fits', () {
    final cost = GameLogic.upgradeCostFor(seeded, PartyUpgradeType.attack);
    expect(
      GameLogic.canForgeGoldSpend(
        seeded.copyWith(gold: cost),
        PartyUpgradeType.attack,
        ForgeGoldSpendMode.x10,
      ),
      isTrue,
    );
  });

  test('wallet-slice modes keep their old caps', () {
    expect(ForgeGoldSpendMode.pct25.maxBuys, isNull);
    expect(ForgeGoldSpendMode.pct100.maxBuys, isNull);
    expect(ForgeGoldSpendMode.one.maxBuys, 1);
    expect(ForgeGoldSpendMode.x10.maxBuys, 10);
    expect(ForgeGoldSpendMode.x10.chipLabel, '×10');
  });
}
