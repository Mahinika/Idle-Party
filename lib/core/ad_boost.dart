import 'dart:math';

import '../models/meta_depth.dart';

/// POWERUPS: Ad Tickets from rewarded ads, spent on timed buffs.
///
/// See [docs/AD_POWERUPS_DESIGN.md]. Duration stacks per buff; effects do not
/// multiply in magnitude.
abstract final class AdBoost {
  static const int hourMs = 60 * 60 * 1000;
  static const int minuteMs = 60 * 1000;
  static const int maxStackMs = 24 * hourMs;

  /// Tickets granted per finished rewarded ad (or ad-free daily claim).
  static const int ticketsPerAd = 1;

  /// Extra attack while Sharp Edge / Full Boost ATK timer is running.
  /// Felt vs GOLD ATK tracks; still far from a second combat class / +100%.
  static const int attackPercent = 40;

  /// Combat + hub AFK gold while Gold Rush / Full Boost gold timer is running.
  static const int goldMul = 2;

  /// Next Welcome Back gold while Away Bonus is pending (one shot).
  static const int awayGoldMul = 3;

  /// Party combat XP while Study Rush is running.
  static const int xpPercent = 50;

  /// Hero walk speed while Fleet Foot is running.
  static const int movePercent = 30;

  /// Additive item-find while Lucky Bag is running (same unit as pet find).
  static const int lootFindPercent = 40;

  /// Dungeon sim + KEY/GR clocks while Time Warp is running (not hub AFK).
  static const int speedPercent = 25;

  /// Sharp Edge / Gold Rush / Study / Fleet / Lucky duration per ticket.
  static const int splitHours = 2;
  static const int splitMs = splitHours * hourMs;

  /// Full Boost: both timers (best ticket value vs buying splits).
  static const int hoursPerAd = 4;
  static const int rewardMs = hoursPerAd * hourMs;

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static bool isActive(int untilMs, {int? nowMs}) {
    final now = nowMs ?? AdBoost.nowMs();
    return untilMs > now;
  }

  static int remainingMs(int untilMs, {int? nowMs}) {
    final now = nowMs ?? AdBoost.nowMs();
    return max(0, untilMs - now);
  }

  static bool atStackCap(int untilMs, {int? nowMs}) {
    return remainingMs(untilMs, nowMs: nowMs) >= maxStackMs;
  }

  /// Extend [untilMs] by [addMs] from remaining time (or from now). Caps 24h.
  static int extendUntil(int untilMs, int addMs, {int? nowMs}) {
    if (addMs <= 0) return untilMs;
    final now = nowMs ?? AdBoost.nowMs();
    final base = untilMs > now ? untilMs : now;
    final cap = now + maxStackMs;
    if (base >= cap) return untilMs;
    final next = base + addMs;
    return next > cap ? cap : next;
  }

  /// Legacy helper — extend by [hoursPerAd] hours (Full Boost slice).
  static int addHour(int untilMs, {int? nowMs}) =>
      extendUntil(untilMs, rewardMs, nowMs: nowMs);

  static String formatRemaining(int untilMs, {int? nowMs}) {
    final ms = remainingMs(untilMs, nowMs: nowMs);
    if (ms <= 0) return '';
    final totalMin = max(1, (ms + 59999) ~/ 60000);
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h <= 0) return '${m}m';
    if (m <= 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static bool atkActive(MetaDepthState md, {int? nowMs}) =>
      isActive(md.adAtkUntilMs, nowMs: nowMs);

  static bool goldActive(MetaDepthState md, {int? nowMs}) =>
      isActive(md.adGoldUntilMs, nowMs: nowMs);

  static bool xpActive(MetaDepthState md, {int? nowMs}) =>
      isActive(md.adXpUntilMs, nowMs: nowMs);

  static bool moveActive(MetaDepthState md, {int? nowMs}) =>
      isActive(md.adMoveUntilMs, nowMs: nowMs);

  static bool lootActive(MetaDepthState md, {int? nowMs}) =>
      isActive(md.adLootUntilMs, nowMs: nowMs);

  static bool speedActive(MetaDepthState md, {int? nowMs}) =>
      isActive(md.adSpeedUntilMs, nowMs: nowMs);

  /// Live dungeon dt multiplier. KEY / GR timers use the same scale.
  static double combatDtMul(MetaDepthState md, {int? nowMs}) =>
      speedActive(md, nowMs: nowMs) ? (1 + speedPercent / 100) : 1.0;

  static bool anyBuffActive(MetaDepthState md, {int? nowMs}) =>
      atkActive(md, nowMs: nowMs) ||
      goldActive(md, nowMs: nowMs) ||
      xpActive(md, nowMs: nowMs) ||
      moveActive(md, nowMs: nowMs) ||
      lootActive(md, nowMs: nowMs) ||
      speedActive(md, nowMs: nowMs) ||
      awayBonusReady(md, nowMs: nowMs);

  static bool awayBonusReady(MetaDepthState md, {int? nowMs}) {
    if (!md.adOfflineMulPending) return false;
    final now = nowMs ?? AdBoost.nowMs();
    final exp = md.adOfflineMulExpiresMs;
    if (exp <= 0) return true;
    return exp > now;
  }

  /// Short FAB label: prefer ATK timer, else gold, else ticket count.
  static String fabStatus(MetaDepthState md, {int? nowMs}) {
    if (atkActive(md, nowMs: nowMs)) {
      return 'ATK ${formatRemaining(md.adAtkUntilMs, nowMs: nowMs)}';
    }
    if (goldActive(md, nowMs: nowMs)) {
      return 'GOLD ${formatRemaining(md.adGoldUntilMs, nowMs: nowMs)}';
    }
    if (xpActive(md, nowMs: nowMs)) {
      return 'XP ${formatRemaining(md.adXpUntilMs, nowMs: nowMs)}';
    }
    if (moveActive(md, nowMs: nowMs)) {
      return 'MOVE ${formatRemaining(md.adMoveUntilMs, nowMs: nowMs)}';
    }
    if (lootActive(md, nowMs: nowMs)) {
      return 'LOOT ${formatRemaining(md.adLootUntilMs, nowMs: nowMs)}';
    }
    if (speedActive(md, nowMs: nowMs)) {
      return 'SPEED ${formatRemaining(md.adSpeedUntilMs, nowMs: nowMs)}';
    }
    if (awayBonusReady(md, nowMs: nowMs)) return 'AWAY READY';
    final n = md.adTickets;
    if (n <= 0) return 'WATCH';
    return n == 1 ? '1 TICKET' : '$n TICKETS';
  }

  static String utcDayKey([DateTime? now]) {
    final d = (now ?? DateTime.now().toUtc());
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static bool canClaimAdFreeDaily(MetaDepthState md, {DateTime? now}) {
    if (!md.adFree) return false;
    return md.adFreeDailyClaimUtc != utcDayKey(now);
  }

  /// Hub camera overlay. Shown on a new save so WATCH is findable.
  /// Hidden only when ad-free and there is nothing to claim or spend.
  static bool showHubFab(MetaDepthState md, {DateTime? now}) {
    if (anyBuffActive(md) || md.adTickets > 0) return true;
    if (md.adFree) return canClaimAdFreeDaily(md, now: now);
    return true;
  }
}

/// Catalog row ids for POWERUPS spend.
enum AdBuffId { atk, gold, xp, move, loot, speed, bundle, offline }

class AdBuffOffer {
  const AdBuffOffer({
    required this.id,
    required this.label,
    required this.blurb,
    required this.ticketCost,
    required this.durationMs,
  });

  final AdBuffId id;
  final String label;
  final String blurb;
  final int ticketCost;
  final int durationMs;
}

/// Fixed POWERUPS shop (combat, farm, convenience).
abstract final class AdBuffCatalog {
  static const List<AdBuffOffer> offered = [
    AdBuffOffer(
      id: AdBuffId.atk,
      label: 'Sharp Edge',
      blurb:
          '+${AdBoost.attackPercent}% ATK for ${AdBoost.splitHours} hours — kills and bosses hit harder',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.gold,
      label: 'Gold Rush',
      blurb:
          '×${AdBoost.goldMul} all gold (kills, chests, hub AFK) for ${AdBoost.splitHours} hours',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.xp,
      label: 'Study Rush',
      blurb:
          '+${AdBoost.xpPercent}% party XP for ${AdBoost.splitHours} hours — levels land faster',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.move,
      label: 'Fleet Foot',
      blurb:
          '+${AdBoost.movePercent}% walk speed for ${AdBoost.splitHours} hours — caves feel snappier',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.loot,
      label: 'Lucky Bag',
      blurb:
          '+${AdBoost.lootFindPercent}% item find for ${AdBoost.splitHours} hours — more gear on kills',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.speed,
      label: 'Time Warp',
      blurb:
          '+${AdBoost.speedPercent}% dungeon speed for ${AdBoost.splitHours} hours — fights run faster; timed clocks keep pace',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.bundle,
      label: 'Full Boost',
      blurb:
          '+${AdBoost.attackPercent}% ATK and ×${AdBoost.goldMul} gold for ${AdBoost.hoursPerAd} hours — best ticket value',
      ticketCost: 2,
      durationMs: AdBoost.rewardMs,
    ),
    AdBuffOffer(
      id: AdBuffId.offline,
      label: 'Away Bonus',
      blurb:
          'Next Welcome Back gold ×${AdBoost.awayGoldMul} (expires in 24h if unused)',
      ticketCost: 1,
      durationMs: AdBoost.maxStackMs,
    ),
  ];

  static AdBuffOffer byId(AdBuffId id) =>
      offered.firstWhere((e) => e.id == id);
}
