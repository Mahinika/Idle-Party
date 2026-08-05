import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/apex_craft.dart';
import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/class_ability.dart';
import '../models/hero_spec.dart';
import '../models/loot.dart';
import '../models/meta_depth.dart';
import '../models/pet.dart';
import '../models/vfx_quality.dart';
import '../spatial/spatial_combat.dart';
import '../ui/game_audio.dart';
import 'game_logic.dart';
import 'game_state.dart';
import 'meta_systems.dart';
import 'story_lore.dart';
import '../models/dungeon_def.dart';

abstract class GameStorage {
  Future<GameState?> load();

  Future<void> save(GameState state);

  /// True when a persisted save blob exists.
  Future<bool> hasSave();

  Future<void> clear();
}

class SharedPreferencesGameStorage implements GameStorage {
  SharedPreferencesGameStorage({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _saveKey = 'idle_party_save_v2';
  static const String _legacySaveKey = 'idle_party_save_v1';
  static const String _corruptSaveKey = 'idle_party_save_v2_corrupt';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<GameState?> load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_saveKey) ?? prefs.getString(_legacySaveKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return GameLogic.stateFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      // Quarantine corrupt blob so Continue is not stuck; keep a copy for debug.
      debugPrint('save load failed (quarantined): $e\n$st');
      await prefs.setString(_corruptSaveKey, raw);
      await prefs.remove(_saveKey);
      await prefs.remove(_legacySaveKey);
      return null;
    }
  }

  @override
  Future<void> save(GameState state) async {
    final prefs = await _prefs;
    await prefs.setString(_saveKey, jsonEncode(state.toJson()));
  }

  @override
  Future<bool> hasSave() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_saveKey) ?? prefs.getString(_legacySaveKey);
    return raw != null && raw.isNotEmpty;
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_saveKey);
    await prefs.remove(_legacySaveKey);
    await prefs.remove(_corruptSaveKey);
  }
}

class InMemoryGameStorage implements GameStorage {
  InMemoryGameStorage([this._state]);

  GameState? _state;

  @override
  Future<GameState?> load() async => _state;

  @override
  Future<void> save(GameState state) async {
    _state = state;
  }

  @override
  Future<bool> hasSave() async => _state != null;

  @override
  Future<void> clear() async {
    _state = null;
  }
}

class GameDirector extends ChangeNotifier {
  GameDirector(
    this._storage, {
    GameState? initialState,
    this.enableSpatialLoop = true,
  }) : _state = initialState ?? GameLogic.createInitialState() {
    GameAudio.muted = _state.soundMuted;
    SpatialCombat.colorblindMode = _state.colorblindMode;
  }

  factory GameDirector.persistent() {
    return GameDirector(SharedPreferencesGameStorage());
  }

  factory GameDirector.preview({GameState? initialState}) {
    final seed = initialState ?? GameLogic.createInitialState();
    return GameDirector(
      InMemoryGameStorage(seed),
      initialState: seed,
      enableSpatialLoop: false,
    );
  }

  final GameStorage _storage;
  final bool enableSpatialLoop;

  GameState _state;
  bool _isLoading = true;
  bool _hasExistingSave = false;
  SpatialWorld? _spatial;
  Timer? _spatialTimer;
  Timer? _uiTimer;
  int _roomGold = 0;
  int _battleToken = 0;
  int _uiThrottle = 0;
  int _visualFrame = 0;
  /// Combat map + corner HUD; bumps every spatial tick (~60 Hz).
  final ValueNotifier<int> combatFrame = ValueNotifier(0);
  bool _awaitingWipeChoice = false;
  /// Soft-pause spatial sim while inventory / meta menus are open.
  bool _uiPaused = false;
  String? _toast;
  double _toastLife = 0;
  String? _clearSummary;
  double _clearSummaryLife = 0;
  OfflineProgressResult? _offlineSummary;
  double _offlineSummaryLife = 0;
  int _lastHighestDungeon = -1;
  double _autosaveAccum = 0;
  int _lastStashLen = 0;
  static const double _autosaveIntervalSec = 25;

  /// Serializes SharedPreferences writes so overlapping unawaited saves cannot
  /// last-write-wins with a stale snapshot.
  Future<void> _saveChain = Future.value();

  void _persist() {
    _saveChain = _saveChain
        .then((_) => _storage.save(_state))
        .catchError((Object e, StackTrace st) {
      debugPrint('save failed: $e\n$st');
    });
  }

  Future<void> _persistFlush() {
    _persist();
    return _saveChain;
  }

  GameState get state => _state;

  bool get isLoading => _isLoading;

  /// True after [boot] if a save was loaded (Continue available).
  bool get hasExistingSave => _hasExistingSave;

  SpatialWorld? get spatial => _spatial;

  /// Increments each spatial sim step — used by combat painter dirty-checks.
  int get visualFrame => _visualFrame;

  static const double _spatialDt = 1 / 60;
  static const Duration _spatialPeriod = Duration(milliseconds: 16);
  /// Full shell rebuild cadence while fighting (~10 Hz).
  static const int _shellNotifyEvery = 6;

  /// Debug / playtest combat multiplier (1 = realtime). Clamped 1–20.
  /// Runs N sim steps per wall-clock tick — does not inflate `dt`.
  double _debugTimeScale = 1;
  double get debugTimeScale => _debugTimeScale;

  void setDebugTimeScale(double scale) {
    final next = scale.clamp(1, 20).toDouble();
    if (next == _debugTimeScale) return;
    _debugTimeScale = next;
    showToast('Dev speed ${_debugTimeScale.round()}x', life: 1.6);
    notifyListeners();
  }

  void cycleDebugTimeScale() {
    setDebugTimeScale(_debugTimeScale >= 9.5 ? 1 : 10);
  }

  /// Test helper: put items in the bag without rebuilding combat.
  @visibleForTesting
  void debugInjectStash(List<EquipmentItem> items) {
    _state = _state.copyWith(
      gearStash: [...items, ..._state.gearStash],
    );
  }

  bool get awaitingWipeChoice => _awaitingWipeChoice;
  bool get uiPaused => _uiPaused;

  /// Freeze dungeon combat while the player is in inventory / overlays.
  void setUiPaused(bool paused) {
    if (_uiPaused == paused) return;
    _uiPaused = paused;
  }

  String? get toast => _toastLife > 0 ? _toast : null;

  String? get clearSummary => _clearSummaryLife > 0 ? _clearSummary : null;

  OfflineProgressResult? get offlineSummary =>
      _offlineSummaryLife > 0 ? _offlineSummary : null;

  void showToast(String message, {double life = 2.4}) {
    if (_toast != null &&
        _toastLife > 0.35 &&
        _toast != message &&
        (_toast!.length + message.length) < 72) {
      _toast = '$_toast · $message';
    } else {
      _toast = message;
    }
    _toastLife = life;
    _ensureUiTimer();
    notifyListeners();
  }

  void dismissOfflineSummary() {
    _offlineSummary = null;
    _offlineSummaryLife = 0;
    notifyListeners();
  }

  void _ensureUiTimer() {
    if (_uiTimer != null) return;
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final had =
          _toastLife > 0 || _clearSummaryLife > 0 || _offlineSummaryLife > 0;
      if (!had) return;
      _tickUiTimers(0.2);
      notifyListeners();
    });
  }

  void _tickUiTimers(double dt) {
    if (_toastLife > 0) {
      _toastLife = (_toastLife - dt).clamp(0, 99);
      if (_toastLife <= 0) _toast = null;
    }
    if (_clearSummaryLife > 0) {
      _clearSummaryLife = (_clearSummaryLife - dt).clamp(0, 99);
      if (_clearSummaryLife <= 0) _clearSummary = null;
    }
    if (_offlineSummaryLife > 0) {
      _offlineSummaryLife = (_offlineSummaryLife - dt).clamp(0, 99);
      if (_offlineSummaryLife <= 0) _offlineSummary = null;
    }
  }

  Future<void> boot({bool deferCombatLoop = false}) async {
    try {
      final saved = await _storage.load();
      _hasExistingSave = saved != null;
      late GameState loaded;
      if (saved == null) {
        // Placeholder only — do not persist until New Game / Continue path.
        loaded = GameLogic.createInitialState();
      } else {
        // Paint immediately — AFK spatial sim must not hold the spinner.
        // Do NOT start the live spatial loop until after offline catch-up.
        _state = GameLogic.ensureRogueHero(saved);
        _lastHighestDungeon = _state.highestDungeonCleared;
        GameAudio.muted = _state.soundMuted;
        SpatialCombat.colorblindMode = _state.colorblindMode;
        _ensureUiTimer();
        // Keep loading flag true until finally{} when intro is deferred —
        // early notify would flash hub/dungeon under the title card.
        if (!deferCombatLoop) {
          _isLoading = false;
          notifyListeners();
        }

        final elapsed = DateTime.now().difference(saved.lastUpdated);
        final offline = GameLogic.applyOfflineProgress(saved, elapsed);
        loaded = offline.state;
        if (offline.hasSummary) {
          _offlineSummary = offline;
          _offlineSummaryLife = 10;
          // Hub shows a tappable banner; toast only when loading mid-dungeon.
          if (saved.inDungeon) {
            showToast(offline.headline, life: 5);
          }
        }
      }
      _state = GameLogic.backfillCodexFromInventory(
        GameLogic.ensureWeeklyContract(
          GameLogic.ensureRogueHero(loaded),
        ),
      );
      _lastHighestDungeon = _state.highestDungeonCleared;
      GameAudio.muted = _state.soundMuted;
      SpatialCombat.colorblindMode = _state.colorblindMode;
      _ensureUiTimer();
      if (_state.inDungeon) {
        _rebuildSpatial();
        if (enableSpatialLoop && !deferCombatLoop) {
          _startSpatialLoop();
        }
        if (!deferCombatLoop) {
          showToast('Floor combat restarted (positions reset)', life: 3.2);
        }
      } else {
        _spatialTimer?.cancel();
        _spatialTimer = null;
        _spatial = null;
      }
      // Only persist when continuing an existing save (offline catch-up).
      if (_hasExistingSave) {
        await _persistFlush();
      }
    } catch (e, st) {
      debugPrint('boot failed: $e\n$st');
      _hasExistingSave = false;
      _state = GameLogic.createInitialState();
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Hard start: wipe save and create a fresh party from [partySpecs] (3 heroes).
  Future<void> startNewGame(List<HeroSpecId> partySpecs) async {
    _awaitingWipeChoice = false;
    _offlineSummary = null;
    _offlineSummaryLife = 0;
    _spatialTimer?.cancel();
    _spatial = null;
    _state = GameLogic.createInitialState(
      partySpecs: GameLogic.normalizeNewGameParty(partySpecs),
    );
    _hasExistingSave = true;
    GameAudio.muted = false;
    SpatialCombat.colorblindMode = _state.colorblindMode;
    _lastHighestDungeon = _state.highestDungeonCleared;
    _ensureUiTimer();
    notifyListeners();
    await _persistFlush();
  }

  /// Continue from the loaded save into play (no-op if already ready).
  void continueGame() {
    if (!_hasExistingSave) return;
    ensureCombatLoop();
    notifyListeners();
  }

  /// Start spatial combat after the cold-start intro (if already in a dungeon).
  void ensureCombatLoop() {
    if (!enableSpatialLoop || !_state.inDungeon) return;
    if (_spatial == null) {
      _rebuildSpatial();
    }
    if (_spatialTimer == null) {
      _startSpatialLoop();
      showToast('Floor combat restarted (positions reset)', life: 3.2);
    }
  }

  void _startSpatialLoop() {
    _spatialTimer?.cancel();
    // ~60 Hz sim; combatFrame drives map paint; shell HUD is throttled.
    _spatialTimer = Timer.periodic(_spatialPeriod, (_) {
      spatialTick();
    });
  }

  void _rebuildSpatial() {
    _spatial = SpatialCombat.build(_state);
    _roomGold = 0;
    _battleToken = _state.battleNumber;
  }

  void _bumpCombatFrame() {
    _visualFrame++;
    combatFrame.value = _visualFrame;
  }

  /// Real-time spatial combat step (~60 Hz). Only while in a dungeon.
  void spatialTick() {
    if (_isLoading || !_state.inDungeon || _spatial == null) {
      return;
    }
    // Freeze sim while wipe modal is up (avoids toast/SFX spam).
    if (_awaitingWipeChoice) {
      return;
    }
    // Soft-pause while inventory / meta menus cover the fight.
    if (_uiPaused) {
      return;
    }

    // Room changed externally (travel / ascend / restart)
    if (_battleToken != _state.battleNumber) {
      _rebuildSpatial();
    }

    final steps = _debugTimeScale.round().clamp(1, 20);
    var playedHit = false;
    var playedLoot = false;
    for (var step = 0; step < steps; step++) {
      if (_awaitingWipeChoice ||
          _uiPaused ||
          !_state.inDungeon ||
          _spatial == null) {
        break;
      }
      if (_battleToken != _state.battleNumber) {
        _rebuildSpatial();
      }

      final result = SpatialCombat.step(_spatial!, _state, dt: _spatialDt);
      final before = _state;
      _spatial = result.world;
      _state = result.state;
      // Only bank this-tick kill gold — clear-frame must not re-fold the room.
      if (!result.roomCleared) {
        _roomGold += result.goldFromKills;
      } else if (result.goldFromKills > 0) {
        _roomGold += result.goldFromKills;
      }
      // Count casts live; defer achievement scan to room clear / discrete events.
      if (result.abilityCasts > 0) {
        _state = _state.copyWith(
          metaDepth: _state.metaDepth.copyWith(
            lifetimeAbilityCasts:
                _state.metaDepth.lifetimeAbilityCasts + result.abilityCasts,
          ),
        );
      }
      _tickUiTimers(_spatialDt);
      _announceAbilityUnlocks(before, _state);
      _announceAchievementUnlocks(before, _state);

      // Live auto-flask (same threshold as AFK): avg living HP < 35%.
      if (step == 0 &&
          GameLogic.canUseConsumable(_state) &&
          !_state.isPartyDefeated) {
        final living = [
          for (final h in _state.heroes)
            if (h.currentHp > 0) h,
        ];
        if (living.isNotEmpty) {
          var ratioSum = 0.0;
          for (final h in living) {
            final maxHp = _state.effectiveHeroMaxHp(h);
            ratioSum += maxHp > 0 ? h.currentHp / maxHp : 0;
          }
          if (ratioSum / living.length < 0.35) {
            final drank = GameLogic.useConsumable(_state);
            if (!identical(drank, _state)) {
              _state = drank;
              _spatial = SpatialCombat.syncPartyFromState(_spatial!, _state);
              SpatialCombat.spawnFlaskHealFx(
                _spatial!,
                reducedVfx: _state.reducedVfx,
              );
            }
          }
        }
      }

      if (result.goldFromKills > 0 && !playedHit) {
        GameAudio.hit();
        playedHit = true;
      }
      if (result.state.gearStash.length > _lastStashLen) {
        if (!playedLoot) {
          GameAudio.loot();
          playedLoot = true;
        }
        // Auto-wear upgrades so bag loot actually powers the party.
        // Must sync spatial (same as bag AUTO) or mid-fight ATK/DEF stay stale.
        final stashBeforeEquip = _state.gearStash.length;
        _state = GameLogic.autoEquipBetterGear(_state);
        if (_spatial != null &&
            _state.inDungeon &&
            before.inDungeon &&
            before.battleNumber == _state.battleNumber &&
            before.layoutSeed == _state.layoutSeed) {
          _spatial = SpatialCombat.syncPartyFromState(_spatial!, _state);
        }
        final equippedN = stashBeforeEquip - _state.gearStash.length;
        if (equippedN > 0) {
          showToast(
            equippedN == 1
                ? 'Equipped 1 upgrade'
                : 'Equipped $equippedN upgrades',
            life: 1.4,
          );
        }
      }
      final stashCap = GameLogic.maxGearStashFor(_state);
      if (before.gearStash.length < stashCap &&
          _state.gearStash.length >= stashCap) {
        showToast('Bag full — oldest loot salvages to essence', life: 2.4);
      }
      if (GameLogic.lastAutoSellCount > 0) {
        final sold = GameLogic.lastAutoSellCount;
        GameLogic.lastAutoSellCount = 0;
        showToast('Bag unstuck · sold $sold', life: 1.5);
      }
      _lastStashLen = _state.gearStash.length;

      _autosaveAccum += _spatialDt;
      if (_autosaveAccum >= _autosaveIntervalSec) {
        _autosaveAccum = 0;
        _persist();
      }

      if (result.partyWiped) {
        _awaitingWipeChoice = true;
        _spatialTimer?.cancel();
        _spatialTimer = null;
        GameAudio.wipe();
        final floor = _state.currentRoom.floorNumber;
        if (_state.inGauntlet) {
          showToast(
            'WIPED — Gauntlet ends on F$floor (best floor saved)',
            life: 4,
          );
        } else {
          final pushFail = _state.dungeonMode == DungeonMode.push &&
              floor > _state.highestFloorCleared;
          showToast(
            pushFail
                ? 'WIPED — Retry retreats to cleared floor (still PUSH), or Hub'
                : 'WIPED — Retry restarts the floor',
            life: 4,
          );
        }
        notifyListeners();
        return;
      }

      if (result.roomCleared) {
        final floorNo = _state.currentRoom.floorNumber;
        final wasTreasure = _spatial?.isTreasure ?? false;
        final gold = wasTreasure
            ? GameLogic.roomCombatBudget(_state.currentRoom).gold
            : (_roomGold > 0
                  ? _roomGold
                  : _state.enemies.fold<int>(0, (s, e) => s + e.rewardGold));
        final beforeDungeon = _state.highestDungeonCleared;
        final wasBoss = _state.currentRoom.type == RoomType.boss;
        final beforeClear = _state;
        // Combat: kill gear already on pickup; floor fillers roll here.
        // Treasure: also rolls chest gear (skipLootRoll: false).
        _state = GameLogic.completeCurrentRoom(
          _state,
          goldGain: gold,
          skipLootRoll: !wasTreasure,
        ).copyWith(lastUpdated: DateTime.now());
        _announceAbilityUnlocks(beforeClear, _state);
        _announceAchievementUnlocks(beforeClear, _state);
        if (wasBoss) {
          GameAudio.boss();
        } else {
          GameAudio.clear();
        }
        _state = MetaSystems.evaluateAchievements(_state);
        _clearSummary = 'FLOOR $floorNo CLEAR  +${gold}g';
        if (beforeClear.inGauntlet) {
          final ess = GameLogic.gauntletEssenceForFloor(
            floorNo,
            boss: wasBoss,
          );
          _clearSummary = 'GAUNTLET F$floorNo  +${gold}g  +${ess}e';
        }
        final matGrants = GameLogic.takeCraftMatGrants();
        if (matGrants.isNotEmpty) {
          final labels = [
            for (final id in matGrants)
              ApexCraft.materialsById[id]?.name ?? id,
          ];
          showToast('+${labels.join(', ')}', life: 2.4);
        }
        // Short enough to fade before the next floor's first fight reads clearly.
        _clearSummaryLife = 1.35;
        if (_state.highestDungeonCleared > beforeDungeon) {
          GameAudio.unlock();
          String? nextId;
          for (final d in DungeonCatalog.all) {
            if (d.number == _state.highestDungeonCleared + 1) {
              nextId = d.id;
              break;
            }
          }
          showToast(
            nextId != null
                ? StoryLore.unlockedNextZone(nextId)
                : StoryLore.dungeonCleared(beforeClear.dungeonId),
            life: 3.2,
          );
          _lastHighestDungeon = _state.highestDungeonCleared;
        } else if (_state.highestDungeonCleared > _lastHighestDungeon) {
          _lastHighestDungeon = _state.highestDungeonCleared;
          showToast(StoryLore.dungeonCleared(beforeClear.dungeonId), life: 3.2);
        }
        if (_state.inDungeon) {
          _rebuildSpatial();
        } else {
          _spatialTimer?.cancel();
          _spatial = null;
          showToast(StoryLore.dungeonCleared(beforeClear.dungeonId), life: 3.2);
        }
        _bumpCombatFrame();
        notifyListeners();
        unawaited(_persistFlush());
        return;
      }

      _bumpCombatFrame();
    }

    _uiThrottle++;
    // Shell chrome (~10 Hz); map/HUD corners listen to [combatFrame] at 60 Hz.
    if (_uiThrottle % _shellNotifyEvery == 0) {
      notifyListeners();
    }
  }

  void _handleWipe() {
    _awaitingWipeChoice = false;
    if (_state.inGauntlet) {
      final floor = _state.currentRoom.floorNumber;
      _state = GameLogic.exitToHubHealed(_state);
      _spatialTimer?.cancel();
      _spatial = null;
      showToast(
        'Gauntlet ended on F$floor · best F${_state.metaDepth.gauntletBestFloor}',
        life: 3.2,
      );
      GameAudio.ui();
      notifyListeners();
      unawaited(_persistFlush());
      return;
    }
    if (_state.dungeonMode == DungeonMode.push &&
        _state.currentRoom.floorNumber > _state.highestFloorCleared) {
      _state = GameLogic.retreatFromFailedPush(
        _state,
      ).copyWith(lastUpdated: DateTime.now());
      showToast(
        'Retreated to floor ${_state.currentRoom.floorNumber} — still PUSH',
        life: 3,
      );
    } else {
      _state = GameLogic.restartFloor(
        _state,
      ).copyWith(lastUpdated: DateTime.now());
      showToast('Floor restarted — fight on', life: 2.5);
    }
    GameAudio.ui();
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    notifyListeners();
    unawaited(_persistFlush());
  }

  void retryAfterWipe() {
    if (!_awaitingWipeChoice) return;
    // Gauntlet has no floor retry — same as hub exit.
    if (_state.inGauntlet) {
      hubAfterWipe();
      return;
    }
    _handleWipe();
  }

  void hubAfterWipe() {
    if (!_awaitingWipeChoice) return;
    _awaitingWipeChoice = false;
    _state = GameLogic.exitToHubHealed(_state);
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _spatial = null;
    showToast('Returned to hub', life: 2);
    GameAudio.ui();
    notifyListeners();
    unawaited(_persistFlush());
  }

  /// God Hand tap — AOE damage at normalized dungeon coords (0..1).
  void godHandAt(double nx, double ny) {
    if (_spatial == null) {
      return;
    }
    godHandAtWorld(
      nx.clamp(0.0, 1.0) * _spatial!.cols,
      ny.clamp(0.0, 1.0) * _spatial!.rows,
    );
  }

  /// God Hand aimed at the nearest live enemy to the party, else party center.
  void godHandAtFocus() {
    final spatial = _spatial;
    if (spatial == null) return;
    final aliveHeroes = spatial.heroes.where((h) => h.hp > 0).toList();
    var cx = spatial.cols / 2.0;
    var cy = spatial.rows / 2.0;
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
    for (final e in spatial.enemies) {
      if (e.hp <= 0 || e.dormant) continue;
      final dx = e.x - cx;
      final dy = e.y - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = e;
      }
    }
    if (best != null) {
      godHandAtWorld(best.x, best.y);
    } else {
      godHandAtWorld(cx, cy);
    }
  }

  /// God Hand tap at world-tile coordinates.
  void godHandAtWorld(double tileX, double tileY) {
    if (_isLoading ||
        !_state.inDungeon ||
        _spatial == null ||
        _state.isPartyDefeated) {
      return;
    }
    final result = SpatialCombat.godHand(
      _spatial!,
      _state,
      tileX: tileX.clamp(0.0, _spatial!.cols.toDouble()).toDouble(),
      tileY: tileY.clamp(0.0, _spatial!.rows.toDouble()).toDouble(),
    );
    _spatial = result.world;
    _state = result.state;
    _roomGold += result.goldFromKills;
    if (result.kills > 0) {
      final g = result.goldFromKills;
      showToast(
        result.kills == 1
            ? (g > 0 ? 'God Hand · 1 kill · +${g}g' : 'God Hand · 1 kill')
            : (g > 0
                ? 'God Hand · ${result.kills} kills · +${g}g'
                : 'God Hand · ${result.kills} kills'),
        life: 1.5,
      );
    }
    notifyListeners();
  }

  void enterDungeon({String dungeonId = 'sandy'}) {
    if (_isLoading) return;
    _awaitingWipeChoice = false;
    _state = GameLogic.enterDungeon(_state, dungeonId: dungeonId);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    showToast(StoryLore.enterDungeon(dungeonId), life: 2.8);
    notifyListeners();
    unawaited(_persistFlush());
  }

  void leaveDungeon() {
    if (_isLoading) return;
    _awaitingWipeChoice = false;
    _state = GameLogic.ensureWeeklyContract(GameLogic.leaveDungeon(_state));
    _spatialTimer?.cancel();
    _spatialTimer = null;
    _spatial = null;
    notifyListeners();
    unawaited(_persistFlush());
  }

  void upgradeGodHand() {
    final before = _state.godHandLevel;
    _applyUpgrade(GameLogic.upgradeGodHand(_state));
    if (_state.godHandLevel > before) {
      GameAudio.unlock();
      showToast(
        'God Hand Lv${_state.godHandLevel} · AOE ${_state.godHandBaseDamage}',
        life: 2.4,
      );
    }
  }

  void bindSoulbound({int? heroIndex}) {
    final beforeFrags = _state.soulboundFragments;
    _applyUpgrade(GameLogic.bindSoulbound(_state, heroIndex: heroIndex));
    if (_state.soulboundFragments < beforeFrags) {
      GameAudio.unlock();
      final name = _state.soulboundItem?.name ?? 'gear';
      showToast('Soulbound: $name', life: 2.2);
    } else if (beforeFrags < 3) {
      showToast('Need 3 soulbound fragments', life: 1.8);
    } else {
      showToast('No gear to bind on this hero', life: 1.8);
    }
  }

  void craftApex({
    required HeroClassId classId,
    required SpecRoleTag role,
    required EquipmentSlot slot,
  }) {
    if (_isLoading) return;
    if (!GameLogic.canCraftApex(
      _state,
      classId: classId,
      role: role,
      slot: slot,
    )) {
      showToast('Missing mats or unlock gate', life: 1.8);
      return;
    }
    _applyUpgrade(
      GameLogic.craftApex(
        _state,
        classId: classId,
        role: role,
        slot: slot,
      ),
    );
    GameAudio.unlock();
    showToast(
      'Crafted ${ApexCraft.pieceName(classId: classId, role: role, slot: slot)}',
      life: 2.4,
    );
  }

  void upgradeApex(String itemId) {
    if (_isLoading) return;
    if (!GameLogic.canUpgradeApex(_state, itemId)) {
      showToast('Cannot upgrade yet', life: 1.8);
      return;
    }
    final before = GameLogic.canUpgradeApex(_state, itemId);
    _applyUpgrade(GameLogic.upgradeApex(_state, itemId));
    if (before) {
      GameAudio.unlock();
      showToast('Apex upgraded', life: 2.0);
    }
  }

  void equipFromApexVault(
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    if (_isLoading) return;
    final before = _state.apexVault.length;
    _applyUpgrade(
      GameLogic.equipFromApexVault(
        _state,
        itemId,
        heroIndex: heroIndex,
        intoSlot: intoSlot,
      ),
    );
    if (_state.apexVault.length < before) {
      showToast('Equipped Apex', life: 1.6);
    } else {
      showToast('Cannot equip Apex', life: 1.6);
    }
  }

  void applyTraining() {
    if (_isLoading) {
      return;
    }

    final updated = GameLogic.trainParty(_state);
    if (identical(updated, _state)) {
      return;
    }

    _applyUpgrade(updated);
  }

  void upgradeAttack() {
    _applyUpgrade(GameLogic.upgradeAttack(_state));
  }

  void upgradeDefense() {
    _applyUpgrade(GameLogic.upgradeDefense(_state));
  }

  void upgradeVitality() {
    _applyUpgrade(GameLogic.upgradeVitality(_state));
  }

  void upgradeMoveSpeed() {
    _applyUpgrade(GameLogic.upgradeMoveSpeed(_state));
  }

  void upgradeAttackSpeed() {
    _applyUpgrade(GameLogic.upgradeAttackSpeed(_state));
  }

  void upgradeCrit() {
    _applyUpgrade(GameLogic.upgradeCrit(_state));
  }

  void unlockRelic(String relicId) {
    final name = GameLogic.relicNames[relicId] ?? relicId;
    final before = _state.hasRelic(relicId);
    _applyUpgrade(GameLogic.unlockRelic(_state, relicId));
    if (!before && _state.hasRelic(relicId)) {
      GameAudio.unlock();
      showToast('Relic: $name', life: 2.4);
    }
  }

  void claimMission(String missionId) {
    int? goldReward;
    int? essenceReward;
    String? title;
    final beforeChain = _state.metaDepth.jobChainCount;
    final beforeEssence = _state.essence;
    for (final m in _state.missions) {
      if (m.id == missionId && m.isComplete) {
        goldReward = m.goldReward;
        essenceReward = m.essenceReward;
        title = m.title;
        break;
      }
    }
    _applyUpgrade(GameLogic.claimMission(_state, missionId));
    if (goldReward != null && essenceReward != null && title != null) {
      GameAudio.loot();
      final chainBonus =
          _state.essence - beforeEssence - essenceReward;
      if (chainBonus > 0 ||
          (beforeChain == 2 && _state.metaDepth.jobChainCount == 0)) {
        showToast(
          '$title: +${goldReward}g +${essenceReward}e · chain +5e!',
          life: 2.8,
        );
      } else {
        showToast(
          '$title: +${goldReward}g +${essenceReward}e',
          life: 2.6,
        );
      }
    }
  }

  void combineGear({required String primaryId, required String secondaryId}) {
    _applyUpgrade(
      GameLogic.combineGear(
        _state,
        primaryId: primaryId,
        secondaryId: secondaryId,
      ),
    );
  }

  void setDungeonMode(DungeonMode mode) {
    final before = _state.dungeonMode;
    _applyUpgrade(GameLogic.setDungeonMode(_state, mode));
    if (_state.dungeonMode != before) {
      GameAudio.ui();
      showToast(
        _state.dungeonMode == DungeonMode.farm
            ? 'FARM — loop this floor for loot'
            : 'PUSH — clear to advance deeper',
        life: 2.2,
      );
    }
  }

  void travelToFloor(int floorNumber) {
    final before = _state.currentRoom.floorNumber;
    _applyUpgrade(GameLogic.travelToFloor(_state, floorNumber));
    final after = _state.currentRoom.floorNumber;
    if (after != before) {
      showToast('Floor $after', life: 1.6);
    }
  }

  void equipFromStash(
    String itemId, {
    int heroIndex = 0,
    EquipmentSlot? intoSlot,
  }) {
    _applyUpgrade(
      GameLogic.equipFromStash(
        _state,
        itemId,
        heroIndex: heroIndex,
        intoSlot: intoSlot,
      ),
    );
  }

  void autoEquipBetterGear() {
    final beforeLen = _state.gearStash.length;
    _applyUpgrade(GameLogic.autoEquipBetterGear(_state));
    final equipped = beforeLen - _state.gearStash.length;
    if (equipped > 0) {
      showToast(
        equipped == 1 ? 'Equipped 1 upgrade' : 'Equipped $equipped upgrades',
        life: 1.8,
      );
    } else {
      showToast('No upgrades in bag', life: 1.5);
    }
  }

  void autoSellJunk() {
    final beforeLen = _state.gearStash.length;
    final beforeEss = _state.essence;
    _applyUpgrade(GameLogic.autoSellJunk(_state));
    GameLogic.lastAutoSellCount = 0;
    final sold = beforeLen - _state.gearStash.length;
    final gained = _state.essence - beforeEss;
    if (sold > 0) {
      showToast(
        'Sold $sold junk · +$gained ess',
        life: 1.9,
      );
    } else {
      final rarePlus = _state.gearStash.any(
        (g) => g.rarity.index >= LootRarity.rare.index,
      );
      showToast(
        rarePlus ? 'No junk left (rare+ kept)' : 'No junk — try AUTO MERGE',
        life: 1.5,
      );
    }
  }

  /// Merge junk bag pairs (same slot, not BiS/upgrades) while gold lasts.
  void autoMergeJunk() {
    final result = GameLogic.autoMergeJunk(_state);
    if (result.merges <= 0) {
      showToast('No junk pairs to merge', life: 1.5);
      return;
    }
    _applyUpgrade(result.state);
    showToast(
      result.merges == 1
          ? 'Auto-merged 1 pair'
          : 'Auto-merged ${result.merges} pairs',
      life: 1.9,
    );
  }

  void setSoundMuted(bool muted) {
    GameAudio.muted = muted;
    _applyUpgrade(_state.copyWith(soundMuted: muted));
  }

  void setReducedVfx(bool value) {
    _applyUpgrade(
      _state.copyWith(
        vfxQuality: value ? VfxQuality.lite : VfxQuality.full,
      ),
    );
  }

  void setVfxQuality(VfxQuality value) {
    _applyUpgrade(_state.copyWith(vfxQuality: value));
  }

  void cycleVfxQuality() {
    setVfxQuality(_state.vfxQuality.next);
  }

  void setAutoSellMaxPower(int value) {
    final cap = GameLogic.maxAutoSellIlvlCap(_state);
    _applyUpgrade(_state.copyWith(autoSellMaxPower: value.clamp(0, cap)));
  }

  void setColorblindMode(bool value) {
    SpatialCombat.colorblindMode = value;
    _applyUpgrade(_state.copyWith(colorblindMode: value));
  }

  void setUiTextScale(double value) {
    _applyUpgrade(_state.copyWith(uiTextScale: value.clamp(0.85, 1.3)));
  }

  void setChallengeBossRush(bool value) {
    _applyUpgrade(_state.copyWith(challengeBossRush: value));
  }

  void setChallengeNoFlask(bool value) {
    _applyUpgrade(_state.copyWith(challengeNoFlask: value));
  }

  void setHardmodeLevel(int level) {
    _applyUpgrade(GameLogic.setHardmodeLevel(_state, level));
  }

  void markChangelogSeen() {
    if (_state.seenChangelogVersion == MetaSystems.currentVersion) return;
    _applyUpgrade(
      _state.copyWith(seenChangelogVersion: MetaSystems.currentVersion),
    );
  }

  // —— Gear loadouts ——————————————————————————————————————————

  void saveLoadout({required String id, required String name}) {
    _applyUpgrade(GameLogic.saveLoadout(_state, id: id, name: name));
    showToast('Gear set "$name" saved', life: 1.8);
  }

  void applyLoadout(String id) {
    final result = GameLogic.applyLoadout(_state, id);
    _applyUpgrade(result.state);
    GameAudio.ui();
    if (result.skipped > 0) {
      showToast(
        'Gear set applied · ${result.skipped} slot'
        '${result.skipped == 1 ? '' : 's'} skipped',
        life: 2.0,
      );
    } else {
      showToast('Gear set applied', life: 1.6);
    }
  }

  void setSoulboundPreferArmor(bool preferArmor) {
    _applyUpgrade(GameLogic.setSoulboundPreferArmor(_state, preferArmor));
  }

  void deleteLoadout(String id) {
    _applyUpgrade(GameLogic.deleteLoadout(_state, id));
  }

  // —— Team composition ————————————————————————————————————————

  void setActiveParty(List<String> heroIds) {
    if (_state.inDungeon) {
      showToast('Leave dungeon to change team', life: 2);
      return;
    }
    final before = _state.activeHeroIds.join(',');
    _applyUpgrade(GameLogic.setActiveParty(_state, heroIds));
    if (_state.activeHeroIds.join(',') != before) {
      showToast('Team updated', life: 1.6);
    }
  }

  void unlockPartySlot5() {
    final before = _state.metaDepth.partySlot5Unlocked;
    _applyUpgrade(GameLogic.unlockPartySlot5(_state));
    if (_state.metaDepth.partySlot5Unlocked && !before) {
      showToast('5th party slot unlocked', life: 2.2);
    }
  }

  void unlockSpec(HeroSpecId specId) {
    if (!GameLogic.canUnlockSpec(_state, specId)) {
      showToast(HeroSpecs.def(specId).unlockHint, life: 2.4);
      return;
    }
    final before = _state.isSpecUnlocked(specId);
    _applyUpgrade(GameLogic.unlockSpec(_state, specId));
    if (_state.isSpecUnlocked(specId) && !before) {
      showToast('${HeroSpecs.def(specId).name} joined roster', life: 2.2);
    }
  }

  // —— Daily run ——————————————————————————————————————————————

  void enterDaily() {
    if (_isLoading) return;
    _state = GameLogic.enterDaily(_state);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    showToast(StoryLore.dailyRun(_state.dungeonId), life: 3.2);
    notifyListeners();
    unawaited(_persistFlush());
  }

  bool get isDailyClaimedToday => MetaSystems.isDailyClaimedToday(_state);

  String get dailyDungeonId =>
      MetaSystems.dailyDungeonId(DateTime.now().toUtc());

  void enterGauntlet() {
    if (_isLoading) return;
    if (!GameLogic.canEnterGauntlet(_state)) {
      showToast(
        _state.ascensionLevel < GameLogic.gauntletMinAscension
            ? 'Gauntlet unlocks at AL${GameLogic.gauntletMinAscension}'
            : 'Leave the dungeon first',
        life: 2.0,
      );
      return;
    }
    _state = GameLogic.enterGauntlet(_state);
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    showToast(
      'Infinity Gauntlet · best F${_state.metaDepth.gauntletBestFloor}',
      life: 3.0,
    );
    notifyListeners();
    unawaited(_persistFlush());
  }

  /// Playtest helper: bump AL to unlock threshold then enter Gauntlet.
  /// Call only from debug UI (`kDebugMode`).
  void devEnterGauntlet() {
    if (_isLoading) return;
    if (_state.inDungeon) {
      showToast('Leave the dungeon first', life: 2.0);
      return;
    }
    if (_state.ascensionLevel < GameLogic.gauntletMinAscension) {
      _state = _state.copyWith(
        ascensionLevel: GameLogic.gauntletMinAscension,
      );
    }
    enterGauntlet();
  }

  // —— Save export / import ——————————————————————————————————————

  String exportSaveJson() => GameLogic.exportSaveJson(_state);

  /// Returns true on success. On failure the current state is untouched.
  bool importSaveJson(String raw) {
    final imported = GameLogic.importSaveJson(raw);
    if (imported == null) return false;
    _awaitingWipeChoice = false;
    _state = GameLogic.ensureRogueHero(imported);
    GameAudio.muted = _state.soundMuted;
    SpatialCombat.colorblindMode = _state.colorblindMode;
    if (_state.inDungeon) {
      _rebuildSpatial();
      if (enableSpatialLoop) {
        _startSpatialLoop();
      }
    } else {
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    }
    notifyListeners();
    unawaited(_persistFlush());
    return true;
  }

  void unequipSlot(EquipmentSlot slot, {int heroIndex = 0}) {
    _applyUpgrade(
      GameLogic.unequipSlot(_state, slot, heroIndex: heroIndex),
    );
  }

  void sellGear(String itemId) {
    final before = _state.essence;
    _applyUpgrade(GameLogic.sellGear(_state, itemId));
    final gained = _state.essence - before;
    if (gained > 0) {
      GameAudio.loot();
      showToast('+$gained ess', life: 1.5);
    }
  }

  void sellGearForGold(String itemId) {
    final before = _state.gold;
    _applyUpgrade(GameLogic.sellGearForGold(_state, itemId));
    if (_state.gold > before) {
      GameAudio.loot();
      showToast('+${_state.gold - before}g', life: 1.6);
    }
  }

  void buyMarketFlask() {
    final cost = GameLogic.marketFlaskCost(_state);
    if (_state.gold < cost) {
      showToast('Need ${cost}g for flask', life: 2);
      return;
    }
    _applyUpgrade(GameLogic.buyMarketFlask(_state));
    GameAudio.loot();
    showToast('Flask acquired', life: 1.8);
  }

  void buyMarketFlasks({int count = 3}) {
    final unit = GameLogic.marketFlaskCost(_state);
    final need = unit * count;
    if (_state.gold < unit) {
      showToast('Need ${unit}g for flask', life: 2);
      return;
    }
    final beforeGold = _state.gold;
    final beforeFlasks = _countFlasks(_state);
    _applyUpgrade(GameLogic.buyMarketFlasks(_state, count: count));
    final bought = _countFlasks(_state) - beforeFlasks;
    final spent = beforeGold - _state.gold;
    if (bought <= 0) {
      showToast('Need ${need}g for $count flasks', life: 2);
      return;
    }
    GameAudio.loot();
    showToast('+$bought flask${bought == 1 ? '' : 's'} (−${spent}g)', life: 1.8);
  }

  void buyMarketBandage() {
    final cost = GameLogic.marketBandageCost(_state);
    if (_state.gold < cost) {
      showToast('Need ${cost}g for bandage', life: 2);
      return;
    }
    _applyUpgrade(GameLogic.buyMarketBandage(_state));
    GameAudio.loot();
    showToast('Field Bandage acquired', life: 1.8);
  }

  static int _countFlasks(GameState state) {
    var n = 0;
    for (final h in state.heroes) {
      if (h.itemIn(EquipmentSlot.consumable) != null) n++;
    }
    for (final g in state.gearStash) {
      if (g.slot == EquipmentSlot.consumable) n++;
    }
    return n;
  }

  void dismissTip(String tipId) {
    final updated = GameLogic.dismissTip(_state, tipId);
    if (identical(updated, _state)) return;
    _state = updated;
    notifyListeners();
    unawaited(_persistFlush());
  }

  void dismissAllTips(Iterable<String> tipIds) {
    final updated = GameLogic.dismissTips(_state, tipIds);
    if (identical(updated, _state)) return;
    _state = updated;
    notifyListeners();
    unawaited(_persistFlush());
  }

  void hatchPet() {
    if (_state.ownedPets.length >= _state.metaDepth.basePetRosterCap) {
      showToast('Roster full', life: 1.8);
      return;
    }
    if (_state.essence < GameLogic.hatchPetCost(_state)) {
      showToast('Need essence', life: 1.8);
      return;
    }
    final beforeCount = _state.ownedPets.length;
    _applyUpgrade(GameLogic.hatchPet(_state));
    if (_state.ownedPets.length > beforeCount) {
      final pet = _state.ownedPets.last;
      GameAudio.unlock();
      showToast('Hatched ${pet.name}!', life: 2.6);
    }
  }

  void mergePets(String petIdA, String petIdB) {
    Pet? a;
    Pet? b;
    for (final pet in _state.ownedPets) {
      if (pet.id == petIdA) a = pet;
      if (pet.id == petIdB) b = pet;
    }
    if (a == null || b == null) return;
    if (a.resolvedSpecies != b.resolvedSpecies) {
      showToast('Need same species', life: 1.8);
      return;
    }
    if (a.rarity == PetRarity.legendary && b.rarity == PetRarity.legendary) {
      showToast('Already legendary', life: 1.8);
      return;
    }
    final before = _state.ownedPets.length;
    _applyUpgrade(GameLogic.mergePets(_state, petIdA, petIdB));
    if (_state.ownedPets.length < before) {
      final pet = _state.ownedPets.last;
      GameAudio.unlock();
      showToast('Merged ${pet.name} · ${pet.rarity.name}!', life: 2.6);
    }
  }

  void setFavoritePetSpecies(String speciesId) {
    _applyUpgrade(GameLogic.setFavoritePetSpecies(_state, speciesId));
    GameAudio.ui();
    showToast('Favorite species set', life: 1.6);
  }

  void setActiveTitle(String title) {
    _applyUpgrade(GameLogic.setActiveTitle(_state, title));
    if (_state.metaDepth.activeTitle == title) {
      GameAudio.ui();
      showToast('Title: $title', life: 1.8);
    }
  }

  void buyPetFrame(String petId, PetFrame frame) {
    final before = _state.essence;
    _applyUpgrade(GameLogic.buyPetFrame(_state, petId, frame));
    if (_state.essence < before) {
      GameAudio.unlock();
      showToast('Frame · ${frame.name}', life: 1.8);
    }
  }

  void bondPet(String petId) {
    var beforeBond = -1;
    String? name;
    for (final pet in _state.ownedPets) {
      if (pet.id == petId) {
        beforeBond = pet.bondLevel;
        name = pet.name;
        break;
      }
    }
    if (beforeBond < 0) return;
    if (_state.essence < GameLogic.bondPetCost(beforeBond)) {
      showToast('Need essence', life: 1.8);
      return;
    }
    _applyUpgrade(GameLogic.bondPet(_state, petId));
    for (final pet in _state.ownedPets) {
      if (pet.id == petId && pet.bondLevel > beforeBond) {
        GameAudio.unlock();
        showToast('${name ?? pet.name} bond Lv${pet.bondLevel}', life: 2.0);
        break;
      }
    }
  }

  void levelUpPet(String petId) {
    var beforeLevel = -1;
    String? name;
    for (final pet in _state.ownedPets) {
      if (pet.id == petId) {
        beforeLevel = pet.level;
        name = pet.name;
        break;
      }
    }
    _applyUpgrade(GameLogic.levelUpPet(_state, petId));
    for (final pet in _state.ownedPets) {
      if (pet.id == petId && pet.level > beforeLevel) {
        GameAudio.unlock();
        showToast('${name ?? pet.name} · Lv${pet.level}!', life: 2.2);
        break;
      }
    }
  }

  void setActivePet(String petId) {
    _applyUpgrade(GameLogic.setActivePet(_state, petId));
  }

  void useConsumable({int? heroIndex}) {
    final before = _state;
    final next = GameLogic.useConsumable(_state, heroIndex: heroIndex);
    _applyUpgrade(next);
    if (!identical(next, before) && _spatial != null && _state.inDungeon) {
      _spatial = SpatialCombat.syncPartyFromState(_spatial!, _state);
      SpatialCombat.spawnFlaskHealFx(
        _spatial!,
        reducedVfx: _state.reducedVfx,
      );
    }
  }

  void upgradeSanctuary(String track) {
    final before = switch (track) {
      'gold' => _state.sanctuaryGoldLevel,
      'power' => _state.sanctuaryPowerLevel,
      'vitality' => _state.sanctuaryVitalityLevel,
      'xp' => _state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    _applyUpgrade(GameLogic.upgradeSanctuary(_state, track));
    final after = switch (track) {
      'gold' => _state.sanctuaryGoldLevel,
      'power' => _state.sanctuaryPowerLevel,
      'vitality' => _state.sanctuaryVitalityLevel,
      'xp' => _state.metaDepth.sanctuaryXpLevel,
      _ => -1,
    };
    if (after > before) {
      final name = GameLogic.sanctuaryNames[track] ?? track;
      final prestige = switch (track) {
        'gold' => _state.metaDepth.sanctuaryGoldPrestige,
        'power' => _state.metaDepth.sanctuaryPowerPrestige,
        'vitality' => _state.metaDepth.sanctuaryVitalityPrestige,
        'xp' => _state.metaDepth.sanctuaryXpPrestige,
        _ => 0,
      };
      final bonus = GameLogic.sanctuaryBonusLabel(
        track,
        after,
        prestige: prestige,
      );
      GameAudio.unlock();
      showToast('$name Lv$after · $bonus', life: 2.4);
    }
  }

  void prestigeSanctuaryTrack(String track) {
    final beforeEssence = _state.essence;
    _applyUpgrade(GameLogic.prestigeSanctuaryTrack(_state, track));
    if (_state.essence > beforeEssence) {
      final name = GameLogic.sanctuaryNames[track] ?? track;
      GameAudio.unlock();
      showToast(
        '$name prestiged · +${_state.essence - beforeEssence}e',
        life: 2.6,
      );
    }
  }

  void upgradeRelicTier(String relicId) {
    final before = _state.metaDepth.relicTierOf(relicId);
    _applyUpgrade(GameLogic.upgradeRelicTier(_state, relicId));
    final after = _state.metaDepth.relicTierOf(relicId);
    if (after > before) {
      final name = GameLogic.relicNames[relicId] ?? relicId;
      GameAudio.unlock();
      showToast('$name · Tier $after', life: 2.2);
    }
  }

  void respecRelics() {
    final beforeEssence = _state.essence;
    _applyUpgrade(GameLogic.respecRelics(_state));
    if (_state.essence < beforeEssence) {
      GameAudio.ui();
      showToast('Relics reset', life: 2.0);
    }
  }

  void refineSoulbound() {
    final before = _state.metaDepth.soulboundRefine;
    _applyUpgrade(GameLogic.refineSoulbound(_state));
    if (_state.metaDepth.soulboundRefine > before) {
      GameAudio.unlock();
      showToast(
        'Soulbound refine +${_state.metaDepth.soulboundRefine}',
        life: 2.2,
      );
    }
  }

  void upgradeGodHandCd() {
    final before = _state.metaDepth.godHandCdLevel;
    _applyUpgrade(GameLogic.upgradeGodHandCd(_state));
    if (_state.metaDepth.godHandCdLevel > before) {
      GameAudio.unlock();
      showToast(
        'God Hand CD Lv${_state.metaDepth.godHandCdLevel}',
        life: 2.2,
      );
    }
  }

  void buyPrestigeShopItem(String id) {
    final before = _state.essence;
    final md = _state.metaDepth;
    final atCap = switch (id) {
      'stash_slot' => md.stashBonusSlots >= 20,
      'combine_luck' => md.combinatorLuck >= 5,
      'torch_keep' => md.torchKeepLevel >= 10,
      'gh_cdr' => md.godHandCdLevel >= 8,
      'roster_cap' => md.petRosterCapBonus >= 10,
      'legacy_spark' => md.legacyPoints >= 20,
      _ => false,
    };
    if (atCap) {
      showToast('At cap', life: 1.8);
      return;
    }
    _applyUpgrade(GameLogic.buyPrestigeShopItem(_state, id));
    if (_state.essence < before) {
      String name = id;
      for (final item in PrestigeShopCatalog.all) {
        if (item.id == id) {
          name = item.name;
          break;
        }
      }
      GameAudio.unlock();
      showToast('Bought $name', life: 2.2);
    }
  }

  void claimWeekly() {
    final before = _state.essence;
    _applyUpgrade(GameLogic.claimWeekly(_state));
    if (_state.essence > before) {
      GameAudio.unlock();
      showToast(
        'Weekly claimed · +${_state.essence - before}e',
        life: 2.4,
      );
    }
  }

  void claimCodexReward(String tierId) {
    final before = _state.essence;
    _applyUpgrade(GameLogic.claimCodexReward(_state, tierId));
    if (_state.essence > before) {
      GameAudio.unlock();
      showToast(
        'Codex reward · +${_state.essence - before}e',
        life: 2.2,
      );
    }
  }

  void ascend() {
    if (_isLoading) {
      return;
    }

    final hadRogue = _state.rogueUnlocked;
    final fromAl = _state.ascensionLevel;
    final updated = GameLogic.ascend(_state);
    if (identical(updated, _state)) {
      return;
    }

    final milestone = MetaSystems.ascendMilestoneReward(
      fromAl,
      updated.ascensionLevel,
    );
    _state = updated;
    GameAudio.unlock();
    final parts = <String>[
      StoryLore.ascendToast(
        al: _state.ascensionLevel,
        milestoneBonus: milestone,
      ),
      'Gear wiped · Apex kept',
    ];
    if (_state.essence >= 20) {
      parts.add('Forge → META for essence');
    }
    if (!hadRogue && _state.rogueUnlocked) {
      parts.add(StoryLore.shadeJoins);
    }
    showToast(parts.join(' · '), life: 4.2);
    if (_state.inDungeon) {
      _rebuildSpatial();
    } else {
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    }
    notifyListeners();
    unawaited(_persistFlush());
  }

  void reviveParty() {
    if (_isLoading || !_state.isPartyDefeated) return;
    // Soft-lock recovery: dead party without modal still exits/retries.
    if (!_awaitingWipeChoice) {
      _awaitingWipeChoice = true;
    }
    if (_state.inGauntlet) {
      hubAfterWipe();
      return;
    }
    retryAfterWipe();
  }

  bool _pendingStartMenu = false;

  bool get pendingStartMenu => _pendingStartMenu;

  void clearPendingStartMenu() {
    _pendingStartMenu = false;
  }

  Future<void> reset() async {
    if (_isLoading) {
      return;
    }
    _awaitingWipeChoice = false;
    await _storage.clear();
    _state = GameLogic.createInitialState();
    _hasExistingSave = false;
    _pendingStartMenu = true;
    GameAudio.muted = false;
    _spatialTimer?.cancel();
    _spatial = null;
    notifyListeners();
  }

  void _applyUpgrade(GameState updated) {
    if (_isLoading || identical(updated, _state)) {
      return;
    }

    final before = _state;
    _state = updated;
    _announceAbilityUnlocks(before, _state);
    _announceAchievementUnlocks(before, _state);
    if (!_state.inDungeon) {
      _spatial = null;
    } else if (_spatial != null &&
        before.inDungeon &&
        before.battleNumber == _state.battleNumber &&
        before.layoutSeed == _state.layoutSeed) {
      // Gear / forge / train mid-fight: keep enemies & positions.
      _spatial = SpatialCombat.syncPartyFromState(_spatial!, _state);
    } else {
      _rebuildSpatial();
    }
    notifyListeners();
    unawaited(_persistFlush());
  }

  void _announceAbilityUnlocks(GameState before, GameState after) {
    for (var i = 0; i < after.heroes.length; i++) {
      final hero = after.heroes[i];
      final oldLevel = i < before.heroes.length ? before.heroes[i].level : 0;
      if (hero.level <= oldLevel) continue;
      final unlocked = ClassKits.unlockedAtSpec(hero.specId, hero.level).where(
            (d) => d.unlockLevel > oldLevel && d.unlockLevel <= hero.level,
          );
      for (final ability in unlocked) {
        GameAudio.unlock();
        showToast('${hero.name}: ${ability.shortLabel}!', life: 2.6);
      }
    }
  }

  void _announceAchievementUnlocks(GameState before, GameState after) {
    if (after.achievements.length <= before.achievements.length) return;
    final known = before.achievements.toSet();
    for (final id in after.achievements) {
      if (known.contains(id)) continue;
      GameAudio.unlock();
      showToast('Achievement unlocked!', life: 2.8);
      break;
    }
  }

  @override
  void dispose() {
    _spatialTimer?.cancel();
    _uiTimer?.cancel();
    combatFrame.dispose();
    super.dispose();
  }
}
