import 'dart:math';

import 'game_state.dart';

/// Hub gold rate and AFK yield — one formula for live ticks, CAMP preview,
/// and sanctuary offline. Dungeon combat gold is separate.
abstract final class GoldIncome {
  /// Raw gold per minute before Torch and gold-find percent.
  static int hubRawPerMinute(GameState state) =>
      2 +
      state.sanctuaryGoldLevel +
      state.ascensionLevel +
      (state.highestDungeonCleared + 1);

  static int goldFindPercent(GameState state) =>
      state.ascensionGoldBonusPercent +
      state.sanctuaryGoldBonusPercent +
      state.ascendBlessingGoldPercent +
      state.gearGoldFindPercent +
      state.petGoldFindPercent;

  static int goldFromRaw(GameState state, int raw) {
    if (raw <= 0) return 0;
    final torched = raw + (raw * state.torchOfflineGoldPercent) ~/ 100;
    final percent = goldFindPercent(state);
    if (percent <= 0) return torched;
    return torched + (torched * percent) ~/ 100;
  }

  static int rawFromSeconds(GameState state, int seconds) {
    if (seconds <= 0) return 0;
    return max(0, (seconds * hubRawPerMinute(state)) ~/ 60);
  }

  /// Gold for [seconds] of hub AFK, ignoring the saved sub-second remainder.
  static int hubGoldForSeconds(GameState state, int seconds) =>
      goldFromRaw(state, rawFromSeconds(state, seconds));

  /// Honest header rate: one minute of hub AFK with current bonuses.
  static int hubGoldPerMinute(GameState state) => hubGoldForSeconds(state, 60);

  static String perMinuteLabel(int goldPerMin) => '${goldPerMin}g/min';

  static String hubRateLine(GameState state) =>
      'Hub ${perMinuteLabel(hubGoldPerMinute(state))}';

  static List<(String, int)> multiplierParts(GameState state) {
    return <(String, int)>[
      ('AL', state.ascensionGoldBonusPercent),
      ('CAMP', state.sanctuaryGoldBonusPercent),
      ('Blessing', state.ascendBlessingGoldPercent),
      ('gear', state.gearGoldFindPercent),
      ('pet', state.petGoldFindPercent),
      ('Torch', state.torchOfflineGoldPercent),
    ].where((p) => p.$2 > 0).toList();
  }

  static String multiplierLine(GameState state) {
    final bits = [
      for (final p in multiplierParts(state)) '${p.$1} +${p.$2}%',
    ];
    if (bits.isEmpty) return 'Gold +0%';
    return bits.join(' · ');
  }

  static int hubGoldPerMinuteAtGoldLevel(GameState state, int goldLevel) =>
      hubGoldPerMinute(state.copyWith(sanctuaryGoldLevel: goldLevel));

  static int nextGoldFindDeltaPerMinute(GameState state) =>
      hubGoldPerMinuteAtGoldLevel(state, state.sanctuaryGoldLevel + 1) -
      hubGoldPerMinute(state);

  static int essenceDue(int totalSec, int sanctuaryPowerLevel) {
    if (totalSec < 600) return 0;
    return (totalSec ~/ 900) + (sanctuaryPowerLevel ~/ 2);
  }

  /// Credit hub AFK for [seconds], banking leftover seconds toward the next
  /// gold tick so 1s live ticks match a long offline apply.
  static GameState applyHubIdle(GameState state, int seconds) {
    if (seconds <= 0) return state;
    final p = hubRawPerMinute(state);
    final total = state.metaDepth.hubIdleSubSec + seconds;
    final raw = p <= 0 ? 0 : max(0, (total * p) ~/ 60);
    var leftover = total;
    if (raw > 0 && p > 0) {
      final consumed = (raw * 60 + p - 1) ~/ p;
      leftover = max(0, total - consumed);
      if ((leftover * p) ~/ 60 > 0) {
        leftover = 0;
      }
    }
    final gold = goldFromRaw(state, raw);
    final accBefore = state.metaDepth.hubAfkSec;
    final accAfter = accBefore + seconds;
    final essence =
        essenceDue(accAfter, state.sanctuaryPowerLevel) -
        essenceDue(accBefore, state.sanctuaryPowerLevel);
    return state.copyWith(
      gold: state.gold + gold,
      lifetimeGoldEarned: state.lifetimeGoldEarned + gold,
      essence: state.essence + essence,
      metaDepth: state.metaDepth.copyWith(
        hubIdleSubSec: leftover,
        hubAfkSec: accAfter,
      ),
    );
  }
}
