import '../core/dps_pipeline.dart';

/// An artifact that provides a stacking DPS multiplier.
class ArtifactDefinition {
  final String id;
  final String name;
  final double dpsMult;
  final int maxLevel;

  const ArtifactDefinition({
    required this.id,
    required this.name,
    required this.dpsMult,
    required this.maxLevel,
  });

  factory ArtifactDefinition.fromJson(Map<String, dynamic> json) =>
      ArtifactDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        dpsMult: (json['dpsMult'] as num?)?.toDouble() ?? 1.0,
        maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 10,
      );
}

/// ArtifactSystem manages levelled artifacts and their pipeline contributions.
///
/// Update order: step 13 (meta progression).
class ArtifactSystem {
  final DpsPipeline dpsPipeline;
  final List<ArtifactDefinition> _catalogue = [];
  final Map<String, int> _levels = {}; // artifactId -> current level

  ArtifactSystem({required this.dpsPipeline});

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _catalogue
      ..clear()
      ..addAll(
        data
            .where((d) => d['type'] == 'artifact')
            .map(ArtifactDefinition.fromJson),
      );
  }

  void unlockArtifact(String id) => _levels[id] = 1;

  void upgradeArtifact(String id) {
    try {
      final art = _catalogue.firstWhere((a) => a.id == id);
      final current = _levels[id] ?? 0;
      if (current < art.maxLevel) _levels[id] = current + 1;
    } catch (_) {
      // Artifact not found; skip.
    }
  }

  void update(double deltaTime) {
    dpsPipeline.clearCategory('artifact');
    for (final entry in _levels.entries) {
      if (entry.value <= 0) continue;
      try {
        final art = _catalogue.firstWhere((a) => a.id == entry.key);
        // Level scaling: each level adds 10% of base multiplier.
        final scaled = 1.0 + (art.dpsMult - 1.0) * entry.value;
        dpsPipeline.addMultiplier('artifact', scaled);
      } catch (_) {
        // Artifact not found; skip silently.
      }
    }
  }
}
