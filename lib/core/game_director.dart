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
import '../systems/team_dps_system.dart';
import '../systems/relic_system.dart';
import '../systems/pet_system.dart';
import '../systems/rune_system.dart';
import '../systems/artifact_system.dart';
import '../managers/buff_manager.dart';
import '../managers/debuff_manager.dart';
import '../managers/skill_trigger_budget.dart';
import '../managers/caps_manager.dart';
import 'dps_pipeline.dart';

/// GameDirector is the single entry-point that owns every system and manager.
/// It enforces the mandatory 15-step update order every game tick.
///
/// Dependency injection: each system receives only the managers/pipelines it
/// needs via constructor parameters, preventing circular imports.
class GameDirector {
  // ── Shared infrastructure ────────────────────────────────────────────────
  final DpsPipeline dpsPipeline;
  final BuffManager buffManager;
  final DebuffManager debuffManager;
  final SkillTriggerBudget skillTriggerBudget;
  final CapsManager capsManager;

  // ── Systems (owned here, never imported cross-system) ─────────────────────
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
  // Formation, TeamDps, Relic, Pet, Rune, Artifact are auxiliary.
  late final FormationSystem formationSystem;
  late final TeamDpsSystem teamDpsSystem;
  late final RelicSystem relicSystem;
  late final PetSystem petSystem;
  late final RuneSystem runeSystem;
  late final ArtifactSystem artifactSystem;

  bool _running = false;

  GameDirector({
    DpsPipeline? dpsPipeline,
    BuffManager? buffManager,
    DebuffManager? debuffManager,
    SkillTriggerBudget? skillTriggerBudget,
    CapsManager? capsManager,
  })  : dpsPipeline = dpsPipeline ?? DpsPipeline(),
        buffManager = buffManager ?? BuffManager(),
        debuffManager = debuffManager ?? DebuffManager(),
        skillTriggerBudget = skillTriggerBudget ?? SkillTriggerBudget(),
        capsManager = capsManager ?? CapsManager() {
    _initSystems();
  }

  void _initSystems() {
    weatherSystem = WeatherSystem();
    eventSystem = EventSystem();
    dungeonSystem = DungeonSystem();
    buffSystem = BuffSystem(buffManager: buffManager);
    debuffSystem = DebuffSystem(debuffManager: debuffManager);
    skillSystem = SkillSystem(
      budget: skillTriggerBudget,
      buffManager: buffManager,
      dpsPipeline: dpsPipeline,
    );
    aiSystem = AiSystem();
    combatSystem = CombatSystem(
      dpsPipeline: dpsPipeline,
      capsManager: capsManager,
    );
    economySystem = EconomySystem(capsManager: capsManager);
    idleSystem = IdleSystem(capsManager: capsManager);
    prestigeSystem = PrestigeSystem();
    ascensionSystem = AscensionSystem();
    formationSystem = FormationSystem();
    teamDpsSystem = TeamDpsSystem(dpsPipeline: dpsPipeline);
    relicSystem = RelicSystem(dpsPipeline: dpsPipeline);
    petSystem = PetSystem();
    runeSystem = RuneSystem(dpsPipeline: dpsPipeline);
    artifactSystem = ArtifactSystem(dpsPipeline: dpsPipeline);
  }

  /// Load JSON game data into all systems.
  Future<void> initialize(GameData data) async {
    await weatherSystem.loadData(data.weather);
    await eventSystem.loadData(data.events);
    await dungeonSystem.loadData(data.dungeonModifiers);
    await skillSystem.loadData(data.skills);
    await combatSystem.loadData(data.enemies);
    await economySystem.loadData(data.items);
    await relicSystem.loadData(data.items);
    await artifactSystem.loadData(data.items);
    _running = true;
  }

  bool get isRunning => _running;

  /// Execute one full game tick following the mandatory 15-step update order.
  void tick(double deltaTime) {
    if (!_running) return;

    // ── 1. Weather ────────────────────────────────────────────────────────
    weatherSystem.update(deltaTime, dpsPipeline);

    // ── 2. Events ─────────────────────────────────────────────────────────
    eventSystem.update(deltaTime, dpsPipeline);

    // ── 3. Dungeon Modifiers ──────────────────────────────────────────────
    dungeonSystem.updateModifiers(deltaTime, dpsPipeline);

    // ── 4. Buffs ──────────────────────────────────────────────────────────
    buffSystem.update(deltaTime);

    // ── 5. Debuffs ────────────────────────────────────────────────────────
    debuffSystem.update(deltaTime);

    // ── 6. Skills ─────────────────────────────────────────────────────────
    skillTriggerBudget.resetForTick();
    skillSystem.update(deltaTime);

    // ── 7. AI ─────────────────────────────────────────────────────────────
    aiSystem.update(deltaTime, dungeonSystem.currentEnemy);

    // ── 8. Combat ─────────────────────────────────────────────────────────
    combatSystem.update(deltaTime);

    // ── 9. Economy ────────────────────────────────────────────────────────
    economySystem.update(deltaTime);

    // ── 10. Idle ──────────────────────────────────────────────────────────
    idleSystem.update(deltaTime);

    // ── 11. Prestige ──────────────────────────────────────────────────────
    prestigeSystem.update(deltaTime);

    // ── 12. Ascension ─────────────────────────────────────────────────────
    ascensionSystem.update(deltaTime);

    // ── 13. Meta Progression (relics, pets, runes, artifacts) ─────────────
    relicSystem.update(deltaTime);
    petSystem.update(deltaTime);
    runeSystem.update(deltaTime);
    artifactSystem.update(deltaTime);

    // ── 14. Loot (dungeon wave resolution) ────────────────────────────────
    dungeonSystem.resolveLoot(deltaTime, economySystem);

    // ── 15. UI (formation / team DPS snapshot for render layer) ───────────
    formationSystem.update(deltaTime);
    teamDpsSystem.snapshot();
  }

  void stop() => _running = false;
}

/// Thin data-transfer object carrying pre-loaded JSON maps.
class GameData {
  final List<Map<String, dynamic>> heroes;
  final List<Map<String, dynamic>> enemies;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> dungeonModifiers;
  final List<Map<String, dynamic>> weather;
  final List<Map<String, dynamic>> events;

  const GameData({
    required this.heroes,
    required this.enemies,
    required this.skills,
    required this.items,
    required this.dungeonModifiers,
    required this.weather,
    required this.events,
  });
}
