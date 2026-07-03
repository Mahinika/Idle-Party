import '../models/hero.dart';
import '../models/enemy.dart';
import '../managers/buff_manager.dart';

class BuffSystem {
  final BuffManager buffManager;

  BuffSystem(this.buffManager);

  void update(List<HeroModel> heroes, List<EnemyModel> enemies, double deltaTime) {
    for (var hero in heroes) {
      if (!hero.isDead) {
        buffManager.tickBuffs(hero, deltaTime);
      }
    }
    
    for (var enemy in enemies) {
      if (!enemy.isDead) {
        buffManager.tickBuffs(enemy, deltaTime);
      }
    }
  }
}
