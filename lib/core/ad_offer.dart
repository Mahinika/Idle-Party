import 'ad_boost.dart';
import 'game_state.dart';

/// Opt-in rewarded offers. One button on screen at a time. No auto-play.
abstract final class AdOffer {
  /// Welcome Back. Doubles the gold and essence from that absence.
  static const String welcomeLabel = 'Watch ad: 2× offline loot';

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
