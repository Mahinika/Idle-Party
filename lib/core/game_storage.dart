import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_play_log.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// Persist / load [GameState] blobs (SharedPreferences or in-memory for tests).
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
    final rawV2 = prefs.getString(_saveKey);
    final rawV1 = prefs.getString(_legacySaveKey);
    final raw = (rawV2 != null && rawV2.isNotEmpty) ? rawV2 : rawV1;
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return GameLogic.stateFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      DebugPlayLog.event('save', 'load failed (quarantined): $e');
      debugPrint('save load failed (quarantined): $e\n$st');
      await prefs.setString(_corruptSaveKey, raw);
      // If v2 was corrupt, try a still-valid legacy v1 before wiping both.
      if (rawV2 != null &&
          rawV2.isNotEmpty &&
          rawV1 != null &&
          rawV1.isNotEmpty &&
          raw == rawV2) {
        try {
          final recovered = GameLogic.stateFromJson(
            jsonDecode(rawV1) as Map<String, dynamic>,
          );
          await prefs.remove(_saveKey);
          DebugPlayLog.event('save', 'recovered from legacy v1');
          debugPrint('save load recovered from legacy v1 after corrupt v2');
          return recovered;
        } catch (e2, st2) {
          debugPrint('legacy v1 also failed: $e2\n$st2');
        }
      }
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
