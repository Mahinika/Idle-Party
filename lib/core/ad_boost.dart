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
  static const int attackPercent = 25;

  /// Legacy: one old “watch ad” = Full Boost duration (3h both).
  static const int hoursPerAd = 3;
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

  static bool anyBuffActive(MetaDepthState md, {int? nowMs}) =>
      atkActive(md, nowMs: nowMs) ||
      goldActive(md, nowMs: nowMs) ||
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
}

/// Catalog row ids for POWERUPS spend.
enum AdBuffId { atk, gold, bundle, offline }

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

/// Fixed POWERUPS shop (exactly four rows).
abstract final class AdBuffCatalog {
  static const List<AdBuffOffer> offered = [
    AdBuffOffer(
      id: AdBuffId.atk,
      label: 'Sharp Edge',
      blurb: '+${AdBoost.attackPercent}% ATK for 60 minutes',
      ticketCost: 1,
      durationMs: 60 * AdBoost.minuteMs,
    ),
    AdBuffOffer(
      id: AdBuffId.gold,
      label: 'Gold Rush',
      blurb: '×2 gold for 60 minutes',
      ticketCost: 1,
      durationMs: 60 * AdBoost.minuteMs,
    ),
    AdBuffOffer(
      id: AdBuffId.bundle,
      label: 'Full Boost',
      blurb:
          '+${AdBoost.attackPercent}% ATK and ×2 gold for ${AdBoost.hoursPerAd} hours',
      ticketCost: 2,
      durationMs: AdBoost.rewardMs,
    ),
    AdBuffOffer(
      id: AdBuffId.offline,
      label: 'Away Bonus',
      blurb: 'Next Welcome Back gold ×2 (expires in 24h if unused)',
      ticketCost: 1,
      durationMs: AdBoost.maxStackMs,
    ),
  ];

  static AdBuffOffer byId(AdBuffId id) =>
      offered.firstWhere((e) => e.id == id);
}
