import '../core/dps_pipeline.dart';
import '../managers/buff_manager.dart';
import '../managers/skill_trigger_budget.dart';

/// Defines when a skill may fire.
enum SkillTriggerType { onAttack, onCrit, onKill, passive, manual }

/// A skill definition loaded from JSON.
class SkillDefinition {
  final String id;
  final String name;
  final SkillTriggerType triggerType;
  final double triggerChance;  // 0.0–1.0
  final double dpsMult;
  final String? applyBuffId;   // Optional buff to apply on trigger
  final double buffDuration;

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.triggerType,
    required this.triggerChance,
    this.dpsMult = 1.0,
    this.applyBuffId,
    this.buffDuration = 5.0,
  });

  factory SkillDefinition.fromJson(Map<String, dynamic> json) =>
      SkillDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        triggerType: SkillTriggerType.values.firstWhere(
          (t) => t.name == (json['triggerType'] as String? ?? 'passive'),
          orElse: () => SkillTriggerType.passive,
        ),
        triggerChance: (json['triggerChance'] as num?)?.toDouble() ?? 1.0,
        dpsMult: (json['dpsMult'] as num?)?.toDouble() ?? 1.0,
        applyBuffId: json['applyBuffId'] as String?,
        buffDuration: (json['buffDuration'] as num?)?.toDouble() ?? 5.0,
      );
}

/// SkillSystem processes passive and triggered skills within the budget.
///
/// Update order: step 6.
class SkillSystem {
  final SkillTriggerBudget budget;
  final BuffManager buffManager;
  final DpsPipeline dpsPipeline;
  final List<SkillDefinition> _skills = [];

  SkillSystem({
    required this.budget,
    required this.buffManager,
    required this.dpsPipeline,
  });

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _skills
      ..clear()
      ..addAll(data.map(SkillDefinition.fromJson));
  }

  void update(double deltaTime) {
    dpsPipeline.clearCategory('skill');

    for (final skill in _skills) {
      if (skill.triggerType == SkillTriggerType.passive) {
        dpsPipeline.addMultiplier('skill', skill.dpsMult);
      }
    }
  }

  /// Process a specific trigger event (called by CombatSystem etc.).
  void processTrigger(
    SkillTriggerType type,
    String heroId, {
    double randomValue = 0.5,
  }) {
    for (final skill in _skills) {
      if (skill.triggerType != type) continue;
      if (randomValue > skill.triggerChance) continue;
      if (!budget.tryConsume(skill.id)) continue;

      dpsPipeline.addMultiplier('skill', skill.dpsMult);

      if (skill.applyBuffId != null) {
        buffManager.apply(
          heroId,
          BuffInstance(
            id: skill.applyBuffId!,
            sourceId: skill.id,
            remainingDuration: skill.buffDuration,
            magnitude: skill.dpsMult - 1.0,
            stat: 'attack',
          ),
        );
      }
    }
  }

  List<SkillDefinition> get skills => List.unmodifiable(_skills);
}
