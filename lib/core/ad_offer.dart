import 'dart:math';

import 'ad_boost.dart';
import 'game_state.dart';
import 'gold_income.dart';

/// Opt-in rewarded offers. One button on screen at a time. No auto-play.
abstract final class AdOffer {
  /// Welcome Back multiplies that trip's gold and essence by this.
  static const int welcomeMul = 3;

  /// The watch pays at least this many minutes of hub gold.
  static const int welcomeFloorMinutes = 30;

  /// Extra gold the watch adds on top of [baseGold] already credited.
  ///
  /// ×[welcomeMul] of the trip, and never under [welcomeFloorMinutes] of hub
  /// gold. Scroll of Rest stays its own ×3 and does not call this.
  static int welcomeExtraGold(GameState state, int baseGold) {
    final scaled = baseGold > 0 ? baseGold * (welcomeMul - 1) : 0;
    final floor = GoldIncome.hubGoldPerMinute(state) * welcomeFloorMinutes;
    return max(scaled, floor);
  }

  /// Extra essence so the trip lands on ×[welcomeMul]. No hub floor.
  static int welcomeExtraEssence(int baseEssence) =>
      baseEssence > 0 ? baseEssence * (welcomeMul - 1) : 0;

  /// Welcome Back. Triples the gold and essence from that absence.
  static const String welcomeLabel = 'Watch ad: 3× offline loot';

  /// Dungeon and hub HUD. One Ad Ticket. Hidden while another offer is up.
  static const String hudLabel = 'WATCH';

  /// After the first boss, with no combat scroll running, and no other ad
  /// offer already on screen. A live fight is not a break.
  static bool showHudButton(
    GameState state, {
    required bool welcomeUp,
    required bool wipeUp,
    required bool fightLive,
    int? nowMs,
  }) {
    if (welcomeUp || wipeUp || fightLive) return false;
    if (state.metaDepth.adFree) return false;
    // Same gate as SCROLLS: first boss or first Ascend.
    if (state.ascensionLevel <= 0 && state.bossVictories <= 0) return false;
    return !AdBoost.combatBoostActive(state.metaDepth, nowMs: nowMs);
  }
}
