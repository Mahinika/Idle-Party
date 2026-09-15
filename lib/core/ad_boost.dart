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

  /// Tight HUD remaining (`42m` or `1:12`).
  static String formatChipRemaining(int untilMs, {int? nowMs}) {
    final ms = remainingMs(untilMs, nowMs: nowMs);
    if (ms <= 0) return '';
    final totalMin = max(1, (ms + 59999) ~/ 60000);
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (h <= 0) return '${m}m';
    return '$h:${m.toString().padLeft(2, '0')}';
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

  /// Short FAB label: tickets or WATCH. Remaining time lives on [hudChips].
  static String fabStatus(MetaDepthState md, {int? nowMs}) {
    final n = md.adTickets;
    if (n <= 0) return 'WATCH';
    return n == 1 ? '1 TICKET' : '$n TICKETS';
  }

  /// Active scrolls for hub / dungeon HUD, catalog order (top → bottom).
  static List<AdScrollHudChip> hudChips(MetaDepthState md, {int? nowMs}) {
    final now = nowMs ?? AdBoost.nowMs();
    final chips = <AdScrollHudChip>[];
    void add(AdBuffId id, int untilMs, String shortLabel) {
      if (!isActive(untilMs, nowMs: now)) return;
      chips.add(
        AdScrollHudChip(
          id: id,
          shortLabel: shortLabel,
          timeLabel: formatChipRemaining(untilMs, nowMs: now),
        ),
      );
    }

    add(AdBuffId.atk, md.adAtkUntilMs, 'ATK');
    add(AdBuffId.gold, md.adGoldUntilMs, 'GOLD');
    add(AdBuffId.xp, md.adXpUntilMs, 'XP');
    add(AdBuffId.move, md.adMoveUntilMs, 'MOVE');
    add(AdBuffId.loot, md.adLootUntilMs, 'LOOT');
    add(AdBuffId.speed, md.adSpeedUntilMs, 'HASTE');
    if (awayBonusReady(md, nowMs: now)) {
      final exp = md.adOfflineMulExpiresMs;
      chips.add(
        AdScrollHudChip(
          id: AdBuffId.offline,
          shortLabel: 'REST',
          timeLabel: exp <= 0 ? 'RDY' : formatChipRemaining(exp, nowMs: now),
        ),
      );
    }
    return chips;
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

  /// Hub SCROLLS overlay. Shown on a new save so tickets are findable.
  /// Hidden only when ad-free and there is nothing to claim or spend.
  static bool showHubFab(MetaDepthState md, {DateTime? now}) {
    if (anyBuffActive(md) || md.adTickets > 0) return true;
    if (md.adFree) return canClaimAdFreeDaily(md, now: now);
    return true;
  }

  /// Timer chip on a POWERUPS spend row, or null if that buff is idle.
  static String? rowTimer(AdBuffId id, MetaDepthState md, {int? nowMs}) {
    switch (id) {
      case AdBuffId.atk:
        return atkActive(md, nowMs: nowMs)
            ? formatRemaining(md.adAtkUntilMs, nowMs: nowMs)
            : null;
      case AdBuffId.gold:
        return goldActive(md, nowMs: nowMs)
            ? formatRemaining(md.adGoldUntilMs, nowMs: nowMs)
            : null;
      case AdBuffId.xp:
        return xpActive(md, nowMs: nowMs)
            ? formatRemaining(md.adXpUntilMs, nowMs: nowMs)
            : null;
      case AdBuffId.move:
        return moveActive(md, nowMs: nowMs)
            ? formatRemaining(md.adMoveUntilMs, nowMs: nowMs)
            : null;
      case AdBuffId.loot:
        return lootActive(md, nowMs: nowMs)
            ? formatRemaining(md.adLootUntilMs, nowMs: nowMs)
            : null;
      case AdBuffId.speed:
        return speedActive(md, nowMs: nowMs)
            ? formatRemaining(md.adSpeedUntilMs, nowMs: nowMs)
            : null;
      case AdBuffId.bundle:
        final a = remainingMs(md.adAtkUntilMs, nowMs: nowMs);
        final g = remainingMs(md.adGoldUntilMs, nowMs: nowMs);
        if (a <= 0 && g <= 0) return null;
        final until = a >= g ? md.adAtkUntilMs : md.adGoldUntilMs;
        return formatRemaining(until, nowMs: nowMs);
      case AdBuffId.offline:
        return awayBonusReady(md, nowMs: nowMs) ? 'READY' : null;
    }
  }
}

/// Catalog row ids for POWERUPS spend.
enum AdBuffId { atk, gold, xp, move, loot, speed, bundle, offline }

/// One lit scroll on hub / dungeon HUD.
class AdScrollHudChip {
  const AdScrollHudChip({
    required this.id,
    required this.shortLabel,
    required this.timeLabel,
  });

  final AdBuffId id;
  final String shortLabel;
  final String timeLabel;
}

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

  /// One-line sheet subtitle (phone width).
  String get effect => switch (id) {
    AdBuffId.atk =>
      '+${AdBoost.attackPercent}% ATK · ${AdBoost.splitHours}h',
    AdBuffId.gold =>
      '×${AdBoost.goldMul} gold · ${AdBoost.splitHours}h',
    AdBuffId.xp =>
      '+${AdBoost.xpPercent}% party XP · ${AdBoost.splitHours}h',
    AdBuffId.move =>
      '+${AdBoost.movePercent}% walk · ${AdBoost.splitHours}h',
    AdBuffId.loot =>
      '+${AdBoost.lootFindPercent}% item find · ${AdBoost.splitHours}h',
    AdBuffId.speed =>
      '+${AdBoost.speedPercent}% dungeon speed · ${AdBoost.splitHours}h',
    AdBuffId.bundle =>
      'ATK + gold · ${AdBoost.hoursPerAd}h',
    AdBuffId.offline =>
      'Next AFK gold ×${AdBoost.awayGoldMul}',
  };
}

/// Fixed POWERUPS shop (combat, farm, convenience).
abstract final class AdBuffCatalog {
  static const List<AdBuffOffer> offered = [
    AdBuffOffer(
      id: AdBuffId.atk,
      label: 'Scroll of Damage',
      blurb:
          '+${AdBoost.attackPercent}% ATK for ${AdBoost.splitHours} hours — kills and bosses hit harder',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.gold,
      label: 'Scroll of Gold',
      blurb:
          '×${AdBoost.goldMul} all gold (kills, chests, hub AFK) for ${AdBoost.splitHours} hours',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.xp,
      label: 'Scroll of XP',
      blurb:
          '+${AdBoost.xpPercent}% party XP for ${AdBoost.splitHours} hours — levels land faster',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.move,
      label: 'Scroll of Speed',
      blurb:
          '+${AdBoost.movePercent}% walk speed for ${AdBoost.splitHours} hours — caves feel snappier',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.loot,
      label: 'Scroll of Loot',
      blurb:
          '+${AdBoost.lootFindPercent}% item find for ${AdBoost.splitHours} hours — more gear on kills',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.speed,
      label: 'Scroll of Haste',
      blurb:
          '+${AdBoost.speedPercent}% dungeon speed for ${AdBoost.splitHours} hours — fights run faster; timed clocks keep pace',
      ticketCost: 1,
      durationMs: AdBoost.splitMs,
    ),
    AdBuffOffer(
      id: AdBuffId.bundle,
      label: 'Scroll of Battle',
      blurb:
          '+${AdBoost.attackPercent}% ATK and ×${AdBoost.goldMul} gold for ${AdBoost.hoursPerAd} hours — best ticket value',
      ticketCost: 2,
      durationMs: AdBoost.rewardMs,
    ),
    AdBuffOffer(
      id: AdBuffId.offline,
      label: 'Scroll of Rest',
      blurb:
          'Next Welcome Back gold ×${AdBoost.awayGoldMul} (expires in 24h if unused)',
      ticketCost: 1,
      durationMs: AdBoost.maxStackMs,
    ),
  ];

  static AdBuffOffer byId(AdBuffId id) =>
      offered.firstWhere((e) => e.id == id);
}
