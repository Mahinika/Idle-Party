import 'dart:math';

import '../models/meta_depth.dart';
import 'game_state.dart';
import 'meta_systems.dart';

/// Daily errand "shipments" — send a pet out only while stock remains (UTC day).
abstract final class PetErrandStock {
  static const int baseCreditsPerDay = 3;
  static const int maxShipmentBonus = 2;
  static const int cinderCostPerBonus = 12;

  static int maxCredits(MetaDepthState md) =>
      baseCreditsPerDay + md.petShipmentBonus.clamp(0, maxShipmentBonus);

  static MetaDepthState rollDay(MetaDepthState md, {DateTime? now}) {
    final day = MetaSystems.dailyDateKey((now ?? DateTime.now()).toUtc());
    if (md.petErrandStockUtcDay == day) return md;
    final max = maxCredits(md);
    return md.copyWith(
      petErrandStockUtcDay: day,
      petErrandStockRemaining: max,
    );
  }

  static GameState ensureDay(GameState state, {DateTime? now}) {
    final rolled = rollDay(state.metaDepth, now: now);
    if (identical(rolled, state.metaDepth)) return state;
    return state.copyWith(metaDepth: rolled);
  }

  static int creditsRemaining(GameState state, {DateTime? now}) {
    final md = rollDay(state.metaDepth, now: now);
    return md.petErrandStockRemaining.clamp(0, maxCredits(md));
  }

  static bool canSend(GameState state, {DateTime? now}) =>
      creditsRemaining(state, now: now) > 0;

  static GameState consumeCredit(GameState state, {DateTime? now}) {
    var next = ensureDay(state, now: now);
    final left = next.metaDepth.petErrandStockRemaining;
    if (left <= 0) return state;
    return next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        petErrandStockRemaining: left - 1,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  static bool canBuyShipmentBonus(GameState state) =>
      state.metaDepth.petShipmentBonus < maxShipmentBonus &&
      state.metaDepth.cinders >= cinderCostPerBonus;

  static GameState buyShipmentBonus(GameState state, {DateTime? now}) {
    if (!canBuyShipmentBonus(state)) return state;
    var md = rollDay(state.metaDepth, now: now);
    md = md.copyWith(
      cinders: md.cinders - cinderCostPerBonus,
      petShipmentBonus: md.petShipmentBonus + 1,
    );
    final max = maxCredits(md);
    md = md.copyWith(
      petErrandStockRemaining: min(
        max,
        md.petErrandStockRemaining + 1,
      ),
    );
    return state.copyWith(metaDepth: md, lastUpdated: DateTime.now());
  }

  static String stockLine(GameState state, {DateTime? now}) {
    final left = creditsRemaining(state, now: now);
    final max = maxCredits(rollDay(state.metaDepth, now: now));
    return '$left of $max errands left today (UTC)';
  }
}
