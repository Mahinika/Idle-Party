import '../models/meta_depth.dart';
import 'game_state.dart';

/// Run bag expansions bought with gold or Cinders (kept on Ascend).
abstract final class RunStashShop {
  static const int goldBuyMax = 2;
  static const int slotsPerGoldBuy = 5;
  static const int cinderBuyMax = 1;
  static const int slotsPerCinderBuy = 10;
  static const int cinderBuyCost = 25;

  static int bonusSlotsFromGold(MetaDepthState md) =>
      md.stashGoldBuys * slotsPerGoldBuy;

  static int bonusSlotsFromCinders(MetaDepthState md) =>
      md.stashCinderBuys * slotsPerCinderBuy;

  static int goldBuyCost(GameState state) {
    final buys = state.metaDepth.stashGoldBuys;
    if (buys >= goldBuyMax) return 0;
    return 12000 + state.ascensionLevel * 2500 + buys * 20000;
  }

  static bool canBuyGold(GameState state) =>
      state.metaDepth.stashGoldBuys < goldBuyMax &&
      state.gold >= goldBuyCost(state);

  static bool goldBuysAtCap(MetaDepthState md) => md.stashGoldBuys >= goldBuyMax;

  static bool cinderBuysAtCap(MetaDepthState md) =>
      md.stashCinderBuys >= cinderBuyMax;

  static GameState buyGoldExpansion(GameState state) {
    if (!canBuyGold(state)) return state;
    final cost = goldBuyCost(state);
    return state.copyWith(
      gold: state.gold - cost,
      metaDepth: state.metaDepth.copyWith(
        stashGoldBuys: state.metaDepth.stashGoldBuys + 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static bool canBuyCinders(GameState state) =>
      state.metaDepth.stashCinderBuys < cinderBuyMax &&
      state.metaDepth.cinders >= cinderBuyCost;

  static GameState buyCinderExpansion(GameState state) {
    if (!canBuyCinders(state)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        cinders: state.metaDepth.cinders - cinderBuyCost,
        stashCinderBuys: state.metaDepth.stashCinderBuys + 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static String goldBuyLabel(GameState state) {
    if (state.metaDepth.stashGoldBuys >= goldBuyMax) {
      return 'BAG +$slotsPerGoldBuy (gold max)';
    }
    return 'BAG +$slotsPerGoldBuy · ${formatGoldCost(goldBuyCost(state))}g';
  }

  static String cinderBuyLabel(GameState state) {
    if (state.metaDepth.stashCinderBuys >= cinderBuyMax) {
      return 'BAG +$slotsPerCinderBuy (Cinder max)';
    }
    return 'BAG +$slotsPerCinderBuy · $cinderBuyCost Cinders';
  }

  static String formatGoldCost(int gold) {
    if (gold >= 1000000) return '${(gold / 1000000).toStringAsFixed(1)}M';
    if (gold >= 1000) return '${(gold / 1000).toStringAsFixed(0)}k';
    return '$gold';
  }

  static int totalBonusSlots(MetaDepthState md) =>
      bonusSlotsFromGold(md) + bonusSlotsFromCinders(md);
}
