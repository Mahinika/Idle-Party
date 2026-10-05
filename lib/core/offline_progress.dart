import 'dart:math';

import '../spatial/spatial_combat.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'gold_income.dart';
import 'offline_sim.dart';

/// What the party did while the phone was in a pocket.
///
/// AFK time is credited from a budget, never from how fast the device ran the
/// walk — see `OfflineSim` for the sliced runner and
/// `test/offline_sim_slice_test.dart` for the guarantee that slicing changes
/// no numbers.
abstract final class OfflineProgress {
  /// Free cave catch-up. Long Away raises this to [dungeonAwayLongSec].
  static const int dungeonAwayBaseSec = 8 * 3600;

  /// Cave catch-up after SHOP Long Away.
  static const int dungeonAwayLongSec = 16 * 3600;

  /// Room budget for a free overnight. The raw clock would clear far more.
  static const int offlineRoomBaseCap = 120;

  /// Room budget after Long Away. Twice the free overnight, still compressed.
  static const int offlineRoomLongCap = 240;

  /// Step budget for a free catch-up. Keeps boot from replaying a whole night.
  static const int offlineStepBaseCap = 12000;

  /// Step budget after Long Away, so the longer clock still fights further.
  static const int offlineStepLongCap = 24000;

  static bool longAwayOwned(GameState state) => state.metaDepth.shopLongAway;

  static int dungeonAwayCapSec(GameState state) =>
      longAwayOwned(state) ? dungeonAwayLongSec : dungeonAwayBaseSec;

  static int offlineRoomCapFor(GameState state) =>
      longAwayOwned(state) ? offlineRoomLongCap : offlineRoomBaseCap;

  static int offlineStepCapFor(GameState state) =>
      longAwayOwned(state) ? offlineStepLongCap : offlineStepBaseCap;

  /// Seconds this absence may credit. Hub and cave use different caps.
  static int creditedAwaySec(GameState state, int away) {
    if (away <= 0) return 0;
    return state.inDungeon
        ? min(away, dungeonAwayCapSec(state))
        : min(away, GoldIncome.hubChestCapSecFor(state));
  }

  /// Result of crediting AFK time on boot / resume.
  /// Same credit as [applyOfflineProgress], but the dungeon replay runs in
  /// slices with the frame handed back between them — boot stays paintable
  /// even after a full night away.
  static Future<OfflineProgressResult> applyOfflineProgressAsync(
    GameState state,
    Duration elapsed,
  ) async {
    final away = elapsed.inSeconds;
    final seconds = creditedAwaySec(state, away);
    if (seconds == 0 || !state.inDungeon) {
      return applyOfflineProgress(state, elapsed);
    }
    final timed = GameLogic.advanceKeystoneTimer(state, seconds * 1000);
    final sim = OfflineSim(timed, seconds);
    while (!sim.done) {
      sim.runSlice(OfflineSim.sliceSteps);
      if (!sim.done) await Future<void>.delayed(Duration.zero);
    }
    return _offlineResultFrom(
      before: state,
      progressed: applyAwayBonus(state, sim.state),
      seconds: seconds,
      roomsCleared: sim.roomsCleared,
      wasInDungeon: true,
    );
  }

  static OfflineProgressResult applyOfflineProgress(
    GameState state,
    Duration elapsed,
  ) {
    // Dungeon catch-up is an 8h fight, 16h with Long Away. Hub gold is its
    // own chest: 12h, or 24h with Long Away, then it stops.
    final away = max(0, elapsed.inSeconds);
    if (away == 0) {
      final next = state.copyWith(lastUpdated: DateTime.now());
      return OfflineProgressResult(
        state: next,
        secondsApplied: 0,
        goldGained: 0,
        essenceGained: 0,
        roomsCleared: 0,
        highestFloorDelta: 0,
        bossDelta: 0,
        wasInDungeon: state.inDungeon,
      );
    }
    final seconds = creditedAwaySec(state, away);
    final hubCap = state.inDungeon ? 0 : GoldIncome.hubChestCapSecFor(state);

    var roomsCleared = 0;
    late GameState progressed;
    if (state.inDungeon) {
      // Idle-friendly keystone: AFK time counts on the timer.
      final timed = GameLogic.advanceKeystoneTimer(state, seconds * 1000);
      final sim = simulateSpatialOffline(timed, seconds);
      progressed = sim.state;
      roomsCleared = sim.roomsCleared;
    } else {
      // Hub AFK: sanctuary idle gold only — no ghost combat / boss farms.
      progressed = applyHubIdleProgress(state, seconds);
    }
    return _offlineResultFrom(
      before: state,
      progressed: applyAwayBonus(state, progressed),
      seconds: seconds,
      secondsAway: away,
      hubChestCapSec: hubCap,
      roomsCleared: roomsCleared,
      wasInDungeon: state.inDungeon,
    );
  }

  static GameState applyAwayBonus(GameState before, GameState progressed) =>
      GameLogic.applyAwayBonusToOfflineGold(before, progressed);

  static OfflineProgressResult _offlineResultFrom({
    required GameState before,
    required GameState progressed,
    required int seconds,
    int secondsAway = 0,
    int hubChestCapSec = 0,
    required int roomsCleared,
    required bool wasInDungeon,
  }) {
    final next = progressed.copyWith(
      offlineSecondsRecovered: progressed.offlineSecondsRecovered + seconds,
      lastUpdated: DateTime.now(),
    );
    return OfflineProgressResult(
      state: next,
      secondsApplied: seconds,
      secondsAway: secondsAway,
      hubChestCapSec: hubChestCapSec,
      goldGained: next.gold - before.gold,
      essenceGained: next.essence - before.essence,
      roomsCleared: roomsCleared,
      highestFloorDelta: next.highestFloorCleared - before.highestFloorCleared,
      bossDelta: next.bossVictories - before.bossVictories,
      levelsGained: _partyLevelSum(next) - _partyLevelSum(before),
      gearFinds: (_ownedGearCount(next) - _ownedGearCount(before)).clamp(
        0,
        999,
      ),
      wasInDungeon: wasInDungeon,
    );
  }

  static int _partyLevelSum(GameState state) =>
      state.heroes.fold<int>(0, (n, h) => n + h.level);

  static int _ownedGearCount(GameState state) {
    var n = state.gearStash.length;
    for (final h in state.heroRoster) {
      n += h.equipped.length;
    }
    return n;
  }

  /// Hub-only AFK: small gold (and rare essence) from sanctuary — no combat ticks.
  static GameState applyHubIdleProgress(GameState state, int seconds) =>
      GoldIncome.applyHubIdle(state, seconds);

  /// How many room clears offline combat may award for [seconds] away.
  /// Front-loaded for the first 30 minutes, then half rate, hard-capped.
  /// Free play caps at [offlineRoomBaseCap]. Long Away uses [offlineRoomLongCap].
  static int offlineFloorBudget(
    int seconds, {
    int roomCap = offlineRoomBaseCap,
  }) {
    if (seconds <= 0) return 0;
    // ~1 clear / 40s for the first 30 minutes (5m≈7, 30m≈45).
    if (seconds <= 30 * 60) {
      return max(1, min(roomCap, seconds ~/ 40));
    }
    const firstBand = (30 * 60) ~/ 40; // 45
    // After 30m: ~1 clear / 80s (1h≈45+22, 8h≈45+337 → cap).
    final extra = (seconds - 30 * 60) ~/ 80;
    return min(roomCap, firstBand + extra);
  }

  /// Replays in-dungeon combat while offline using [SpatialCombat] (same
  /// authority as live play). See [OfflineSim] — boot runs the same walk in
  /// slices so a long absence cannot freeze the app on return.
  static ({GameState state, int roomsCleared}) simulateSpatialOffline(
    GameState state,
    int seconds,
  ) {
    if (!state.inDungeon || seconds <= 0) {
      return (state: state, roomsCleared: 0);
    }
    final sim = OfflineSim(state, seconds)..runAll();
    return (state: sim.state, roomsCleared: sim.roomsCleared);
  }

  /// Nearest awake enemy to living party centroid, or null if none.
  /// Shared by AFK catch-up and balance sims (live/AFK assist aim).
  static (double, double)? godHandAim(SpatialWorld world) {
    return _offlineGodHandAim(world);
  }

  /// Nearest awake enemy to living party centroid, or null if none.
  static (double, double)? _offlineGodHandAim(SpatialWorld world) {
    final aliveHeroes = <SpatialActor>[
      for (final h in world.heroes)
        if (h.hp > 0) h,
    ];
    var cx = world.cols / 2.0;
    var cy = world.rows / 2.0;
    if (aliveHeroes.isNotEmpty) {
      cx = 0;
      cy = 0;
      for (final h in aliveHeroes) {
        cx += h.x;
        cy += h.y;
      }
      cx /= aliveHeroes.length;
      cy /= aliveHeroes.length;
    }
    SpatialActor? best;
    var bestD2 = double.infinity;
    for (final e in world.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final dx = e.x - cx;
      final dy = e.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = e;
      }
    }
    if (best == null) return null;
    return (best.x, best.y);
  }
}
