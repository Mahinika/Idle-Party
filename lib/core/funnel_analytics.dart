import 'game_state.dart';

/// Growth-mandate Play funnel. Once-per-install flags live on metaDepth
/// (survive Ascend). Firebase auto-collects `first_open`; we still stamp it
/// locally so the rest of the chain has an install day.
class FunnelHit {
  const FunnelHit(this.name, [this.params = const <String, Object>{}]);

  final String name;
  final Map<String, Object> params;
}

class FunnelTick {
  const FunnelTick(this.state, this.events);

  final GameState state;
  final List<FunnelHit> events;

  static FunnelTick none(GameState state) =>
      FunnelTick(state, const <FunnelHit>[]);
}

abstract final class FunnelAnalytics {
  static const firstOpen = 'first_open';
  static const appReady = 'app_ready';
  static const firstEnter = 'first_enter';
  static const firstReward = 'first_reward';
  static const firstBoss = 'first_boss';
  static const d1Return = 'd1_return';
  static const timeToCombat = 'time_to_combat';

  /// Mandate names plus the seconds-to-combat companion event.
  static const List<String> allNames = <String>[
    firstOpen,
    appReady,
    firstEnter,
    firstReward,
    firstBoss,
    d1Return,
    timeToCombat,
  ];

  /// Pre-funnel saves: stamp install and mark the chain done without emitting.
  static const List<String> _legacyBackfill = <String>[
    firstOpen,
    appReady,
    firstEnter,
    firstReward,
    firstBoss,
    d1Return,
    timeToCombat,
  ];

  static bool has(GameState state, String name) =>
      state.metaDepth.funnelLogged.contains(name);

  /// New Game — first_open + app_ready once.
  static FunnelTick onNewInstall(GameState state, DateTime now) {
    final ms = now.toUtc().millisecondsSinceEpoch;
    var next = state;
    final events = <FunnelHit>[];
    if (next.metaDepth.funnelInstallMs == 0) {
      next = _stampInstall(next, ms);
    }
    if (!has(next, firstOpen)) {
      next = _mark(next, firstOpen);
      events.add(const FunnelHit(firstOpen));
    }
    if (!has(next, appReady)) {
      next = _mark(next, appReady);
      events.add(const FunnelHit(appReady));
    }
    return events.isEmpty ? FunnelTick.none(state) : FunnelTick(next, events);
  }

  /// Continue / cold boot of an existing save.
  static FunnelTick onExistingSession(GameState state, DateTime now) {
    if (state.metaDepth.funnelInstallMs == 0) {
      return FunnelTick(
        state.copyWith(
          metaDepth: state.metaDepth.copyWith(
            funnelInstallMs: now.toUtc().millisecondsSinceEpoch,
            funnelLogged: List<String>.from(_legacyBackfill),
          ),
        ),
        const <FunnelHit>[],
      );
    }
    var next = state;
    final events = <FunnelHit>[];
    if (!has(next, appReady)) {
      next = _mark(next, appReady);
      events.add(const FunnelHit(appReady));
    }
    final d1 = _maybeD1Return(next, now);
    if (d1 != null) {
      next = d1.state;
      events.addAll(d1.events);
    }
    final progress = reconcileProgress(next, now);
    next = progress.state;
    events.addAll(progress.events);
    if (identical(next, state) && events.isEmpty) {
      return FunnelTick.none(state);
    }
    return FunnelTick(next, events);
  }

  /// First dungeon enter this install. [sessionReadyMs] is this process's
  /// app-ready clock (time-to-combat). Omit seconds when reconciling a resume.
  static FunnelTick onFirstEnter(
    GameState state,
    DateTime now, {
    required String dungeonId,
    int? sessionReadyMs,
  }) {
    if (has(state, firstEnter)) return FunnelTick.none(state);
    var next = _mark(state, firstEnter);
    final seconds = (sessionReadyMs != null && sessionReadyMs > 0)
        ? _secondsSince(sessionReadyMs, now)
        : null;
    final params = <String, Object>{
      'dungeon_id': dungeonId,
      'seconds_to_combat': ?seconds,
    };
    final events = <FunnelHit>[FunnelHit(firstEnter, params)];
    if (seconds != null && !has(next, timeToCombat)) {
      next = _mark(next, timeToCombat);
      events.add(FunnelHit(timeToCombat, {'seconds': seconds}));
    }
    return FunnelTick(next, events);
  }

  static FunnelTick onFirstReward(GameState state) {
    if (has(state, firstReward)) return FunnelTick.none(state);
    return FunnelTick(_mark(state, firstReward), const [
      FunnelHit(firstReward),
    ]);
  }

  static FunnelTick onFirstBoss(GameState state) {
    if (has(state, firstBoss)) return FunnelTick.none(state);
    return FunnelTick(_mark(state, firstBoss), const [FunnelHit(firstBoss)]);
  }

  /// Catch-up after offline / crash: emit missing progress events (no TTC).
  static FunnelTick reconcileProgress(GameState state, DateTime now) {
    var next = state;
    final events = <FunnelHit>[];
    if (!has(next, firstEnter) && next.inDungeon) {
      final tick = onFirstEnter(next, now, dungeonId: next.dungeonId);
      next = tick.state;
      events.addAll(tick.events);
    }
    if (!has(next, firstReward) && next.lifetimeGoldEarned > 0) {
      final tick = onFirstReward(next);
      next = tick.state;
      events.addAll(tick.events);
    }
    if (!has(next, firstBoss) &&
        (next.bossVictories > 0 || next.metaDepth.lifetimeBossKills > 0)) {
      final tick = onFirstBoss(next);
      next = tick.state;
      events.addAll(tick.events);
    }
    if (identical(next, state) && events.isEmpty) {
      return FunnelTick.none(state);
    }
    return FunnelTick(next, events);
  }

  static FunnelTick? _maybeD1Return(GameState state, DateTime now) {
    if (has(state, d1Return)) return null;
    final installMs = state.metaDepth.funnelInstallMs;
    if (installMs <= 0) return null;
    final install = DateTime.fromMillisecondsSinceEpoch(installMs, isUtc: true);
    final days = utcCalendarDaysApart(install, now.toUtc());
    if (days < 1) return null;
    return FunnelTick(_mark(state, d1Return), [
      FunnelHit(d1Return, {'days_since_install': days}),
    ]);
  }

  static int utcCalendarDaysApart(DateTime fromUtc, DateTime toUtc) {
    final a = DateTime.utc(fromUtc.year, fromUtc.month, fromUtc.day);
    final b = DateTime.utc(toUtc.year, toUtc.month, toUtc.day);
    return b.difference(a).inDays;
  }

  static int _secondsSince(int readyMs, DateTime now) {
    final delta = now.millisecondsSinceEpoch - readyMs;
    if (delta <= 0) return 0;
    return (delta / 1000).round().clamp(0, 86400);
  }

  static GameState _stampInstall(GameState state, int ms) {
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(funnelInstallMs: ms),
    );
  }

  static GameState _mark(GameState state, String name) {
    if (state.metaDepth.funnelLogged.contains(name)) return state;
    return state.copyWith(
      metaDepth: state.metaDepth.copyWith(
        funnelLogged: [...state.metaDepth.funnelLogged, name],
      ),
    );
  }
}
