import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/loot.dart';
import 'audio_assets.dart';
import 'audio_variation_bank.dart';
import 'combat_feel.dart';
import 'music_score.dart';

enum AmbienceKind { none, hub, dungeon }

enum _CombatFamily { melee, bow, spell, priority }

/// Platform SFX/haptics + SoLoud backend. Director's audio port — lives in
/// core so [GameDirector] does not import ui/.
abstract final class GameAudio {
  static bool muted = false;
  static bool hapticsEnabled = true;

  /// Master SFX gain 0..1 (default 0.45).
  static double sfxVolume = 0.45;

  /// Ambience gain 0..1 (default 0.20).
  static double ambienceVolume = 0.20;

  /// Background music gain 0..1 (default 0.22).
  static double musicVolume = 0.22;

  /// Per play-id floor so the same weapon does not hammer.
  static const combatFeelMinGap = Duration(milliseconds: 750);

  /// Sliding window for total combat feel *events* (not layers).
  static const combatWindow = Duration(milliseconds: 200);
  static const combatWindowMax = 2;

  static const lootMinGap = Duration(milliseconds: 1200);
  static const unlockMinGap = Duration(seconds: 2);
  static const uiMinGap = Duration(milliseconds: 80);

  static bool _ready = false;
  static bool _initFailed = false;
  static final Map<String, AudioSource> _sourcesByPath =
      <String, AudioSource>{};
  static AudioSource? _hubAmb;
  static AudioSource? _hubMusic;
  static final Map<ZoneMood, AudioSource> _moodAmb = <ZoneMood, AudioSource>{};
  static final Map<ZoneMood, AudioSource> _moodMusic = <ZoneMood, AudioSource>{};
  static ZoneMood _audibleMood = ZoneMood.warm;
  static AudioSource? _bossMusic;
  static AudioSource? _resolveMusic;
  static AudioSource? _downMusic;
  static SoundHandle? _ambienceHandle;
  static SoundHandle? _musicHandle;
  static AmbienceKind _ambience = AmbienceKind.none;
  static bool _backgroundPaused = false;
  static final MusicScore _score = MusicScore();
  static MusicStem _playing = MusicStem.none;
  static Timer? _scoreTimer;
  static int _fadeGen = 0;
  static final Map<String, DateTime> _lastPlayAt = <String, DateTime>{};
  static final Map<_CombatFamily, DateTime> _lastFamilyAt =
      <_CombatFamily, DateTime>{};
  static final List<DateTime> _combatWindowAt = <DateTime>[];
  static DateTime? _lastLootAt;
  static DateTime? _lastUnlockAt;
  static DateTime? _lastUiAt;
  static final Map<String, DateTime> _lastCueAt = <String, DateTime>{};
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
  static final math.Random _rng = math.Random();

  /// Per-id gain multiplier on top of [sfxVolume].
  static const Map<String, double> _idGain = <String, double>{
    'ui': 0.75,
    'ui_tap': 0.70,
    'ui_tab': 0.68,
    'ui_confirm': 0.74,
    'ui_back': 0.66,
    'ui_deny': 0.70,
    'loot': 0.80,
    'loot_rare': 0.84,
    'loot_epic': 0.88,
    'loot_legendary': 0.92,
    'gold': 0.78,
    'equip': 0.76,
    'forge_up': 0.80,
    'achievement': 0.82,
    'ascend': 0.84,
    'enemy_hit': 0.62,
    'hero_down': 0.80,
    'heal': 0.70,
    'shield': 0.66,
    'boss_tell': 0.78,
    'enrage': 0.82,
    'enemy_die_flesh': 0.70,
    'enemy_die_bone': 0.70,
    'enemy_die_stone': 0.72,
    'unlock': 0.72,
    'level': 0.78,
    'clear': 0.70,
    'boss': 0.75,
    'wipe': 0.78,
    'flask': 0.82,
    'crit': 0.88,
    'kill': 0.85,
    'hit_blade': 0.88,
    'hit_axe': 0.90,
    'hit_blunt': 0.90,
    'hit_dagger': 0.85,
    'hit_fist': 0.86,
    'hit_bow': 0.84,
    'spell_fire': 0.86,
    'spell_frost': 0.86,
    'spell_holy': 0.84,
    'spell_shadow': 0.86,
    'spell_arcane': 0.86,
    'spell_nature': 0.86,
    'spell_lightning': 0.88,
    'spell_demon': 0.88,
    'spell_poison': 0.84,
    'swish_melee': 0.55,
    'swish_bow': 0.50,
    'mat_flesh': 0.45,
    'mat_bone': 0.42,
    'mat_wet': 0.40,
    'mat_stone': 0.48,
  };

  /// Test hook: counts play attempts that passed mute/rate-limit gates.
  @visibleForTesting
  static int debugPlayCount = 0;

  /// Test hook: how many times ambience/music were actually (re)started.
  @visibleForTesting
  static int debugBackgroundStartCount = 0;

  @visibleForTesting
  static void debugReset() {
    debugPlayCount = 0;
    debugBackgroundStartCount = 0;
    _lastPlayAt.clear();
    _lastFamilyAt.clear();
    _combatWindowAt.clear();
    _lastLootAt = null;
    _lastUnlockAt = null;
    _lastUiAt = null;
    _lastCueAt.clear();
    _audibleMood = ZoneMood.warm;
    _sfxReady = false;
    _warmFuture = null;
    _scoreTimer?.cancel();
    _scoreTimer = null;
    _score.reset();
    _playing = MusicStem.none;
    _fadeGen++;
  }

  static bool get isReady => _ready;

  /// True once SFX banks + dungeon bed are loaded (may lag [isReady]).
  static bool get sfxReady => _sfxReady;

  static bool _sfxReady = false;
  static Future<void>? _warmFuture;

  /// Boots SoLoud + hub ambience/music only — keeps cold start off the main
  /// hitch. Call [warmRemainingAssets] (unawaited) right after.
  static Future<void> init() async {
    if (_ready || _initFailed) return;
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await soloud.init();
      }
      _hubAmb = await soloud.loadAsset(AudioAssets.hubAmbience);
      _hubMusic = await soloud.loadAsset(AudioAssets.hubMusic);
      _ready = true;
    } catch (e, st) {
      _initFailed = true;
      debugPrint('GameAudio.init failed: $e\n$st');
    }
  }

  /// Loads SFX banks + dungeon bed off the critical path. Yields between
  /// assets so the first hub frame can paint.
  static Future<void> warmRemainingAssets() {
    return _warmFuture ??= _warmRemainingAssets();
  }

  static Future<void> _warmRemainingAssets() async {
    if (!_ready || _initFailed) return;
    try {
      final soloud = SoLoud.instance;
      for (final bank in AudioVariationCatalog.banks.values) {
        for (final v in bank.variations) {
          if (_sourcesByPath.containsKey(v.path)) continue;
          _sourcesByPath[v.path] = await soloud.loadAsset(v.path);
          await Future<void>.delayed(Duration.zero);
        }
      }
      for (final mood in ZoneMood.values) {
        await _ensureMood(mood);
        await Future<void>.delayed(Duration.zero);
      }
      _bossMusic ??= await soloud.loadAsset(AudioAssets.bossMusic);
      _resolveMusic ??= await soloud.loadAsset(AudioAssets.resolveMusic);
      _downMusic ??= await soloud.loadAsset(AudioAssets.downMusic);
      _sfxReady = true;
    } catch (e, st) {
      debugPrint('GameAudio.warmRemainingAssets failed: $e\n$st');
    }
  }

  /// Ensures dungeon bed is present before [setAmbience] (hub bed is in [init]).
  static Future<void> _ensureBedFor(AmbienceKind kind) async {
    if (!_ready || _initFailed) return;
    if (kind != AmbienceKind.dungeon) return;
    await _ensureMood(_score.mood);
  }

  static Future<void> _ensureMood(ZoneMood mood) async {
    if (!_ready || _initFailed) return;
    if (_moodAmb.containsKey(mood) && _moodMusic.containsKey(mood)) return;
    try {
      final soloud = SoLoud.instance;
      _moodAmb[mood] ??= await soloud.loadAsset(AudioAssets.dungeonAmbience(mood));
      _moodMusic[mood] ??= await soloud.loadAsset(AudioAssets.dungeonMusic(mood));
    } catch (e, st) {
      debugPrint('GameAudio mood load failed: $e\n$st');
    }
  }

  static void disposeEngine() {
    if (!_ready) return;
    try {
      stopAmbience();
      SoLoud.instance.deinit();
    } catch (e, st) {
      debugPrint('GameAudio disposeEngine failed: $e\n$st');
    }
    _sourcesByPath.clear();
    _hubAmb = null;
    _hubMusic = null;
    _moodAmb.clear();
    _moodMusic.clear();
    _audibleMood = ZoneMood.warm;
    _bossMusic = null;
    _resolveMusic = null;
    _downMusic = null;
    _scoreTimer?.cancel();
    _scoreTimer = null;
    _score.reset();
    _playing = MusicStem.none;
    _ready = false;
    _sfxReady = false;
    _warmFuture = null;
  }

  static void applyVolumes({double? sfx, double? ambience, double? music}) {
    if (sfx != null) sfxVolume = sfx.clamp(0.0, 1.0);
    if (ambience != null) {
      ambienceVolume = ambience.clamp(0.0, 1.0);
      _refreshAmbienceVolume();
    }
    if (music != null) {
      musicVolume = music.clamp(0.0, 1.0);
      _refreshMusicVolume();
    }
  }

  static void setMuted(bool value) {
    if (muted == value) return;
    muted = value;
    if (muted) {
      stopAmbience();
    }
    // Unmute playback is the caller's [setAmbience] so the place and boss
    // cue stay in one path (settings always follows this with a sync).
  }

  static void play(String id) {
    if (muted) return;
    if (id == 'ui') id = 'ui_tap';
    final now = DateTime.now();

    if (id.startsWith('ui_')) {
      final last = _lastUiAt ?? _epoch;
      if (now.difference(last) < uiMinGap) return;
      _lastUiAt = now;
    } else if (AudioAssets.lootIds.contains(id)) {
      final last = _lastLootAt ?? _epoch;
      if (now.difference(last) < lootMinGap) return;
      _lastLootAt = now;
    } else if (id == 'unlock' || id == 'achievement' || id == 'ascend') {
      final last = _lastUnlockAt ?? _epoch;
      if (now.difference(last) < unlockMinGap) return;
      _lastUnlockAt = now;
    }

    if (AudioAssets.combatFeelIds.contains(id)) {
      if (id.startsWith('hit') || id.startsWith('spell_')) {
        playCombatHit(CombatFeelHit(impactId: id));
        return;
      }
      if (!_admitCombatFeel(id, now)) return;
    }

    debugPlayCount++;
    _hapticFor(id);
    _playLayer(id, volumeMul: 1.0, pan: 0.0, speedMul: 1.0);
    if (id == 'wipe' ||
        id == 'boss' ||
        id == 'clear' ||
        id == 'loot_legendary' ||
        id == 'ascend') {
      _duckBackgroundBriefly();
    }
  }

  /// Hero hurt, tells, and deaths. Separate from the weapon hammer.
  static void playCue(String id) {
    if (muted || !AudioAssets.bodyCueIds.contains(id)) return;
    final now = DateTime.now();
    final gap = switch (id) {
      'enemy_hit' => const Duration(milliseconds: 420),
      'heal' || 'shield' => const Duration(milliseconds: 650),
      'boss_tell' || 'enrage' => const Duration(milliseconds: 900),
      _ => const Duration(milliseconds: 280),
    };
    final last = _lastCueAt[id] ?? _epoch;
    if (now.difference(last) < gap) return;
    _lastCueAt[id] = now;
    debugPlayCount++;
    _hapticFor(id);
    _playLayer(id, volumeMul: 1.0, pan: 0.0, speedMul: 1.0);
  }

  /// Layered combat hit: optional swish → impact → soft material chirp.
  static void playCombatHit(CombatFeelHit hit) {
    if (muted) return;
    final now = DateTime.now();
    final id = hit.impactId;
    if (!_admitCombatFeel(id, now)) {
      if (id.startsWith('hit') || id.startsWith('spell_')) {
        _hapticFor('hit_blade');
      }
      return;
    }

    debugPlayCount++;
    _hapticFor(id);

    final distGain = CombatFeel.distanceGain(hit.distance);
    final pan = hit.panBias.clamp(-0.55, 0.55);
    final volMul = (0.75 + _rng.nextDouble() * 0.25) * distGain;
    final heavyMul = hit.heavy ? 1.12 : 1.0;
    final speedMul = hit.heavy ? 0.94 : 1.0;
    final isSpell = id.startsWith('spell_');

    if (hit.withSwish && !isSpell) {
      _playLayer(
        CombatFeel.swishIdFor(id),
        volumeMul: volMul * 0.85,
        pan: pan,
        speedMul: speedMul,
        heavy: hit.heavy,
      );
    }

    final impactDelay = hit.withSwish && !isSpell
        ? const Duration(milliseconds: 55)
        : Duration.zero;
    void playImpactAndMat() {
      if (muted) return;
      _playLayer(
        id,
        volumeMul: volMul * heavyMul,
        pan: pan,
        speedMul: speedMul,
        heavy: hit.heavy,
      );
      // Material chirps are physical-only — spells keep school identity.
      if (!isSpell) {
        _playLayer(
          CombatFeel.materialSfxId(hit.material),
          volumeMul: volMul * 0.7,
          pan: pan * 0.8,
          speedMul: speedMul,
          heavy: false,
        );
      }
    }

    if (impactDelay == Duration.zero) {
      playImpactAndMat();
    } else {
      Future<void>.delayed(impactDelay, playImpactAndMat);
    }
  }

  static void _playLayer(
    String id, {
    required double volumeMul,
    required double pan,
    required double speedMul,
    bool heavy = false,
  }) {
    if (!_ready) return;
    final bank = AudioVariationCatalog.banks[id];
    if (bank == null || bank.isEmpty) return;
    try {
      final variation = bank.pick(_rng, heavy: heavy);
      final source = _sourcesByPath[variation.path];
      if (source == null) return;
      final pitch = (variation.rollPitch(_rng) * speedMul).clamp(0.85, 1.15);
      final layerVol = (variation.rollVolume(_rng) * volumeMul).clamp(0.0, 1.5);
      final gain = _idGain[id] ?? 1.0;
      final soloud = SoLoud.instance;
      final handle = soloud.play(
        source,
        volume: (sfxVolume * gain * layerVol).clamp(0.0, 1.0),
        pan: pan.clamp(-1.0, 1.0),
        paused: pitch != 1.0,
      );
      if (pitch != 1.0) {
        soloud.setRelativePlaySpeed(handle, pitch);
        soloud.setPause(handle, false);
      }
    } catch (e, st) {
      debugPrint('GameAudio play failed: $e\n$st');
    }
  }

  static bool _admitCombatFeel(String id, DateTime now) {
    final family = _familyFor(id);
    final familyGap = switch (family) {
      _CombatFamily.melee => const Duration(milliseconds: 140),
      _CombatFamily.bow => const Duration(milliseconds: 160),
      _CombatFamily.spell => const Duration(milliseconds: 150),
      _CombatFamily.priority => const Duration(milliseconds: 280),
    };
    final lastFamily = _lastFamilyAt[family] ?? _epoch;
    if (now.difference(lastFamily) < familyGap) return false;

    final lastId = _lastPlayAt[id] ?? _epoch;
    if (now.difference(lastId) < combatFeelMinGap) return false;

    _combatWindowAt.removeWhere((t) => now.difference(t) >= combatWindow);
    final priority = AudioAssets.priorityFeelIds.contains(id);
    if (!priority && _combatWindowAt.length >= combatWindowMax) {
      return false;
    }

    _lastPlayAt[id] = now;
    _lastFamilyAt[family] = now;
    _combatWindowAt.add(now);
    return true;
  }

  static _CombatFamily _familyFor(String id) {
    if (AudioAssets.priorityFeelIds.contains(id)) {
      return _CombatFamily.priority;
    }
    if (AudioAssets.bowFeelIds.contains(id)) return _CombatFamily.bow;
    if (AudioAssets.spellFeelIds.contains(id)) return _CombatFamily.spell;
    return _CombatFamily.melee;
  }

  static Future<void> setAmbience(
    AmbienceKind kind, {
    bool forceRestart = false,
    bool? bossFight,
    int floor = 0,
    String? dungeonId,
  }) async {
    final now = DateTime.now();
    final placeChanged = _score.setPlace(_placeOf(kind), now);
    final moodChanged =
        dungeonId != null &&
        _score.setMood(AudioAssets.moodForDungeon(dungeonId));
    final bossChanged = bossFight != null && kind == AmbienceKind.dungeon
        ? _score.syncBoss(active: bossFight, floor: floor, now: now)
        : false;
    _ambience = kind;
    if (!_ready || muted || _backgroundPaused) {
      if (muted) stopAmbience();
      return;
    }
    _ensureScoreTimer();
    // Rest is a real state (no music handle). Do not treat that as a
    // failed start and restart the bed on every settings sync.
    final musicOk = _musicMatches();
    if (!forceRestart &&
        !placeChanged &&
        !bossChanged &&
        !moodChanged &&
        kind == _ambience &&
        _ambienceHandle != null &&
        musicOk) {
      return;
    }
    await _ensureBedFor(kind);
    if (forceRestart ||
        placeChanged ||
        moodChanged ||
        _ambienceHandle == null) {
      _restartAmbienceOnly();
    }
    if (forceRestart || placeChanged || bossChanged || moodChanged || !musicOk) {
      await _realizeMusic(
        restart: forceRestart || placeChanged || bossChanged || moodChanged,
      );
    }
  }

  /// Fight state, without going through a full ambience restart.
  static void syncBossFight({required bool active, required int floor}) {
    if (_score.syncBoss(active: active, floor: floor, now: DateTime.now())) {
      unawaited(_realizeMusic());
    }
  }

  /// Stairs opened. Short resolution, then quiet.
  static void noteFloorClear(int floor) {
    if (_score.noteClear(floor, DateTime.now())) {
      unawaited(_realizeMusic());
    }
  }

  /// Party wiped. Falling phrase, then a longer quiet.
  static void noteWipe() {
    if (_score.noteWipe(DateTime.now())) {
      unawaited(_realizeMusic());
    }
  }

  static MusicPlace _placeOf(AmbienceKind kind) => switch (kind) {
    AmbienceKind.hub => MusicPlace.hub,
    AmbienceKind.dungeon => MusicPlace.dungeon,
    AmbienceKind.none => MusicPlace.none,
  };

  static bool _musicMatches() {
    final stem = _score.stem;
    if (stem == MusicStem.none || musicVolume <= 0.01) {
      return _playing == MusicStem.none;
    }
    if (stem == MusicStem.dungeon && _audibleMood != _score.mood) return false;
    return _playing == stem && _musicHandle != null;
  }

  static void _ensureScoreTimer() {
    if (_scoreTimer != null) return;
    // Widget tests boot the app. A periodic timer left running fails the test.
    final binding = SchedulerBinding.instance.runtimeType.toString();
    if (binding.contains('Test')) return;
    _scoreTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_ready || _backgroundPaused) return;
      if (!_score.tick(DateTime.now())) return;
      if (muted) return;
      unawaited(_realizeMusic());
    });
  }

  static void _restartAmbienceOnly() {
    final amb = _ambienceHandle;
    _ambienceHandle = null;
    if (_ready && amb != null) {
      try {
        SoLoud.instance.stop(amb);
      } catch (e, st) {
        debugPrint('GameAudio ambience stop failed: $e\n$st');
      }
    }
    if (!_ready || muted || _backgroundPaused) return;
    final ambSource = switch (_ambience) {
      AmbienceKind.hub => _hubAmb,
      AmbienceKind.dungeon => _moodAmb[_score.mood],
      AmbienceKind.none => null,
    };
    if (ambSource == null) return;
    try {
      debugBackgroundStartCount++;
      _ambienceHandle = SoLoud.instance.play(
        ambSource,
        volume: _effectiveAmbienceVolume(),
        looping: true,
      );
    } catch (e, st) {
      _ambienceHandle = null;
      debugPrint('GameAudio ambience start failed: $e\n$st');
    }
  }

  static Future<void> _realizeMusic({bool restart = false}) async {
    if (!_ready || muted || _backgroundPaused) return;
    final stem = musicVolume <= 0.01 ? MusicStem.none : _score.stem;
    if (!restart &&
        _playing == stem &&
        (stem == MusicStem.none || _musicHandle != null)) {
      return;
    }
    final gen = ++_fadeGen;
    final previous = _musicHandle;
    _musicHandle = null;
    _playing = stem;
    final fade = _fadeFor(stem);
    _releaseHandle(previous, fade);
    if (stem == MusicStem.none) return;
    await _ensureStem(stem);
    if (gen != _fadeGen || muted || _backgroundPaused) return;
    final source = _sourceFor(stem);
    if (source == null) {
      _playing = MusicStem.none;
      return;
    }
    try {
      final handle = SoLoud.instance.play(
        source,
        volume: 0.001,
        looping: _loops(stem),
      );
      if (gen != _fadeGen) {
        _releaseHandle(handle, Duration.zero);
        return;
      }
      _musicHandle = handle;
      if (stem == MusicStem.dungeon) _audibleMood = _score.mood;
      SoLoud.instance.fadeVolume(handle, _musicGain(stem), fade);
    } catch (e, st) {
      _musicHandle = null;
      _playing = MusicStem.none;
      debugPrint('GameAudio music start failed: $e\n$st');
    }
  }

  static Future<void> _ensureStem(MusicStem stem) async {
    if (!_ready) return;
    try {
      final soloud = SoLoud.instance;
      switch (stem) {
        case MusicStem.hub:
          _hubMusic ??= await soloud.loadAsset(AudioAssets.hubMusic);
        case MusicStem.dungeon:
          await _ensureMood(_score.mood);
        case MusicStem.boss:
          _bossMusic ??= await soloud.loadAsset(AudioAssets.bossMusic);
        case MusicStem.resolve:
          _resolveMusic ??= await soloud.loadAsset(AudioAssets.resolveMusic);
        case MusicStem.down:
          _downMusic ??= await soloud.loadAsset(AudioAssets.downMusic);
        case MusicStem.none:
          break;
      }
    } catch (e, st) {
      debugPrint('GameAudio stem load failed: $e\n$st');
    }
  }

  static AudioSource? _sourceFor(MusicStem stem) => switch (stem) {
    MusicStem.hub => _hubMusic,
    MusicStem.dungeon => _moodMusic[_score.mood],
    MusicStem.boss => _bossMusic,
    MusicStem.resolve => _resolveMusic,
    MusicStem.down => _downMusic,
    MusicStem.none => null,
  };

  static bool _loops(MusicStem stem) =>
      stem == MusicStem.hub ||
      stem == MusicStem.dungeon ||
      stem == MusicStem.boss;

  static double _stemGain(MusicStem stem) => switch (stem) {
    MusicStem.boss => 1.08,
    MusicStem.resolve => 1.04,
    _ => 1.0,
  };

  static double _musicGain(MusicStem stem) =>
      (_effectiveMusicVolume() * _stemGain(stem)).clamp(0.0, 1.0);

  static Duration _fadeFor(MusicStem stem) => switch (stem) {
    MusicStem.boss => const Duration(milliseconds: 420),
    MusicStem.resolve || MusicStem.down => const Duration(milliseconds: 280),
    MusicStem.none => const Duration(milliseconds: 1600),
    _ => const Duration(milliseconds: 1100),
  };

  static void _releaseHandle(SoundHandle? handle, Duration fade) {
    if (handle == null || !_ready) return;
    try {
      if (fade == Duration.zero) {
        SoLoud.instance.stop(handle);
        return;
      }
      SoLoud.instance.fadeVolume(handle, 0, fade);
      Future<void>.delayed(fade, () {
        try {
          SoLoud.instance.stop(handle);
        } catch (_) {}
      });
    } catch (e, st) {
      debugPrint('GameAudio music release failed: $e\n$st');
    }
  }

  static void stopAmbience() {
    final amb = _ambienceHandle;
    final mus = _musicHandle;
    _ambienceHandle = null;
    _musicHandle = null;
    _playing = MusicStem.none;
    _fadeGen++;
    if (!_ready) return;
    try {
      final soloud = SoLoud.instance;
      if (amb != null) soloud.stop(amb);
      if (mus != null) soloud.stop(mus);
    } catch (e, st) {
      debugPrint('GameAudio stopAmbience failed: $e\n$st');
    }
  }

  /// App lifecycle: pause ambience + music when backgrounded.
  static void onAppPaused() {
    _backgroundPaused = true;
    _pauseBackgroundInternal();
  }

  static void onAppResumed() {
    _backgroundPaused = false;
    if (!muted) {
      unawaited(setAmbience(_ambience, forceRestart: true));
    }
  }

  static void _pauseBackgroundInternal() {
    if (!_ready) return;
    try {
      final soloud = SoLoud.instance;
      final amb = _ambienceHandle;
      if (amb != null) soloud.setPause(amb, true);
      final mus = _musicHandle;
      if (mus != null) soloud.setPause(mus, true);
    } catch (_) {
      stopAmbience();
    }
  }

  static void _refreshAmbienceVolume() {
    final h = _ambienceHandle;
    if (h == null || !_ready) return;
    try {
      SoLoud.instance.setVolume(h, _effectiveAmbienceVolume());
    } catch (e, st) {
      debugPrint('GameAudio ambience volume failed: $e\n$st');
    }
  }

  static void _refreshMusicVolume() {
    if (!_ready) return;
    final h = _musicHandle;
    if (musicVolume <= 0.01) {
      if (h != null) {
        _releaseHandle(h, const Duration(milliseconds: 200));
        _musicHandle = null;
        _playing = MusicStem.none;
      }
      return;
    }
    if (h != null) {
      try {
        SoLoud.instance.setVolume(h, _musicGain(_playing));
      } catch (e, st) {
        debugPrint('GameAudio music volume failed: $e\n$st');
      }
      return;
    }
    if (_score.stem != MusicStem.none && !muted && !_backgroundPaused) {
      unawaited(_realizeMusic(restart: true));
    }
  }

  static double _effectiveAmbienceVolume() =>
      muted ? 0.0 : ambienceVolume.clamp(0.0, 1.0);

  static double _effectiveMusicVolume() =>
      muted ? 0.0 : musicVolume.clamp(0.0, 1.0);

  static void _duckBackgroundBriefly() {
    if (_playing == MusicStem.boss ||
        _playing == MusicStem.resolve ||
        _playing == MusicStem.down) {
      return;
    }
    final amb = _ambienceHandle;
    final mus = _musicHandle;
    if (!_ready || muted) return;
    if (amb == null && mus == null) return;
    try {
      final soloud = SoLoud.instance;
      final ambBase = _effectiveAmbienceVolume();
      if (amb != null) soloud.setVolume(amb, ambBase * 0.35);
      if (mus != null) soloud.setVolume(mus, _musicGain(_playing) * 0.35);
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (muted) return;
        try {
          if (amb != null && _ambienceHandle == amb) {
            soloud.setVolume(amb, _effectiveAmbienceVolume());
          }
          if (mus != null && _musicHandle == mus) {
            soloud.setVolume(mus, _musicGain(_playing));
          }
        } catch (e, st) {
          debugPrint('GameAudio duck restore failed: $e\n$st');
        }
      });
    } catch (e, st) {
      debugPrint('GameAudio duck failed: $e\n$st');
    }
  }

  static void _hapticFor(String id) {
    switch (id) {
      case 'hit_blade':
      case 'hit_axe':
      case 'hit_blunt':
      case 'hit_dagger':
      case 'hit_fist':
      case 'hit_bow':
      case 'spell_fire':
      case 'spell_frost':
      case 'spell_holy':
      case 'spell_shadow':
      case 'spell_arcane':
      case 'spell_nature':
      case 'spell_lightning':
      case 'spell_demon':
      case 'spell_poison':
        _haptic(HapticFeedback.selectionClick);
      case 'kill':
      case 'crit':
      case 'flask':
      case 'level':
      case 'clear':
        _haptic(HapticFeedback.mediumImpact);
      case 'loot':
      case 'unlock':
        _haptic(HapticFeedback.lightImpact);
      case 'enemy_hit':
      case 'shield':
      case 'heal':
        _haptic(HapticFeedback.selectionClick);
      case 'hero_down':
      case 'boss_tell':
      case 'enrage':
        _haptic(HapticFeedback.mediumImpact);
      case 'wipe':
      case 'boss':
      case 'ascend':
        _haptic(HapticFeedback.heavyImpact);
      default:
        break;
    }
  }

  static void _haptic(Future<void> Function() pulse) {
    if (!hapticsEnabled) return;
    pulse();
  }

  static void hit() => play('hit_blade');
  static void kill() => play('kill');
  static void crit() => play('crit');
  static void loot() => lootRarity(LootRarity.common);
  static void lootRarity(LootRarity rarity) =>
      play(AudioAssets.lootIdFor(rarity));
  static void gold() => play('gold');
  static void equip() => play('equip');
  static void forgeUp() => play('forge_up');
  static void achievement() => play('achievement');
  static void ascend() => play('ascend');
  static void flask() => play('flask');
  static void levelUp() => play('level');
  static void wipe() => play('wipe');
  static void boss() => play('boss');
  static void clear() => play('clear');
  static void unlock() => play('unlock');
  static void ui() => uiTap();
  static void uiTap() => play('ui_tap');
  static void uiTab() => play('ui_tab');
  static void uiConfirm() => play('ui_confirm');
  static void uiBack() => play('ui_back');
  static void uiDeny() => play('ui_deny');
}
