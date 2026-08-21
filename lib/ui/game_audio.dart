import 'package:flutter/services.dart';

/// Lightweight SFX via system sounds + haptics (no asset pack required).
/// Respects [muted] and [hapticsEnabled] so Settings toggles actually work.
abstract final class GameAudio {
  static bool muted = false;
  static bool hapticsEnabled = true;

  static void play(String id) {
    if (muted) return;
    switch (id) {
      case 'hit':
        SystemSound.play(SystemSoundType.click);
        _haptic(HapticFeedback.selectionClick);
      case 'kill':
        SystemSound.play(SystemSoundType.click);
        _haptic(HapticFeedback.mediumImpact);
      case 'crit':
        SystemSound.play(SystemSoundType.click);
        _haptic(HapticFeedback.mediumImpact);
      case 'loot':
        SystemSound.play(SystemSoundType.click);
        _haptic(HapticFeedback.lightImpact);
        Future<void>.delayed(const Duration(milliseconds: 40), () {
          if (!muted) SystemSound.play(SystemSoundType.click);
        });
      case 'flask':
        SystemSound.play(SystemSoundType.click);
        _haptic(HapticFeedback.mediumImpact);
      case 'level':
        SystemSound.play(SystemSoundType.alert);
        _haptic(HapticFeedback.mediumImpact);
      case 'wipe':
        SystemSound.play(SystemSoundType.alert);
        _haptic(HapticFeedback.heavyImpact);
      case 'boss':
        SystemSound.play(SystemSoundType.alert);
        _haptic(HapticFeedback.heavyImpact);
      case 'clear':
        SystemSound.play(SystemSoundType.click);
        _haptic(HapticFeedback.mediumImpact);
      case 'unlock':
        SystemSound.play(SystemSoundType.alert);
        _haptic(HapticFeedback.lightImpact);
      case 'ui':
        SystemSound.play(SystemSoundType.click);
      default:
        SystemSound.play(SystemSoundType.click);
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
