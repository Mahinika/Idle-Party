import 'package:flutter/services.dart';

/// Lightweight SFX via system sounds + haptics (no asset pack required).
/// Respects [muted] so Settings mute actually works.
abstract final class GameAudio {
  static bool muted = false;

  static void play(String id) {
    if (muted) return;
    switch (id) {
      case 'hit':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
      case 'crit':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      case 'loot':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
      case 'level':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
      case 'wipe':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      case 'boss':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      case 'clear':
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      case 'unlock':
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.lightImpact();
      case 'ui':
        SystemSound.play(SystemSoundType.click);
      default:
        SystemSound.play(SystemSoundType.click);
    }
  }

  static void hit() => play('hit');
  static void crit() => play('crit');
  static void loot() => play('loot');
  static void levelUp() => play('level');
  static void wipe() => play('wipe');
  static void boss() => play('boss');
  static void clear() => play('clear');
  static void unlock() => play('unlock');
  static void ui() => play('ui');
}
