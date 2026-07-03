import '../models/hero.dart';
import '../models/enemy.dart';
import '../managers/skill_trigger_budget.dart';
import 'skill_system.dart';

class AiDecision {
  final HeroModel actor;
  final String actionType; // "skill" or "normal_attack"
  final String? skillId;
  final EnemyModel target;

  AiDecision({
    required this.actor,
    required this.actionType,
    this.skillId,
    required this.target,
  });
}

class AiSystem {
  final SkillSystem skillSystem;

  AiSystem(this.skillSystem);

  /// Analyzes heroes and living enemies to decide hero attacks/skill casts.
  /// Returns a list of decisions to be processed in CombatSystem.
  List<AiDecision> updateHeroActions(
    List<HeroModel> heroes,
    List<EnemyModel> enemies,
    SkillTriggerBudget budget,
  ) {
    final decisions = <AiDecision>[];
    final activeEnemies = enemies.where((e) => !e.isDead).toList();
    if (activeEnemies.isEmpty) return decisions;

    for (var hero in heroes) {
      if (hero.isDead) continue;

      // Check if hero has a skill ready to cast
      String? chosenSkillId;
      for (var skillId in hero.skills) {
        if (!hero.skillCooldowns.containsKey(skillId)) {
          chosenSkillId = skillId;
          break;
        }
      }

      // Select target (default: first enemy or random)
      final target = activeEnemies[0];

      if (chosenSkillId != null) {
        decisions.add(AiDecision(
          actor: hero,
          actionType: 'skill',
          skillId: chosenSkillId,
          target: target,
        ));
      } else {
        decisions.add(AiDecision(
          actor: hero,
          actionType: 'normal_attack',
          target: target,
        ));
      }
    }

    return decisions;
  }
}
