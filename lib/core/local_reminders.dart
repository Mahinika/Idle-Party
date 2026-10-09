import 'funnel_analytics.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'gold_income.dart';

/// One scheduled away ping (id is stable so each kind overwrites itself).
class LocalPing {
  const LocalPing({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
  });

  static const goldId = 1;
  static const morningId = 2;
  static const petId = 3;
  static const eveningId = 4;

  final int id;
  final DateTime fireAt;
  final String title;
  final String body;
}

/// Silent chest line shown while hub gold fills. Not a ping.
class ChestTray {
  const ChestTray({required this.fullAt, required this.body});

  static const id = 5;
  static const title = 'Gold filling';

  final DateTime fullAt;
  final String body;
}

/// Growth-mandate local reminders: opt-in after a milestone, ≤2 pings per UTC day.
abstract final class LocalReminders {
  static const int maxPerUtcDay = 2;
  static const Duration horizon = Duration(hours: 36);
  static const Duration slotLead = Duration(minutes: 45);
  static const int morningHour = 8;
  static const int eveningHour = 20;
  static const String title = 'Idle Party';
  static const String caveBodyNew = 'Your party is ready when you are.';
  static const String optInTitle = 'A quiet ping?';

  static String get optInBody =>
      'A quiet chest line stays up while hub gold fills, and goes away when you open the game. '
      'Gold fills for ${GoldIncome.hubChestCapHours} hours, then stops. '
      'At most a couple of pings a day: when the chest is full, and in the morning or evening when a prize is waiting. '
      'Never during a fight. Turn off anytime in SETTINGS.';

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

  /// Hub card once the first boss is down, so the phone can pull them back.
  /// Never on install, never on first loot, never in a fight.
  static bool shouldOfferOptIn(GameState state) {
    if (state.inDungeon) return false;
    if (state.metaDepth.notifyPrompted || state.metaDepth.notifyOptIn) {
      return false;
    }
    return GameLogic.showDailyChase(state);
  }

  /// Same ask on a cleared floor. The pack is dead, so this is not a fight.
  /// A live cave still waits.
  static bool shouldOfferOnFloorClear(
    GameState state, {
    required bool floorClear,
  }) {
    if (!floorClear || state.isPartyDefeated) return false;
    if (state.metaDepth.notifyPrompted || state.metaDepth.notifyOptIn) {
      return false;
    }
    return GameLogic.showDailyChase(state);
  }

  /// SETTINGS row after the milestone (or after they already answered).
  static bool showSettingsToggle(GameState state) =>
      milestoneReached(state) ||
      state.metaDepth.notifyPrompted ||
      state.metaDepth.notifyOptIn;

  static String appointmentBody(GameState state) {
    if (!GameLogic.showDailyChase(state)) return caveBodyNew;
    final pay = GameLogic.checkInPayout(state);
    if (state.metaDepth.dailyVaultClaimed) {
      return 'Tomorrow: ${pay.name}, ${pay.hookPrize}.';
    }
    if (GameLogic.canClaimDailyVault(state)) {
      return 'Claim ${pay.hookPrize} before the day ends.';
    }
    return 'One cave fills today\'s vault.';
  }

  static String chestFullBody(GameState state) {
    final gold = _chestGold(state);
    return '${GoldIncome.groupDigits(gold)} gold is waiting. '
        'The chest is full and takes no more.';
  }

  static String chestFillBody(GameState state) {
    final gold = _chestGold(state);
    return 'Chest fills to ${GoldIncome.groupDigits(gold)} gold, then stops.';
  }

  /// Ongoing tray while the hub chest fills. Null in a fight.
  static ChestTray? chestTray(GameState state, DateTime now) {
    if (!state.metaDepth.notifyOptIn) return null;
    if (!milestoneReached(state)) return null;
    if (state.inDungeon) return null;
    return ChestTray(
      fullAt: now.add(Duration(seconds: GoldIncome.hubChestCapSecFor(state))),
      body: chestFillBody(state),
    );
  }

  static List<LocalPing> plan(GameState state, DateTime now) {
    if (!state.metaDepth.notifyOptIn) return const [];
    if (!milestoneReached(state)) return const [];
    final fired = <int>[
      for (final ms in state.metaDepth.notifyPingMs)
        if (ms <= now.millisecondsSinceEpoch) ms,
    ];
    final candidates = <({LocalPing ping, int rank})>[];
    final petAt = _petFireAt(state, now);
    if (petAt != null) {
      candidates.add((
        ping: LocalPing(
          id: LocalPing.petId,
          fireAt: petAt,
          title: title,
          body: _petBody(state),
        ),
        rank: 0,
      ));
    }
    if (!state.inDungeon) {
      final fullAt = now.add(
        Duration(seconds: GoldIncome.hubChestCapSecFor(state)),
      );
      candidates.add((
        ping: LocalPing(
          id: LocalPing.goldId,
          fireAt: fullAt,
          title: title,
          body: chestFullBody(state),
        ),
        rank: 1,
      ));
    }
    final prize = appointmentBody(state);
    for (final slot in <(int, int)>[
      (morningHour, LocalPing.morningId),
      (eveningHour, LocalPing.eveningId),
    ]) {
      final at = nextClock(now, slot.$1);
      if (at.difference(now) < slotLead) continue;
      candidates.add((
        ping: LocalPing(
          id: slot.$2,
          fireAt: at,
          title: title,
          body: prize,
        ),
        rank: 2,
      ));
    }
    candidates.sort((a, b) {
      final rank = a.rank.compareTo(b.rank);
      if (rank != 0) return rank;
      return a.ping.fireAt.compareTo(b.ping.fireAt);
    });
    final counted = <int>[...fired];
    final accepted = <LocalPing>[];
    for (final candidate in candidates) {
      final at = candidate.ping.fireAt;
      if (!at.isAfter(now)) continue;
      if (at.difference(now) > horizon) continue;
      if (_countOnUtcDay(counted, at) >= maxPerUtcDay) continue;
      accepted.add(candidate.ping);
      counted.add(at.millisecondsSinceEpoch);
    }
    accepted.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return accepted;
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

  /// Next [hour]:00 in the same zone as [now]. At least [slotLead] ahead.
  static DateTime nextClock(DateTime now, int hour) {
    final DateTime slot;
    if (now.isUtc) {
      slot = DateTime.utc(now.year, now.month, now.day, hour);
    } else {
      slot = DateTime(now.year, now.month, now.day, hour);
    }
    if (slot.isAfter(now.add(slotLead))) return slot;
    return slot.add(const Duration(days: 1));
  }

  static int _chestGold(GameState state) => GoldIncome.hubGoldForSeconds(
    state,
    GoldIncome.hubChestCapSecFor(state),
  );

  static DateTime? _petFireAt(GameState state, DateTime now) {
    final endsMs = state.metaDepth.petErrandEndsMs;
    final id = state.metaDepth.petErrandPetId;
    if (id.isEmpty || endsMs <= 0) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(endsMs, isUtc: now.isUtc);
    if (!at.isAfter(now)) return null;
    return at;
  }

  static String _petBody(GameState state) {
    final id = state.metaDepth.petErrandPetId;
    for (final pet in state.ownedPets) {
      if (pet.id == id) return '${pet.name} is home. Open and claim.';
    }
    return 'Your pet is home. Open and claim.';
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
