import 'dart:io';
import 'lib/core/game_director.dart';
import 'lib/systems/formation_system.dart';

void main() {
  print('===========================================================');
  print('       IDLE PARTY - ADVANCED MODULAR RPG ENGINE            ');
  print('===========================================================');

  // 1. Instantiate the GameDirector
  print('[Init] Initializing central GameDirector...');
  final director = GameDirector();

  // 2. Load the JSON-driven data from files
  print('[Init] Loading JSON-driven game data from assets...');
  try {
    final heroesJson = File('lib/data/heroes.json').readAsStringSync();
    final enemiesJson = File('lib/data/enemies.json').readAsStringSync();
    final skillsJson = File('lib/data/skills.json').readAsStringSync();
    final itemsJson = File('lib/data/items.json').readAsStringSync();
    final dungeonModifiersJson = File('lib/data/dungeon_modifiers.json').readAsStringSync();
    final weatherJson = File('lib/data/weather.json').readAsStringSync();
    final eventsJson = File('lib/data/events.json').readAsStringSync();

    director.loadGameData(
      heroesJson: heroesJson,
      enemiesJson: enemiesJson,
      skillsJson: skillsJson,
      itemsJson: itemsJson,
      dungeonModifiersJson: dungeonModifiersJson,
      weatherJson: weatherJson,
      eventsJson: eventsJson,
    );
    print('[Success] Game data loaded successfully!');
  } catch (e) {
    print('[Error] Failed to load JSON files: $e');
    return;
  }

  // Configure initial strategic formation
  print('\n[Setup] Placing Valiant Warrior in the frontline, Fire Mage & Shadow Rogue in the backline...');
  director.formationSystem.assignPosition('hero_warrior', FormationPosition.frontline);
  director.formationSystem.assignPosition('hero_mage', FormationPosition.backline);
  director.formationSystem.assignPosition('hero_rogue', FormationPosition.backline);

  // Print initial party status
  _printPartyStatus(director);

  // 3. Simulate Combat Ticks (Active play)
  print('\n===========================================================');
  print('            SIMULATING ACTIVE COMBAT TICKS                 ');
  print('===========================================================');
  
  // Register a UI update listener for Step 15
  director.addUiListener(() {
    print('[UI Step 15] State updated. Weather: ${director.weatherSystem.currentWeather?.name}. Active Event: ${director.eventSystem.activeEvent?.name}. Zone: ${director.dungeonSystem.currentZone}, Wave: ${director.dungeonSystem.currentWave}/${5}. Gold: ${director.economySystem.gold.toStringAsFixed(1)}');
  });

  for (int tick = 1; tick <= 5; tick++) {
    print('\n--- [Tick $tick] deltaTime: 1.0s ---');
    director.tick(1.0);
    _printLivingEnemies(director);
  }

  // 4. Upgrade Hero Level using accumulated Gold
  print('\n===========================================================');
  print('             UPGRADING AND PROGRESSION                     ');
  print('===========================================================');
  final targetHero = director.heroes.first;
  final upgradeCost = director.economySystem.getUpgradeCost(targetHero);
  print('Current Gold: ${director.economySystem.gold.toStringAsFixed(1)}');
  print('Cost to upgrade ${targetHero.name}: ${upgradeCost.toStringAsFixed(1)}');
  
  if (director.economySystem.tryUpgradeHero(targetHero)) {
    print('[Success] Upgraded ${targetHero.name} to Level ${targetHero.level}!');
    print('New stats: ${targetHero.currentStats}');
  } else {
    print('[Upgrade Failed] Insufficient Gold!');
  }

  // 5. Simulating Offline Idle Rewards (Capped at max hours via CapsManager)
  print('\n===========================================================');
  print('          SIMULATING OFFLINE IDLE REWARDS                  ');
  print('===========================================================');
  const double offlineTime = 12 * 3600.0; // 12 hours offline
  print('Simulating offline progress for ${offlineTime / 3600} hours...');
  
  final previousGold = director.economySystem.gold;

  director.processOfflineProgress(offlineTime);
  
  print('Received gold offline reward: ${(director.economySystem.gold - previousGold).toStringAsFixed(1)}');
  print('Party status after returning offline:');
  _printPartyStatus(director);

  // 6. Prestige Reset
  print('\n===========================================================');
  print('                  PRESTIGE RESET                           ');
  print('===========================================================');
  final pendingPrestige = director.prestigeSystem.calculatePendingPrestigePoints(
    director.dungeonSystem.currentZone,
    director.economySystem.gold,
  );
  print('Pending Prestige Points to earn: ${pendingPrestige.toStringAsFixed(1)}');

  if (director.prestigeSystem.performPrestige(
    heroes: director.heroes,
    dungeonSystem: director.dungeonSystem,
    economySystem: director.economySystem,
  )) {
    print('[Success] Prestige performed! Game reset.');
    print('Prestige Points: ${director.prestigeSystem.totalPrestigePoints.toStringAsFixed(1)}');
    print('Passive Prestige Bonuses active: Damage +${(director.prestigeSystem.dpsMultiplierBonus * 100).toStringAsFixed(0)}%, HP +${(director.prestigeSystem.hpMultiplierBonus * 100).toStringAsFixed(0)}%');
    print('Hero levels reset to: ${targetHero.level}');
    print('Gold reset to: ${director.economySystem.gold}');
  } else {
    print('[Prestige Failed] Must reach at least Zone 5 to Prestige!');
  }
  
  print('\n===========================================================');
  print('          SIMULATION COMPLETED SUCCESSFULLY!                ');
  print('===========================================================');
}

void _printPartyStatus(GameDirector director) {
  print('\n--- PARTY MEMBERS ---');
  for (var hero in director.heroes) {
    print('- [Lvl ${hero.level}] ${hero.name} (${hero.element}) | Position: ${director.formationSystem.getPosition(hero.id).name} | ${hero.currentStats}');
  }
}

void _printLivingEnemies(GameDirector director) {
  print('--- Active Enemies ---');
  for (var enemy in director.enemies) {
    if (enemy.isDead) {
      print('- ${enemy.name} (DEAD)');
    } else {
      print('- ${enemy.name} (Lvl ${enemy.level}) | HP: ${enemy.currentStats.hp.toStringAsFixed(1)}/${enemy.currentStats.maxHp.toStringAsFixed(1)} | Atk: ${enemy.currentStats.attack.toStringAsFixed(1)}');
    }
  }
}
