import 'dart:math';

import 'package:idle_party/core/equipment_factory.dart';
import 'package:idle_party/core/game_logic.dart';

/// Pins every shared random source so a test reads the same in isolation and
/// in a full-suite run. `GameLogic.random` also feeds layout seeds, enemy
/// spawns and SpatialCombat, so seeding only the equipment factory is not
/// enough for combat or difficulty probes.
void seedAll(int seed) {
  GameLogic.random = Random(seed);
  EquipmentFactory.random = Random(seed);
}

/// Restores unseeded randomness (call from `tearDown`).
void unseedAll() {
  GameLogic.random = Random();
  EquipmentFactory.random = Random();
}
