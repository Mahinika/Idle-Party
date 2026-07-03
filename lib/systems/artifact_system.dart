class Artifact {
  final String id;
  final String name;
  final String description;
  final double baseEffect;
  final String effectType; // "base_stats", "idle_mult", "boss_slayer"
  int level;

  Artifact({
    required this.id,
    required this.name,
    required this.description,
    required this.baseEffect,
    required this.effectType,
    this.level = 0,
  });

  double get currentEffect => level * baseEffect;
}

class ArtifactSystem {
  final Map<String, Artifact> _artifacts = {};

  ArtifactSystem() {
    _registerArtifacts();
  }

  void _registerArtifacts() {
    _artifacts['artifact_stats'] = Artifact(
      id: 'artifact_stats',
      name: 'Cosmic Essence',
      description: 'Increases all base hero stats by +50% per level.',
      baseEffect: 0.50,
      effectType: 'base_stats',
    );
    _artifacts['artifact_idle'] = Artifact(
      id: 'artifact_idle',
      name: 'Chronos Hourglass',
      description: 'Increases offline idle reward values by +25% per level.',
      baseEffect: 0.25,
      effectType: 'idle_mult',
    );
    _artifacts['artifact_boss'] = Artifact(
      id: 'artifact_boss',
      name: 'Slayer Emblem',
      description: 'Increases damage dealt against Bosses by +100% per level.',
      baseEffect: 1.00,
      effectType: 'boss_slayer',
    );
  }

  List<Artifact> get activeArtifacts => _artifacts.values.toList();

  Artifact? getArtifact(String artifactId) {
    return _artifacts[artifactId];
  }

  double getUpgradeCost(String artifactId) {
    final art = getArtifact(artifactId);
    if (art == null) return 0.0;
    return (art.level + 1) * 1.0; // Costs 1 ascension point per level up
  }

  bool tryUpgradeArtifact(String artifactId, double availableAscensionPoints, Function(double cost) onDeduct) {
    final art = getArtifact(artifactId);
    if (art == null) return false;

    final cost = getUpgradeCost(artifactId);
    if (availableAscensionPoints >= cost) {
      art.level++;
      onDeduct(cost);
      return true;
    }
    return false;
  }

  double getBaseStatsMultiplier() {
    return _artifacts['artifact_stats']?.currentEffect ?? 0.0;
  }

  double getIdleMultiplierBonus() {
    return _artifacts['artifact_idle']?.currentEffect ?? 0.0;
  }

  double getBossSlayerMultiplier() {
    return _artifacts['artifact_boss']?.currentEffect ?? 0.0;
  }
}
