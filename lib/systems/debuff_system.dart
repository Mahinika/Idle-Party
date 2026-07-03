import '../models/hero.dart';
import '../models/enemy.dart';
import '../managers/debuff_manager.dart';

class DebuffSystem {
  final DebuffManager debuffManager;

  DebuffSystem(this.debuffManager);

  void update(List<HeroModel> heroes, List<EnemyModel> enemies, double deltaTime) {
    for (var hero in heroes) {
      if (!hero.isDead) {
        // Ticking dot effects
        _applyTickingDamage(hero, deltaTime);
        debuffManager.tickDebuffs(hero, deltaTime);
      }
    }
    
    for (var enemy in enemies) {
      if (!enemy.isDead) {
        // Ticking dot effects
        _applyTickingDamage(enemy, deltaTime);
        debuffManager.tickDebuffs(enemy, deltaTime);
      }
    }
  }

  void _applyTickingDamage(dynamic target, double deltaTime) {
    // Check poison
    if (debuffManager.hasDebuff(target, 'poison')) {
      final stacks = debuffManager.getStacks(target, 'poison');
      // Deals 5 damage per stack per second
      final damage = stacks * 5.0 * deltaTime;
      target.takeDamage(damage);
    }

    // Check burn
    if (debuffManager.hasDebuff(target, 'burn')) {
      final stacks = debuffManager.getStacks(target, 'burn');
      // Deals 10 damage per stack per second
      final damage = stacks * 10.0 * deltaTime;
      target.takeDamage(damage);
    }
  }
}
