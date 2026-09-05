/// Combat visual detail preference (settings + offline sim).
enum VfxQuality {
  /// Full bursts, floaters, auras, trails.
  full,

  /// Skip bursts/floaters; keep projectiles + actor auras + ground discs.
  lite,

  /// Minimal: no bursts/floaters/auras/ground discs; simple projectiles only.
  minimal;

  bool get reduced => this != VfxQuality.full;

  bool get showBurstsAndFloaters => this == VfxQuality.full;

  bool get showActorAuras => this != VfxQuality.minimal;

  /// Consecration / Bladestorm / trap discs — persistent, low motion.
  bool get showGroundFx => this != VfxQuality.minimal;

  bool get showGuideAndPulse => this != VfxQuality.minimal;

  bool get showProjectileTrails => this == VfxQuality.full;

  /// Fancy loot pulse rings (rare+).
  bool get showLootPulse => this == VfxQuality.full;

  String get settingsLabel => switch (this) {
    VfxQuality.full => 'Full VFX',
    VfxQuality.lite => 'Lite VFX',
    VfxQuality.minimal => 'Minimal VFX (reduce motion)',
  };

  String get settingsHint => switch (this) {
    VfxQuality.full => 'All combat effects',
    VfxQuality.lite => 'No floaters/bursts — discs & auras stay',
    VfxQuality.minimal => 'Reduce motion — auras & discs off too',
  };

  VfxQuality get next => switch (this) {
    VfxQuality.full => VfxQuality.lite,
    VfxQuality.lite => VfxQuality.minimal,
    VfxQuality.minimal => VfxQuality.full,
  };

  static VfxQuality fromJson(Object? raw, {bool? legacyReduced}) {
    if (raw is String) {
      return switch (raw) {
        'lite' => VfxQuality.lite,
        'minimal' => VfxQuality.minimal,
        'full' => VfxQuality.full,
        _ => VfxQuality.full,
      };
    }
    if (legacyReduced == true) return VfxQuality.lite;
    return VfxQuality.full;
  }
}
