import '../core/dps_pipeline.dart';

/// A relic loaded from JSON.
class RelicDefinition {
  final String id;
  final String name;
  final double dpsMult;

  const RelicDefinition({
    required this.id,
    required this.name,
    required this.dpsMult,
  });

  factory RelicDefinition.fromJson(Map<String, dynamic> json) =>
      RelicDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        dpsMult: (json['dpsMult'] as num?)?.toDouble() ?? 1.0,
      );
}

/// RelicSystem manages collected relics and their pipeline contributions.
///
/// Update order: step 13 (meta progression).
class RelicSystem {
  final DpsPipeline dpsPipeline;
  final List<RelicDefinition> _catalogue = [];
  final List<String> _equippedIds = [];

  RelicSystem({required this.dpsPipeline});

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _catalogue
      ..clear()
      ..addAll(
        data
            .where((d) => d['type'] == 'relic')
            .map(RelicDefinition.fromJson),
      );
  }

  void equipRelic(String id) {
    if (!_equippedIds.contains(id)) _equippedIds.add(id);
  }

  void unequipRelic(String id) => _equippedIds.remove(id);

  void update(double deltaTime) {
    dpsPipeline.clearCategory('relic');
    for (final id in _equippedIds) {
      try {
        final relic = _catalogue.firstWhere((r) => r.id == id);
        dpsPipeline.addMultiplier('relic', relic.dpsMult);
      } catch (_) {
        // Relic not found in catalogue; skip silently.
      }
    }
  }
}
