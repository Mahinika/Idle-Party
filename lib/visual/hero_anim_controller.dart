import 'hero_anim_state.dart';

/// Pure-Dart animation state machine for dungeon heroes.
///
/// Priority: death > hit > attack|cast > walk > idle.
/// Victory is optional and only wins when nothing higher is active.
class HeroAnimController {
  HeroAnimKind _kind = HeroAnimKind.idle;
  double _clipElapsed = 0;
  bool _locked = false;

  HeroAnimKind get kind => _kind;
  bool get locked => _locked;

  /// Advance [dt] seconds using [signals]; returns the painter pose.
  HeroAnimPose tick(double dt, HeroAnimSignals signals) {
    if (_locked && _kind == HeroAnimKind.death) {
      return HeroAnimPose(
        kind: HeroAnimKind.death,
        frame: _frameFor(HeroAnimKind.death, 1),
        locked: true,
        progress: 1,
      );
    }

    final next = _resolveKind(signals);
    if (next != _kind) {
      _kind = next;
      _clipElapsed = 0;
      if (next == HeroAnimKind.death) _locked = true;
    } else {
      _clipElapsed += dt;
    }

    final duration = _clipDuration(_kind);
    final progress = duration <= 0
        ? 0.0
        : (_clipElapsed / duration).clamp(0.0, 1.0);
    final frame = _frameFor(_kind, progress);

    // One-shots fall back when their flash expires.
    if (!_locked &&
        (_kind == HeroAnimKind.attack ||
            _kind == HeroAnimKind.cast ||
            _kind == HeroAnimKind.hit) &&
        progress >= 1) {
      _kind = signals.moving ? HeroAnimKind.walk : HeroAnimKind.idle;
      _clipElapsed = 0;
      return tick(0, signals);
    }

    return HeroAnimPose(
      kind: _kind,
      frame: frame,
      locked: _locked,
      progress: progress,
    );
  }

  HeroAnimKind _resolveKind(HeroAnimSignals signals) {
    if (signals.dead || _locked) return HeroAnimKind.death;
    if (signals.hit || signals.hitFlash > 0.02) return HeroAnimKind.hit;
    if (signals.attacking || signals.attackFlash > 0.02) {
      return HeroAnimKind.attack;
    }
    if (signals.casting || signals.castFlash > 0.02) {
      return HeroAnimKind.cast;
    }
    if (signals.victory) return HeroAnimKind.victory;
    if (signals.moving) return HeroAnimKind.walk;
    return HeroAnimKind.idle;
  }

  static double _clipDuration(HeroAnimKind kind) => switch (kind) {
    HeroAnimKind.idle => 0.8,
    HeroAnimKind.walk => 0.35,
    HeroAnimKind.attack => 0.22,
    HeroAnimKind.cast => 0.35,
    HeroAnimKind.hit => 0.18,
    HeroAnimKind.death => 0.4,
    HeroAnimKind.victory => 0.6,
  };

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

  void reset() {
    _kind = HeroAnimKind.idle;
    _clipElapsed = 0;
    _locked = false;
  }

  /// Stateless pose for painters (no persistent controller needed).
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
