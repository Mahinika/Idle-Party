part of 'spatial_combat.dart';

/// Queues a body cue for the live mixer. Offline fights stay silent.
void combatNoteAudioCue(SpatialWorld world, String id) {
  if (world.afkAssist || id.isEmpty) return;
  if (world.pendingAudioCues.length >= 8) return;
  world.pendingAudioCues.add(id);
}

String combatEnemyDieCue(SpatialActor enemy) =>
    AudioAssets.enemyDieId(CombatFeel.materialFor(enemy.archetype));
