import 'package:test/test.dart';
import '../lib/core/dps_pipeline.dart';
import '../lib/managers/buff_manager.dart';
import '../lib/managers/skill_trigger_budget.dart';
import '../lib/managers/caps_manager.dart';
import '../lib/models/hero.dart';
import '../lib/models/stats.dart';
import '../lib/systems/dungeon_system.dart';
import '../lib/systems/prestige_system.dart';
import '../lib/systems/economy_system.dart';

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
}
