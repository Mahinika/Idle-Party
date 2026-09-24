part of 'spatial_combat.dart';

void combatUpdateChambers(
  SpatialWorld world, {
  bool reducedVfx = false,
  bool softLock = true,
}) {
  if (world.map.chambers.isEmpty) return;

  final chamberCount = world.map.chambers.length;
  // Chambers unlock in order, while empty chambers are safely skipped.
  while (world.clearedChambers.length < chamberCount) {
    var maxCleared = -1;
    for (final chamber in world.clearedChambers) {
      if (chamber > maxCleared) maxCleared = chamber;
    }
    final next = maxCleared + 1;
    if (next >= chamberCount) break;
    final hasLivingEnemy = world.enemies.any(
      (enemy) => enemy.chamberIndex == next && enemy.hp > 0,
    );
    if (hasLivingEnemy) break;
    world.clearedChambers.add(next);
    if (!reducedVfx) {
      for (final chamber in world.map.chambers) {
        if (chamber.index != next) continue;
        SpatialCombat.spawnRing(
          world,
          x: chamber.x + chamber.w * 0.5,
          y: chamber.y + chamber.h * 0.5,
          argb: 0xFF50C070,
          radius: math.min(chamber.w, chamber.h) * 0.35,
          life: 0.55,
        );
        break;
      }
    }
  }

  for (final gate in world.map.gates) {
    if (!world.clearedChambers.contains(gate.opensAfterChamber)) continue;
    final wasOpen = world.openGateIds.contains(gate.id);
    world.openGateIds.add(gate.id);
    if (!wasOpen) {
      // One shout per door strip — multi-tile gates used to spam OPEN×3.
      var alreadyShouted = false;
      for (final f in world.floaters) {
        if (f.text.startsWith('OPEN') && f.priority >= 2) {
          alreadyShouted = true;
          break;
        }
      }
      if (!reducedVfx) {
        SpatialCombat.spawnRing(
          world,
          x: gate.x + 0.5,
          y: gate.y + 0.5,
          argb: 0xFFFFD070,
          radius: 1.35,
          life: 0.55,
        );
      }
      if (!alreadyShouted) {
        if (!reducedVfx) {
          SpatialCombat.spawnSpark(
            world,
            x: gate.x + 0.5,
            y: gate.y + 0.5,
            argb: 0xFFFFF0A0,
            radius: 0.55,
          );
        }
        // Priority floater — still paints on Lite VFX.
        SpatialCombat.spawnFloater(
          world,
          x: gate.x + 0.5,
          y: gate.y - 0.45,
          text: 'OPEN →',
          argb: SpatialCombat._floaterGold,
          life: 0.95,
          priority: 2,
        );
      }
    }
  }

  var maxCleared = -1;
  for (final chamber in world.clearedChambers) {
    if (chamber > maxCleared) maxCleared = chamber;
  }
  final nextChamber = math.min(chamberCount - 1, maxCleared + 1);
  world.activeChamber = nextChamber;
  for (final enemy in world.enemies) {
    if (enemy.chamberIndex <= maxCleared + 1 ||
        enemy.chamberIndex == nextChamber) {
      enemy.dormant = false;
    }
  }

  // Idle-safe: if nothing active remains but dormant packs do, open the
  // road and wake them so the party isn't soft-locked behind gates.
  final hasActive = world.enemies.any((e) => e.hp > 0 && !e.dormant);
  final hasDormant = world.enemies.any((e) => e.hp > 0 && e.dormant);
  if (!hasActive && hasDormant) {
    SpatialCombat._openAllGatesAndWake(world);
  }

  // Path soft-lock once per step (not on the early chamber pass).
  if (softLock) {
    SpatialCombat._unlockIfEnemiesUnreachable(world);
  }
}

void combatOpenAllGatesAndWake(SpatialWorld world) {
  for (final gate in world.map.gates) {
    world.openGateIds.add(gate.id);
  }
  for (final enemy in world.enemies) {
    if (enemy.hp > 0) enemy.dormant = false;
  }
}

/// Opens remaining gates when any *active* living enemy is unreachable.
/// One flood-fill from the party — not heroes×enemies BFS.
void combatUnlockIfEnemiesUnreachable(SpatialWorld world) {
  if (!_CombatPathing.anyActiveEnemyUnreachable(world)) return;
  SpatialCombat._openAllGatesAndWake(world);
}

/// Apply any remaining ground loot into state and clear the pile.
/// Used when exit starts early (AFK) or right before roomCleared.
GameState combatVacuumGroundLoot(SpatialWorld world, GameState state) {
  if (world.groundLoot.isEmpty) return state;
  final drops = <LootDrop>[for (final loot in world.groundLoot) loot.drop];
  final names = <String>[];
  for (final drop in drops) {
    if (!drop.isEquipment) continue;
    if (names.length >= 4) break;
    final item = drop.equipment;
    final label = item != null ? item.combatPopLabel : drop.name;
    if (label.isNotEmpty && !names.contains(label)) names.add(label);
  }
  world.groundLoot.clear();
  final granted = GameLogic.grantLoot(state, drops);
  world.pendingFeelPickups += drops.length;
  final bits = <String>[...names];
  if (granted.receipt.goldGained > 0) {
    bits.add('+${granted.receipt.goldGained}g');
  } else if (names.isEmpty && granted.receipt.essenceGained > 0) {
    bits.add('+${granted.receipt.essenceGained}e');
  }
  if (bits.isNotEmpty) {
    world.pendingVacuumLootLine = bits.join(' · ');
  }
  return granted.state;
}
