import 'gauntlet_pact.dart';

/// Infinity Gauntlet floor modifiers. Same SpatialCombat — not a second hunt.
///
/// Between every boss the four squeezes each take a floor: tight corridors,
/// a swarm (or MIGHT · RUSH), a borrowed boss tell, extra gates. The order
/// rotates after each boss. Boss floors stay clear. Cycle is deterministic
/// from floor number.
enum GauntletAnomaly {
  tightCorridors,
  swarmUprising,
  /// MIGHT pact only — denser swarms than [swarmUprising].
  bloodRush,
  bossEcho,
  gateGauntlet,
}

abstract final class GauntletAnomalies {
  static const int bossEvery = 5;

  /// Floors 1–4, in climb order. Floor 5 is the first boss.
  static const List<GauntletAnomaly> openingNight = <GauntletAnomaly>[
    GauntletAnomaly.tightCorridors,
    GauntletAnomaly.swarmUprising,
    GauntletAnomaly.bossEcho,
    GauntletAnomaly.gateGauntlet,
  ];

  static const List<GauntletAnomaly> mightOpeningNight = <GauntletAnomaly>[
    GauntletAnomaly.tightCorridors,
    GauntletAnomaly.bloodRush,
    GauntletAnomaly.bossEcho,
    GauntletAnomaly.gateGauntlet,
  ];

  static List<GauntletAnomaly> openingFor(GauntletPact? pact) =>
      pact == GauntletPact.might ? mightOpeningNight : openingNight;

  /// Trophy grid per pact (MIGHT earns RUSH instead of SWARM).
  static List<GauntletAnomaly> trophiesFor(GauntletPact pact) =>
      openingFor(pact);

  static GauntletAnomaly? forFloor(
    int floor, {
    required bool inGauntlet,
    GauntletPact? pact,
  }) {
    if (!inGauntlet || floor <= 0) return null;
    if (floor % bossEvery == 0) return null;
    // Floors 1–4, 6–9, 11–14, … are the four squeezes. Slot 4 is the boss.
    final slot = floor % bossEvery;
    final cycle = (floor - 1) ~/ bossEvery;
    final night = openingFor(pact);
    final index = (slot - 1 + cycle) % night.length;
    return night[index];
  }

  static String chip(GauntletAnomaly a) => switch (a) {
    GauntletAnomaly.tightCorridors => 'TIGHT',
    GauntletAnomaly.swarmUprising => 'SWARM',
    GauntletAnomaly.bloodRush => 'RUSH',
    GauntletAnomaly.bossEcho => 'ECHO',
    GauntletAnomaly.gateGauntlet => 'GATES',
  };

  static String oneLiner(GauntletAnomaly a) => switch (a) {
    GauntletAnomaly.tightCorridors =>
      'The Spire squeezes inward — tight corridors.',
    GauntletAnomaly.swarmUprising =>
      'More enemies gather — expect heavy swarms.',
    GauntletAnomaly.bloodRush =>
      'MIGHTbound rush — thicker swarms than a normal SWARM floor.',
    GauntletAnomaly.bossEcho =>
      'A borrowed boss tell echoes on this floor.',
    GauntletAnomaly.gateGauntlet =>
      'Sealed chambers — clear each gate to push.',
  };

  static int layoutPressureBonus(GauntletAnomaly? a) => switch (a) {
    GauntletAnomaly.tightCorridors => 8,
    GauntletAnomaly.gateGauntlet => 4,
    _ => 0,
  };

  static int extraCombatRooms(GauntletAnomaly? a) => switch (a) {
    GauntletAnomaly.gateGauntlet => 2,
    GauntletAnomaly.tightCorridors => 1,
    _ => 0,
  };

  static bool tightRooms(GauntletAnomaly? a) =>
      a == GauntletAnomaly.tightCorridors;

  static bool swarmPacks(GauntletAnomaly? a) =>
      a == GauntletAnomaly.swarmUprising || a == GauntletAnomaly.bloodRush;

  static bool bloodRushFloor(GauntletAnomaly? a) =>
      a == GauntletAnomaly.bloodRush;

  static double swarmCountMul(GauntletAnomaly? a) {
    if (bloodRushFloor(a)) return 1.5;
    if (a == GauntletAnomaly.swarmUprising) return 1.35;
    return 1.0;
  }

  static bool bossEcho(GauntletAnomaly? a) => a == GauntletAnomaly.bossEcho;

  static int nextBossFloor(int floor) {
    if (floor <= 0) return bossEvery;
    return ((floor ~/ bossEvery) + 1) * bossEvery;
  }

  /// Place line while climbing. A living boss keeps its name. An anomaly
  /// floor names the squeeze. Other floors name the next boss.
  static String climbPlaceLine(int floor, {String? liveBossName}) {
    final boss = liveBossName?.trim() ?? '';
    if (boss.isNotEmpty) return 'CLIMB · $boss';
    if (floor > 0 && floor % bossEvery == 0) return 'CLIMB · boss F$floor';
    final anomaly = forFloor(floor, inGauntlet: true);
    if (anomaly != null) return 'CLIMB · ${chip(anomaly)}';
    return 'CLIMB · boss F${nextBossFloor(floor)}';
  }

  static int? nextAnomalyFloor(int floor) {
    for (var f = floor + 1; f <= floor + 12; f++) {
      if (forFloor(f, inGauntlet: true) != null) return f;
    }
    return null;
  }

  static bool isTreasureFloor(int floor) => floor > 0 && floor % 6 == 0;
}
