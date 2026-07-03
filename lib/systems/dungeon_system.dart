import 'dart:math';

class DungeonModifier {
  final String id;
  final String name;
  final double hpMultiplier;
  final double damageMultiplier;
  final double goldMultiplier;
  final String description;

  DungeonModifier({
    required this.id,
    required this.name,
    required this.hpMultiplier,
    required this.damageMultiplier,
    required this.goldMultiplier,
    required this.description,
  });

  factory DungeonModifier.fromJson(Map<String, dynamic> json) {
    return DungeonModifier(
      id: json['id'] as String,
      name: json['name'] as String,
      hpMultiplier: (json['hp_multiplier'] as num).toDouble(),
      damageMultiplier: (json['damage_multiplier'] as num).toDouble(),
      goldMultiplier: (json['gold_multiplier'] as num).toDouble(),
      description: json['description'] as String,
    );
  }
}

class DungeonSystem {
  final List<DungeonModifier> _modifiers = [];
  DungeonModifier? _activeModifier;
  
  int currentZone = 1;
  int currentWave = 1;
  static const int wavesPerZone = 5;

  DungeonSystem();

  void loadModifiers(List<dynamic> jsonData) {
    _modifiers.clear();
    for (var item in jsonData) {
      _modifiers.add(DungeonModifier.fromJson(item as Map<String, dynamic>));
    }
    if (_modifiers.isNotEmpty) {
      _activeModifier = _modifiers.first;
    }
  }

  DungeonModifier? get activeModifier => _activeModifier;

  bool get isBossWave => currentWave == wavesPerZone;

  /// Updates dungeon zone modifiers based on current zone level.
  /// Harder zones apply harder modifiers.
  void update(double deltaTime) {
    if (_modifiers.isEmpty) return;

    if (currentZone >= 10) {
      _activeModifier = _modifiers.firstWhere((m) => m.id == 'modifier_nightmare', orElse: () => _modifiers.last);
    } else if (currentZone >= 5) {
      _activeModifier = _modifiers.firstWhere((m) => m.id == 'modifier_hard', orElse: () => _modifiers.last);
    } else {
      _activeModifier = _modifiers.firstWhere((m) => m.id == 'modifier_easy', orElse: () => _modifiers.first);
    }
  }

  void advanceWave() {
    if (isBossWave) {
      // Boss defeated! Advance zone
      currentZone++;
      currentWave = 1;
    } else {
      currentWave++;
    }
  }

  void resetToZone(int zone) {
    currentZone = zone;
    currentWave = 1;
  }

  // Zone scaling factors
  double get zoneHpMultiplier => pow(1.15, currentZone - 1).toDouble() * (_activeModifier?.hpMultiplier ?? 1.0);
  double get zoneDamageMultiplier => pow(1.10, currentZone - 1).toDouble() * (_activeModifier?.damageMultiplier ?? 1.0);
  double get zoneGoldMultiplier => pow(1.20, currentZone - 1).toDouble() * (_activeModifier?.goldMultiplier ?? 1.0);
  double get zoneXpMultiplier => pow(1.12, currentZone - 1).toDouble();
}
