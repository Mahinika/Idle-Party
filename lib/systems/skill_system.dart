import '../models/hero.dart';
import '../models/enemy.dart';
import '../managers/skill_trigger_budget.dart';
import '../managers/buff_manager.dart';
import '../managers/debuff_manager.dart';

class SkillDefinition {
  final String id;
  final String name;
  final double cooldown;
  final double damageMultiplier;
  final String effectType; // "buff", "debuff", "none"
  final String effectId;
  final double effectDuration;
  final String description;

  SkillDefinition({
    required this.id,
    required this.name,
    required this.cooldown,
    required this.damageMultiplier,
    required this.effectType,
    required this.effectId,
    required this.effectDuration,
    required this.description,
  });

  factory SkillDefinition.fromJson(Map<String, dynamic> json) {
    return SkillDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      cooldown: (json['cooldown'] as num).toDouble(),
      damageMultiplier: (json['damage_multiplier'] as num).toDouble(),
      effectType: json['effect_type'] as String,
      effectId: json['effect_id'] as String,
      effectDuration: (json['effect_duration'] as num).toDouble(),
      description: json['description'] as String,
    );
  }
}

class SkillSystem {
  final Map<String, SkillDefinition> _skills = {};
  final BuffManager buffManager;
  final DebuffManager debuffManager;

  SkillSystem(this.buffManager, this.debuffManager);

  void loadSkills(List<dynamic> jsonData) {
    _skills.clear();
    for (var item in jsonData) {
      final def = SkillDefinition.fromJson(item as Map<String, dynamic>);
      _skills[def.id] = def;
    }
  }

  SkillDefinition? getSkill(String skillId) {
    return _skills[skillId];
  }

  void update(List<HeroModel> heroes, double deltaTime) {
    for (var hero in heroes) {
      if (hero.isDead) continue;
      
      // Update cooldowns
      final cooldownKeys = List<String>.from(hero.skillCooldowns.keys);
      for (var skillId in cooldownKeys) {
        final currentCd = hero.skillCooldowns[skillId] ?? 0.0;
        final newCd = (currentCd - deltaTime).clamp(0.0, double.infinity);
        if (newCd <= 0.0) {
          hero.skillCooldowns.remove(skillId);
        } else {
          hero.skillCooldowns[skillId] = newCd;
        }
      }
    }
  }

  /// Attempts to activate a skill for a hero.
  /// Respects cooldowns and SkillTriggerBudget.
  /// Returns the damage multiplier if successful, or 0.0 if not cast.
  double tryCastSkill(
    HeroModel hero,
    String skillId,
    List<EnemyModel> enemies,
    SkillTriggerBudget budget,
  ) {
    if (hero.isDead) return 0.0;
    
    // Check cooldown
    if (hero.skillCooldowns.containsKey(skillId)) {
      return 0.0;
    }

    final def = _skills[skillId];
    if (def == null) return 0.0;

    // Check budget
    if (!budget.tryTrigger()) {
      // Loop detected or budget exceeded for this tick
      return 0.0;
    }

    // Set skill on cooldown
    hero.skillCooldowns[skillId] = def.cooldown;

    // Apply special effects
    if (def.effectType == 'buff') {
      buffManager.applyBuff(hero, def.effectId, def.effectDuration);
    } else if (def.effectType == 'debuff') {
      final activeEnemies = enemies.where((e) => !e.isDead).toList();
      if (activeEnemies.isNotEmpty) {
        // Apply debuff to a random living enemy
        final target = activeEnemies[0];
        debuffManager.applyDebuff(target, def.effectId, def.effectDuration);
      }
    }

    return def.damageMultiplier;
  }
}
