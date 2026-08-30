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

  static bool _ready = false;
  static bool _initFailed = false;
  static final Map<String, AudioSource> _sfx = <String, AudioSource>{};
  static AudioSource? _hubAmb;
  static AudioSource? _dungeonAmb;
  static SoundHandle? _ambienceHandle;
  static AmbienceKind _ambience = AmbienceKind.none;
  static bool _ambiencePaused = false;
  static DateTime _lastHitAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _hitMinGap = Duration(milliseconds: 90);

  /// Test hook: counts play attempts that passed mute/rate-limit gates.
  @visibleForTesting
  static int debugPlayCount = 0;

  @visibleForTesting
  static void debugReset() {
    debugPlayCount = 0;
    _lastHitAt = DateTime.fromMillisecondsSinceEpoch(0);
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
    _ready = false;
  }

  static void applyVolumes({double? sfx, double? ambience}) {
    if (sfx != null) sfxVolume = sfx.clamp(0.0, 1.0);
    if (ambience != null) {
      ambienceVolume = ambience.clamp(0.0, 1.0);
      _refreshAmbienceVolume();
    }
  }

  static void setMuted(bool value) {
    muted = value;
    if (muted) {
      stopAmbience();
    } else if (!_ambiencePaused) {
      unawaited(setAmbience(_ambience, forceRestart: true));
    }
  }

  static void play(String id) {
    if (muted) return;
    if (id == 'hit') {
      final now = DateTime.now();
      if (now.difference(_lastHitAt) < _hitMinGap) {
        _hapticFor(id);
        return;
      }
      _lastHitAt = now;
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
        _duckAmbienceBriefly();
      }
    } catch (_) {}
  }

  static Future<void> setAmbience(
    AmbienceKind kind, {
    bool forceRestart = false,
  }) async {
    if (!forceRestart && kind == _ambience && _ambienceHandle != null) {
      return;
    }
    _ambience = kind;
    if (!_ready || muted || _ambiencePaused) {
      stopAmbience();
      return;
    }
    stopAmbience();
    final source = switch (kind) {
      AmbienceKind.hub => _hubAmb,
      AmbienceKind.dungeon => _dungeonAmb,
      AmbienceKind.none => null,
    };
    if (source == null) return;
    try {
      _ambienceHandle = SoLoud.instance.play(
        source,
        volume: _effectiveAmbienceVolume(),
        looping: true,
      );
    } catch (_) {
      _ambienceHandle = null;
    }
  }

  static void stopAmbience() {
    final h = _ambienceHandle;
    _ambienceHandle = null;
    if (h == null || !_ready) return;
    try {
      SoLoud.instance.stop(h);
    } catch (_) {}
  }

  /// App lifecycle: pause ambience when backgrounded.
  static void onAppPaused() {
    _ambiencePaused = true;
    _pauseAmbienceInternal();
  }

  static void onAppResumed() {
    _ambiencePaused = false;
    if (!muted) {
      unawaited(setAmbience(_ambience, forceRestart: true));
    }
  }

  static void _pauseAmbienceInternal() {
    final h = _ambienceHandle;
    if (h == null || !_ready) return;
    try {
      SoLoud.instance.setPause(h, true);
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

  static double _effectiveAmbienceVolume() =>
      muted ? 0.0 : ambienceVolume.clamp(0.0, 1.0);

  static void _duckAmbienceBriefly() {
    final h = _ambienceHandle;
    if (h == null || !_ready || muted) return;
    try {
      final soloud = SoLoud.instance;
      final base = _effectiveAmbienceVolume();
      soloud.setVolume(h, base * 0.35);
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (_ambienceHandle != h || muted) return;
        try {
          soloud.setVolume(h, _effectiveAmbienceVolume());
        } catch (_) {}
      });
    } catch (_) {}
  }

  static void _hapticFor(String id) {
    switch (id) {
      case 'hit':
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

  static void hit() => play('hit');
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
