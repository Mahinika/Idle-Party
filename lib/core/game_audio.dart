import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_assets.dart';

enum AmbienceKind { none, hub, dungeon }

/// Platform SFX/haptics + SoLoud backend. Director's audio port — lives in
/// core so [GameDirector] does not import ui/.
abstract final class GameAudio {
  static bool muted = false;
  static bool hapticsEnabled = true;

  /// Master SFX gain 0..1 (default 0.7).
  static double sfxVolume = 0.7;

  /// Ambience gain 0..1 (default 0.25).
  static double ambienceVolume = 0.25;

  /// Background music gain 0..1 (default 0.4).
  static double musicVolume = 0.4;

  /// Per combat-feel clip floor so haste farms stay listenable.
  static const combatFeelMinGap = Duration(seconds: 3);

  static bool _ready = false;
  static bool _initFailed = false;
  static final Map<String, AudioSource> _sfx = <String, AudioSource>{};
  static AudioSource? _hubAmb;
  static AudioSource? _dungeonAmb;
  static AudioSource? _hubMusic;
  static AudioSource? _dungeonMusic;
  static SoundHandle? _ambienceHandle;
  static SoundHandle? _musicHandle;
  static AmbienceKind _ambience = AmbienceKind.none;
  static bool _backgroundPaused = false;
  static final Map<String, DateTime> _lastPlayAt = <String, DateTime>{};
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

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
  }

  static bool get isReady => _ready;

  static Future<void> init() async {
    if (_ready || _initFailed) return;
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await soloud.init();
      }
      for (final entry in AudioAssets.sfxById.entries) {
        _sfx[entry.key] = await soloud.loadAsset(entry.value);
      }
      // Extra loot layer (second coin tick).
      _sfx['loot_b'] = await soloud.loadAsset(AudioAssets.lootB);
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
    _sfx.clear();
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
    if (AudioAssets.combatFeelIds.contains(id)) {
      final now = DateTime.now();
      final last = _lastPlayAt[id] ?? _epoch;
      if (now.difference(last) < combatFeelMinGap) {
        // Keep light haptic for blocked combat hits so the phone still ticks.
        if (id.startsWith('hit') || id.startsWith('spell_')) {
          _hapticFor('hit');
        }
        return;
      }
      _lastPlayAt[id] = now;
    }

    debugPlayCount++;
    _hapticFor(id);

    if (!_ready) return;
    final source = _sfx[id];
    if (source == null) return;
    try {
      final soloud = SoLoud.instance;
      soloud.play(source, volume: sfxVolume);
      if (id == 'loot') {
        final b = _sfx['loot_b'];
        if (b != null) {
          Future<void>.delayed(const Duration(milliseconds: 40), () {
            if (muted || !_ready) return;
            try {
              soloud.play(b, volume: sfxVolume * 0.85);
            } catch (_) {}
          });
        }
      }
      if (id == 'wipe' || id == 'boss' || id == 'clear') {
        _duckBackgroundBriefly();
      }
    } catch (_) {}
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
