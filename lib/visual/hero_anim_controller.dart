import 'hero_anim_state.dart';

/// Pure-Dart animation resolver for dungeon heroes.
///
/// Priority: death > hit > attack|cast > walk > idle.
/// Victory is optional and only wins when nothing higher is active.
///
/// Stateless by design — the dungeon repaints from combat flash timers, so
/// there is no per-hero clip clock to keep.
abstract final class HeroAnimController {
  /// Kenney body columns: 0 = idle/stand, 1 = walk/attack lean.
  static int _frameFor(HeroAnimKind kind, double progress) => switch (kind) {
    HeroAnimKind.idle => 0,
    HeroAnimKind.walk => progress < 0.5 ? 0 : 1,
    HeroAnimKind.attack => progress < 0.45 ? 1 : 0,
    HeroAnimKind.cast => progress < 0.55 ? 1 : 0,
    HeroAnimKind.hit => 1,
    HeroAnimKind.death => 1,
    HeroAnimKind.victory => progress < 0.5 ? 0 : 1,
  };

  /// Pose for painters, straight from this frame's combat signals.
  ///
  /// Uses flash timers for one-shot progress; [walkPhase] 0–1 picks walk frame.
  static HeroAnimPose snapshot(
    HeroAnimSignals signals, {
    double walkPhase = 0,
  }) {
    if (signals.dead) {
      return const HeroAnimPose(
        kind: HeroAnimKind.death,
        frame: 1,
        locked: true,
        progress: 1,
      );
    }
    if (signals.hit || signals.hitFlash > 0.02) {
      final progress = signals.hitFlash > 0
          ? (1 - (signals.hitFlash / 0.18).clamp(0.0, 1.0))
          : 0.5;
      return HeroAnimPose(
        kind: HeroAnimKind.hit,
        frame: _frameFor(HeroAnimKind.hit, progress),
        progress: progress,
      );
    }
    if (signals.attacking || signals.attackFlash > 0.02) {
      final progress = signals.attackFlash > 0
          ? (1 - (signals.attackFlash / 0.22).clamp(0.0, 1.0))
          : 0.5;
      return HeroAnimPose(
        kind: HeroAnimKind.attack,
        frame: _frameFor(HeroAnimKind.attack, progress),
        progress: progress,
      );
    }
    if (signals.casting || signals.castFlash > 0.02) {
      final progress = signals.castFlash > 0
          ? (1 - (signals.castFlash / 0.35).clamp(0.0, 1.0))
          : 0.5;
      return HeroAnimPose(
        kind: HeroAnimKind.cast,
        frame: _frameFor(HeroAnimKind.cast, progress),
        progress: progress,
      );
    }
    if (signals.victory) {
      return HeroAnimPose(
        kind: HeroAnimKind.victory,
        frame: _frameFor(HeroAnimKind.victory, walkPhase),
        progress: walkPhase,
      );
    }
    if (signals.moving) {
      final progress = walkPhase.clamp(0.0, 1.0);
      return HeroAnimPose(
        kind: HeroAnimKind.walk,
        frame: _frameFor(HeroAnimKind.walk, progress),
        progress: progress,
      );
    }
    return const HeroAnimPose(kind: HeroAnimKind.idle, frame: 0);
  }
}
