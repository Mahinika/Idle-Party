import 'dart:math';

import '../models/dungeon_mode.dart';
import '../models/hero.dart';
import '../models/vfx_quality.dart';
import '../spatial/spatial_combat.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';
import 'offline_progress.dart';

/// AFK catch-up: replays the dungeon through [SpatialCombat] — the same
/// authority as live play — in slices the caller controls.
///
/// The walk used to run up to 12000 steps in one synchronous call, so coming
/// back after a long absence froze the app while it caught up. Slicing lets
/// boot hand the frame back between chunks; the numbers are identical either
/// way, since the budget comes from [GameLogic.offlineFloorBudget], never from
/// how fast the phone happens to be.
class OfflineSim {
  OfflineSim(GameState state, int seconds)
    : _preferVfx = state.vfxQuality,
      _maxFloors = _budget(state, seconds) {
    if (_maxFloors <= 0) {
      _done = true;
      _current = state;
      return;
    }
    _current = state.copyWith(vfxQuality: VfxQuality.minimal);
    // Ticket World Boss: no AFK soft clear — practice / normal runs keep assist.
    final ticketBoss =
        state.inWorldBoss && !state.worldBossPractice;
    _world = SpatialCombat.build(
      _current,
      threatScale: _threatScale,
      afkAssist: ticketBoss ? false : _afkAssist,
    );
    _maxSteps = min(12000, max(240, _maxFloors * 420));
  }

  /// Steps to run between yields — ~4 ms of work on a mid phone.
  static const int sliceSteps = 400;

  static const double _threatScale = 1.0;
  static const bool _afkAssist = true;
  static const double _dt = 0.12;

  final VfxQuality _preferVfx;
  final int _maxFloors;

  late GameState _current;
  late SpatialWorld _world;
  int _maxSteps = 0;
  int _step = 0;
  int _floorsCleared = 0;
  int _abilityCasts = 0;
  bool _done = false;

  bool get done => _done;
  int get roomsCleared => _floorsCleared;

  /// State with the player's own VFX setting restored and casts credited.
  GameState get state {
    var out = _current;
    if (_abilityCasts > 0) {
      out = out.copyWith(
        metaDepth: out.metaDepth.copyWith(
          lifetimeAbilityCasts:
              out.metaDepth.lifetimeAbilityCasts + _abilityCasts,
        ),
      );
    }
    return out.copyWith(vfxQuality: _preferVfx);
  }

  static int _budget(GameState state, int seconds) {
    if (!state.inDungeon || seconds <= 0) return 0;
    var maxFloors = GameLogic.offlineFloorBudget(seconds);
    // Gauntlet AFK: hard soft-cap so offline can't mint endless climb rewards.
    if (state.inGauntlet) maxFloors = min(maxFloors, 6);
    // Rift / Greater Rift AFK: short wave budget — timer/kills resolve the run.
    if (state.inRift) maxFloors = min(maxFloors, 3);
    if (state.inGreaterRift) maxFloors = min(maxFloors, 2);
    return maxFloors;
  }

  /// Runs the whole catch-up in one go (tests, sims, sync callers).
  void runAll() {
    while (!_done) {
      runSlice(sliceSteps);
    }
  }

  /// Advances at most [budget] steps. Same math as [runAll], just paused.
  void runSlice(int budget) {
    var used = 0;
    while (!_done && used < budget) {
      used++;
      if (_step >= _maxSteps ||
          !_current.inDungeon ||
          _floorsCleared >= _maxFloors) {
        _done = true;
        break;
      }
      final step = _step++;

      final stashLenBefore = _current.gearStash.length;
      final result = SpatialCombat.step(_world, _current, dt: _dt);
      _world = result.world;
      _current = result.state;
      if (result.goldFromKills > 0) {
        _current = GameLogic.creditCombatGold(_current, result.goldFromKills);
      }
      if (_current.inRift) {
        _current = GameLogic.advanceRiftTimer(
          _current,
          (_dt * 1000).round(),
        );
        if (result.kills > 0) {
          _current = GameLogic.noteRiftKills(_current, result.kills);
        }
        final resolved = GameLogic.tryResolveRift(_current);
        if (resolved != null) {
          _current = resolved;
          _done = true;
          break;
        }
      }
      if (_current.inGreaterRift) {
        _current = GameLogic.advanceGreaterRiftTimer(
          _current,
          (_dt * 1000).round(),
        );
        if (result.kills > 0) {
          _current = GameLogic.noteGreaterRiftKills(_current, result.kills);
        }
        final resolved = GameLogic.tryResolveGreaterRift(_current);
        if (resolved != null) {
          _current = resolved;
          _done = true;
          break;
        }
      }
      _abilityCasts += result.abilityCasts;
      // Live parity: wear clear upgrades mid-floor and sync actor sheets.
      if (_current.gearStash.length > stashLenBefore) {
        _current = GameLogic.autoEquipBetterGear(_current);
        _world = SpatialCombat.syncPartyFromState(_world, _current);
      }

      // Keep AFK sim lean — strip accumulated VFX lists periodically.
      if (step % 40 == 0) {
        _world.floaters.clear();
        _world.bursts.clear();
        _world.groundFx.clear();
        if (_world.projectiles.length > 24) {
          _world.projectiles.removeRange(0, _world.projectiles.length - 24);
        }
      }

      // Wipe before flask/God Hand — avoid post-wipe loot/XP from assist.
      if (result.partyWiped) {
        // Gauntlet / Rift wipe always ends the run (same as live hub exit).
        if (_current.inGauntlet || _current.inAnyRiftMode) {
          _current = GameLogic.exitToHubHealed(_current);
          _done = true;
          break;
        }
        if (MetaSystems.isActiveDailyRun(_current)) {
          _current = GameLogic.restartFloor(_current);
          if (!_current.inDungeon) {
            _done = true;
            break;
          }
          _rebuildWorld();
          continue;
        }
        if (_current.dungeonMode == DungeonMode.push &&
            _current.currentRoom.floorNumber > _current.highestFloorCleared) {
          _current = GameLogic.retreatFromFailedPush(_current);
          _done = true;
          break;
        }
        _current = GameLogic.restartFloor(_current);
        if (!_current.inDungeon) {
          _done = true;
          break;
        }
        _rebuildWorld();
        continue;
      }

      // Mid-fight flask when living party avg HP drops below 35%.
      if (step % 12 == 0 && GameLogic.canUseConsumable(_current)) {
        final living = <PartyHero>[
          for (final h in _current.heroes)
            if (h.currentHp > 0) h,
        ];
        if (living.isNotEmpty) {
          var ratioSum = 0.0;
          for (final h in living) {
            final maxHp = _current.effectiveHeroMaxHp(h);
            ratioSum += maxHp > 0 ? h.currentHp / maxHp : 0;
          }
          if (ratioSum / living.length < 0.35) {
            _current = GameLogic.useConsumable(_current);
            _world = SpatialCombat.syncPartyFromState(_world, _current);
            SpatialCombat.spawnFlaskHealFx(
              _world,
              reducedVfx: _current.reducedVfx,
            );
          }
        }
      }

      // God Hand toward nearest live enemy when ready.
      // Soft cadence: every ~4.3s of sim time so AFK doesn't hard-carry mid PUSH.
      if (step % 36 == 0 && _world.godHandCooldown <= 0) {
        final aim = OfflineProgress.godHandAim(_world);
        if (aim != null) {
          final gh = SpatialCombat.godHand(
            _world,
            _current,
            tileX: aim.$1,
            tileY: aim.$2,
          );
          _world = gh.world;
          _current = gh.state;
          if (gh.goldFromKills > 0) {
            _current = GameLogic.creditCombatGold(_current, gh.goldFromKills);
          }
        }
      }

      if (!result.roomCleared) continue;

      final wasTreasure = _world.isTreasure;
      // Combat gold already credited per kill; treasure pays scaled chest budget.
      final gold = wasTreasure ? GameLogic.treasureGoldBudget(_current) : 0;
      _current = GameLogic.completeCurrentRoom(
        _current,
        goldGain: gold,
        skipLootRoll: _current.inGreaterRift || !wasTreasure,
      );
      _floorsCleared++;
      if (!_current.inDungeon || _floorsCleared >= _maxFloors) {
        _done = true;
        break;
      }
      _rebuildWorld();
    }
  }

  void _rebuildWorld() {
    final ticketBoss =
        _current.inWorldBoss && !_current.worldBossPractice;
    _world = SpatialCombat.build(
      _current,
      threatScale: _threatScale,
      afkAssist: ticketBoss ? false : _afkAssist,
    );
  }
}
