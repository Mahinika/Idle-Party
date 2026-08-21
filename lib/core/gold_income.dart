import 'dart:math';

import 'ad_boost.dart';
import 'game_state.dart';
import 'game_logic.dart';

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
    final found = percent <= 0
        ? torched
        : torched + (torched * percent) ~/ 100;
    if (!AdBoost.isActive(state.metaDepth.adBoostUntilMs)) return found;
    return found * 2;
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

  /// Rolling combat gold/min from credited samples (not a DPS formula).
  static const int sessionWindowMs = 120000;
  static const int sessionWarmupMs = 15000;

  static int runGoldPerMinuteFromSamples(
    List<(int ms, int gold)> samples, {
    required int nowMs,
    int windowMs = sessionWindowMs,
    int warmupMs = sessionWarmupMs,
  }) {
    final cutoff = nowMs - windowMs;
    var gold = 0;
    var first = nowMs;
    var any = false;
    for (final s in samples) {
      if (s.$1 < cutoff) continue;
      any = true;
      gold += s.$2;
      if (s.$1 < first) first = s.$1;
    }
    if (!any || gold <= 0) return 0;
    final spanMs = nowMs - first;
    if (spanMs < warmupMs) return 0;
    return (gold * 60000) ~/ spanMs;
  }

  static String ratesLine(GameState state, {int runGpm = 0}) {
    final hub = hubRateLine(state);
    if (runGpm <= 0) return hub;
    return '$hub · Run ${perMinuteLabel(runGpm)}';
  }

  /// Scale an observed rate when gold-find percent changes (combat already
  /// includes find — this is the honest +X g/min on CAMP / Blessing).
  static int scaledGpm(int gpm, int oldPercent, int newPercent) {
    if (gpm <= 0) return 0;
    final oldMul = 100 + oldPercent;
    if (oldMul <= 0) return gpm;
    return (gpm * (100 + newPercent)) ~/ oldMul;
  }

  static int goldFindDeltaOnRate(int gpm, int oldPercent, int newPercent) =>
      scaledGpm(gpm, oldPercent, newPercent) - gpm;

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
    if (AdBoost.isActive(state.metaDepth.adBoostUntilMs)) {
      bits.add('Ad ×2 gold');
      bits.add('Ad +${AdBoost.attackPercent}% ATK');
    }
    if (bits.isEmpty) return 'Gold +0%';
    return bits.join(' · ');
  }

  static int hubGoldPerMinuteAtGoldLevel(GameState state, int goldLevel) =>
      hubGoldPerMinute(state.copyWith(sanctuaryGoldLevel: goldLevel));

  static int nextGoldFindDeltaPerMinute(GameState state) =>
      hubGoldPerMinuteAtGoldLevel(state, state.sanctuaryGoldLevel + 1) -
      hubGoldPerMinute(state);

  static const int sanctuaryGoldBulkMax = 5;

  static int goldFindBulkAffordableLevels(GameState state) =>
      GameLogic.sanctuaryBulkAffordableLevels(
        state,
        'gold',
        maxLevels: sanctuaryGoldBulkMax,
      );

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
