import '../core/dps_pipeline.dart';

/// A rune that provides a DPS multiplier.
class RuneDefinition {
  final String id;
  final String name;
  final double dpsMult;
  final int tier; // higher tier = more powerful

  const RuneDefinition({
    required this.id,
    required this.name,
    required this.dpsMult,
    required this.tier,
  });

  factory RuneDefinition.fromJson(Map<String, dynamic> json) => RuneDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        dpsMult: (json['dpsMult'] as num?)?.toDouble() ?? 1.0,
        tier: (json['tier'] as num?)?.toInt() ?? 1,
      );
}

/// RuneSystem manages socketed runes and their pipeline contributions.
///
/// Update order: step 13 (meta progression).
class RuneSystem {
  final DpsPipeline dpsPipeline;
  final List<RuneDefinition> _catalogue = [];
  final List<String> _socketedIds = [];

  RuneSystem({required this.dpsPipeline});

  Future<void> loadData(List<Map<String, dynamic>> data) async {
    _catalogue
      ..clear()
      ..addAll(
        data
            .where((d) => d['type'] == 'rune')
            .map(RuneDefinition.fromJson),
      );
  }

  void socketRune(String id) {
    if (!_socketedIds.contains(id)) _socketedIds.add(id);
  }

  void unsocketRune(String id) => _socketedIds.remove(id);

  void update(double deltaTime) {
    dpsPipeline.clearCategory('rune');
    for (final id in _socketedIds) {
      try {
        final rune = _catalogue.firstWhere((r) => r.id == id);
        dpsPipeline.addMultiplier('rune', rune.dpsMult);
      } catch (_) {
        // Rune not found; skip silently.
      }
    }
  }
}
