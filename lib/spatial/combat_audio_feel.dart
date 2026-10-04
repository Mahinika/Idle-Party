part of 'spatial_combat.dart';

/// Queues the sound of an arrow or spell leaving a hero's hand.
///
/// The hit sound still plays when the bolt lands. Enemy shots stay quiet
/// so a crowded fight does not become a wall of noise.
abstract final class CombatAudioFeel {
  static void noteProjectile(SpatialWorld world, SpatialProjectile bolt) {
    if (world.afkAssist || bolt.team != SpatialTeam.hero) return;
    final id = AudioAssets.launchIdFor(bolt.style);
    if (id == null) return;
    if (world.pendingFeelLaunches.length >= 12) return;
    world.pendingFeelLaunches.add(
      CombatFeelLaunch(id, delay: bolt.delay),
    );
  }

  static void tick(SpatialWorld world, double dt) {
    if (dt <= 0 || world.pendingFeelLaunches.isEmpty) return;
    for (var i = 0; i < world.pendingFeelLaunches.length; i++) {
      final launch = world.pendingFeelLaunches[i];
      if (launch.delay > 0) {
        world.pendingFeelLaunches[i] = launch.advanced(dt);
      }
    }
  }
}
