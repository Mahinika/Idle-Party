import '../models/enemy.dart';

/// One combat-hit feel event for the audio mixer (not a raw clip id).
class CombatFeelHit {
  const CombatFeelHit({
    required this.impactId,
    this.distance = 0,
    this.panBias = 0,
    this.material = CombatHitMaterial.flesh,
    this.heavy = false,
    this.withSwish = true,
  });

  /// Impact / spell clip family id (`hit_blade`, `spell_fire`, …).
  final String impactId;

  /// World-tile distance from party centroid to impact (pseudo attenuation).
  final double distance;

  /// Stereo bias from relative X (−1 left … +1 right), pre-clamped by mixer.
  final double panBias;

  final CombatHitMaterial material;

  /// Crit / heavy impact — slightly louder, deeper pitch.
  final bool heavy;

  /// Play a short swish/release before the impact (melee + bow).
  final bool withSwish;
}

/// Target-body material layer for soft impact chirps.
enum CombatHitMaterial {
  /// Default meaty thud.
  flesh,

  /// Brittle / bone (glass, many casters).
  bone,

  /// Wet / soft (swarm).
  wet,

  /// Hard shell / stone (tank).
  stone,
}

abstract final class CombatFeel {
  static CombatHitMaterial materialFor(EnemyArchetype archetype) {
    return switch (archetype) {
      EnemyArchetype.swarm => CombatHitMaterial.wet,
      EnemyArchetype.glass => CombatHitMaterial.bone,
      EnemyArchetype.tank => CombatHitMaterial.stone,
      EnemyArchetype.support || EnemyArchetype.ranged => CombatHitMaterial.bone,
      EnemyArchetype.brute => CombatHitMaterial.flesh,
    };
  }

  static String materialSfxId(CombatHitMaterial m) => switch (m) {
    CombatHitMaterial.flesh => 'mat_flesh',
    CombatHitMaterial.bone => 'mat_bone',
    CombatHitMaterial.wet => 'mat_wet',
    CombatHitMaterial.stone => 'mat_stone',
  };

  static String swishIdFor(String impactId) {
    if (impactId == 'hit_bow' || impactId.startsWith('spell_')) {
      return 'swish_bow';
    }
    return 'swish_melee';
  }

  /// Volume scale from tile distance (near = 1, far ≈ 0.28).
  static double distanceGain(double distance) {
    return (1.0 / (1.0 + distance * 0.12)).clamp(0.28, 1.0);
  }
}
