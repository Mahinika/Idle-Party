import 'dart:math';

import '../models/loot.dart';
import '../spatial/spatial_combat.dart';
import 'ad_boost.dart';
import 'comeback_chest.dart';
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

  /// Hub absences shorter than this stay on the chest.
  static const int autoCaveMinSec = 5 * 60;

  /// Seconds this absence may credit. Hub and cave use different caps.
  /// A hub absence that moves into the last cave keeps the 12h / 24h chest
  /// clock. The fight may pay more. It does not shrink the window to 8h / 16h.
  static int creditedAwaySec(
    GameState state,
    int away, {
    bool keepHubChestCap = false,
  }) {
    if (away <= 0) return 0;
    if (!state.inDungeon || keepHubChestCap) {
      return min(away, GoldIncome.hubChestCapSecFor(state));
    }
    return min(away, dungeonAwayCapSec(state));
  }

  /// Last cave for a hub absence. Already-in-cave saves stay put.
  /// Floor progress is kept. A KEY dial on the hub does not start a key.
  /// Under [autoCaveMinSec] the hub chest still pays and the cave stays closed.
  static GameState _awayFightState(GameState state, int awaySec) {
    if (state.inDungeon || !state.autoCaveOnLeave) return state;
    if (awaySec < autoCaveMinSec) return state;
    final id = state.dungeonId.trim().isEmpty
        ? GameLogic.recommendedDungeonId(state)
        : state.dungeonId;
    final keepFloor = state.highestFloorCleared;
    final entered = GameLogic.enterDungeon(
      state.copyWith(hardmodeLevel: 0),
      dungeonId: id,
    );
    if (!entered.inDungeon) return state;
    if (entered.highestFloorCleared >= keepFloor) return entered;
    var next = entered.copyWith(highestFloorCleared: keepFloor);
    final dest = max(1, keepFloor);
    if (next.currentRoom.floorNumber != dest) {
      final traveled = GameLogic.travelToFloor(next, dest);
      if (traveled.inDungeon) next = traveled;
    }
    return next;
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
    final prepared = _awayFightState(state, away);
    final autoEntered = !state.inDungeon && prepared.inDungeon;
    final seconds = creditedAwaySec(
      prepared,
      away,
      keepHubChestCap: autoEntered,
    );
    if (seconds == 0 || !prepared.inDungeon) {
      return applyOfflineProgress(state, elapsed);
    }
    final timed = GameLogic.advanceKeystoneTimer(prepared, seconds * 1000);
    final sim = OfflineSim(timed, seconds);
    while (!sim.done) {
      sim.runSlice(OfflineSim.sliceSteps);
      if (!sim.done) await Future<void>.delayed(Duration.zero);
    }
    final raw = _atLeastHubChest(
      before: state,
      progressed: sim.state,
      seconds: seconds,
      autoEntered: autoEntered,
    );
    final boosted = applyAwayBonus(state, raw);
    return _offlineResultFrom(
      before: state,
      progressed: boosted,
      seconds: seconds,
      secondsAway: away,
      roomsCleared: sim.roomsCleared,
      kills: sim.kills,
      stoppedOnWipe: sim.stoppedOnWipe,
      farmedSafeFloor: sim.farmedSafeFloor,
      wasInDungeon: true,
      autoEnteredCave: autoEntered,
      awayGoldMultiplied: _restMultipliedGold(state, raw, boosted),
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
    final prepared = _awayFightState(state, away);
    final autoEntered = !state.inDungeon && prepared.inDungeon;
    final seconds = creditedAwaySec(
      prepared,
      away,
      keepHubChestCap: autoEntered,
    );
    final hubCap = prepared.inDungeon
        ? 0
        : GoldIncome.hubChestCapSecFor(state);

    var roomsCleared = 0;
    var kills = 0;
    var stoppedOnWipe = false;
    var farmedSafeFloor = false;
    late GameState progressed;
    if (prepared.inDungeon) {
      // Idle-friendly keystone: AFK time counts on the timer.
      final timed = GameLogic.advanceKeystoneTimer(prepared, seconds * 1000);
      final sim = simulateSpatialOffline(timed, seconds);
      progressed = _atLeastHubChest(
        before: state,
        progressed: sim.state,
        seconds: seconds,
        autoEntered: autoEntered,
      );
      roomsCleared = sim.roomsCleared;
      kills = sim.kills;
      stoppedOnWipe = sim.stoppedOnWipe;
      farmedSafeFloor = sim.farmedSafeFloor;
    } else {
      // Hub AFK: sanctuary idle gold only — no ghost combat / boss farms.
      progressed = applyHubIdleProgress(state, seconds);
    }
    final boosted = applyAwayBonus(state, progressed);
    return _offlineResultFrom(
      before: state,
      progressed: boosted,
      seconds: seconds,
      secondsAway: away,
      hubChestCapSec: hubCap,
      roomsCleared: roomsCleared,
      kills: kills,
      stoppedOnWipe: stoppedOnWipe,
      farmedSafeFloor: farmedSafeFloor,
      wasInDungeon: prepared.inDungeon,
      autoEnteredCave: autoEntered,
      awayGoldMultiplied: _restMultipliedGold(state, progressed, boosted),
    );
  }

  /// Cave loot can beat the hub chest. The same window must not pay less.
  static GameState _atLeastHubChest({
    required GameState before,
    required GameState progressed,
    required int seconds,
    required bool autoEntered,
  }) {
    if (!autoEntered || seconds <= 0) return progressed;
    final chestGold = GoldIncome.hubGoldForSeconds(before, seconds);
    final gained = progressed.gold - before.gold;
    var next = progressed;
    if (gained < chestGold) {
      final extra = chestGold - gained;
      next = next.copyWith(
        gold: next.gold + extra,
        lifetimeGoldEarned: next.lifetimeGoldEarned + extra,
      );
    }
    final accBefore = before.metaDepth.hubAfkSec;
    final chestEssence =
        GoldIncome.essenceDue(accBefore + seconds, before.sanctuaryPowerLevel) -
        GoldIncome.essenceDue(accBefore, before.sanctuaryPowerLevel);
    final essenceGained = next.essence - before.essence;
    if (essenceGained < chestEssence) {
      next = next.copyWith(
        essence: next.essence + (chestEssence - essenceGained),
      );
    }
    // The hub clock moves with the cave, or the next hub tick pays this
    // essence again.
    return next.copyWith(
      metaDepth: next.metaDepth.copyWith(
        hubAfkSec: accBefore + seconds,
        hubIdleSubSec: _hubIdleLeftover(before, seconds),
      ),
    );
  }

  /// Same leftover [GoldIncome.applyHubIdle] would bank for [seconds].
  static int _hubIdleLeftover(GameState before, int seconds) {
    final perMinute = GoldIncome.hubRawPerMinute(before);
    final total = before.metaDepth.hubIdleSubSec + seconds;
    if (perMinute <= 0) return total;
    final raw = max(0, (total * perMinute) ~/ 60);
    if (raw <= 0) return total;
    final consumed = (raw * 60 + perMinute - 1) ~/ perMinute;
    var leftover = max(0, total - consumed);
    if ((leftover * perMinute) ~/ 60 > 0) leftover = 0;
    return leftover;
  }

  /// True when Scroll of Rest (or Forever Rest) added gold on top of [raw].
  static bool _restMultipliedGold(
    GameState before,
    GameState raw,
    GameState boosted,
  ) {
    if (!AdBoost.awayBonusReady(before.metaDepth)) return false;
    final plain = raw.gold - before.gold;
    return plain > 0 && boosted.gold > raw.gold;
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
    int kills = 0,
    bool stoppedOnWipe = false,
    bool farmedSafeFloor = false,
    required bool wasInDungeon,
    bool autoEnteredCave = false,
    bool awayGoldMultiplied = false,
  }) {
    final awayForChest = secondsAway > 0 ? secondsAway : seconds;
    final noted = ComebackChest.noteAbsence(progressed, awayForChest);
    // Entering the last cave clears the hub KEY dial so the absence is not
    // a keystone. Put the dial back; the next manual enter starts the key.
    final keptDial = autoEnteredCave
        ? noted.copyWith(hardmodeLevel: before.hardmodeLevel)
        : noted;
    final next = keptDial.copyWith(
      offlineSecondsRecovered: noted.offlineSecondsRecovered + seconds,
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
      kills: kills,
      bestDrop: _bestNewGearName(before, next),
      stoppedOnWipe: stoppedOnWipe,
      farmedSafeFloor: farmedSafeFloor,
      wasInDungeon: wasInDungeon,
      autoEnteredCave: autoEnteredCave,
      highestFloorDelta: next.highestFloorCleared - before.highestFloorCleared,
      bossDelta: next.bossVictories - before.bossVictories,
      levelsGained: _partyLevelSum(next) - _partyLevelSum(before),
      gearFinds: (_ownedGearCount(next) - _ownedGearCount(before)).clamp(
        0,
        999,
      ),
      rareFinds: (_rareGearCount(next) - _rareGearCount(before)).clamp(0, 999),
      awayGoldMultiplied: awayGoldMultiplied,
    );
  }

  static int _rareGearCount(GameState state) {
    var n = 0;
    for (final item in state.gearStash) {
      if (item.rarity.index >= LootRarity.rare.index) n++;
    }
    for (final hero in state.heroRoster) {
      for (final item in hero.equipped.values) {
        if (item.rarity.index >= LootRarity.rare.index) n++;
      }
    }
    return n;
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
  static ({
    GameState state,
    int roomsCleared,
    int kills,
    bool stoppedOnWipe,
    bool farmedSafeFloor,
  }) simulateSpatialOffline(
    GameState state,
    int seconds,
  ) {
    if (!state.inDungeon || seconds <= 0) {
      return (
        state: state,
        roomsCleared: 0,
        kills: 0,
        stoppedOnWipe: false,
        farmedSafeFloor: false,
      );
    }
    final sim = OfflineSim(state, seconds)..runAll();
    return (
      state: sim.state,
      roomsCleared: sim.roomsCleared,
      kills: sim.kills,
      stoppedOnWipe: sim.stoppedOnWipe,
      farmedSafeFloor: sim.farmedSafeFloor,
    );
  }

  static String _bestNewGearName(GameState before, GameState after) {
    final beforeIds = <String>{
      for (final item in before.gearStash) item.id,
      for (final hero in before.heroRoster)
        for (final item in hero.equipped.values) item.id,
    };
    EquipmentItem? best;
    void consider(EquipmentItem item) {
      if (beforeIds.contains(item.id)) return;
      if (best == null || item.rarity.index > best!.rarity.index) {
        best = item;
      }
    }
    for (final item in after.gearStash) {
      consider(item);
    }
    for (final hero in after.heroRoster) {
      for (final item in hero.equipped.values) {
        consider(item);
      }
    }
    return best?.name ?? '';
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
