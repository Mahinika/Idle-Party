import 'funnel_analytics.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// One scheduled away ping (id is stable so gold/cave overwrite themselves).
class LocalPing {
  const LocalPing({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
  });

  static const goldId = 1;
  static const caveId = 2;

  final int id;
  final DateTime fireAt;
  final String title;
  final String body;
}

/// Growth-mandate local reminders: opt-in after a milestone, ≤2/UTC day.
abstract final class LocalReminders {
  static const int maxPerUtcDay = 2;
  static const Duration goldDelay = Duration(hours: 4);
  static const Duration caveDelay = Duration(hours: 18);
  static const String title = 'Idle Party';
  static const String goldBody = 'Gold kept coming in. Come pick it up.';
  static const String caveBodyNew = 'Your party is ready when you are.';
  static const String caveBodyDaily = 'One cave is waiting today.';
  static const String optInTitle = 'A quiet ping?';
  static const String optInBody =
      'Want a reminder when gold is waiting, or when a cave is ready? '
      'At most a couple a day. Never during a fight. Turn off anytime in SETTINGS.';

  static bool milestoneReached(GameState state) {
    final reward =
        FunnelAnalytics.has(state, FunnelAnalytics.firstReward) ||
        FunnelAnalytics.has(state, FunnelAnalytics.firstBoss) ||
        state.lifetimeGoldEarned > 0 ||
        state.bossVictories > 0;
    if (!reward) return false;
    return FunnelAnalytics.has(state, FunnelAnalytics.firstEnter) ||
        state.highestFloorCleared >= 1 ||
        state.metaDepth.lifetimeFloorClears >= 1 ||
        state.ascensionLevel >= 1;
  }

  /// In-game card — hub only, after first loot, never install, never combat.
  static bool shouldOfferOptIn(GameState state) {
    if (state.inDungeon) return false;
    if (state.metaDepth.notifyPrompted || state.metaDepth.notifyOptIn) {
      return false;
    }
    return milestoneReached(state);
  }

  /// SETTINGS row after the milestone (or after they already answered).
  static bool showSettingsToggle(GameState state) =>
      milestoneReached(state) ||
      state.metaDepth.notifyPrompted ||
      state.metaDepth.notifyOptIn;

  static String caveBodyFor(GameState state) =>
      GameLogic.showDailyChase(state) ? caveBodyDaily : caveBodyNew;

  static List<LocalPing> plan(GameState state, DateTime now) {
    if (!state.metaDepth.notifyOptIn) return const [];
    if (!milestoneReached(state)) return const [];
    final fired = <int>[
      for (final ms in state.metaDepth.notifyPingMs)
        if (ms <= now.millisecondsSinceEpoch) ms,
    ];
    final out = <LocalPing>[];
    final goldAt = now.add(goldDelay);
    if (_countOnUtcDay(fired, goldAt) < maxPerUtcDay) {
      out.add(
        LocalPing(
          id: LocalPing.goldId,
          fireAt: goldAt,
          title: title,
          body: goldBody,
        ),
      );
    }
    final caveAt = now.add(caveDelay);
    final counted = [
      ...fired,
      ...out.map((p) => p.fireAt.millisecondsSinceEpoch),
    ];
    if (_countOnUtcDay(counted, caveAt) < maxPerUtcDay) {
      out.add(
        LocalPing(
          id: LocalPing.caveId,
          fireAt: caveAt,
          title: title,
          body: caveBodyFor(state),
        ),
      );
    }
    return out;
  }

  static GameState recordPlan(
    GameState state,
    List<LocalPing> pings, {
    required DateTime now,
  }) {
    final kept = <int>[
      for (final ms in state.metaDepth.notifyPingMs)
        if (ms <= now.millisecondsSinceEpoch) ms,
    ];
    final next = <int>[
      ...kept,
      ...pings.map((p) => p.fireAt.millisecondsSinceEpoch),
    ];
    final cutoff = now
        .toUtc()
        .subtract(const Duration(days: 3))
        .millisecondsSinceEpoch;
    next.removeWhere((ms) => ms < cutoff);
    if (_sameInts(next, state.metaDepth.notifyPingMs)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(notifyPingMs: List<int>.from(next)),
    );
  }

  static GameState clearFuture(GameState state, DateTime now) {
    final kept = <int>[
      for (final ms in state.metaDepth.notifyPingMs)
        if (ms <= now.millisecondsSinceEpoch) ms,
    ];
    if (_sameInts(kept, state.metaDepth.notifyPingMs)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(notifyPingMs: kept),
    );
  }

  static GameState setOptIn(GameState state, {required bool enabled}) {
    final prompted = true;
    if (state.metaDepth.notifyOptIn == enabled &&
        state.metaDepth.notifyPrompted == prompted &&
        (enabled || state.metaDepth.notifyPingMs.isEmpty)) {
      return state;
    }
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        notifyOptIn: enabled,
        notifyPrompted: prompted,
        notifyPingMs: enabled ? state.metaDepth.notifyPingMs : const <int>[],
      ),
    );
  }

  static DateTime utcDay(DateTime t) {
    final u = t.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }

  static int _countOnUtcDay(List<int> pingMs, DateTime fireAt) {
    final day = utcDay(fireAt);
    var n = 0;
    for (final ms in pingMs) {
      final t = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      if (utcDay(t) == day) n++;
    }
    return n;
  }

  static bool _sameInts(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
