import 'dart:math';
import '../models/hero.dart';
import '../models/enemy.dart';
import '../core/dps_pipeline.dart';
import '../managers/skill_trigger_budget.dart';
import '../managers/caps_manager.dart';
import '../managers/buff_manager.dart';
import '../managers/debuff_manager.dart';
import 'ai_system.dart';
import 'skill_system.dart';
import 'dungeon_system.dart';
import 'weather_system.dart';
import 'event_system.dart';
import 'rune_system.dart';
import 'inventory_system.dart';
import 'skill_tree_system.dart';

class CombatSystem {
  final DpsPipeline dpsPipeline;
  final SkillSystem skillSystem;
  final CapsManager capsManager;
  final BuffManager buffManager;
  final DebuffManager debuffManager;
  final RuneSystem? runeSystem;
  final InventorySystem? inventorySystem;
  final SkillTreeSystem? skillTreeSystem;
  final Random _random = Random();

  CombatSystem({
    required this.dpsPipeline,
    required this.skillSystem,
    required this.capsManager,
    required this.buffManager,
    required this.debuffManager,
    this.runeSystem,
    this.inventorySystem,
    this.skillTreeSystem,
  });

  /// Processes hero decisions and handles enemy retaliation.
  void processCombat({
    required List<HeroModel> heroes,
    required List<EnemyModel> enemies,
    required List<AiDecision> decisions,
    required SkillTriggerBudget budget,
    required DungeonSystem dungeonSystem,
    required WeatherSystem weatherSystem,
    required EventSystem eventSystem,
    required double deltaTime,
    required Function(double gold, double xp) onEnemyDefeated,
    required Function() onHeroesWiped,
  }) {
    final activeEnemies = enemies.where((e) => !e.isDead).toList();
    if (activeEnemies.isEmpty) return;

    // 1. Process Hero Decisions (Attacks)
    for (var decision in decisions) {
      if (decision.actor.isDead || decision.target.isDead) continue;

      double baseDmg = decision.actor.currentStats.attack;
      double actionMultiplier = 1.0;

      if (decision.actionType == 'skill' && decision.skillId != null) {
        final cdMultiplier = skillTreeSystem?.getCooldownReductionMultiplier(decision.actor.id) ?? 1.0;
        actionMultiplier = skillSystem.tryCastSkill(
          decision.actor,
          decision.skillId!,
          enemies,
          budget,
          heroes,
          cdMultiplier,
        );
        if (actionMultiplier == 0.0) {
          // If cast failed (e.g. cooldown/budget), fallback to normal attack
          actionMultiplier = 1.0;
        }
      }

      // 2. Set up DPS Pipeline for the category multipliers
      dpsPipeline.clear();
      
      // Category 1: Skill action multiplier
      dpsPipeline.addBonus(MultiplierCategory.skill, actionMultiplier - 1.0);

      // Category 2: Weather effects
      dpsPipeline.addBonus(MultiplierCategory.weather, weatherSystem.dpsMultiplier - 1.0);

      // Category 3: Event effects
      // We can assume events might boost dps indirectly or directly
      dpsPipeline.addBonus(MultiplierCategory.event, eventSystem.activeEvent?.id == 'event_frenzy' ? 0.50 : 0.0);

      // Category 4: Dungeon modifiers
      dpsPipeline.addBonus(MultiplierCategory.dungeon, dungeonSystem.activeModifier?.damageMultiplier ?? 1.0 - 1.0);

      // Category 5: Buffs on Hero
      double attackBuff = buffManager.getMultiplierBonus(decision.actor, 'attack_boost', 0.15);
      dpsPipeline.addBonus(MultiplierCategory.buff, attackBuff);

      // Category 6: Debuffs on Enemy
      double vulnerability = debuffManager.getMultiplierBonus(decision.target, 'scorch_vulnerability', 0.20);
      dpsPipeline.addBonus(MultiplierCategory.debuff, vulnerability);

      // Category Rune: Rune bonuses from direct socketing and equipped items
      double runeFireBonus = runeSystem?.getFireDamageBonus(decision.actor.id) ?? 0.0;
      double equippedRuneFire = 0.0;
      if (inventorySystem != null) {
        final equippedItems = inventorySystem!.getEquippedItems(decision.actor.id);
        for (var item in equippedItems) {
          for (var rune in item.socketedRunes) {
            if (rune.type == RuneType.fire) {
              equippedRuneFire += rune.power;
            }
          }
        }
      }
      dpsPipeline.addBonus(MultiplierCategory.rune, runeFireBonus + equippedRuneFire);

      // Process raw damage from pipeline
      double calculatedDmg = dpsPipeline.process(baseDmg);

      // Category 7: Crit check (Combat category)
      final isCrit = _random.nextDouble() < decision.actor.currentStats.critRate;
      if (isCrit) {
        calculatedDmg *= decision.actor.currentStats.critDamage;
      }

      // Defense reduction: Damage = Max(1, Damage - target.defense * weather_penalty)
      final effectiveDefense = decision.target.currentStats.defense * weatherSystem.defenseMultiplier;
      double finalDamage = (calculatedDmg - effectiveDefense).clamp(1.0, double.infinity);

      // Enemy Effective HP Cap Check (via caps manager)
      finalDamage = capsManager.clampHeroStat(finalDamage);

      // Poison on attack from Skill Tree
      final poisonChance = skillTreeSystem?.getPoisonChance(decision.actor.id) ?? 0.0;
      if (poisonChance > 0.0 && _random.nextDouble() < poisonChance) {
        debuffManager.applyDebuff(decision.target, 'poison', 4.0);
      }

      // Apply Damage
      decision.target.takeDamage(finalDamage);

      // Check Boss Phases
      if (decision.target.isBoss) {
        _handleBossPhases(decision.target);
      }

      // Handle Enemy Death
      if (decision.target.isDead) {
        final scaledGold = decision.target.goldReward * dungeonSystem.zoneGoldMultiplier * eventSystem.goldMultiplier;
        final scaledXp = decision.target.level * 10.0 * dungeonSystem.zoneXpMultiplier * eventSystem.xpMultiplier;
        onEnemyDefeated(scaledGold, scaledXp);
        
        // If all enemies are dead, stop processing this tick
        if (enemies.every((e) => e.isDead)) {
          return;
        }
      }
    }

    // 3. Enemy Retaliation
    final livingHeroes = heroes.where((h) => !h.isDead).toList();
    if (livingHeroes.isEmpty) {
      onHeroesWiped();
      return;
    }

    final livingEnemies = enemies.where((e) => !e.isDead).toList();
    for (var enemy in livingEnemies) {
      // Enemy attacks a random or first hero
      final targetHero = livingHeroes[_random.nextInt(livingHeroes.length)];
      
      // Basic enemy attack formula
      double enemyAtk = enemy.currentStats.attack;
      
      // Debuff check on enemy (e.g. burn reduces attack by 10% per stack)
      if (debuffManager.hasDebuff(enemy, 'burn')) {
        final burnStacks = debuffManager.getStacks(enemy, 'burn');
        enemyAtk *= (1.0 - burnStacks * 0.05).clamp(0.5, 1.0);
      }

      final heroDefense = targetHero.currentStats.defense;
      double damageToHero = (enemyAtk - heroDefense).clamp(1.0, double.infinity);
      
      targetHero.takeDamage(damageToHero);

      if (heroes.every((h) => h.isDead)) {
        onHeroesWiped();
        return;
      }
    }
  }

  /// Special feature: Boss changes behaviour or boosts stats in critical phases (e.g., at 50% HP)
  void _handleBossPhases(EnemyModel boss) {
    final hpPct = boss.currentStats.hp / boss.currentStats.maxHp;
    if (hpPct <= 0.50 && !buffManager.hasBuff(boss, 'attack_boost')) {
      // Apply Frenzy buff to the boss
      buffManager.applyBuff(boss, 'attack_boost', 30.0); // 30 seconds attack boost
      // Boost the base attack stats directly
      boss.currentStats = boss.currentStats.copyWith(
        attack: boss.currentStats.attack * 1.5,
      );
    }
  }
}
