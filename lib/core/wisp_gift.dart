import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/dungeon_def.dart';
import '../models/dungeon_room.dart';
import '../models/meta_depth.dart';
import 'ad_boost.dart';
import 'economy_service.dart';
import 'encounter_factory.dart';
import 'game_state.dart';
import 'keystone.dart';

/// Floating WISP: tap for a small gold pile; optional rewarded ad for a
/// bigger gold pile (no time boost). See plan / AD_POWERUPS.
///
/// Amounts track **best cleared zone** (and a wallet soft floor), not the
/// farm floor you happen to stand on — otherwise late-game Sandy runs make
/// a 30s ad pay pocket change.
abstract final class WispGift {
  static const int keepFloorMul = 3;
  /// Floors of reference gold for the WATCH pile (before wallet floor).
  static const int watchFloorMul = 60;
  /// WATCH is at least ~4% of wallet so endgame always feels worth the ad.
  static const int watchWalletDivisor = 25;
  /// Wallet floor cannot exceed this many reference floors (anti-whale spike).
  static const int watchWalletCapFloorMul = 120;
  /// Floor used when scoring the best cleared zone.
  static const int referenceFloor = 10;

  /// Live cadence. Debug builds (emulator) spawn often with no daily cap
  /// so the gift can be tried without waiting. Release keeps the real loop.
  static const int releaseDailyCap = 6;
  static const int releaseFirstDelayMs = 90 * 1000;
  static const int releaseIntervalMs = 10 * 60 * 1000;
  static int get dailyCap => kDebugMode ? 1000000 : releaseDailyCap;
  static int get firstDelayMs => kDebugMode ? 20 * 1000 : releaseFirstDelayMs;
  static int get intervalMs => kDebugMode ? 20 * 1000 : releaseIntervalMs;
  static const int visibleMs = 10 * 1000;

  static bool get unlimitedToday => kDebugMode;

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
    if (unlimitedToday) return true;
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

  static String _dungeonIdForClearedIndex(int cleared) {
    final idx = cleared.clamp(0, DungeonCatalog.all.length - 1);
    return DungeonCatalog.all[idx].id;
  }

  /// One normal-floor gold payout for [dungeonId] / [floor], with live KEY
  /// combat level only (dial alone does not inflate hub WISP).
  static int floorGold(
    GameState state, {
    required String dungeonId,
    required int floor,
  }) {
    final room = DungeonRoom(
      floorNumber: max(1, floor),
      roomIndex: 0,
      type: RoomType.normal,
      enemyLevel: max(1, floor),
      enemyCount: 1,
    );
    final budget = EncounterFactory.roomCombatBudget(
      room,
      dungeonId: dungeonId,
      hardmodeLevel: Keystone.combatLevel(state),
      ascensionLevel: state.ascensionLevel,
      gearPressure: EncounterFactory.partyGearPressure(state),
    );
    return max(1, EconomyService.applyGoldGain(state, budget.gold));
  }

  /// Gold from one normal floor at the player's current room (legacy helper).
  static int perFloorGold(GameState state) {
    final room = state.currentRoom;
    return floorGold(
      state,
      dungeonId: state.dungeonId,
      floor: room.floorNumber,
    );
  }

  /// Better of current floor vs best-cleared zone at [referenceFloor].
  static int referencePerFloorGold(GameState state) {
    final current = perFloorGold(state);
    final bestId = _dungeonIdForClearedIndex(state.highestDungeonCleared);
    final bestFloor = max(
      referenceFloor,
      min(20, max(1, state.currentRoom.floorNumber)),
    );
    final best = floorGold(state, dungeonId: bestId, floor: bestFloor);
    return max(current, best);
  }

  static int keepGold(GameState state) =>
      max(1, referencePerFloorGold(state) * keepFloorMul);

  static int watchGold(GameState state) {
    final ref = referencePerFloorGold(state);
    final fromFloors = ref * watchFloorMul;
    final fromKeepBand = keepGold(state) * 10;
    final rawWallet = state.gold <= 0 ? 0 : state.gold ~/ watchWalletDivisor;
    final walletCap = max(fromFloors, ref * watchWalletCapFloorMul);
    final fromWallet = min(rawWallet, walletCap);
    return max(1, max(fromKeepBand, max(fromFloors, fromWallet)));
  }

  static bool shouldSpawn(MetaDepthState md, int nowMs) {
    if (!md.wispUnlocked) return false;
    if (!canTapToday(md)) return false;
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

  /// After a finished ad (or ad-free auto): grant locked WATCH gold only.
  static GameState grantWatchReward(GameState state) {
    final md = state.metaDepth;
    final pending = md.wispPendingWatchGold;
    if (pending <= 0) return state;
    final nextMd = md.copyWith(
      wispPendingWatchGold: 0,
      wispPendingKeepGold: 0,
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

  static String watchButtonLabel(GameState state) {
    final watch = state.metaDepth.wispPendingWatchGold;
    return '${_formatGold(watch)} GOLD';
  }

  static String keepButtonLabel(GameState state) {
    final keep = state.metaDepth.wispPendingKeepGold;
    final shown = keep > 0 ? keep : keepGold(state);
    return '${_formatGold(shown)} GOLD';
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
