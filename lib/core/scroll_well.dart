import '../models/meta_depth.dart';
import 'ad_boost.dart';

/// Daily bonus ladder in hub SCROLLS: 1 free ticket + 2 rewarded steps (UTC).
abstract final class ScrollWell {
  /// Free claim plus two ad steps.
  static const int bonusSteps = 3;

  /// Extra WATCH ads after the well, per UTC day. Wipe tickets do not count.
  static const int extraAdCap = 8;

  static MetaDepthState rollDay(MetaDepthState md, {DateTime? now}) {
    final day = AdBoost.utcDayKey(now);
    if (md.scrollWellUtcDay == day) return md;
    return md.copyWith(scrollWellUtcDay: day, scrollWellBonusClaims: 0);
  }

  static int bonusClaims(MetaDepthState md, {DateTime? now}) =>
      rollDay(md, now: now).scrollWellBonusClaims;

  static bool ladderComplete(MetaDepthState md, {DateTime? now}) =>
      bonusClaims(md, now: now) >= bonusSteps;

  static bool canClaimFree(MetaDepthState md, {DateTime? now}) =>
      !md.adFree && bonusClaims(md, now: now) == 0;

  static bool canAdvanceWithAd(MetaDepthState md, {DateTime? now}) {
    if (md.adFree) return false;
    final claims = bonusClaims(md, now: now);
    return claims >= 1 && claims < bonusSteps;
  }

  static int bonusRemaining(MetaDepthState md, {DateTime? now}) =>
      (bonusSteps - bonusClaims(md, now: now)).clamp(0, bonusSteps);

  /// Extra ticket ads already used today. A missing or stale day is 0.
  static int extraAdsToday(MetaDepthState md, {DateTime? now}) {
    final day = AdBoost.utcDayKey(now);
    if (md.extraTicketAdsUtc != day) return 0;
    return md.extraTicketAdsToday;
  }

  static int extraAdsRemaining(MetaDepthState md, {DateTime? now}) =>
      (extraAdCap - extraAdsToday(md, now: now)).clamp(0, extraAdCap);

  /// F2P only, and only after today's well ladder is finished.
  static bool canWatchExtraAd(MetaDepthState md, {DateTime? now}) {
    if (md.adFree) return false;
    if (!ladderComplete(md, now: now)) return false;
    return extraAdsToday(md, now: now) < extraAdCap;
  }

  static String extraAdsLine(MetaDepthState md, {DateTime? now}) {
    final used = extraAdsToday(md, now: now);
    return 'Extra tickets $used/$extraAdCap today';
  }

  static String progressLine(MetaDepthState md, {DateTime? now}) {
    final claims = bonusClaims(md, now: now);
    return '$claims/$bonusSteps today';
  }
}
