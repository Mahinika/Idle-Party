import 'package:flutter_test/flutter_test.dart';
import 'package:idle_party/core/economy_service.dart';
import 'package:idle_party/core/game_logic.dart';
import 'package:idle_party/core/gold_income.dart';
import 'package:idle_party/core/keystone.dart';
import 'package:idle_party/core/market_listings_service.dart';

void main() {
  test('AL0 forge and gold find stay gentle', () {
    final state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 22));
    expect(state.effectiveGoldFindPercent, 0);
    expect(GameLogic.upgradeCostFor(state, PartyUpgradeType.attack), 18);
    expect(EconomyService.applyGoldGain(state, 100), 100);
  });

  test('AL20 stacked gold-find soft-caps below raw total', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 22));
    state = state.copyWith(
      ascensionLevel: 20,
      sanctuaryGoldLevel: 15,
      metaDepth: state.metaDepth.copyWith(ascendBlessings: 20),
    );
    expect(state.totalGoldFindPercent, greaterThan(250));
    expect(state.effectiveGoldFindPercent, lessThan(state.totalGoldFindPercent));
    expect(state.effectiveGoldFindPercent, inInclusiveRange(290, 310));

    final rawGain = 10000;
    final cappedGain = EconomyService.applyGoldGain(state, rawGain);
    final uncappedGain =
        rawGain + (rawGain * state.totalGoldFindPercent) ~/ 100;
    expect(cappedGain, lessThan(uncappedGain));
  });

  test('AL20 forge and market refresh scale with ascension', () {
    var state = GameLogic.createInitialState(now: DateTime.utc(2026, 8, 22));
    state = state.copyWith(ascensionLevel: 20);
    expect(
      GameLogic.upgradeCostFor(state, PartyUpgradeType.attack),
      18 + 20 * 25,
    );
    expect(MarketListingsService.paidRefreshCost(state), 25000 + 20 * 1000);
  });

  test('daily vault and hub essence pace up at endgame', () {
    expect(Keystone.dailyVaultEssence(12), 64);
    expect(Keystone.dailyVaultEssence(0), 16);
    expect(GoldIncome.essenceDue(3600, 12), 4 + 6);
  });
}
