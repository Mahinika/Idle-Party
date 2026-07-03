import '../core/dps_pipeline.dart';
import '../models/hero.dart';

/// Calculates and caches the team's combined DPS for the UI layer.
///
/// Update order: step 15 (snapshot only, no mutation).
class TeamDpsSystem {
  final DpsPipeline dpsPipeline;
  final List<HeroState> _party = [];
  double _lastSnapshotDps = 0.0;

  TeamDpsSystem({required this.dpsPipeline});

  void setParty(List<HeroState> party) {
    _party
      ..clear()
      ..addAll(party);
  }

  double get teamDps => _lastSnapshotDps;

  /// Recalculate and cache team DPS without mutating any state.
  void snapshot() {
    var raw = 0.0;
    for (final hero in _party) {
      if (hero.isAlive) raw += hero.effectiveStats.attack;
    }
    _lastSnapshotDps = dpsPipeline.apply(raw);
  }
}
