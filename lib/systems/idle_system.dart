import '../models/hero.dart';
import '../managers/caps_manager.dart';
import 'team_dps_system.dart';

class IdleReward {
  final double goldEarned;
  final double xpEarned;
  final double actualSeconds;

  IdleReward({
    required this.goldEarned,
    required this.xpEarned,
    required this.actualSeconds,
  });
}

class IdleSystem {
  final TeamDpsSystem teamDpsSystem;
  final CapsManager capsManager;

  IdleSystem(this.teamDpsSystem, this.capsManager);

  /// Calculates offline progress rewards given elapsed offline time in seconds.
  /// Uses CapsManager to limit offline time to the configured maximum duration.
  IdleReward calculateOfflineRewards(List<HeroModel> heroes, double offlineSeconds) {
    // Apply idle time cap
    final cappedSeconds = capsManager.clampIdleTime(offlineSeconds);
    
    // Calculate team dps
    final teamDps = teamDpsSystem.calculateTeamDps(heroes);
    
    // Rewards formulas:
    // Gold: 15% of Team DPS per second
    final goldEarned = cappedSeconds * teamDps * 0.15;
    // XP: 5% of Team DPS per second (applied to all living heroes)
    final xpEarned = cappedSeconds * teamDps * 0.05;

    return IdleReward(
      goldEarned: goldEarned,
      xpEarned: xpEarned,
      actualSeconds: cappedSeconds,
    );
  }
}
