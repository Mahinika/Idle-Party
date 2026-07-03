import '../models/hero.dart';

class TeamDpsSystem {
  TeamDpsSystem();

  /// Calculates the total static DPS estimate of the hero team.
  /// Useful for offline idle progression and UI estimates.
  double calculateTeamDps(List<HeroModel> heroes) {
    double totalDps = 0.0;
    for (var hero in heroes) {
      if (hero.isDead) continue;
      
      final baseAtk = hero.currentStats.attack;
      final speed = hero.currentStats.speed;
      final critMultiplier = 1.0 + (hero.currentStats.critRate * (hero.currentStats.critDamage - 1.0));
      
      totalDps += baseAtk * speed * critMultiplier;
    }
    return totalDps;
  }
}
