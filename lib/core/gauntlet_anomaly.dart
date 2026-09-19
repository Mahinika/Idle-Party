/// Infinity Gauntlet floor modifiers. Same SpatialCombat — not a second hunt.
///
/// Lands on floors where [floor] % 5 == 3 (3, 8, 13, 18, …) so they never
/// collide with bosses every 5. Cycle is deterministic from floor number.
enum GauntletAnomaly {
  tightCorridors,
  swarmUprising,
  bossEcho,
  gateGauntlet,
}

abstract final class GauntletAnomalies {
  static const int bossEvery = 5;

  static GauntletAnomaly? forFloor(int floor, {required bool inGauntlet}) {
    if (!inGauntlet || floor <= 0) return null;
    if (floor % bossEvery == 0) return null;
    if (floor % 6 == 0) return null;
    if (floor % bossEvery != 3) return null;
    return GauntletAnomaly.values[(floor ~/ bossEvery) % 4];
  }

  static String chip(GauntletAnomaly a) => switch (a) {
    GauntletAnomaly.tightCorridors => 'TIGHT',
    GauntletAnomaly.swarmUprising => 'SWARM',
    GauntletAnomaly.bossEcho => 'ECHO',
    GauntletAnomaly.gateGauntlet => 'GATES',
  };

  static String oneLiner(GauntletAnomaly a) => switch (a) {
    GauntletAnomaly.tightCorridors =>
      'The Spire squeezes inward — tight corridors.',
    GauntletAnomaly.swarmUprising =>
      'More enemies gather — expect heavy swarms.',
    GauntletAnomaly.bossEcho =>
      'A fragment of a past boss tell echoes here.',
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
      a == GauntletAnomaly.swarmUprising;

  static bool bossEcho(GauntletAnomaly? a) => a == GauntletAnomaly.bossEcho;
}
