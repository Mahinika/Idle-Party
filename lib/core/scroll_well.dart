import '../models/meta_depth.dart';
import 'ad_boost.dart';

/// Daily bonus ladder in hub SCROLLS: 1 free ticket + 2 rewarded steps (UTC).
abstract final class ScrollWell {
  /// Free claim plus two ad steps.
  static const int bonusSteps = 3;

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

  static String progressLine(MetaDepthState md, {DateTime? now}) {
    final claims = bonusClaims(md, now: now);
    return '$claims/$bonusSteps today';
  }
}
