import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_assets.dart';
import 'combat_feel.dart';

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
  static final Map<String, List<AudioSource>> _sfxVariants =
      <String, List<AudioSource>>{};
  static AudioSource? _hubAmb;
  static AudioSource? _dungeonAmb;
  static AudioSource? _hubMusic;
  static AudioSource? _dungeonMusic;
  static SoundHandle? _ambienceHandle;
  static SoundHandle? _musicHandle;
  static AmbienceKind _ambience = AmbienceKind.none;
  static bool _backgroundPaused = false;
  static final Map<String, DateTime> _lastPlayAt = <String, DateTime>{};
  static final Map<_CombatFamily, DateTime> _lastFamilyAt =
      <_CombatFamily, DateTime>{};
  static final List<DateTime> _combatWindowAt = <DateTime>[];
  static DateTime? _lastLootAt;
  static DateTime? _lastUnlockAt;
  static DateTime? _lastUiAt;
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
  static final math.Random _rng = math.Random();

  /// Per-id gain multiplier on top of [sfxVolume].
  static const Map<String, double> _idGain = <String, double>{
    'ui': 0.75,
    'loot': 0.80,
    'unlock': 0.72,
    'level': 0.78,
    'clear': 0.70,
    'boss': 0.75,
    'wipe': 0.78,
    'flask': 0.82,
    'crit': 0.88,
    'kill': 0.85,
    'hit': 0.90,
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
  }

  static bool get isReady => _ready;

  static Future<void> init() async {
    if (_ready || _initFailed) return;
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await soloud.init();
      }
      for (final entry in AudioAssets.sfxVariants.entries) {
        final loaded = <AudioSource>[];
        for (final path in entry.value) {
          loaded.add(await soloud.loadAsset(path));
        }
        _sfxVariants[entry.key] = loaded;
      }
      _hubAmb = await soloud.loadAsset(AudioAssets.hubAmbience);
      _dungeonAmb = await soloud.loadAsset(AudioAssets.dungeonAmbience);
      _hubMusic = await soloud.loadAsset(AudioAssets.hubMusic);
      _dungeonMusic = await soloud.loadAsset(AudioAssets.dungeonMusic);
      _ready = true;
    } catch (e, st) {
      _initFailed = true;
      debugPrint('GameAudio.init failed: $e\n$st');
    }
  }

  static void disposeEngine() {
    if (!_ready) return;
    try {
      stopAmbience();
      SoLoud.instance.deinit();
    } catch (_) {}
    _sfxVariants.clear();
    _hubAmb = null;
    _dungeonAmb = null;
    _hubMusic = null;
    _dungeonMusic = null;
    _ready = false;
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
    } else if (!_backgroundPaused) {
      unawaited(setAmbience(_ambience, forceRestart: true));
    }
  }

  static void play(String id) {
    if (muted) return;
    final now = DateTime.now();

    if (id == 'ui') {
      final last = _lastUiAt ?? _epoch;
      if (now.difference(last) < uiMinGap) return;
      _lastUiAt = now;
    } else if (id == 'loot') {
      final last = _lastLootAt ?? _epoch;
      if (now.difference(last) < lootMinGap) return;
      _lastLootAt = now;
    } else if (id == 'unlock') {
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
    _playLayer(id, volumeMul: 1.0, pan: 0.0, speed: 1.0);
    if (id == 'wipe' || id == 'boss' || id == 'clear') {
      _duckBackgroundBriefly();
    }
  }

  /// Layered combat hit: optional swish → impact → soft material chirp.
  static void playCombatHit(CombatFeelHit hit) {
    if (muted) return;
    final now = DateTime.now();
    final id = hit.impactId;
    if (!_admitCombatFeel(id, now)) {
      if (id.startsWith('hit') || id.startsWith('spell_')) {
        _hapticFor('hit');
      }
      return;
    }

    debugPlayCount++;
    _hapticFor(id);

    final distGain = CombatFeel.distanceGain(hit.distance);
    final pan = hit.panBias.clamp(-0.55, 0.55);
    final volMul = (0.75 + _rng.nextDouble() * 0.25) * distGain;
    final heavyMul = hit.heavy ? 1.12 : 1.0;
    final pitch = _pitchFor(id) * (hit.heavy ? 0.94 : 1.0);
    final isSpell = id.startsWith('spell_');

    if (hit.withSwish && !isSpell) {
      _playLayer(
        CombatFeel.swishIdFor(id),
        volumeMul: volMul * 0.85,
        pan: pan,
        speed: pitch,
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
        speed: pitch,
      );
      _playLayer(
        CombatFeel.materialSfxId(hit.material),
        volumeMul: volMul * 0.7,
        pan: pan * 0.8,
        speed: pitch,
      );
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
    required double speed,
  }) {
    if (!_ready) return;
    final variants = _sfxVariants[id];
    if (variants == null || variants.isEmpty) return;
    try {
      final source = variants[_rng.nextInt(variants.length)];
      final gain = _idGain[id] ?? 1.0;
      final soloud = SoLoud.instance;
      final handle = soloud.play(
        source,
        volume: (sfxVolume * gain * volumeMul).clamp(0.0, 1.0),
        pan: pan.clamp(-1.0, 1.0),
        paused: speed != 1.0,
      );
      if (speed != 1.0) {
        soloud.setRelativePlaySpeed(handle, speed.clamp(0.85, 1.15));
        soloud.setPause(handle, false);
      }
    } catch (_) {}
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

    _combatWindowAt.removeWhere(
      (t) => now.difference(t) >= combatWindow,
    );
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

  static double _pitchFor(String id) {
    final family = _familyFor(id);
    final spread = switch (family) {
      _CombatFamily.bow => 0.08,
      _CombatFamily.spell => 0.06,
      _CombatFamily.melee => 0.05,
      _CombatFamily.priority => 0.04,
    };
    return (1.0 + (_rng.nextDouble() * 2 - 1) * spread).clamp(0.88, 1.12);
  }

  static Future<void> setAmbience(
    AmbienceKind kind, {
    bool forceRestart = false,
  }) async {
    // Music may be intentionally off (volume 0 → no handle). That must not
    // force a restart of the ambience loop on every UI state sync.
    final musicOk =
        _musicHandle != null || musicVolume <= 0.01 || kind == AmbienceKind.none;
    if (!forceRestart &&
        kind == _ambience &&
        _ambienceHandle != null &&
        musicOk) {
      return;
    }
    _ambience = kind;
    if (!_ready || muted || _backgroundPaused) {
      stopAmbience();
      return;
    }
    stopAmbience();
    debugBackgroundStartCount++;
    final ambSource = switch (kind) {
      AmbienceKind.hub => _hubAmb,
      AmbienceKind.dungeon => _dungeonAmb,
      AmbienceKind.none => null,
    };
    final musicSource = switch (kind) {
      AmbienceKind.hub => _hubMusic,
      AmbienceKind.dungeon => _dungeonMusic,
      AmbienceKind.none => null,
    };
    try {
      final soloud = SoLoud.instance;
      if (ambSource != null) {
        _ambienceHandle = soloud.play(
          ambSource,
          volume: _effectiveAmbienceVolume(),
          looping: true,
        );
      }
      if (musicSource != null && musicVolume > 0.01) {
        _musicHandle = soloud.play(
          musicSource,
          volume: _effectiveMusicVolume(),
          looping: true,
        );
      }
    } catch (_) {
      _ambienceHandle = null;
      _musicHandle = null;
    }
  }

  static void stopAmbience() {
    final amb = _ambienceHandle;
    final mus = _musicHandle;
    _ambienceHandle = null;
    _musicHandle = null;
    if (!_ready) return;
    try {
      final soloud = SoLoud.instance;
      if (amb != null) soloud.stop(amb);
      if (mus != null) soloud.stop(mus);
    } catch (_) {}
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
    } catch (_) {}
  }

  static void _refreshMusicVolume() {
    final h = _musicHandle;
    if (h == null || !_ready) return;
    try {
      SoLoud.instance.setVolume(h, _effectiveMusicVolume());
    } catch (_) {}
    if (musicVolume <= 0.01 && h != null) {
      // Volume cycled to Off — stop the music layer only.
      try {
        SoLoud.instance.stop(h);
      } catch (_) {}
      _musicHandle = null;
    } else if (h == null &&
        musicVolume > 0.01 &&
        _ambience != AmbienceKind.none &&
        !muted &&
        !_backgroundPaused) {
      unawaited(setAmbience(_ambience, forceRestart: true));
    }
  }

  static double _effectiveAmbienceVolume() =>
      muted ? 0.0 : ambienceVolume.clamp(0.0, 1.0);

  static double _effectiveMusicVolume() =>
      muted ? 0.0 : musicVolume.clamp(0.0, 1.0);

  static void _duckBackgroundBriefly() {
    final amb = _ambienceHandle;
    final mus = _musicHandle;
    if (!_ready || muted) return;
    if (amb == null && mus == null) return;
    try {
      final soloud = SoLoud.instance;
      final ambBase = _effectiveAmbienceVolume();
      final musBase = _effectiveMusicVolume();
      if (amb != null) soloud.setVolume(amb, ambBase * 0.35);
      if (mus != null) soloud.setVolume(mus, musBase * 0.35);
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (muted) return;
        try {
          if (amb != null && _ambienceHandle == amb) {
            soloud.setVolume(amb, _effectiveAmbienceVolume());
          }
          if (mus != null && _musicHandle == mus) {
            soloud.setVolume(mus, _effectiveMusicVolume());
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  static void _hapticFor(String id) {
    switch (id) {
      case 'hit':
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
      case 'wipe':
      case 'boss':
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
  static void loot() => play('loot');
  static void flask() => play('flask');
  static void levelUp() => play('level');
  static void wipe() => play('wipe');
  static void boss() => play('boss');
  static void clear() => play('clear');
  static void unlock() => play('unlock');
  static void ui() => play('ui');
}
