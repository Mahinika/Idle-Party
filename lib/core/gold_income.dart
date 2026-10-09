import 'dart:math';

import 'ad_boost.dart';
import 'blessing_constellation.dart';
import 'game_state.dart';
import 'game_logic.dart';

/// Hub gold rate and AFK yield — one formula for live ticks, CAMP preview,
/// and sanctuary offline. Dungeon combat gold is separate.
abstract final class GoldIncome {
  /// Raw gold per minute before Torch and gold-find percent.
  ///
  /// Hub is slower than a dungeon run, but overnight at the keep should still
  /// buy forge — not sit at 2g/min while combat prints ~90.
  static int hubRawPerMinute(GameState state) =>
      10 +
      state.sanctuaryGoldLevel +
      state.ascensionLevel * 2 +
      (state.highestDungeonCleared + 1) * 2;

  static int goldFindPercent(GameState state) =>
      state.effectiveGoldFindPercent;

  static int goldFromRaw(GameState state, int raw) {
    if (raw <= 0) return 0;
    final torched = raw + (raw * state.torchOfflineGoldPercent) ~/ 100;
    final percent = goldFindPercent(state);
    final found = percent <= 0
        ? torched
        : torched + (torched * percent) ~/ 100;
    final porch = state.relicOfflineGoldPercent;
    final withPorch = porch <= 0 ? found : found + (found * porch) ~/ 100;
    if (!AdBoost.goldActive(state.metaDepth)) return withPorch;
    return withPorch * AdBoost.goldMul;
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

  /// Hub sanctuary gold while the app is closed. Live ticks on the open hub
  /// are not this chest — the player is here. Dungeon offline stays separate.
  static const int hubChestCapSec = 12 * 3600;

  /// Hub chest after SHOP Long Away.
  static const int hubChestLongSec = 24 * 3600;

  static int get hubChestCapHours => hubChestCapSec ~/ 3600;

  static int hubChestCapSecFor(GameState state) =>
      state.metaDepth.shopLongAway ? hubChestLongSec : hubChestCapSec;

  static int hubChestCapHoursFor(GameState state) =>
      hubChestCapSecFor(state) ~/ 3600;

  /// Commas past 999. `8640` → `8,640`.
  static String groupDigits(int n) {
    final negative = n < 0;
    final s = n.abs().toString();
    final buf = StringBuffer();
    if (negative) buf.write('-');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// What the party earns if the player leaves. Hub rate is steady gold.
  /// A cave keeps the fight going instead — that is not a second gold rate.
  /// [wasInDungeon] is the place they actually left. The hub rate is not
  /// the story when the party was in a cave.
  static String awayPromise(GameState state, {bool wasInDungeon = false}) {
    final hours = hubChestCapHoursFor(state);
    if (wasInDungeon) {
      return 'Your party kept fighting in the cave. '
          'On the hub, gold gathers for up to $hours hours, then it stops.';
    }
    final rate = perMinuteLabel(hubGoldPerMinute(state));
    return 'While you are away the hub pays $rate for up to '
        '$hours hours, then it stops. '
        'Leave the party in a cave and they keep fighting.';
  }

  static String hubRateLine(GameState state) => awayPromise(state);

  /// Tiny hub header suffix next to gold (full line in income sheet).
  static String hubRateCompact(GameState state) =>
      '+${hubGoldPerMinute(state)}/m · ${hubChestCapHoursFor(state)}h';

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
      ('Essence', state.sanctuaryGoldBonusPercent),
      ('Blessing', state.ascendBlessingGoldPercent),
      ('Stars', BlessingConstellation.goldFindPercent(state)),
      ('gear', state.gearGoldFindPercent),
      ('pet', state.petGoldFindPercent),
      ('Relic', state.relicOfflineGoldPercent),
      ('Torch', state.torchOfflineGoldPercent),
    ].where((p) => p.$2 > 0).toList();
  }

  static String multiplierLine(GameState state) {
    final bits = [
      for (final p in multiplierParts(state)) '${p.$1} +${p.$2}%',
    ];
    // Hub gold uses the soft-capped find, not the raw stack of those percents.
    if (state.totalGoldFindPercent > state.effectiveGoldFindPercent) {
      bits.add('uses ${state.effectiveGoldFindPercent}%');
    }
    if (AdBoost.goldActive(state.metaDepth)) {
      bits.add('Ad ×${AdBoost.goldMul} gold');
    }
    if (AdBoost.atkActive(state.metaDepth)) {
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

  /// Hub AFK essence stays slow — CAMP/KEEP buys are permanent.
  ///
  /// After a 10-min gate: about 1e per 12.5 min at War Altar 0. Each Altar
  /// level shortens the interval so deltas actually credit power (the old
  /// flat `power~/2` canceled in every live tick).
  static int essenceDue(int totalSec, int sanctuaryPowerLevel) {
    if (totalSec < 600) return 0;
    final power = sanctuaryPowerLevel < 0 ? 0 : sanctuaryPowerLevel;
    final interval = max(450, 750 - power * 25);
    return totalSec ~/ interval;
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
