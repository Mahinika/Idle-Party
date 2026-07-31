import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dungeon_mode.dart';
import '../models/dungeon_room.dart';
import '../models/class_ability.dart';
import '../models/loot.dart';
import '../models/meta_depth.dart';
import '../models/pet.dart';
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

    try {
      return GameLogic.stateFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('save load failed: $e\n$st');
      return null;
    }
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
  SpatialWorld? _spatial;
  Timer? _spatialTimer;
  Timer? _uiTimer;
  int _roomGold = 0;
  int _battleToken = 0;
  int _uiThrottle = 0;
  int _visualFrame = 0;
  bool _awaitingWipeChoice = false;
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

  GameState get state => _state;

  bool get isLoading => _isLoading;

  SpatialWorld? get spatial => _spatial;

  /// Increments each spatial sim step — used by combat painter dirty-checks.
  int get visualFrame => _visualFrame;

  /// Test helper: put items in the bag without rebuilding combat.
  @visibleForTesting
  void debugInjectStash(List<EquipmentItem> items) {
    _state = _state.copyWith(
      gearStash: [...items, ..._state.gearStash],
    );
  }

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

  Future<void> boot({bool deferCombatLoop = false}) async {
    try {
      final saved = await _storage.load();
      late GameState loaded;
      if (saved == null) {
        loaded = GameLogic.createInitialState();
      } else {
        // Paint immediately — AFK spatial sim must not hold the spinner.
        _state = GameLogic.ensureRogueHero(saved);
        _lastHighestDungeon = _state.highestDungeonCleared;
        GameAudio.muted = _state.soundMuted;
        SpatialCombat.colorblindMode = _state.colorblindMode;
        _ensureUiTimer();
        if (_state.inDungeon) {
          _rebuildSpatial();
          if (enableSpatialLoop && !deferCombatLoop) {
            _startSpatialLoop();
          }
        }
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
          showToast(offline.headline, life: 5);
        }
      }
      _state = GameLogic.ensureWeeklyContract(
        GameLogic.ensureRogueHero(loaded),
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
      await _storage.save(_state);
    } catch (e, st) {
      debugPrint('boot failed: $e\n$st');
      _state = GameLogic.createInitialState();
      _spatialTimer?.cancel();
      _spatialTimer = null;
      _spatial = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    final before = _state;
    _spatial = result.world;
    _state = result.state;
    _roomGold += result.goldFromKills;
    _tickUiTimers(0.033);
    _announceAbilityUnlocks(before, _state);
    _announceAchievementUnlocks(before, _state);

    if (result.goldFromKills > 0) {
      GameAudio.hit();
    }
    if (result.state.gearStash.length > _lastStashLen) {
      GameAudio.loot();
    }
    _lastStashLen = result.state.gearStash.length;

    _autosaveAccum += 0.033;
    if (_autosaveAccum >= _autosaveIntervalSec) {
      _autosaveAccum = 0;
      unawaited(_storage.save(_state));
    }

    if (result.partyWiped) {
      _awaitingWipeChoice = true;
      GameAudio.wipe();
      final floor = _state.currentRoom.floorNumber;
      final pushFail = _state.dungeonMode == DungeonMode.push &&
          floor > _state.highestFloorCleared;
      showToast(
        pushFail
            ? 'WIPED — Retry farms this floor, or Hub'
            : 'WIPED — Retry restarts the floor',
        life: 4,
      );
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
      _state = GameLogic.completeCurrentRoom(
        _state,
        goldGain: gold,
        skipLootRoll: false,
      ).copyWith(lastUpdated: DateTime.now());
      _announceAbilityUnlocks(beforeClear, _state);
      _announceAchievementUnlocks(beforeClear, _state);
      if (wasBoss) {
        GameAudio.boss();
      } else {
        GameAudio.clear();
      }
      _clearSummary = 'FLOOR $floorNo CLEAR  +${gold}g';
      _clearSummaryLife = 2.2;
      showToast(_clearSummary!, life: 2.0);
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
      notifyListeners();
      unawaited(_storage.save(_state));
      return;
    }

    _uiThrottle++;
    _visualFrame++;
    // ~15 Hz UI rebuilds (sim stays 30 Hz).
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
      showToast('Switched to FARM on cleared floor', life: 3);
    } else {
      _state = GameLogic.restartFloor(
        _state,
      ).copyWith(lastUpdated: DateTime.now());
      showToast('Floor restarted — fight on', life: 2.5);
    }
    GameAudio.ui();
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
    showToast('Returned to hub', life: 2);
    GameAudio.ui();
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
    _lastStashLen = _state.gearStash.length;
    _autosaveAccum = 0;
    _rebuildSpatial();
    if (enableSpatialLoop) {
      _startSpatialLoop();
    }
    showToast(StoryLore.enterDungeon(dungeonId), life: 2.8);
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void leaveDungeon() {
    if (_isLoading) return;
    _state = GameLogic.ensureWeeklyContract(GameLogic.leaveDungeon(_state));
    _spatialTimer?.cancel();
    _spatial = null;
    notifyListeners();
    unawaited(_storage.save(_state));
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
      showToast(
        '$title: +${goldReward}g +${essenceReward}e',
        life: 2.6,
      );
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
    _applyUpgrade(GameLogic.travelToFloor(_state, floorNumber));
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
    final sold = beforeLen - _state.gearStash.length;
    final gained = _state.essence - beforeEss;
    if (sold > 0) {
      showToast(
        'Sold $sold junk · +$gained ess',
        life: 1.9,
      );
    } else {
      showToast('No junk to sell', life: 1.5);
    }
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
    showToast('Loadout "$name" saved', life: 1.8);
  }

  void applyLoadout(String id) {
    _applyUpgrade(GameLogic.applyLoadout(_state, id));
    GameAudio.ui();
    showToast('Loadout applied', life: 1.6);
  }

  void deleteLoadout(String id) {
    _applyUpgrade(GameLogic.deleteLoadout(_state, id));
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
    unawaited(_storage.save(_state));
  }

  bool get isDailyClaimedToday => MetaSystems.isDailyClaimedToday(_state);

  String get dailyDungeonId =>
      MetaSystems.dailyDungeonId(DateTime.now().toUtc());

  // —— Save export / import ——————————————————————————————————————

  String exportSaveJson() => GameLogic.exportSaveJson(_state);

  /// Returns true on success. On failure the current state is untouched.
  bool importSaveJson(String raw) {
    final imported = GameLogic.importSaveJson(raw);
    if (imported == null) return false;
    _state = GameLogic.ensureRogueHero(imported);
    GameAudio.muted = _state.soundMuted;
    SpatialCombat.colorblindMode = _state.colorblindMode;
    if (_state.inDungeon) {
      _rebuildSpatial();
    } else {
      _spatial = null;
    }
    notifyListeners();
    unawaited(_storage.save(_state));
    return true;
  }

  void unequipSlot(EquipmentSlot slot, {int heroIndex = 0}) {
    _applyUpgrade(
      GameLogic.unequipSlot(_state, slot, heroIndex: heroIndex),
    );
  }

  void sellGear(String itemId) {
    _applyUpgrade(GameLogic.sellGear(_state, itemId));
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

  void dismissTip(String tipId) {
    final updated = GameLogic.dismissTip(_state, tipId);
    if (identical(updated, _state)) return;
    _state = updated;
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void hatchPet() {
    final beforeCount = _state.ownedPets.length;
    _applyUpgrade(GameLogic.hatchPet(_state));
    if (_state.ownedPets.length > beforeCount) {
      final pet = _state.ownedPets.last;
      GameAudio.unlock();
      showToast('Hatched ${pet.name}!', life: 2.6);
    }
  }

  void mergePets(String petIdA, String petIdB) {
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
    _applyUpgrade(GameLogic.useConsumable(_state, heroIndex: heroIndex));
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
      final bonus = GameLogic.sanctuaryBonusLabel(track, after);
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
    showToast(
      StoryLore.ascendToast(al: _state.ascensionLevel, milestoneBonus: milestone),
      life: 3,
    );
    if (!hadRogue && _state.rogueUnlocked) {
      showToast(StoryLore.shadeJoins, life: 3.5);
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
    unawaited(_storage.save(_state));
  }

  void _announceAbilityUnlocks(GameState before, GameState after) {
    for (var i = 0; i < after.heroes.length; i++) {
      final hero = after.heroes[i];
      final oldLevel = i < before.heroes.length ? before.heroes[i].level : 0;
      if (hero.level <= oldLevel) continue;
      final unlocked = ClassKits.unlockedAt(hero.role, hero.level).where(
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
    super.dispose();
  }
}
