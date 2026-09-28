import 'dart:math';

import '../models/dungeon_room.dart';
import '../models/meta_depth.dart';
import 'ad_boost.dart';
import 'economy_service.dart';
import 'encounter_factory.dart';
import 'game_state.dart';

/// Floating WISP: tap for a small gold pile; optional rewarded ad on hub for
/// 10× gold + 1h ×2 gold (Scroll of Gold magnitude). See plan / AD_POWERUPS.
abstract final class WispGift {
  static const int keepFloorMul = 3;
  static const int watchFloorMul = 30;
  static const int watchGoldHourMs = AdBoost.hourMs;
  static const int dailyCap = 6;
  static const int firstDelayMs = 90 * 1000;
  static const int intervalMs = 10 * 60 * 1000;
  static const int visibleMs = 10 * 1000;

  static String utcDayKey([DateTime? now]) => AdBoost.utcDayKey(now);

  static MetaDepthState rollDaily(MetaDepthState md, {DateTime? now}) {
    final day = utcDayKey(now);
    if (md.wispGiftUtcDay == day) return md;
    return md.copyWith(wispGiftUtcDay: day, wispGiftClaimsToday: 0);
  }

  static int claimsToday(MetaDepthState md, {DateTime? now}) {
    final rolled = rollDaily(md, now: now);
    return rolled.wispGiftClaimsToday;
  }

  static bool canTapToday(MetaDepthState md, {DateTime? now}) {
    return claimsToday(md, now: now) < dailyCap;
  }

  static bool unlocked(MetaDepthState md) => md.wispUnlocked;

  /// First dungeon enter arms the schedule.
  static MetaDepthState unlockOnFirstEnter(MetaDepthState md, {int? nowMs}) {
    if (md.wispUnlocked) return md;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return md.copyWith(
      wispUnlocked: true,
      wispNextSpawnMs: now + firstDelayMs,
    );
  }

  static bool hasPendingChoice(MetaDepthState md) => md.wispPendingWatchGold > 0;

  /// Gold from one normal floor at the player's current progression.
  static int perFloorGold(GameState state) {
    final room = state.currentRoom;
    final normal = room.type == RoomType.boss
        ? room.copyWith(type: RoomType.normal)
        : room;
    final budget = EncounterFactory.roomCombatBudget(
      normal,
      dungeonId: state.dungeonId,
      hardmodeLevel: state.hardmodeLevel,
      ascensionLevel: state.ascensionLevel,
      gearPressure: EncounterFactory.partyGearPressure(state),
    );
    return max(1, EconomyService.applyGoldGain(state, budget.gold));
  }

  static int keepGold(GameState state) =>
      max(1, perFloorGold(state) * keepFloorMul);

  static int watchGold(GameState state) =>
      max(keepGold(state) * 10, perFloorGold(state) * watchFloorMul);

  static bool shouldSpawn(MetaDepthState md, int nowMs) {
    if (!md.wispUnlocked) return false;
    if (!canTapToday(md)) return false;
    if (hasPendingChoice(md)) return false;
    if (md.wispNextSpawnMs <= 0) return false;
    return nowMs >= md.wispNextSpawnMs;
  }

  static GameState creditGold(GameState state, int gained) {
    if (gained <= 0) return state;
    return state.copyWith(
      gold: state.gold + gained,
      lifetimeGoldEarned: state.lifetimeGoldEarned + gained,
    );
  }

  /// Tap the visible WISP: grant KEEP, lock WATCH amount, schedule next spawn.
  static GameState onWispTapped(GameState state, {int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    var md = rollDaily(state.metaDepth, now: DateTime.fromMillisecondsSinceEpoch(now).toUtc());
    if (!canTapToday(md, now: DateTime.fromMillisecondsSinceEpoch(now).toUtc())) {
      return state;
    }
    final keep = keepGold(state);
    final watch = watchGold(state);
    final nextClaims = md.wispGiftClaimsToday + 1;
    md = md.copyWith(
      wispGiftUtcDay: utcDayKey(DateTime.fromMillisecondsSinceEpoch(now).toUtc()),
      wispGiftClaimsToday: nextClaims.clamp(0, dailyCap),
      wispPendingWatchGold: watch,
      wispPendingKeepGold: keep,
      wispNextSpawnMs: now + intervalMs,
    );
    return creditGold(state.copyWith(metaDepth: md), keep);
  }

  /// After a finished ad (or ad-free auto): grant locked WATCH + 1h gold scroll.
  static GameState grantWatchReward(GameState state, {int? nowMs}) {
    final md = state.metaDepth;
    final pending = md.wispPendingWatchGold;
    if (pending <= 0) return state;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    var goldUntil = md.adGoldUntilMs;
    final atCap = AdBoost.atStackCap(goldUntil, nowMs: now);
    if (!atCap) {
      goldUntil = AdBoost.extendUntil(goldUntil, watchGoldHourMs, nowMs: now);
    }
    final legacy = goldUntil > md.adAtkUntilMs ? goldUntil : md.adAtkUntilMs;
    final nextMd = md.copyWith(
      wispPendingWatchGold: 0,
      wispPendingKeepGold: 0,
      adGoldUntilMs: goldUntil,
      adBoostUntilMs: legacy,
    );
    return creditGold(state.copyWith(metaDepth: nextMd), pending);
  }

  /// WISP vanished without a tap — wait for the next interval.
  static GameState onWispMissed(GameState state, {int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(wispNextSpawnMs: now + intervalMs),
    );
  }

  static GameState dismissPending(GameState state) {
    final md = state.metaDepth;
    if (!hasPendingChoice(md)) return state;
    return state.copyWith(
      metaDepth: md.copyWith(
        wispPendingWatchGold: 0,
        wispPendingKeepGold: 0,
      ),
    );
  }

  static bool goldHourAtCap(GameState state, {int? nowMs}) {
    return AdBoost.atStackCap(state.metaDepth.adGoldUntilMs, nowMs: nowMs);
  }

  static String watchButtonLabel(GameState state) {
    final watch = state.metaDepth.wispPendingWatchGold;
    return '${_formatGold(watch)} GOLD + 1 HOUR ×2';
  }

  static String _formatGold(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) {
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return '$n';
  }
}
