import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dungeon_def.dart';
import 'debug_play_log.dart';
import 'game_logic.dart';
import 'game_state.dart';

/// One of the five title-screen save files.
class SaveSlotSummary {
  const SaveSlotSummary({
    required this.index,
    this.partyName,
    this.zoneName,
    this.ascensionLevel,
    this.partyLevel,
    this.corrupt = false,
  });

  final int index;
  final String? partyName;
  final String? zoneName;
  final int? ascensionLevel;
  final int? partyLevel;
  final bool corrupt;

  bool get occupied => partyName != null || corrupt;

  String get label => 'SAVE ${index + 1}';

  /// Zone, party level, and Ascend level for the title row.
  String? get detail {
    if (!occupied || corrupt) return null;
    final bits = <String>[zoneName ?? 'Sandy Caverns'];
    if (partyLevel != null) bits.add('Lv $partyLevel');
    if ((ascensionLevel ?? 0) > 0) bits.add('AL $ascensionLevel');
    return bits.join(' · ');
  }

  static SaveSlotSummary empty(int index) => SaveSlotSummary(index: index);

  static SaveSlotSummary unreadable(int index) =>
      SaveSlotSummary(index: index, corrupt: true);

  static SaveSlotSummary fromState(int index, GameState? state) {
    if (state == null) return empty(index);
    return SaveSlotSummary(
      index: index,
      partyName: state.partyName,
      zoneName: DungeonCatalog.byId(state.dungeonId).name,
      ascensionLevel: state.ascensionLevel,
      partyLevel: GameLogic.partyMeanLevel(state),
    );
  }

  /// Lightweight read so the title can list slots without a full migrate.
  static SaveSlotSummary fromBlob(int index, String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return unreadable(index);
      final json = Map<String, dynamic>.from(decoded);
      final roster = json['heroRoster'];
      var level = 1;
      if (roster is List && roster.isNotEmpty) {
        var sum = 0;
        var n = 0;
        for (final hero in roster) {
          if (hero is Map && hero['level'] is num) {
            sum += (hero['level'] as num).toInt();
            n++;
          }
        }
        if (n > 0) level = sum ~/ n;
        if (level < 1) level = 1;
      }
      final dungeonId = json['dungeonId'] as String? ?? 'sandy';
      final name = json['partyName'];
      return SaveSlotSummary(
        index: index,
        partyName: name is String && name.trim().isNotEmpty
            ? name.trim()
            : 'The Party',
        zoneName: DungeonCatalog.byId(dungeonId).name,
        ascensionLevel: (json['ascensionLevel'] as num?)?.toInt() ?? 0,
        partyLevel: level,
      );
    } catch (_) {
      return unreadable(index);
    }
  }
}

/// Persist / load [GameState] blobs (SharedPreferences or in-memory for tests).
abstract class GameStorage {
  static const int slotCount = 5;

  /// Active slot (the save Continue / autosave uses).
  int get activeSlotIndex;

  Future<GameState?> load();

  Future<void> save(GameState state);

  /// True when the active slot has a persisted blob.
  Future<bool> hasSave();

  Future<void> clear();

  Future<List<SaveSlotSummary>> listSlots();

  Future<void> setActiveSlot(int index);

  Future<GameState?> loadSlot(int index);

  Future<void> clearSlot(int index);
}

class SharedPreferencesGameStorage implements GameStorage {
  SharedPreferencesGameStorage({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _saveKey = 'idle_party_save_v2';
  static const String _legacySaveKey = 'idle_party_save_v1';
  static const String _corruptSaveKey = 'idle_party_save_v2_corrupt';
  static const String _activeKey = 'idle_party_active_slot';
  static const String _slotsReadyKey = 'idle_party_slots_ready';

  final SharedPreferences? _preferences;
  int _active = 0;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  static String _slotKey(int index) => 'idle_party_save_slot_$index';

  @override
  int get activeSlotIndex => _active;

  Future<void> _prepare(SharedPreferences prefs) async {
    if (prefs.getBool(_slotsReadyKey) != true) {
      final hasSlot = List<int>.generate(GameStorage.slotCount, (i) => i).any((
        i,
      ) {
        final raw = prefs.getString(_slotKey(i));
        return raw != null && raw.isNotEmpty;
      });
      if (!hasSlot) {
        final rawV2 = prefs.getString(_saveKey);
        final rawV1 = prefs.getString(_legacySaveKey);
        final raw = (rawV2 != null && rawV2.isNotEmpty) ? rawV2 : rawV1;
        if (raw != null && raw.isNotEmpty) {
          await prefs.setString(_slotKey(0), raw);
          await prefs.setInt(_activeKey, 0);
        }
      }
      await prefs.setBool(_slotsReadyKey, true);
    }
    _active = (prefs.getInt(_activeKey) ?? 0).clamp(
      0,
      GameStorage.slotCount - 1,
    );
  }

  int _clampSlot(int index) => index.clamp(0, GameStorage.slotCount - 1);

  Future<GameState?> _readBlob(
    SharedPreferences prefs,
    String key,
    String raw,
  ) async {
    try {
      return GameLogic.stateFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, st) {
      DebugPlayLog.event('save', 'load failed (quarantined): $e');
      debugPrint('save load failed (quarantined): $e\n$st');
      final rawV2 = prefs.getString(_saveKey);
      final rawV1 = prefs.getString(_legacySaveKey);
      if (rawV2 != null &&
          rawV2.isNotEmpty &&
          rawV1 != null &&
          rawV1.isNotEmpty &&
          raw == rawV2) {
        try {
          final recovered = GameLogic.stateFromJson(
            jsonDecode(rawV1) as Map<String, dynamic>,
          );
          await prefs.setString(_corruptSaveKey, raw);
          await prefs.remove(_saveKey);
          await prefs.setString(key, jsonEncode(recovered.toJson()));
          DebugPlayLog.event('save', 'recovered from legacy v1');
          debugPrint('save load recovered from legacy v1 after corrupt v2');
          return recovered;
        } catch (e2, st2) {
          debugPrint('legacy v1 also failed: $e2\n$st2');
        }
      }
      await prefs.setString(
        raw == rawV2 ? _corruptSaveKey : '${key}_corrupt',
        raw,
      );
      await prefs.remove(key);
      if (raw == rawV2) await prefs.remove(_saveKey);
      if (raw == rawV1) await prefs.remove(_legacySaveKey);
      return null;
    }
  }

  Future<GameState?> _readSlot(SharedPreferences prefs, int index) async {
    final key = _slotKey(_clampSlot(index));
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return _readBlob(prefs, key, raw);
  }

  @override
  Future<GameState?> load() async {
    final prefs = await _prefs;
    await _prepare(prefs);
    return _readSlot(prefs, _active);
  }

  @override
  Future<GameState?> loadSlot(int index) async {
    final prefs = await _prefs;
    await _prepare(prefs);
    return _readSlot(prefs, index);
  }

  @override
  Future<void> save(GameState state) async {
    final prefs = await _prefs;
    await _prepare(prefs);
    final raw = jsonEncode(state.toJson());
    await prefs.setString(_slotKey(_active), raw);
    // Older builds still read the single v2 key — keep it as the last played slot.
    await prefs.setString(_saveKey, raw);
  }

  @override
  Future<bool> hasSave() async {
    final prefs = await _prefs;
    await _prepare(prefs);
    final raw = prefs.getString(_slotKey(_active));
    return raw != null && raw.isNotEmpty;
  }

  @override
  Future<void> clear() => clearSlot(_active);

  @override
  Future<void> clearSlot(int index) async {
    final prefs = await _prefs;
    await _prepare(prefs);
    final slot = _clampSlot(index);
    final key = _slotKey(slot);
    final raw = prefs.getString(key);
    await prefs.remove(key);
    if (raw != null && raw == prefs.getString(_saveKey)) {
      await prefs.remove(_saveKey);
    }
  }

  @override
  Future<void> setActiveSlot(int index) async {
    final prefs = await _prefs;
    await _prepare(prefs);
    _active = _clampSlot(index);
    await prefs.setInt(_activeKey, _active);
  }

  @override
  Future<List<SaveSlotSummary>> listSlots() async {
    final prefs = await _prefs;
    await _prepare(prefs);
    return [
      for (var i = 0; i < GameStorage.slotCount; i++)
        _summary(i, prefs.getString(_slotKey(i))),
    ];
  }

  SaveSlotSummary _summary(int index, String? raw) {
    if (raw == null || raw.isEmpty) return SaveSlotSummary.empty(index);
    return SaveSlotSummary.fromBlob(index, raw);
  }
}

class InMemoryGameStorage implements GameStorage {
  InMemoryGameStorage([GameState? state]) {
    if (state != null) _slots[0] = state;
  }

  final List<GameState?> _slots = List<GameState?>.filled(
    GameStorage.slotCount,
    null,
  );
  int _active = 0;

  int _clampSlot(int index) => index.clamp(0, GameStorage.slotCount - 1);

  @override
  int get activeSlotIndex => _active;

  @override
  Future<GameState?> load() async => _slots[_active];

  @override
  Future<GameState?> loadSlot(int index) async => _slots[_clampSlot(index)];

  @override
  Future<void> save(GameState state) async {
    _slots[_active] = state;
  }

  @override
  Future<bool> hasSave() async => _slots[_active] != null;

  @override
  Future<void> clear() async {
    _slots[_active] = null;
  }

  @override
  Future<void> clearSlot(int index) async {
    _slots[_clampSlot(index)] = null;
  }

  @override
  Future<void> setActiveSlot(int index) async {
    _active = _clampSlot(index);
  }

  @override
  Future<List<SaveSlotSummary>> listSlots() async => [
    for (var i = 0; i < GameStorage.slotCount; i++)
      SaveSlotSummary.fromState(i, _slots[i]),
  ];
}
