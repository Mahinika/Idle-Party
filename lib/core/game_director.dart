import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dungeon_mode.dart';
import '../models/loot.dart';
import '../spatial/spatial_combat.dart';
import 'game_logic.dart';
import 'game_state.dart';

abstract class GameStorage {
  Future<GameState?> load();

  Future<void> save(GameState state);
}

class SharedPreferencesGameStorage implements GameStorage {
  SharedPreferencesGameStorage({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _saveKey = 'idle_party_save_v2';
  static const String _legacySaveKey = 'idle_party_save_v1';

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

    return GameLogic.stateFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(GameState state) async {
    final prefs = await _prefs;
    await prefs.setString(_saveKey, jsonEncode(state.toJson()));
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
}

class GameDirector extends ChangeNotifier {
  GameDirector(
    this._storage, {
    GameState? initialState,
    this.enableSpatialLoop = true,
  }) : _state = initialState ?? GameLogic.createInitialState();

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
  SpatialWorld? _spatial;
  Timer? _spatialTimer;
  int _roomGold = 0;
  int _battleToken = 0;
  int _uiThrottle = 0;

  GameState get state => _state;

  bool get isLoading => _isLoading;

  SpatialWorld? get spatial => _spatial;

  Future<void> boot() async {
    final saved = await _storage.load();
    if (saved == null) {
      _state = GameLogic.createInitialState();
    } else {
      _state = GameLogic.applyOfflineProgress(
        saved,
        DateTime.now().difference(saved.lastUpdated),
      );
    }

    _isLoading = false;
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    notifyListeners();
    await _storage.save(_state);
  }

  void _startSpatialLoop() {
    _spatialTimer?.cancel();
    // 30 Hz sim is enough; UI notifies every other tick (~15 fps).
    _spatialTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      spatialTick();
    });
  }

  void _rebuildSpatial() {
    _spatial = SpatialCombat.build(_state);
    _roomGold = 0;
    _battleToken = _state.battleNumber;
  }

  /// Real-time spatial combat step (~20 Hz).
  void spatialTick() {
    if (_isLoading || _spatial == null) {
      return;
    }

    // Room changed externally (travel / ascend / restart)
    if (_battleToken != _state.battleNumber) {
      _rebuildSpatial();
    }

    final result = SpatialCombat.step(_spatial!, _state, dt: 0.033);
    _spatial = result.world;
    _state = result.state;
    _roomGold += result.goldFromKills;

    if (result.partyWiped) {
      _handleWipe();
      return;
    }

    if (result.roomCleared) {
      final wasTreasure = _spatial?.isTreasure ?? false;
      final gold = wasTreasure
          ? GameLogic.roomCombatBudget(_state.currentRoom).gold
          : (_roomGold > 0
                ? _roomGold
                : _state.enemies.fold<int>(0, (s, e) => s + e.rewardGold));
      _state = GameLogic.completeCurrentRoom(
        _state,
        goldGain: gold,
        skipLootRoll: false,
      ).copyWith(lastUpdated: DateTime.now());
      _rebuildSpatial();
      notifyListeners();
      unawaited(_storage.save(_state));
      return;
    }

    _uiThrottle++;
    if (_uiThrottle % 2 == 0) {
      notifyListeners();
    }
  }

  void _handleWipe() {
    if (_state.dungeonMode == DungeonMode.push &&
        _state.currentRoom.floorNumber > _state.highestFloorCleared) {
      _state = GameLogic.retreatFromFailedPush(
        _state,
      ).copyWith(lastUpdated: DateTime.now());
    } else {
      _state = GameLogic.restartFloor(
        _state,
      ).copyWith(lastUpdated: DateTime.now());
    }
    _rebuildSpatial();
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  /// God Hand tap — AOE damage at normalized dungeon coords (0..1).
  void godHandAt(double nx, double ny) {
    if (_isLoading || _spatial == null || _state.isPartyDefeated) {
      return;
    }
    final tileX = nx.clamp(0.0, 1.0) * SpatialCombat.cols;
    final tileY = ny.clamp(0.0, 1.0) * SpatialCombat.rows;
    final result = SpatialCombat.godHand(
      _spatial!,
      _state,
      tileX: tileX,
      tileY: tileY,
    );
    _spatial = result.world;
    _state = result.state;
    _roomGold += result.goldFromKills;
    notifyListeners();
  }

  /// Legacy single abstract tick (tests / debug). Prefer spatialTick.
  void tick() {
    if (_isLoading) {
      return;
    }

    _state = GameLogic.advance(_state);
    _state = _state.copyWith(lastUpdated: DateTime.now());
    _rebuildSpatial();
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void applyTraining() {
    if (_isLoading) {
      return;
    }

    final updated = GameLogic.trainParty(_state);
    if (identical(updated, _state)) {
      return;
    }

    _state = updated;
    _rebuildSpatial();
    notifyListeners();
    unawaited(_storage.save(_state));
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

  void unlockRelic(String relicId) {
    _applyUpgrade(GameLogic.unlockRelic(_state, relicId));
  }

  void claimMission(String missionId) {
    _applyUpgrade(GameLogic.claimMission(_state, missionId));
  }

  void combineGear({
    required String primaryId,
    required String secondaryId,
  }) {
    _applyUpgrade(
      GameLogic.combineGear(
        _state,
        primaryId: primaryId,
        secondaryId: secondaryId,
      ),
    );
  }

  void setDungeonMode(DungeonMode mode) {
    _applyUpgrade(GameLogic.setDungeonMode(_state, mode));
  }

  void travelToFloor(int floorNumber) {
    _applyUpgrade(GameLogic.travelToFloor(_state, floorNumber));
  }

  void equipFromStash(String itemId) {
    _applyUpgrade(GameLogic.equipFromStash(_state, itemId));
  }

  void unequipSlot(EquipmentSlot slot) {
    _applyUpgrade(GameLogic.unequipSlot(_state, slot));
  }

  void sellGear(String itemId) {
    _applyUpgrade(GameLogic.sellGear(_state, itemId));
  }

  void hatchPet() {
    _applyUpgrade(GameLogic.hatchPet(_state));
  }

  void setActivePet(String petId) {
    _applyUpgrade(GameLogic.setActivePet(_state, petId));
  }

  void upgradeSanctuary(String track) {
    _applyUpgrade(GameLogic.upgradeSanctuary(_state, track));
  }

  void ascend() {
    if (_isLoading) {
      return;
    }

    final updated = GameLogic.ascend(_state);
    if (identical(updated, _state)) {
      return;
    }

    _state = updated;
    _rebuildSpatial();
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void reviveParty() {
    if (_isLoading || !_state.isPartyDefeated) {
      return;
    }

    _handleWipe();
  }

  void _applyUpgrade(GameState updated) {
    if (_isLoading || identical(updated, _state)) {
      return;
    }

    _state = updated;
    // Keep positions; refresh combat stats from new bonuses
    _rebuildSpatial();
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  Future<void> reset() async {
    _state = GameLogic.createInitialState();
    _state = _state.copyWith(lastUpdated: DateTime.now());
    _isLoading = false;
    _rebuildSpatial();
    notifyListeners();
    await _storage.save(_state);
  }

  @override
  void dispose() {
    _spatialTimer?.cancel();
    super.dispose();
  }
}
