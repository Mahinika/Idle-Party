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

enum AiPriority {
  default_priority,
  lowest_hp,
  focus_boss,
}

class AiSystem {
  final SkillSystem skillSystem;
  AiPriority priority = AiPriority.default_priority;
  bool prioritizeHealingUnder30 = true;

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

    // Determine target selection based on AiPriority
    EnemyModel selectTarget(List<EnemyModel> active) {
      if (priority == AiPriority.focus_boss) {
        final boss = active.firstWhere((e) => e.isBoss, orElse: () => active.first);
        return boss;
      } else if (priority == AiPriority.lowest_hp) {
        var lowest = active.first;
        for (var enemy in active) {
          if (enemy.currentStats.hp < lowest.currentStats.hp) {
            lowest = enemy;
          }
        }
        return lowest;
      }
      return active.first;
    }

    // Check if any ally has < 30% HP
    bool hasLowHpAlly = false;
    for (var h in heroes) {
      if (!h.isDead && (h.currentStats.hp / h.currentStats.maxHp < 0.30)) {
        hasLowHpAlly = true;
        break;
      }
    }

    for (var hero in heroes) {
      if (hero.isDead) continue;

      // Check if hero has a skill ready to cast
      String? chosenSkillId;

      // If prioritizeHealingUnder30 is active and an ally is low on HP,
      // try to find a healing skill that is ready!
      if (prioritizeHealingUnder30 && hasLowHpAlly) {
        for (var skillId in hero.skills) {
          final skillDef = skillSystem.getSkill(skillId);
          if (skillDef != null && skillDef.effectType == 'heal') {
            if (!hero.skillCooldowns.containsKey(skillId)) {
              chosenSkillId = skillId;
              break;
            }
          }
        }
      }

      // If no healing skill was chosen, select the first ready skill (standard behaviour)
      if (chosenSkillId == null) {
        for (var skillId in hero.skills) {
          if (!hero.skillCooldowns.containsKey(skillId)) {
            chosenSkillId = skillId;
            break;
          }
        }
      }

      final target = selectTarget(activeEnemies);

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
