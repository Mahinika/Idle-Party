import 'package:test/test.dart';
import '../lib/core/dps_pipeline.dart';
import '../lib/managers/buff_manager.dart';
import '../lib/managers/skill_trigger_budget.dart';
import '../lib/managers/caps_manager.dart';
import '../lib/models/hero.dart';
import '../lib/models/enemy.dart';
import '../lib/models/stats.dart';
import '../lib/systems/dungeon_system.dart';
import '../lib/systems/prestige_system.dart';
import '../lib/systems/economy_system.dart';
import '../lib/systems/inventory_system.dart';
import '../lib/systems/skill_tree_system.dart';
import '../lib/systems/rune_system.dart';
import '../lib/systems/ai_system.dart';
import '../lib/core/game_director.dart';

void main() {
  group('DPS Pipeline Tests', () {
    test('Category-based multipliers should apply correctly and be additive within categories', () {
      final pipeline = DpsPipeline();
      
      // Add multiple bonuses to same category (category multiplier: 1.0 + sum of bonuses: 0.15 + 0.10 = 1.25)
      pipeline.addBonus(MultiplierCategory.buff, 0.15);
      pipeline.addBonus(MultiplierCategory.buff, 0.10);
      
      // Add bonus to another category (multiplicative: 1.0 + 0.20 = 1.20)
      pipeline.addBonus(MultiplierCategory.weather, 0.20);
      
      final result = pipeline.process(100.0);
      
      // Expected: 100 * (1.0 + 0.25) * (1.0 + 0.20) = 100 * 1.25 * 1.20 = 150.0
      expect(result, closeTo(150.0, 0.001));
    });
  });

  group('Buff Manager Tests', () {
    test('Buff stacking rules should respect configured maximum stacks', () {
      final hero = HeroModel(
        id: 'test_hero',
        name: 'Test Hero',
        element: 'Physical',
        baseStats: const Stats(hp: 100, maxHp: 100, attack: 10, defense: 5, speed: 1.0, critRate: 0.1, critDamage: 1.5),
      );
      
      final buffManager = BuffManager();
      buffManager.setMaxStacks('test_buff', 3);
      
      // Apply buff multiple times
      buffManager.applyBuff(hero, 'test_buff', 10.0);
      buffManager.applyBuff(hero, 'test_buff', 10.0);
      buffManager.applyBuff(hero, 'test_buff', 10.0);
      buffManager.applyBuff(hero, 'test_buff', 10.0); // 4th application, should cap at 3
      
      expect(buffManager.getStacks(hero, 'test_buff'), 3);
      expect(buffManager.hasBuff(hero, 'test_buff'), isTrue);
    });

    test('Buffs should tick down and expire correctly', () {
      final hero = HeroModel(
        id: 'test_hero',
        name: 'Test Hero',
        element: 'Physical',
        baseStats: const Stats(hp: 100, maxHp: 100, attack: 10, defense: 5, speed: 1.0, critRate: 0.1, critDamage: 1.5),
      );
      
      final buffManager = BuffManager();
      buffManager.applyBuff(hero, 'test_buff', 5.0);
      
      // Tick down by 2.0s
      buffManager.tickBuffs(hero, 2.0);
      expect(buffManager.hasBuff(hero, 'test_buff'), isTrue);
      
      // Tick down by another 4.0s (total 6.0s) -> should expire
      final expired = buffManager.tickBuffs(hero, 4.0);
      expect(expired, contains('test_buff'));
      expect(buffManager.hasBuff(hero, 'test_buff'), isFalse);
    });
  });

  group('Skill Trigger Budget Tests', () {
    test('Budget should block triggers when exhausted to prevent infinite loops', () {
      final budget = SkillTriggerBudget(maxTriggersPerTick: 3);
      
      expect(budget.tryTrigger(), isTrue);
      expect(budget.tryTrigger(), isTrue);
      expect(budget.tryTrigger(), isTrue);
      expect(budget.tryTrigger(), isFalse); // exhausted
      expect(budget.isExhausted, isTrue);
      
      budget.reset();
      expect(budget.isExhausted, isFalse);
      expect(budget.tryTrigger(), isTrue);
    });
  });

  group('Caps Manager Tests', () {
    test('Caps should clamp stats and idle durations correctly', () {
      final caps = CapsManager();
      
      expect(caps.clampIdleTime(100000.0), closeTo(86400.0, 0.001)); // max 24 hrs
      expect(caps.clampHeroStat(1e60), closeTo(1e50, 0.001)); // max hero power cap
    });
  });

  group('Dungeon and Progression Tests', () {
    test('Zone scaling and wave progress should work correctly', () {
      final dungeon = DungeonSystem();
      expect(dungeon.currentZone, 1);
      expect(dungeon.currentWave, 1);
      expect(dungeon.isBossWave, isFalse);
      
      // Advance 4 times to reach wave 5 (boss wave)
      dungeon.advanceWave();
      dungeon.advanceWave();
      dungeon.advanceWave();
      dungeon.advanceWave();
      
      expect(dungeon.currentWave, 5);
      expect(dungeon.isBossWave, isTrue);
      
      // Defeating boss advances zone
      dungeon.advanceWave();
      expect(dungeon.currentZone, 2);
      expect(dungeon.currentWave, 1);
    });
  });

  group('Prestige System Tests', () {
    test('Prestige reset should award points and revert progression', () {
      final heroes = [
        HeroModel(
          id: 'hero_1',
          name: 'Hero 1',
          element: 'Physical',
          baseStats: const Stats(hp: 100, maxHp: 100, attack: 10, defense: 5, speed: 1.0, critRate: 0.1, critDamage: 1.5),
        )
      ];
      heroes.first.level = 10;
      heroes.first.recalculateStats();

      final dungeon = DungeonSystem();
      dungeon.currentZone = 6;

      final economy = EconomySystem();
      economy.gold = 50000.0;

      final prestige = PrestigeSystem();
      final pending = prestige.calculatePendingPrestigePoints(dungeon.currentZone, economy.gold);
      expect(pending, greaterThan(0.0));

      final success = prestige.performPrestige(
        heroes: heroes,
        dungeonSystem: dungeon,
        economySystem: economy,
      );

      expect(success, isTrue);
      expect(prestige.totalPrestigePoints, closeTo(pending, 0.001));
      expect(heroes.first.level, 1);
      expect(dungeon.currentZone, 1);
      expect(economy.gold, 100.0);
    });
  });

  group('Idle System Offline Progress & Timestamp Tests', () {
    test('Timestamp saving and calculation of offline time works correctly', () {
      final director = GameDirector();
      final now = DateTime(2026, 7, 3, 12, 0, 0);
      final later = now.add(const Duration(hours: 4));

      director.idleSystem.saveTimestamp(now);
      final elapsed = director.idleSystem.getElapsedOfflineSeconds(later);

      expect(elapsed, closeTo(4 * 3600.0, 0.001));
    });
  });

  group('Inventory & Equipment System Tests', () {
    test('Adding, equipping, unequipping items and calculating stat boosts works correctly', () {
      final inventory = InventorySystem();
      final item = Item(
        id: 'sword_epic',
        name: 'Dragontooth Blade',
        slot: 'Weapon',
        attackBoost: 50.0,
        defenseBoost: 10.0,
        rarity: 'Epic',
        goldValue: 500.0,
      );

      inventory.addItem(item);
      expect(inventory.items, contains(item));

      final equipped = inventory.equipItem('hero_warrior', item);
      expect(equipped, isTrue);
      expect(inventory.items, isNot(contains(item)));
      expect(inventory.getEquippedItemInSlot('hero_warrior', 'Weapon'), item);

      final atkBoost = inventory.getHeroAttackBoost('hero_warrior');
      final defBoost = inventory.getHeroDefenseBoost('hero_warrior');
      expect(atkBoost, closeTo(50.0, 0.001));
      expect(defBoost, closeTo(10.0, 0.001));

      final unequipped = inventory.unequipItem('hero_warrior', 'Weapon');
      expect(unequipped, item);
      expect(inventory.items, contains(item));
    });
  });

  group('Tactical AI System & Healing Skill Tests', () {
    test('Healing skills heal the lowest-HP hero and Tactical AI targets appropriately', () {
      final director = GameDirector();
      
      // Load raw skill list so that 'healing_touch' is recognized by the skill system
      director.skillSystem.loadSkills([
        {
          "id": "healing_touch",
          "name": "Healing Touch",
          "cooldown": 8.0,
          "damage_multiplier": 0.0,
          "effect_type": "heal",
          "effect_id": "heal_30",
          "effect_duration": 0.0,
          "description": "Heals the most wounded ally for 30% of their max HP."
        }
      ]);

      final hero = HeroModel(
        id: 'hero_warrior',
        name: 'Valiant Warrior',
        element: 'Physical',
        baseStats: const Stats(hp: 100, maxHp: 100, attack: 10, defense: 5, speed: 1.0, critRate: 0.1, critDamage: 1.5),
        skills: ['healing_touch'],
      );
      hero.takeDamage(80.0); // HP is 20/100 (which is < 30%)
      expect(hero.currentStats.hp, closeTo(20.0, 0.001));

      director.heroes.clear();
      director.heroes.add(hero);

      // Add a live enemy so updating hero actions produces decisions
      director.enemies.clear();
      director.enemies.add(EnemyModel(
        id: 'test_enemy',
        name: 'Test Enemy',
        element: 'Physical',
        baseStats: const Stats(hp: 100, maxHp: 100, attack: 5, defense: 2, speed: 1.0, critRate: 0.0, critDamage: 1.0),
        goldReward: 10.0,
        level: 1,
        isBoss: false,
      ));

      // AI should choose healing_touch because prioritizeHealingUnder30 is true and hero HP is < 30%
      director.aiSystem.prioritizeHealingUnder30 = true;
      final decisions = director.aiSystem.updateHeroActions(director.heroes, director.enemies, director.skillTriggerBudget);
      expect(decisions.first.skillId, 'healing_touch');

      // Execute combat which casts healing_touch and heals the hero
      director.combatSystem.processCombat(
        heroes: director.heroes,
        enemies: director.enemies,
        decisions: decisions,
        budget: director.skillTriggerBudget,
        dungeonSystem: director.dungeonSystem,
        weatherSystem: director.weatherSystem,
        eventSystem: director.eventSystem,
        deltaTime: 1.0,
        onEnemyDefeated: (_, __) {},
        onHeroesWiped: () {},
      );

      // Healed by 30% of maxHp (30 HP) -> 20 + 30 = 50 HP.
      // Then enemy retaliates and deals (5 attack - 5 defense) clamp 1.0 = 1.0 damage -> 49.0 HP.
      expect(hero.currentStats.hp, closeTo(49.0, 0.001));
    });

    test('AI system respects lowest-HP priority and focus boss priority', () {
      final director = GameDirector();
      
      // Add a hero so updating hero actions produces decisions
      director.heroes.clear();
      director.heroes.add(HeroModel(
        id: 'hero_warrior',
        name: 'Valiant Warrior',
        element: 'Physical',
        baseStats: const Stats(hp: 100, maxHp: 100, attack: 10, defense: 5, speed: 1.0, critRate: 0.1, critDamage: 1.5),
      ));

      final dummyEnemy1 = EnemyModel(
        id: 'enemy_1',
        name: 'Enemy 1',
        element: 'Physical',
        baseStats: const Stats(hp: 100, maxHp: 100, attack: 5, defense: 2, speed: 1.0, critRate: 0.0, critDamage: 1.0),
        goldReward: 10.0,
        level: 1,
        isBoss: false,
      );
      final dummyEnemy2 = EnemyModel(
        id: 'enemy_2',
        name: 'Enemy 2 (Boss)',
        element: 'Physical',
        baseStats: const Stats(hp: 500, maxHp: 500, attack: 20, defense: 10, speed: 1.0, critRate: 0.0, critDamage: 1.0),
        goldReward: 100.0,
        level: 1,
        isBoss: true,
      );

      director.enemies.clear();
      director.enemies.addAll([dummyEnemy1, dummyEnemy2]);

      // Set target priority to lowest HP -> should target enemy_1
      director.aiSystem.priority = AiPriority.lowest_hp;
      var decisions = director.aiSystem.updateHeroActions(director.heroes, director.enemies, director.skillTriggerBudget);
      expect(decisions.first.target.id, 'enemy_1');

      // Set target priority to focus boss -> should target enemy_2 (boss)
      director.aiSystem.priority = AiPriority.focus_boss;
      decisions = director.aiSystem.updateHeroActions(director.heroes, director.enemies, director.skillTriggerBudget);
      expect(decisions.first.target.id, 'enemy_2');
    });
  });

  group('Rune Fusion & Socketing Tests', () {
    test('Fusing runes increases power and socketed item runes boost hero dps/stats', () {
      final runeSystem = RuneSystem();
      final rune1 = Rune(id: 'rune_speed_1', name: 'Speed Rune', type: RuneType.speed, power: 0.05);
      final rune2 = Rune(id: 'rune_speed_2', name: 'Speed Rune', type: RuneType.speed, power: 0.05);

      final fused = runeSystem.fuseRunes(rune1, rune2);
      expect(fused, isNotNull);
      expect(fused!.type, RuneType.speed);
      expect(fused.power, closeTo(0.125, 0.0001)); // (0.05 + 0.05) * 1.25 = 0.125
    });
  });

  group('Skill Tree System Tests', () {
    test('Heroes gain skill points on level up and can allocate to passive bonuses', () {
      final hero = HeroModel(
        id: 'hero_warrior',
        name: 'Valiant Warrior',
        element: 'Physical',
        baseStats: const Stats(hp: 100, maxHp: 100, attack: 10, defense: 5, speed: 1.0, critRate: 0.1, critDamage: 1.5),
      );

      expect(hero.skillPoints, 0);
      hero.levelUp();
      expect(hero.skillPoints, 1);

      final skillTree = SkillTreeSystem();
      final upgraded = skillTree.tryUpgradeNode(hero, 'crit_rate_boost');
      expect(upgraded, isTrue);
      expect(hero.skillPoints, 0);
      expect(skillTree.getNodeLevel(hero.id, 'crit_rate_boost'), 1);
      expect(skillTree.getCritRateBonus(hero.id), closeTo(0.02, 0.001));
    });
  });
}
