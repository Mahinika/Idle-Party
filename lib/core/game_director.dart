import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dungeon_mode.dart';
import '../models/loot.dart';
import '../spatial/spatial_combat.dart';
import '../ui/game_audio.dart';
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
  }) : _state = initialState ?? GameLogic.createInitialState() {
    GameAudio.muted = _state.soundMuted;
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
  SpatialWorld? _spatial;
  Timer? _spatialTimer;
  Timer? _uiTimer;
  int _roomGold = 0;
  int _battleToken = 0;
  int _uiThrottle = 0;
  bool _awaitingWipeChoice = false;
  String? _toast;
  double _toastLife = 0;
  String? _clearSummary;
  double _clearSummaryLife = 0;
  OfflineProgressResult? _offlineSummary;
  double _offlineSummaryLife = 0;
  int _lastHighestDungeon = -1;

  GameState get state => _state;

  bool get isLoading => _isLoading;

  SpatialWorld? get spatial => _spatial;

  bool get awaitingWipeChoice => _awaitingWipeChoice;

  String? get toast => _toastLife > 0 ? _toast : null;

  String? get clearSummary => _clearSummaryLife > 0 ? _clearSummary : null;

  OfflineProgressResult? get offlineSummary =>
      _offlineSummaryLife > 0 ? _offlineSummary : null;

  void showToast(String message, {double life = 2.4}) {
    _toast = message;
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

  Future<void> boot() async {
    final saved = await _storage.load();
    if (saved == null) {
      _state = GameLogic.createInitialState();
    } else {
      final elapsed = DateTime.now().difference(saved.lastUpdated);
      final offline = GameLogic.applyOfflineProgress(saved, elapsed);
      _state = offline.state;
      if (offline.hasSummary) {
        _offlineSummary = offline;
        _offlineSummaryLife = 10;
        showToast(offline.headline, life: 5);
      }
    }
    _state = GameLogic.ensureRogueHero(_state);
    _lastHighestDungeon = _state.highestDungeonCleared;
    GameAudio.muted = _state.soundMuted;
    _ensureUiTimer();

    _isLoading = false;
    if (_state.inDungeon) {
      _rebuildSpatial();
      if (enableSpatialLoop) {
        _startSpatialLoop();
      }
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

  /// Real-time spatial combat step (~30 Hz). Only while in a dungeon.
  void spatialTick() {
    if (_isLoading || !_state.inDungeon || _spatial == null) {
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
    _tickUiTimers(0.033);

    if (result.partyWiped) {
      _awaitingWipeChoice = true;
      showToast('PARTY WIPED', life: 3);
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
      _state = GameLogic.completeCurrentRoom(
        _state,
        goldGain: gold,
        skipLootRoll: false,
      ).copyWith(lastUpdated: DateTime.now());
      _clearSummary = 'FLOOR $floorNo CLEAR  +${gold}g';
      _clearSummaryLife = 2.2;
      showToast(_clearSummary!, life: 2.0);
      if (_state.highestDungeonCleared > beforeDungeon) {
        showToast('UNLOCKED NEXT ZONE!', life: 3.2);
        _lastHighestDungeon = _state.highestDungeonCleared;
      } else if (_state.highestDungeonCleared > _lastHighestDungeon) {
        _lastHighestDungeon = _state.highestDungeonCleared;
        showToast('DUNGEON CLEARED!', life: 3);
      }
      if (_state.inDungeon) {
        _rebuildSpatial();
      } else {
        _spatialTimer?.cancel();
        _spatial = null;
        showToast('DUNGEON COMPLETE', life: 3);
      }
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
    _awaitingWipeChoice = false;
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

  void retryAfterWipe() {
    if (!_awaitingWipeChoice) return;
    _handleWipe();
  }

  void hubAfterWipe() {
    if (!_awaitingWipeChoice) return;
    _awaitingWipeChoice = false;
    _state = GameLogic.leaveDungeon(_state);
    _spatialTimer?.cancel();
    _spatial = null;
    notifyListeners();
    unawaited(_storage.save(_state));
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
    notifyListeners();
  }

  void enterDungeon({String dungeonId = 'sandy'}) {
    if (_isLoading) return;
    _state = GameLogic.enterDungeon(_state, dungeonId: dungeonId);
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void leaveDungeon() {
    if (_isLoading) return;
    _state = GameLogic.leaveDungeon(_state);
    _spatialTimer?.cancel();
    _spatial = null;
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void upgradeGodHand() {
    _applyUpgrade(GameLogic.upgradeGodHand(_state));
  }

  void bindSoulbound({int? heroIndex}) {
    _applyUpgrade(GameLogic.bindSoulbound(_state, heroIndex: heroIndex));
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
    _applyUpgrade(GameLogic.setDungeonMode(_state, mode));
  }

  void travelToFloor(int floorNumber) {
    _applyUpgrade(GameLogic.travelToFloor(_state, floorNumber));
  }

  void equipFromStash(String itemId, {int heroIndex = 0}) {
    _applyUpgrade(
      GameLogic.equipFromStash(_state, itemId, heroIndex: heroIndex),
    );
  }

  void autoEquipBetterGear() {
    _applyUpgrade(GameLogic.autoEquipBetterGear(_state));
  }

  void autoSellJunk() {
    _applyUpgrade(GameLogic.autoSellJunk(_state));
  }

  void setSoundMuted(bool muted) {
    GameAudio.muted = muted;
    _applyUpgrade(_state.copyWith(soundMuted: muted));
  }

  void setReducedVfx(bool value) {
    _applyUpgrade(_state.copyWith(reducedVfx: value));
  }

  void setAutoSellMaxPower(int value) {
    _applyUpgrade(_state.copyWith(autoSellMaxPower: value.clamp(0, 80)));
  }

  void unequipSlot(EquipmentSlot slot, {int heroIndex = 0}) {
    _applyUpgrade(
      GameLogic.unequipSlot(_state, slot, heroIndex: heroIndex),
    );
  }

  void sellGear(String itemId) {
    _applyUpgrade(GameLogic.sellGear(_state, itemId));
  }

  void hatchPet() {
    _applyUpgrade(GameLogic.hatchPet(_state));
  }

  void levelUpPet(String petId) {
    _applyUpgrade(GameLogic.levelUpPet(_state, petId));
  }

  void setActivePet(String petId) {
    _applyUpgrade(GameLogic.setActivePet(_state, petId));
  }

  void useConsumable({int? heroIndex}) {
    _applyUpgrade(GameLogic.useConsumable(_state, heroIndex: heroIndex));
  }

  void upgradeSanctuary(String track) {
    _applyUpgrade(GameLogic.upgradeSanctuary(_state, track));
  }

  void ascend() {
    if (_isLoading) {
      return;
    }

    final hadRogue = _state.rogueUnlocked;
    final updated = GameLogic.ascend(_state);
    if (identical(updated, _state)) {
      return;
    }

    _state = updated;
    if (!hadRogue && _state.rogueUnlocked) {
      showToast('SHADE THE ROGUE JOINS!', life: 3.5);
    }
    if (_state.inDungeon) {
      _rebuildSpatial();
    } else {
      _spatial = null;
    }
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void reviveParty() {
    if (_isLoading) return;
    if (_awaitingWipeChoice || _state.isPartyDefeated) {
      retryAfterWipe();
    }
  }

  Future<void> reset() async {
    if (_isLoading) {
      return;
    }
    _awaitingWipeChoice = false;
    _state = GameLogic.createInitialState();
    GameAudio.muted = false;
    _spatialTimer?.cancel();
    _spatial = null;
    notifyListeners();
    await _storage.save(_state);
  }

  void _applyUpgrade(GameState updated) {
    if (_isLoading || identical(updated, _state)) {
      return;
    }

    _state = updated;
    if (_state.inDungeon) {
      _rebuildSpatial();
    } else {
      _spatial = null;
    }
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  @override
  void dispose() {
    _spatialTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }
}
