import 'day_clock.dart';
import 'game_state.dart';

/// One-time rewrite of UTC day keys onto the local calendar.
abstract final class DayMigrate {
  static GameState apply(GameState state, DateTime now) {
    final roi = state.metaDepth.roi2;
    if (roi.dayKeysAreLocal) return state;
    final utc = now.toUtc();
    final offset = DayClock.offsetMinutes();
    final utcKey = DayClock.ymd(utc, 0);
    final localKey = DayClock.ymd(utc, offset);
    String rewrite(String stored) => stored == utcKey ? localKey : stored;
    final hold = utcKey == localKey
        ? 0
        : DayClock.laterMs(
            DayClock.nextMidnightUtcMs(utc, 0),
            DayClock.nextMidnightUtcMs(utc, offset),
          );
    final md = state.metaDepth;
    return state.copyWith(
      lastDailyDate: state.lastDailyDate == null
          ? null
          : rewrite(state.lastDailyDate!),
      metaDepth: md.copyWith(
        dailyVaultDate: rewrite(md.dailyVaultDate),
        pushPeakDate: rewrite(md.pushPeakDate),
        prevPushPeakDate: rewrite(md.prevPushPeakDate),
        dailyQuestDate: rewrite(md.dailyQuestDate),
        adFreeDailyClaimUtc: rewrite(md.adFreeDailyClaimUtc),
        scrollWellUtcDay: rewrite(md.scrollWellUtcDay),
        questRerollUtcDay: rewrite(md.questRerollUtcDay),
        petErrandStockUtcDay: rewrite(md.petErrandStockUtcDay),
        campAdUtc: rewrite(md.campAdUtc),
        extraTicketAdsUtc: rewrite(md.extraTicketAdsUtc),
        wispGiftUtcDay: rewrite(md.wispGiftUtcDay),
        awayPromiseUtc: rewrite(md.awayPromiseUtc),
        roi2: roi.copyWith(
          dayKeysAreLocal: true,
          tzOffsetMinutes: offset,
          tzPinnedDay: localKey,
          dailyRefillHoldUntilMs: hold,
        ),
      ),
    );
  }
}
