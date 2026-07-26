/// Lightweight audio stubs — no package dependency.
/// Call sites stay stable if real audio is wired later.
abstract final class GameAudio {
  static bool muted = false;

  static void play(String id) {
    if (muted) return;
    // Stub: reserved for hit/crit/loot/level/wipe/boss SFX.
  }

  static void hit() => play('hit');
  static void crit() => play('crit');
  static void loot() => play('loot');
  static void levelUp() => play('level');
  static void wipe() => play('wipe');
  static void boss() => play('boss');
  static void clear() => play('clear');
  static void unlock() => play('unlock');
}
