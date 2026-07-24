import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_logic.dart';
import 'game_state.dart';

abstract class GameStorage {
  Future<GameState?> load();

  Future<void> save(GameState state);
}

class SharedPreferencesGameStorage implements GameStorage {
  SharedPreferencesGameStorage({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _saveKey = 'idle_party_save_v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<GameState?> load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_saveKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
  GameDirector(this._storage, {GameState? initialState})
    : _state = initialState ?? GameLogic.createInitialState();

  factory GameDirector.persistent() {
    return GameDirector(SharedPreferencesGameStorage());
  }

  factory GameDirector.preview({GameState? initialState}) {
    final seed = initialState ?? GameLogic.createInitialState();
    return GameDirector(InMemoryGameStorage(seed), initialState: seed);
  }

  final GameStorage _storage;

  GameState _state;
  bool _isLoading = true;

  GameState get state => _state;

  bool get isLoading => _isLoading;

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
    notifyListeners();
    await _storage.save(_state);
  }

  void tick() {
    if (_isLoading) {
      return;
    }

    _state = GameLogic.advance(_state);
    _state = _state.copyWith(lastUpdated: DateTime.now());
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

  void reviveParty() {
    if (_isLoading || !_state.isPartyDefeated) {
      return;
    }

    _state = _state.copyWith(
      heroes: _state.heroes
          .map(
            (hero) => hero.copyWith(currentHp: _state.effectiveHeroMaxHp(hero)),
          )
          .toList(),
      enemy: _state.enemy.healToFull(),
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  void _applyUpgrade(GameState updated) {
    if (_isLoading || identical(updated, _state)) {
      return;
    }

    _state = updated;
    notifyListeners();
    unawaited(_storage.save(_state));
  }

  Future<void> reset() async {
    _state = GameLogic.createInitialState();
    _state = _state.copyWith(lastUpdated: DateTime.now());
    _isLoading = false;
    notifyListeners();
    await _storage.save(_state);
  }
}
