# Idle Party - Advanced Idle RPG Engine

A modular, scalable Flutter/Dart-based idle RPG game engine with:
- **Modular Architecture**: Clean separation of concerns with isolated systems and managers
- **Null-Safe Dart**: Complete null-safety implementation
- **JSON-Driven Data**: All game data loaded from JSON files
- **Centralized Orchestration**: GameDirector controls the entire game loop
- **Strict Update Order**: 15-step update pipeline ensuring consistent game state
- **Zero Circular Dependencies**: Clean dependency tree throughout
- **High Performance**: Efficient DPS pipeline with category-based multipliers
- **Easy to Extend**: Clear patterns for adding new systems, heroes, skills, and progression

## Project Structure

```
lib/
├── core/
│   ├── game_director.dart      # Central game orchestrator
│   └── dps_pipeline.dart       # Category-based DPS multiplier system
├── models/
│   ├── hero.dart               # Hero data model
│   ├── enemy.dart              # Enemy data model
│   └── stats.dart              # Character statistics
├── systems/                    # Game systems (each isolated)
│   ├── weather_system.dart
│   ├── event_system.dart
│   ├── dungeon_system.dart
│   ├── buff_system.dart
│   ├── debuff_system.dart
│   ├── skill_system.dart
│   ├── ai_system.dart
│   ├── combat_system.dart
│   ├── economy_system.dart
│   ├── idle_system.dart
│   ├── prestige_system.dart
│   ├── ascension_system.dart
│   ├── formation_system.dart
│   ├── team_dps_system.dart
│   ├── relic_system.dart
│   ├── pet_system.dart
│   ├── rune_system.dart
│   └── artifact_system.dart
├── managers/                   # Game managers
│   ├── buff_manager.dart
│   ├── debuff_manager.dart
│   ├── skill_trigger_budget.dart
│   └── caps_manager.dart
├── data/                       # JSON game data
│   ├── heroes.json
│   ├── enemies.json
│   ├── skills.json
│   ├── items.json
│   ├── dungeon_modifiers.json
│   ├── weather.json
│   └── events.json
└── main.dart
```

## Update Order (Strict)

1. Weather
2. Events
3. Dungeon Modifiers
4. Buffs
5. Debuffs
6. Skills
7. AI
8. Combat
9. Economy
10. Idle
11. Prestige
12. Ascension
13. Meta Progression
14. Loot
15. UI

## Architecture Principles

- **Isolation**: All systems operate independently with clear contracts
- **Data-Driven**: Game mechanics defined in JSON, not hardcoded
- **Dependency Injection**: Systems accept their dependencies as parameters
- **No Global State**: Everything flows through GameDirector
- **Testable**: Each system can be tested independently
- **Extensible**: New systems follow the same pattern

## Getting Started

1. Clone the repository
2. Run `flutter pub get`
3. Run `flutter run`

## Development

See ARCHITECTURE.md for detailed design patterns and guidelines.
