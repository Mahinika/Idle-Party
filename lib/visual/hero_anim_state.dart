/// Frame-based hero animation kinds for dungeon layered rendering.
enum HeroAnimKind {
  idle,
  walk,
  attack,
  cast,
  hit,
  death,
  victory,
}

/// Snapshot of the current clip + frame for painters.
class HeroAnimPose {
  const HeroAnimPose({
    required this.kind,
    required this.frame,
    this.locked = false,
    this.progress = 0,
  });

  final HeroAnimKind kind;

  /// Clip-local frame index (0-based).
  final int frame;

  /// When true, [kind] must not leave (death).
  final bool locked;

  /// 0–1 progress through a one-shot clip (attack/cast/hit).
  final double progress;
}

/// Combat → animation input. No sprite knowledge.
class HeroAnimSignals {
  const HeroAnimSignals({
    this.moving = false,
    this.attacking = false,
    this.casting = false,
    this.hit = false,
    this.dead = false,
    this.victory = false,
    this.attackFlash = 0,
    this.castFlash = 0,
    this.hitFlash = 0,
  });

  final bool moving;
  final bool attacking;
  final bool casting;
  final bool hit;
  final bool dead;
  final bool victory;

  /// Seconds remaining on attack punch (SpatialActor.attackFlash).
  final double attackFlash;

  /// Seconds remaining on cast VFX.
  final double castFlash;

  /// Seconds remaining on hit flinch.
  final double hitFlash;
}
