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
  static const String displacedKey = 'idle_party_displaced_save';
  static const String stagingKey = 'idle_party_save_staging';
  static const String holdKey = 'idle_party_save_hold';
  static const String journalKey = 'idle_party_save_journal';

  /// Slot 0 keeps the original key so a file written before the keys were
  /// split still resolves. An early build also stored every slot's journal
  /// under these unsuffixed names. The selected slot is not the owner.
  /// [SaveSwap] copies an older journal onto another slot only when that
  /// slot's saved bytes are the only match. A journal this build writes
  /// names its slot. A missing file is not that proof.
  static String displacedKeyFor(int slot) =>
      slot <= 0 ? displacedKey : '${displacedKey}_$slot';

  static String stagingKeyFor(int slot) =>
      slot <= 0 ? stagingKey : '${stagingKey}_$slot';

  static String holdKeyFor(int slot) =>
      slot <= 0 ? holdKey : '${holdKey}_$slot';

  static String journalKeyFor(int slot) =>
      slot <= 0 ? journalKey : '${journalKey}_$slot';

  /// Active slot (the save Continue / autosave uses).
  int get activeSlotIndex;

  Future<GameState?> load();

  /// False when the blob did not land. A thrown error is a failed write too.
  Future<bool> save(GameState state);

  /// True when the active slot has a persisted blob.
  Future<bool> hasSave();

  Future<void> clear();

  Future<List<SaveSlotSummary>> listSlots();

  Future<void> setActiveSlot(int index);

  Future<GameState?> loadSlot(int index);

  Future<void> clearSlot(int index);

  /// JSON kept when a cloud restore replaces the active slot. Not a sixth slot.
  /// An empty string clears it.
  Future<bool> keepDisplacedSave(String json);

  Future<String?> loadDisplacedSave();

  /// Raw active-slot JSON, without migrating it into a [GameState].
  Future<String?> loadActiveRaw();

  /// Raw JSON for one slot. Recovery of a slot that is not active uses this.
  Future<String?> loadSlotRaw(int index);

  /// Writes [json] as the active slot. False when the bytes did not land.
  Future<bool> writeActiveRaw(String json);

  /// Side file (device copy, staging, journal). Null [json] deletes it.
  Future<String?> loadExtra(String key);

  Future<bool> writeExtra(String key, String? json);

  /// Drop a cache that may already show a write the platform rejected.
  /// SharedPreferences updates its map before the platform returns.
  Future<void> reloadDurable();
}

/// Thrown by the in-memory store to simulate a process death after durable
/// bytes changed and before the caller observed success. This is not a real
/// process kill.
class SimulatedSaveKill implements Exception {
  const SimulatedSaveKill();
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
  Future<bool> save(GameState state) async {
    final prefs = await _prefs;
    await _prepare(prefs);
    final raw = jsonEncode(state.toJson());
    final slotOk = await prefs.setString(_slotKey(_active), raw);
    // Older builds still read the single v2 key — keep it as the last played slot.
    final mirrorOk = await prefs.setString(_saveKey, raw);
    return slotOk && mirrorOk;
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

  @override
  Future<bool> keepDisplacedSave(String json) => writeExtra(
    GameStorage.displacedKeyFor(_active),
    json.isEmpty ? null : json,
  );

  @override
  Future<String?> loadDisplacedSave() =>
      loadExtra(GameStorage.displacedKeyFor(_active));

  @override
  Future<String?> loadActiveRaw() => loadSlotRaw(_active);

  @override
  Future<String?> loadSlotRaw(int index) async {
    final prefs = await _prefs;
    await _prepare(prefs);
    final raw = prefs.getString(_slotKey(_clampSlot(index)));
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  Future<bool> writeActiveRaw(String json) async {
    final prefs = await _prefs;
    await _prepare(prefs);
    final slotOk = await prefs.setString(_slotKey(_active), json);
    final mirrorOk = await prefs.setString(_saveKey, json);
    if (!slotOk || !mirrorOk) return false;
    await prefs.reload();
    return prefs.getString(_slotKey(_active)) == json &&
        prefs.getString(_saveKey) == json;
  }

  @override
  Future<String?> loadExtra(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  Future<bool> writeExtra(String key, String? json) async {
    final prefs = await _prefs;
    if (json == null || json.isEmpty) {
      final removed = await prefs.remove(key);
      if (!removed) return false;
      await prefs.reload();
      return prefs.getString(key) == null;
    }
    final wrote = await prefs.setString(key, json);
    if (!wrote) return false;
    await prefs.reload();
    return prefs.getString(key) == json;
  }

  @override
  Future<void> reloadDurable() async {
    final prefs = await _prefs;
    await prefs.reload();
    await _prepare(prefs);
  }
}

class InMemoryGameStorage implements GameStorage {
  InMemoryGameStorage([GameState? state]) {
    if (state != null) {
      _slots[0] = state;
      _activeRaw = GameLogic.exportSaveJson(state);
      _slotRaw[0] = _activeRaw;
    }
  }

  final List<GameState?> _slots = List<GameState?>.filled(
    GameStorage.slotCount,
    null,
  );
  final List<String?> _slotRaw = List<String?>.filled(
    GameStorage.slotCount,
    null,
  );
  int _active = 0;
  String? _activeRaw;
  final Map<String, String> _extras = <String, String>{};

  /// Test seam. The next raw or active write waits on this, once.
  Future<void>? pauseBeforeNextWrite;

  /// Test seam. The next active-slot write fails and does not change bytes.
  bool failNextActiveWrite = false;

  /// In-process test seam. The next [save] throws before any byte changes.
  /// This is not an operating-system kill.
  bool throwNextActiveWrite = false;

  /// Test seam. After this many successful [save] calls, later saves return
  /// false and do not change bytes. Armed by [armFailAfterSuccessfulSaves].
  int? failAfterSuccessfulSaves;

  int _savesSinceArm = 0;

  void armFailAfterSuccessfulSaves(int successes) {
    failAfterSuccessfulSaves = successes;
    _savesSinceArm = 0;
  }

  /// Test seam. Plants active bytes without parsing. A malformed plant
  /// leaves the slot unreadable so recovery can fail closed.
  void debugPlantActiveRaw(String raw) {
    _activeRaw = raw;
    _slotRaw[_active] = raw;
    _slots[_active] = GameLogic.importSaveJson(raw);
    if (_diskSplit) _disk['\u0000active'] = raw;
  }

  /// Test seam. The next N side-file writes fail and do not change bytes.
  /// This counts attempts from now, not the Nth successful write.
  int failNextExtraWrites = 0;

  /// Test seam. When this returns true the side-file write fails once.
  bool Function(String key, String? value)? failExtraWhen;

  /// Test seam. 1-based. That side-file attempt returns false and does not
  /// change bytes. An in-process fault, not an operating-system kill.
  int? failNthExtraWrite;

  /// Test seam. 1-based. That side-file attempt throws before the bytes change.
  /// An in-process fault, not an operating-system kill.
  int? throwBeforeNthExtraWrite;

  /// Test seam. 1-based. That side-file attempt lands, then throws.
  /// An in-process fault, not an operating-system kill.
  int? throwAfterNthExtraWrite;

  int _extraWriteOrdinal = 0;

  /// Arms one simulated side-file cut and starts the count at the next write.
  /// At most one of [failAt], [throwBefore], and [throwAfter] should be set.
  void armExtraWriteCut({int? failAt, int? throwBefore, int? throwAfter}) {
    _extraWriteOrdinal = 0;
    failNthExtraWrite = failAt;
    throwBeforeNthExtraWrite = throwBefore;
    throwAfterNthExtraWrite = throwAfter;
  }

  /// Drops a cut armed by [armExtraWriteCut] so the next write is honest.
  void clearExtraWriteCut() {
    failNthExtraWrite = null;
    throwBeforeNthExtraWrite = null;
    throwAfterNthExtraWrite = null;
  }

  /// Test seam. A failed write updates the cache and leaves durable bytes.
  /// Models shared_preferences, which updates its map before the platform
  /// returns. This is a simulation of that cache, not a device.
  bool cacheAheadOnFailedWrite = false;

  /// Test seam. The slot bytes land and the legacy mirror does not.
  /// [writeActiveRaw] returns false. A durable reload still sees the slot.
  bool failNextMirrorWrite = false;

  /// Test seam. Durable active bytes land, then this throws
  /// [SimulatedSaveKill]. Not a real process kill. [bytesAtKill] keeps the
  /// durable map from the moment of the throw, before recovery continues
  /// in this process.
  bool killAfterNextActiveDurableWrite = false;

  /// Durable bytes at the simulated kill, if one was thrown.
  Map<String, String>? bytesAtKill;

  /// Test seam. The next N [reloadDurable] calls throw after the bytes
  /// have already landed. An in-process failure, not a process kill.
  int reloadThrowsRemaining = 0;

  /// Test seam. This many reloads succeed before [reloadThrowsRemaining]
  /// starts. A swap reloads before cleanup; the throw has to land after
  /// the parties are already in place.
  int skipReloadsBeforeThrow = 0;

  /// Test seam. Deleting this extra key succeeds, then throws.
  /// Models an interrupted cleanup cut.
  String? throwAfterDeletingKey;

  /// Test seam. Set when a write is entered, including one that then waits.
  bool writeEntered = false;

  final Map<String, String> _disk = <String, String>{};
  bool _diskSplit = false;

  void _captureDisk() {
    _disk
      ..clear()
      ..addAll(_extras);
    if (_activeRaw != null) _disk['\u0000active'] = _activeRaw!;
  }

  /// Bytes that would survive a process death. The cache is not included
  /// once a failed write has split it from this map.
  Map<String, String> durableBytes() {
    if (_diskSplit) return Map<String, String>.from(_disk);
    final out = Map<String, String>.from(_extras);
    if (_activeRaw != null) out['\u0000active'] = _activeRaw!;
    return out;
  }

  /// Loads [bytes] from [durableBytes] as a new process would.
  void restoreDurableBytes(Map<String, String> bytes) {
    _diskSplit = false;
    _disk.clear();
    _extras
      ..clear()
      ..addAll(bytes)
      ..remove('\u0000active');
    _activeRaw = bytes['\u0000active'];
    _slotRaw[_active] = _activeRaw;
    final raw = _activeRaw;
    _slots[_active] = raw == null ? null : GameLogic.importSaveJson(raw);
  }

  Future<void> _awaitPause() async {
    writeEntered = true;
    final pause = pauseBeforeNextWrite;
    if (pause == null) return;
    pauseBeforeNextWrite = null;
    await pause;
  }

  int _clampSlot(int index) => index.clamp(0, GameStorage.slotCount - 1);

  @override
  int get activeSlotIndex => _active;

  @override
  Future<GameState?> load() async => _slots[_active];

  @override
  Future<GameState?> loadSlot(int index) async => _slots[_clampSlot(index)];

  @override
  Future<bool> save(GameState state) async {
    await _awaitPause();
    if (throwNextActiveWrite) {
      throwNextActiveWrite = false;
      throw StateError('simulated active write failure');
    }
    if (failNextActiveWrite) {
      failNextActiveWrite = false;
      return false;
    }
    if (failAfterSuccessfulSaves != null &&
        _savesSinceArm >= failAfterSuccessfulSaves!) {
      return false;
    }
    _slots[_active] = state;
    _activeRaw = GameLogic.exportSaveJson(state);
    _slotRaw[_active] = _activeRaw;
    if (_diskSplit && _activeRaw != null) _disk['\u0000active'] = _activeRaw!;
    if (failAfterSuccessfulSaves != null) _savesSinceArm++;
    return true;
  }

  @override
  Future<bool> hasSave() async => _slots[_active] != null;

  @override
  Future<void> clear() async {
    _slots[_active] = null;
    _activeRaw = null;
    _slotRaw[_active] = null;
  }

  @override
  Future<void> clearSlot(int index) async {
    final slot = _clampSlot(index);
    _slots[slot] = null;
    _slotRaw[slot] = null;
    if (slot == _active) _activeRaw = null;
  }

  @override
  Future<void> setActiveSlot(int index) async {
    _active = _clampSlot(index);
    _activeRaw = _slotRaw[_active];
  }

  @override
  Future<List<SaveSlotSummary>> listSlots() async => [
    for (var i = 0; i < GameStorage.slotCount; i++)
      SaveSlotSummary.fromState(i, _slots[i]),
  ];

  @override
  Future<bool> keepDisplacedSave(String json) => writeExtra(
    GameStorage.displacedKeyFor(_active),
    json.isEmpty ? null : json,
  );

  @override
  Future<String?> loadDisplacedSave() =>
      loadExtra(GameStorage.displacedKeyFor(_active));

  @override
  Future<String?> loadActiveRaw() async => _activeRaw;

  @override
  Future<String?> loadSlotRaw(int index) async {
    return _slotRaw[_clampSlot(index)];
  }

  @override
  Future<void> reloadDurable() async {
    if (skipReloadsBeforeThrow > 0) {
      skipReloadsBeforeThrow--;
    } else if (reloadThrowsRemaining > 0) {
      reloadThrowsRemaining--;
      throw StateError('simulated reload failure');
    }
    if (!_diskSplit) return;
    _activeRaw = _disk['\u0000active'];
    _slotRaw[_active] = _activeRaw;
    _extras
      ..clear()
      ..addAll(_disk)
      ..remove('\u0000active');
    final raw = _activeRaw;
    _slots[_active] = raw == null ? null : GameLogic.importSaveJson(raw);
  }

  void _splitBeforeLie() {
    if (_diskSplit) return;
    _captureDisk();
    _diskSplit = true;
  }

  @override
  Future<bool> writeActiveRaw(String json) async {
    await _awaitPause();
    if (failNextActiveWrite) {
      failNextActiveWrite = false;
      if (cacheAheadOnFailedWrite) {
        _splitBeforeLie();
        _activeRaw = json;
        final parsed = GameLogic.importSaveJson(json);
        if (parsed != null) _slots[_active] = parsed;
      }
      return false;
    }
    final parsed = GameLogic.importSaveJson(json);
    if (parsed == null) return false;
    _activeRaw = json;
    _slotRaw[_active] = json;
    _slots[_active] = parsed;
    if (_diskSplit) _disk['\u0000active'] = json;
    if (killAfterNextActiveDurableWrite) {
      killAfterNextActiveDurableWrite = false;
      if (!_diskSplit) {
        _captureDisk();
        _diskSplit = true;
      }
      _disk['\u0000active'] = json;
      bytesAtKill = Map<String, String>.from(_disk);
      throw const SimulatedSaveKill();
    }
    if (failNextMirrorWrite) {
      failNextMirrorWrite = false;
      return false;
    }
    return true;
  }

  @override
  Future<String?> loadExtra(String key) async {
    final raw = _extras[key];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  @override
  Future<bool> writeExtra(String key, String? json) async {
    await _awaitPause();
    _extraWriteOrdinal++;
    final ordinal = _extraWriteOrdinal;
    if (throwBeforeNthExtraWrite != null &&
        ordinal == throwBeforeNthExtraWrite) {
      throwBeforeNthExtraWrite = null;
      throw StateError('simulated extra-write cut before bytes');
    }
    if (failNthExtraWrite != null && ordinal == failNthExtraWrite) {
      failNthExtraWrite = null;
      return false;
    }
    final failWhen = failExtraWhen;
    final targeted = failWhen != null && failWhen(key, json);
    if (failNextExtraWrites > 0 || targeted) {
      if (failNextExtraWrites > 0) failNextExtraWrites--;
      if (cacheAheadOnFailedWrite) {
        _splitBeforeLie();
        if (json == null || json.isEmpty) {
          _extras.remove(key);
        } else {
          _extras[key] = json;
        }
      }
      return false;
    }
    if (json == null || json.isEmpty) {
      _extras.remove(key);
      if (_diskSplit) _disk.remove(key);
      if (throwAfterDeletingKey == key) {
        throwAfterDeletingKey = null;
        throw StateError('simulated cleanup cut');
      }
      _throwIfNthExtraWriteLanded(ordinal);
      return true;
    }
    _extras[key] = json;
    if (_diskSplit) _disk[key] = json;
    _throwIfNthExtraWriteLanded(ordinal);
    return true;
  }

  void _throwIfNthExtraWriteLanded(int ordinal) {
    if (throwAfterNthExtraWrite == null || ordinal != throwAfterNthExtraWrite) {
      return;
    }
    throwAfterNthExtraWrite = null;
    throw StateError('simulated extra-write cut after bytes');
  }
}
