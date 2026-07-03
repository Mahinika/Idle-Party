import 'dart:convert';
import 'dart:math';
import '../models/hero.dart';
import '../models/enemy.dart';
import '../managers/buff_manager.dart';
import '../managers/debuff_manager.dart';
import '../managers/skill_trigger_budget.dart';
import '../managers/caps_manager.dart';
import '../systems/weather_system.dart';
import '../systems/event_system.dart';
import '../systems/dungeon_system.dart';
import '../systems/buff_system.dart';
import '../systems/debuff_system.dart';
import '../systems/skill_system.dart';
import '../systems/ai_system.dart';
import '../systems/combat_system.dart';
import '../systems/economy_system.dart';
import '../systems/idle_system.dart';
import '../systems/prestige_system.dart';
import '../systems/ascension_system.dart';
import '../systems/formation_system.dart';
import '../systems/relic_system.dart';
import '../systems/pet_system.dart';
import '../systems/rune_system.dart';
import '../systems/artifact_system.dart';
import '../systems/team_dps_system.dart';
import 'dps_pipeline.dart';

class GameDirector {
  // Models
  final List<HeroModel> heroes = [];
  final List<EnemyModel> enemies = [];
  final Random _random = Random();

  // Managers
  final BuffManager buffManager = BuffManager();
  final DebuffManager debuffManager = DebuffManager();
  final SkillTriggerBudget skillTriggerBudget = SkillTriggerBudget();
  final CapsManager capsManager = CapsManager();

  // Systems
  late final WeatherSystem weatherSystem;
  late final EventSystem eventSystem;
  late final DungeonSystem dungeonSystem;
  late final BuffSystem buffSystem;
  late final DebuffSystem debuffSystem;
  late final SkillSystem skillSystem;
  late final AiSystem aiSystem;
  late final CombatSystem combatSystem;
  late final EconomySystem economySystem;
  late final IdleSystem idleSystem;
  late final PrestigeSystem prestigeSystem;
  late final AscensionSystem ascensionSystem;
  late final FormationSystem formationSystem;
  late final RelicSystem relicSystem;
  late final PetSystem petSystem;
  late final RuneSystem runeSystem;
  late final ArtifactSystem artifactSystem;

  // Raw item templates for Loot System
  List<dynamic> _itemTemplates = [];

  // UI callbacks or state listeners
  final List<Function()> _uiListeners = [];

  GameDirector() {
    _initializeSystems();
  }

  void _initializeSystems() {
    weatherSystem = WeatherSystem();
    eventSystem = EventSystem();
    dungeonSystem = DungeonSystem();
    buffSystem = BuffSystem(buffManager);
    debuffSystem = DebuffSystem(debuffManager);
    skillSystem = SkillSystem(buffManager, debuffManager);
    aiSystem = AiSystem(skillSystem);
    
    final dpsPipeline = DpsPipeline();
    combatSystem = CombatSystem(
      dpsPipeline: dpsPipeline,
      skillSystem: skillSystem,
      capsManager: capsManager,
      buffManager: buffManager,
      debuffManager: debuffManager,
    );

    economySystem = EconomySystem();
    
    final teamDpsSystem = TeamDpsSystem();
    idleSystem = IdleSystem(teamDpsSystem, capsManager);
    prestigeSystem = PrestigeSystem();
    ascensionSystem = AscensionSystem();
    formationSystem = FormationSystem();
    relicSystem = RelicSystem();
    petSystem = PetSystem();
    runeSystem = RuneSystem();
    artifactSystem = ArtifactSystem();
  }

  /// Registers a UI/listener callback to be triggered in Step 15.
  void addUiListener(Function() listener) {
    _uiListeners.add(listener);
  }

  /// Loads the entire game state and templates from JSON content.
  void loadGameData({
    required String heroesJson,
    required String enemiesJson,
    required String skillsJson,
    required String itemsJson,
    required String dungeonModifiersJson,
    required String weatherJson,
    required String eventsJson,
  }) {
    // 1. Load skill templates
    skillSystem.loadSkills(jsonDecode(skillsJson) as List);

    // 2. Load weather conditions
    weatherSystem.loadConditions(jsonDecode(weatherJson) as List);

    // 3. Load active events
    eventSystem.loadEvents(jsonDecode(eventsJson) as List);

    // 4. Load dungeon modifiers
    dungeonSystem.loadModifiers(jsonDecode(dungeonModifiersJson) as List);

    // 5. Store items for loot processing
    _itemTemplates = jsonDecode(itemsJson) as List;

    // 6. Spawn active heroes (default level 1)
    final heroList = jsonDecode(heroesJson) as List;
    heroes.clear();
    for (var h in heroList) {
      heroes.add(HeroModel.fromJson(h as Map<String, dynamic>));
    }

    // 7. Store enemy metadata & Spawn first wave
    _enemyTemplates = jsonDecode(enemiesJson) as List;
    spawnNextWave();
  }

  List<dynamic> _enemyTemplates = [];

  /// Spawns the enemies for the current wave/zone.
  void spawnNextWave() {
    enemies.clear();

    if (_enemyTemplates.isEmpty) return;

    final isBoss = dungeonSystem.isBossWave;
    
    if (isBoss) {
      // Find a boss enemy or default to the last template
      final bossJson = _enemyTemplates.firstWhere((e) => e['is_boss'] == true, orElse: () => _enemyTemplates.last);
      final enemy = EnemyModel.fromJson(bossJson as Map<String, dynamic>, level: dungeonSystem.currentZone);
      
      // Apply Dungeon modifier HP boost and scale
      final zoneHp = enemy.currentStats.maxHp * dungeonSystem.zoneHpMultiplier;
      final zoneAtk = enemy.currentStats.attack * dungeonSystem.zoneDamageMultiplier;
      
      enemy.currentStats = enemy.currentStats.copyWith(
        hp: capsManager.clampEnemyHp(zoneHp),
        maxHp: capsManager.clampEnemyHp(zoneHp),
        attack: zoneAtk,
      );
      
      enemies.add(enemy);
    } else {
      // Spawn 1 to 3 standard enemies
      final normalTemplates = _enemyTemplates.where((e) => e['is_boss'] != true).toList();
      if (normalTemplates.isEmpty) normalTemplates.add(_enemyTemplates.first);

      final count = 1 + (dungeonSystem.currentWave % 3); // spawns 1, 2, or 3 enemies
      for (int i = 0; i < count; i++) {
        final template = normalTemplates[i % normalTemplates.length];
        final enemy = EnemyModel.fromJson(template as Map<String, dynamic>, level: dungeonSystem.currentZone);
        
        final zoneHp = enemy.currentStats.maxHp * dungeonSystem.zoneHpMultiplier;
        final zoneAtk = enemy.currentStats.attack * dungeonSystem.zoneDamageMultiplier;
        
        enemy.currentStats = enemy.currentStats.copyWith(
          hp: capsManager.clampEnemyHp(zoneHp),
          maxHp: capsManager.clampEnemyHp(zoneHp),
          attack: zoneAtk,
        );
        
        enemies.add(enemy);
      }
    }
  }

  /// Ticks the complete game engine.
  /// Enforces the MANDATORY 15-step update order.
  void tick(double deltaTime) {
    if (deltaTime <= 0) return;

    // --- STEP 1: Weather ---
    weatherSystem.update(deltaTime);

    // --- STEP 2: Events ---
    eventSystem.update(deltaTime);

    // --- STEP 3: Dungeon Modifiers ---
    dungeonSystem.update(deltaTime);

    // --- STEP 4: Buffs ---
    buffSystem.update(heroes, enemies, deltaTime);

    // --- STEP 5: Debuffs ---
    debuffSystem.update(heroes, enemies, deltaTime);

    // --- STEP 6: Skills ---
    skillSystem.update(heroes, deltaTime);

    // --- STEP 7: AI ---
    skillTriggerBudget.reset();
    final decisions = aiSystem.updateHeroActions(heroes, enemies, skillTriggerBudget);

    // --- STEP 8: Combat ---
    combatSystem.processCombat(
      heroes: heroes,
      enemies: enemies,
      decisions: decisions,
      budget: skillTriggerBudget,
      dungeonSystem: dungeonSystem,
      weatherSystem: weatherSystem,
      eventSystem: eventSystem,
      deltaTime: deltaTime,
      onEnemyDefeated: (gold, xp) {
        // Award rewards
        economySystem.addGold(gold);
        for (var hero in heroes) {
          hero.gainXp(xp / heroes.length);
        }
        
        // Advance wave if all enemies in the wave are dead
        if (enemies.every((e) => e.isDead)) {
          // --- STEP 14: Loot (triggered when enemy dies) ---
          _processLootDrop();
          
          dungeonSystem.advanceWave();
          spawnNextWave();
        }
      },
      onHeroesWiped: () {
        // Heroes are dead: penalize by setting back to wave 1 of current zone and heal them
        dungeonSystem.currentWave = 1;
        for (var hero in heroes) {
          hero.healFully();
        }
        spawnNextWave();
      },
    );

    // --- STEP 9: Economy ---
    final teamDpsSystem = TeamDpsSystem();
    final teamDps = teamDpsSystem.calculateTeamDps(heroes);
    economySystem.update(deltaTime, teamDps);

    // --- STEP 10: Idle ---
    // Normally offline/idle calculation is triggered at startup, 
    // but idle system processes active tracking / capped offline limits here if needed.

    // --- STEP 11: Prestige ---
    // Handled via explicit reset command in prestigeSystem.

    // --- STEP 12: Ascension ---
    // Handled via explicit reset command in ascensionSystem.

    // --- STEP 13: Meta Progression ---
    // Combine relic, pet, and artifact bonuses to scale heroes
    _applyMetaProgressionBonuses();

    // --- STEP 14: Loot ---
    // (Handled incrementally on enemy defeat during Step 8 Combat)

    // --- STEP 15: UI ---
    for (var listener in _uiListeners) {
      listener();
    }
  }

  /// Processes random loot drops from _itemTemplates on enemy defeat.
  void _processLootDrop() {
    if (_itemTemplates.isEmpty) return;
    // 20% chance to drop an item
    if (_random.nextDouble() < 0.20) {
      // Find item
      final item = _itemTemplates[0]; // drop first item as demo
      final goldVal = (item['gold_value'] as num).toDouble();
      economySystem.addGold(goldVal); // sell immediately for gold in simple idle loop
    }
  }

  /// Incorporates meta-progression modifiers (Pets, Relics, Artifacts, Prestige, Ascension, Formations)
  /// and updates heroes' actual stats in the DPS pipeline / stat adjustments.
  void _applyMetaProgressionBonuses() {
    // Prestige bonuses: +2% dmg, +1% hp per prestige point
    final prestigeDmg = prestigeSystem.dpsMultiplierBonus;
    final prestigeHp = prestigeSystem.hpMultiplierBonus;

    // Ascension bonuses: +10% dmg, +5% hp per ascension point
    final ascensionDmg = ascensionSystem.dpsMultiplierBonus;
    final ascensionHp = ascensionSystem.hpMultiplierBonus;

    // Relic bonuses: +5% attack, +5% defense per level
    final relicAttack = relicSystem.getAttackBonusMultiplier();
    final relicDefense = relicSystem.getDefenseBonusMultiplier();

    // Pet bonuses: +3% dps, +4% hp per level
    final petDps = petSystem.getDpsBonusMultiplier();
    final petHp = petSystem.getHpBonusMultiplier();

    // Artifact bonuses: +50% stats scale, +25% idle
    final artifactStatsMult = artifactSystem.getBaseStatsMultiplier();

    for (var hero in heroes) {
      if (hero.isDead) continue;

      // Base stat adjustment
      final baseMultiplier = 1.0 + artifactStatsMult;
      
      // Calculate multiplier bonuses
      final dmgMultiplier = 1.0 + prestigeDmg + ascensionDmg + relicAttack + petDps + formationSystem.getAttackMultiplierBonus(hero.id);
      final hpMultiplier = 1.0 + prestigeHp + ascensionHp + petHp;
      final defMultiplier = 1.0 + relicDefense + formationSystem.getDefenseMultiplierBonus(hero.id);

      // Re-apply adjusted values dynamically
      final baseAtk = hero.baseStats.attack * baseMultiplier * dmgMultiplier;
      final baseMaxHp = hero.baseStats.maxHp * baseMultiplier * hpMultiplier;
      final baseDef = hero.baseStats.defense * baseMultiplier * defMultiplier;

      // Caps Manager check
      hero.currentStats = hero.currentStats.copyWith(
        attack: capsManager.clampHeroStat(baseAtk),
        maxHp: capsManager.clampHeroStat(baseMaxHp),
        defense: capsManager.clampHeroStat(baseDef),
      );
    }
  }

  /// External trigger to apply offline progress rewards when player returns.
  void processOfflineProgress(double elapsedSeconds) {
    final reward = idleSystem.calculateOfflineRewards(heroes, elapsedSeconds);
    
    // Add extra artifact scaling if any
    final artifactIdleBonus = artifactSystem.getIdleMultiplierBonus();
    final finalGold = reward.goldEarned * (1.0 + artifactIdleBonus + relicSystem.getGoldBonusMultiplier());
    final finalXp = reward.xpEarned;

    economySystem.addGold(finalGold);
    for (var hero in heroes) {
      hero.gainXp(finalXp / heroes.length);
    }
  }
}
